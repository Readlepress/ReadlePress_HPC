import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/competency.dart';
import '../models/student.dart';
import '../providers/app_providers.dart';
import '../services/gps_timestamp_service.dart';
import '../widgets/competency_selector.dart';
import '../widgets/evidence_attachment.dart';
import '../widgets/mastery_level_indicator.dart';

class ObservationCaptureScreen extends ConsumerStatefulWidget {
  const ObservationCaptureScreen({super.key, this.initialStudentId});
  final String? initialStudentId;

  @override
  ConsumerState<ObservationCaptureScreen> createState() =>
      _ObservationCaptureScreenState();
}

class _ObservationCaptureScreenState
    extends ConsumerState<ObservationCaptureScreen> {
  int _currentStep = 0;
  static const _totalSteps = 6;

  Student? _selectedStudent;
  Competency? _selectedCompetency;
  DescriptorLevel? _selectedLevel;
  List<File> _evidenceFiles = [];
  final _noteController = TextEditingController();
  bool _isSaving = false;
  TimestampResult? _timestampResult;

  final _stepTitles = const [
    'Select Student',
    'Select Competency',
    'Mastery Level',
    'Add Evidence',
    'Observation Note',
    'Review & Save',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTimestamp();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchTimestamp() async {
    final gps = ref.read(gpsTimestampServiceProvider);
    final result = await gps.getTimestamp();
    if (mounted) setState(() => _timestampResult = result);
  }

  bool get _canAdvance {
    switch (_currentStep) {
      case 0:
        return _selectedStudent != null;
      case 1:
        return _selectedCompetency != null;
      case 2:
        return _selectedLevel != null;
      case 3:
        return true; // evidence is optional
      case 4:
        return _evidenceFiles.isNotEmpty ||
            _noteController.text.trim().isNotEmpty;
      case 5:
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1 && _canAdvance) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final captureService = ref.read(captureServiceProvider);
      final draft = await captureService.captureObservation(
        studentId: _selectedStudent!.id,
        competencyId: _selectedCompetency!.id,
        numericValue: _selectedLevel!.numericValue,
        descriptorLevelId: _selectedLevel!.id,
        observationNote: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        sourceType: 'DIRECT_OBSERVATION',
      );

      for (final file in _evidenceFiles) {
        await captureService.attachEvidence(
          draftLocalId: draft.localId,
          localFilePath: file.path,
          contentType: 'IMAGE',
          mimeType: 'image/jpeg',
        );
      }

      captureService.queueBackgroundSync();
      ref.invalidate(syncStatusProvider);
      ref.invalidate(allDraftsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observation saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitles[_currentStep]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: _buildStepContent(),
      bottomNavigationBar: _buildNavBar(theme),
    );
  }

  Widget _buildNavBar(ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (_currentStep > 0)
              OutlinedButton.icon(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
              ),
            const Spacer(),
            Text(
              '${_currentStep + 1} / $_totalSteps',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (_currentStep < _totalSteps - 1)
              FilledButton.icon(
                onPressed: _canAdvance ? _nextStep : null,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Next'),
              )
            else
              FilledButton.icon(
                onPressed: (!_isSaving && _canAdvance) ? _save : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_isSaving ? 'Saving…' : 'Save'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStudentStep();
      case 1:
        return _buildCompetencyStep();
      case 2:
        return _buildLevelStep();
      case 3:
        return _buildEvidenceStep();
      case 4:
        return _buildNoteStep();
      case 5:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStudentStep() {
    final studentsAsync = ref.watch(studentsProvider);
    return studentsAsync.when(
      data: (students) {
        if (students.isEmpty) {
          return const Center(child: Text('No students available'));
        }
        return _StudentSearchList(
          students: students,
          selectedId: _selectedStudent?.id,
          onSelected: (s) => setState(() => _selectedStudent = s),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading students: $e')),
    );
  }

  Widget _buildCompetencyStep() {
    return CompetencySelector(
      stageFilter: _selectedStudent?.stage,
      selectedId: _selectedCompetency?.id,
      onSelected: (c) => setState(() {
        _selectedCompetency = c;
        _selectedLevel = null;
      }),
    );
  }

  Widget _buildLevelStep() {
    final theme = Theme.of(context);
    final stage = _selectedStudent?.stage ?? 'FOUNDATIONAL';
    final levels = _selectedCompetency?.descriptorLevels.isNotEmpty == true
        ? _selectedCompetency!.descriptorLevels
        : _defaultLevels;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Select mastery level for:',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          _selectedCompetency?.name ?? '',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ...levels.map((level) {
          final selected = _selectedLevel?.id == level.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              elevation: selected ? 3 : 0,
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedLevel = level),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      MasteryLevelIndicator(
                        numericValue: level.numericValue,
                        stageCode: stage,
                        showLabel: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              level.label,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${(level.numericValue * 100).round()}%',
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle,
                            color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEvidenceStep() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add photographic evidence (optional)',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'If you skip evidence, an observation note will be required.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          EvidenceAttachment(
            initialFiles: _evidenceFiles,
            onFilesChanged: (files) => setState(() => _evidenceFiles = files),
          ),
          const Spacer(),
          if (_evidenceFiles.isEmpty)
            Center(
              child: TextButton(
                onPressed: _nextStep,
                child: const Text('Skip — add note instead'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteStep() {
    final theme = Theme.of(context);
    final required = _evidenceFiles.isEmpty;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required
                ? 'Observation Note (required)'
                : 'Observation Note (optional)',
            style: theme.textTheme.titleSmall,
          ),
          if (required) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 14, color: theme.colorScheme.error),
                const SizedBox(width: 4),
                Text(
                  'No evidence attached — note is required (no naked scoring)',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Describe what you observed…',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    final stage = _selectedStudent?.stage ?? 'FOUNDATIONAL';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Review Observation',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _ReviewRow(label: 'Student', value: _selectedStudent?.name ?? ''),
        _ReviewRow(
            label: 'Competency', value: _selectedCompetency?.name ?? ''),
        _ReviewRow(label: 'Competency Code',
            value: _selectedCompetency?.code ?? ''),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text('Mastery Level: ',
                  style: theme.textTheme.bodyMedium),
              if (_selectedLevel != null)
                MasteryLevelIndicator(
                  numericValue: _selectedLevel!.numericValue,
                  stageCode: stage,
                  size: MasteryIndicatorSize.medium,
                ),
            ],
          ),
        ),
        const Divider(),
        _ReviewRow(
          label: 'Evidence',
          value: _evidenceFiles.isEmpty
              ? 'None'
              : '${_evidenceFiles.length} photo${_evidenceFiles.length != 1 ? 's' : ''}',
        ),
        if (_noteController.text.trim().isNotEmpty)
          _ReviewRow(
            label: 'Note',
            value: _noteController.text.trim(),
          ),
        const Divider(),
        if (_timestampResult != null) ...[
          _ReviewRow(
            label: 'Timestamp Source',
            value: _timestampResult!.timestampSource,
          ),
          _ReviewRow(
            label: 'Confidence',
            value: _timestampResult!.timestampConfidence,
          ),
        ],
        const SizedBox(height: 8),
        _buildTimestampBadge(theme),
      ],
    );
  }

  Widget _buildTimestampBadge(ThemeData theme) {
    if (_timestampResult == null) return const SizedBox.shrink();
    final confidence = _timestampResult!.timestampConfidence;
    final Color color;
    final IconData icon;
    switch (confidence) {
      case 'HIGH':
        color = Colors.green;
        icon = Icons.gps_fixed;
        break;
      case 'MEDIUM':
        color = Colors.orange;
        icon = Icons.gps_not_fixed;
        break;
      default:
        color = Colors.red;
        icon = Icons.gps_off;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GPS Timestamp: ${_timestampResult!.timestampSource}',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  'Confidence: $confidence',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static final _defaultLevels = [
    const DescriptorLevel(
        id: 'default_l1',
        label: 'Beginning',
        numericValue: 0.125,
        sortOrder: 0),
    const DescriptorLevel(
        id: 'default_l2',
        label: 'Developing',
        numericValue: 0.375,
        sortOrder: 1),
    const DescriptorLevel(
        id: 'default_l3',
        label: 'Proficient',
        numericValue: 0.625,
        sortOrder: 2),
    const DescriptorLevel(
        id: 'default_l4',
        label: 'Advanced',
        numericValue: 0.875,
        sortOrder: 3),
  ];
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _StudentSearchList extends StatefulWidget {
  const _StudentSearchList({
    required this.students,
    this.selectedId,
    required this.onSelected,
  });

  final List<Student> students;
  final String? selectedId;
  final ValueChanged<Student> onSelected;

  @override
  State<_StudentSearchList> createState() => _StudentSearchListState();
}

class _StudentSearchListState extends State<_StudentSearchList> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.students
        .where((s) =>
            _search.isEmpty ||
            s.name.toLowerCase().contains(_search.toLowerCase()) ||
            s.rollNumber.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search students…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final s = filtered[i];
              final selected = s.id == widget.selectedId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(s.name),
                subtitle: Text('Roll: ${s.rollNumber} · ${s.classSection}'),
                trailing: selected
                    ? Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                selected: selected,
                onTap: () => widget.onSelected(s),
              );
            },
          ),
        ),
      ],
    );
  }
}
