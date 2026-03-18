import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/competency.dart';
import '../models/student.dart';
import '../providers/app_providers.dart';
import '../services/gps_timestamp_service.dart';
import 'evidence_attachment.dart';
import 'mastery_level_indicator.dart';

/// Observation form widget used inside ObservationCaptureScreen.
/// Handles student selection, competency choice, descriptor level,
/// evidence attachment, notes, and GPS timestamp display.
class ObservationForm extends ConsumerStatefulWidget {
  const ObservationForm({
    super.key,
    this.preselectedStudent,
    this.onSaved,
  });

  final Student? preselectedStudent;
  final VoidCallback? onSaved;

  @override
  ConsumerState<ObservationForm> createState() => _ObservationFormState();
}

class _ObservationFormState extends ConsumerState<ObservationForm> {
  Student? _selectedStudent;
  Competency? _selectedCompetency;
  DescriptorLevel? _selectedLevel;
  List<File> _evidenceFiles = [];
  final _noteController = TextEditingController();
  bool _isSaving = false;
  TimestampResult? _timestampResult;

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.preselectedStudent;
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

  bool get _hasEvidence => _evidenceFiles.isNotEmpty;
  bool get _hasNote => _noteController.text.trim().isNotEmpty;
  bool get _meetsEvidenceRequirement => _hasEvidence || _hasNote;

  bool get _canSave =>
      _selectedStudent != null &&
      _selectedCompetency != null &&
      _selectedLevel != null &&
      _meetsEvidenceRequirement &&
      !_isSaving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    try {
      final captureService = ref.read(captureServiceProvider);
      final draft = await captureService.captureObservation(
        studentId: _selectedStudent!.id,
        competencyId: _selectedCompetency!.id,
        numericValue: _selectedLevel!.numericValue,
        descriptorLevelId: _selectedLevel!.id,
        observationNote:
            _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observation saved'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStudentField(theme),
          const SizedBox(height: 16),
          _buildCompetencyField(theme),
          const SizedBox(height: 16),
          if (_selectedCompetency != null) ...[
            _buildDescriptorLevels(theme),
            const SizedBox(height: 16),
          ],
          EvidenceAttachment(
            onFilesChanged: (files) => setState(() => _evidenceFiles = files),
          ),
          const SizedBox(height: 16),
          _buildNoteField(theme),
          const SizedBox(height: 12),
          _buildTimestampInfo(theme),
          const SizedBox(height: 24),
          if (!_meetsEvidenceRequirement &&
              _selectedLevel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Add evidence or an observation note (no naked scoring)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canSave ? _save : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving…' : 'Save Observation'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentField(ThemeData theme) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _selectedStudent != null
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            _selectedStudent != null ? Icons.person : Icons.person_add,
            color: _selectedStudent != null
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          _selectedStudent?.name ?? 'Select Student',
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: _selectedStudent != null
            ? Text('Roll: ${_selectedStudent!.rollNumber}')
            : const Text('Tap to choose'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final students = ref.read(studentsProvider).valueOrNull ?? [];
          final picked = await _showStudentPicker(context, students);
          if (picked != null) setState(() => _selectedStudent = picked);
        },
      ),
    );
  }

  Widget _buildCompetencyField(ThemeData theme) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _selectedCompetency != null
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.school,
            color: _selectedCompetency != null
                ? theme.colorScheme.tertiary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          _selectedCompetency?.name ?? 'Select Competency',
          style: theme.textTheme.bodyLarge,
        ),
        subtitle: _selectedCompetency != null
            ? Text(_selectedCompetency!.code)
            : const Text('Tap to choose'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final result = await showModalBottomSheet<Competency>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Select Competency',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _CompetencyPickerInline(
                      stageFilter: _selectedStudent?.stage,
                      selectedId: _selectedCompetency?.id,
                      onSelected: (c) => Navigator.of(ctx).pop(c),
                    ),
                  ),
                ],
              ),
            ),
          );
          if (result != null) {
            setState(() {
              _selectedCompetency = result;
              _selectedLevel = null;
            });
          }
        },
      ),
    );
  }

  Widget _buildDescriptorLevels(ThemeData theme) {
    final levels = _selectedCompetency?.descriptorLevels ?? [];
    if (levels.isEmpty) {
      return _buildDefaultDescriptorLevels(theme);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mastery Level', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...levels.map((level) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ChoiceChip(
                selected: _selectedLevel?.id == level.id,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MasteryLevelIndicator(
                      numericValue: level.numericValue,
                      stageCode: _selectedStudent?.stage ?? 'FOUNDATIONAL',
                      size: MasteryIndicatorSize.small,
                      showLabel: false,
                    ),
                    const SizedBox(width: 8),
                    Text(level.label),
                  ],
                ),
                onSelected: (_) => setState(() => _selectedLevel = level),
              ),
            )),
      ],
    );
  }

  Widget _buildDefaultDescriptorLevels(ThemeData theme) {
    final stage = _selectedStudent?.stage ?? 'FOUNDATIONAL';
    const defaults = [
      DescriptorLevel(id: 'l1', label: 'Beginning', numericValue: 0.125, sortOrder: 0),
      DescriptorLevel(id: 'l2', label: 'Developing', numericValue: 0.375, sortOrder: 1),
      DescriptorLevel(id: 'l3', label: 'Proficient', numericValue: 0.625, sortOrder: 2),
      DescriptorLevel(id: 'l4', label: 'Advanced', numericValue: 0.875, sortOrder: 3),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mastery Level', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: defaults.map((level) {
            final selected = _selectedLevel?.id == level.id;
            return ChoiceChip(
              selected: selected,
              label: MasteryLevelIndicator(
                numericValue: level.numericValue,
                stageCode: stage,
                size: MasteryIndicatorSize.small,
              ),
              onSelected: (_) => setState(() => _selectedLevel = level),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNoteField(ThemeData theme) {
    final required = !_hasEvidence;
    return TextField(
      controller: _noteController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: required ? 'Observation Note *' : 'Observation Note',
        hintText: 'Describe what you observed…',
        border: const OutlineInputBorder(),
        helperText: required ? 'Required when no evidence is attached' : null,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildTimestampInfo(ThemeData theme) {
    if (_timestampResult == null) return const SizedBox.shrink();
    final source = _timestampResult!.timestampSource;
    final confidence = _timestampResult!.timestampConfidence;
    final IconData icon;
    final Color color;
    switch (confidence) {
      case 'HIGH':
        icon = Icons.gps_fixed;
        color = Colors.green;
        break;
      case 'MEDIUM':
        icon = Icons.gps_not_fixed;
        color = Colors.orange;
        break;
      default:
        icon = Icons.gps_off;
        color = Colors.red;
    }
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          'Timestamp: $source ($confidence)',
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }

  Future<Student?> _showStudentPicker(
    BuildContext context,
    List<Student> students,
  ) {
    return showModalBottomSheet<Student>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StudentPickerSheet(students: students),
    );
  }
}

class _StudentPickerSheet extends StatefulWidget {
  const _StudentPickerSheet({required this.students});
  final List<Student> students;

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.students
        .where((s) =>
            _search.isEmpty ||
            s.name.toLowerCase().contains(_search.toLowerCase()) ||
            s.rollNumber.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Select Student',
              style: Theme.of(ctx).textTheme.titleMedium),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or roll number…',
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
              controller: controller,
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final s = filtered[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(s.name),
                  subtitle: Text('Roll: ${s.rollNumber}'),
                  onTap: () => Navigator.of(ctx).pop(s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompetencyPickerInline extends ConsumerStatefulWidget {
  const _CompetencyPickerInline({
    this.stageFilter,
    this.selectedId,
    required this.onSelected,
  });

  final String? stageFilter;
  final String? selectedId;
  final ValueChanged<Competency> onSelected;

  @override
  ConsumerState<_CompetencyPickerInline> createState() =>
      _CompetencyPickerInlineState();
}

class _CompetencyPickerInlineState
    extends ConsumerState<_CompetencyPickerInline> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final domainsAsync = ref.watch(domainsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search…',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: domainsAsync.when(
            data: (domains) {
              final filtered = domains
                  .map((d) => Domain(
                        id: d.id,
                        name: d.name,
                        color: d.color,
                        competencies: d.competencies.where((c) {
                          if (widget.stageFilter != null &&
                              c.stage.toUpperCase() !=
                                  widget.stageFilter!.toUpperCase()) {
                            return false;
                          }
                          if (_search.isNotEmpty) {
                            return c.name.toLowerCase().contains(_search) ||
                                c.code.toLowerCase().contains(_search);
                          }
                          return true;
                        }).toList(),
                      ))
                  .where((d) => d.competencies.isNotEmpty)
                  .toList();
              return ListView(
                children: filtered
                    .expand((d) => [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              d.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: d.color,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          ...d.competencies.map((c) => ListTile(
                                dense: true,
                                selected: c.id == widget.selectedId,
                                title: Text(c.name),
                                subtitle: Text(c.code),
                                trailing: c.id == widget.selectedId
                                    ? const Icon(Icons.check_circle)
                                    : null,
                                onTap: () => widget.onSelected(c),
                              )),
                        ])
                    .toList(),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Failed to load')),
          ),
        ),
      ],
    );
  }
}
