import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/competency.dart';
import '../providers/app_providers.dart';
import '../widgets/evidence_attachment.dart';
import '../widgets/mastery_level_indicator.dart';

class RubricAssessmentScreen extends ConsumerStatefulWidget {
  const RubricAssessmentScreen({super.key});

  @override
  ConsumerState<RubricAssessmentScreen> createState() =>
      _RubricAssessmentScreenState();
}

class _RubricAssessmentScreenState
    extends ConsumerState<RubricAssessmentScreen> {
  RubricTemplate? _selectedTemplate;
  final Map<String, DescriptorLevel?> _dimensionSelections = {};
  final Map<String, TextEditingController> _dimensionNotes = {};
  List<File> _evidenceFiles = [];
  final Set<String> _selectedStudentIds = {};
  bool _groupMode = false;
  bool _isSaving = false;

  static final _sampleTemplates = [
    RubricTemplate(
      id: 'rubric_1',
      name: 'Foundational Literacy Assessment',
      stage: 'FOUNDATIONAL',
      dimensions: [
        RubricDimension(
          id: 'dim_1',
          name: 'Letter Recognition',
          descriptorLevels: _defaultLevels,
        ),
        RubricDimension(
          id: 'dim_2',
          name: 'Word Reading',
          descriptorLevels: _defaultLevels,
        ),
        RubricDimension(
          id: 'dim_3',
          name: 'Sentence Comprehension',
          descriptorLevels: _defaultLevels,
        ),
      ],
    ),
    RubricTemplate(
      id: 'rubric_2',
      name: 'Numeracy Assessment',
      stage: 'FOUNDATIONAL',
      dimensions: [
        RubricDimension(
          id: 'dim_4',
          name: 'Number Recognition',
          descriptorLevels: _defaultLevels,
        ),
        RubricDimension(
          id: 'dim_5',
          name: 'Basic Operations',
          descriptorLevels: _defaultLevels,
        ),
        RubricDimension(
          id: 'dim_6',
          name: 'Problem Solving',
          descriptorLevels: _defaultLevels,
        ),
      ],
    ),
  ];

  static final _defaultLevels = [
    const DescriptorLevel(
        id: 'r_l1', label: 'Beginning', numericValue: 0.125, sortOrder: 0),
    const DescriptorLevel(
        id: 'r_l2', label: 'Developing', numericValue: 0.375, sortOrder: 1),
    const DescriptorLevel(
        id: 'r_l3', label: 'Proficient', numericValue: 0.625, sortOrder: 2),
    const DescriptorLevel(
        id: 'r_l4', label: 'Advanced', numericValue: 0.875, sortOrder: 3),
  ];

  @override
  void dispose() {
    for (final c in _dimensionNotes.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit =>
      _selectedTemplate != null &&
      (_groupMode
          ? _selectedStudentIds.isNotEmpty
          : _selectedStudentIds.length == 1) &&
      _dimensionSelections.values.every((v) => v != null) &&
      _dimensionSelections.length == _selectedTemplate!.dimensions.length &&
      !_isSaving;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSaving = true);

    try {
      final captureService = ref.read(captureServiceProvider);
      int savedCount = 0;

      for (final studentId in _selectedStudentIds) {
        for (final dim in _selectedTemplate!.dimensions) {
          final level = _dimensionSelections[dim.id];
          if (level == null) continue;

          final note = _dimensionNotes[dim.id]?.text.trim();
          final draft = await captureService.captureObservation(
            studentId: studentId,
            competencyId: dim.id,
            numericValue: level.numericValue,
            descriptorLevelId: level.id,
            observationNote: note?.isNotEmpty == true ? note : null,
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
          savedCount++;
        }
      }

      captureService.queueBackgroundSync();
      ref.invalidate(syncStatusProvider);
      ref.invalidate(allDraftsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$savedCount assessments saved'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        title: const Text('Rubric Assessment'),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Group', style: theme.textTheme.labelMedium),
              Switch(
                value: _groupMode,
                onChanged: (v) => setState(() {
                  _groupMode = v;
                  if (!v && _selectedStudentIds.length > 1) {
                    final first = _selectedStudentIds.first;
                    _selectedStudentIds
                      ..clear()
                      ..add(first);
                  }
                }),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTemplateSelector(theme),
          const SizedBox(height: 16),
          _buildStudentSelector(theme),
          if (_selectedTemplate != null) ...[
            const SizedBox(height: 20),
            Text(
              _selectedTemplate!.name,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Stage: ${_selectedTemplate!.stage}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 16),
            ..._selectedTemplate!.dimensions
                .map((dim) => _buildDimensionCard(theme, dim)),
            const SizedBox(height: 16),
            EvidenceAttachment(
              onFilesChanged: (f) => setState(() => _evidenceFiles = f),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving
                    ? 'Saving…'
                    : _groupMode
                        ? 'Submit for ${_selectedStudentIds.length} students'
                        : 'Submit Assessment'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rubric Template', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ..._sampleTemplates.map((t) {
          final selected = _selectedTemplate?.id == t.id;
          return Card(
            color: selected
                ? theme.colorScheme.primaryContainer
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(t.name),
              subtitle: Text(
                  '${t.dimensions.length} dimensions · ${t.stage}'),
              trailing: selected
                  ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                  : null,
              onTap: () => setState(() {
                _selectedTemplate = t;
                _dimensionSelections.clear();
                _dimensionNotes.clear();
              }),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStudentSelector(ThemeData theme) {
    final studentsAsync = ref.watch(studentsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _groupMode ? 'Select Students' : 'Select Student',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        studentsAsync.when(
          data: (students) {
            if (students.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No students available'),
                ),
              );
            }
            return Card(
              child: ExpansionTile(
                title: Text(
                  _selectedStudentIds.isEmpty
                      ? 'Tap to select'
                      : '${_selectedStudentIds.length} selected',
                ),
                children: students.map((s) {
                  final selected = _selectedStudentIds.contains(s.id);
                  return CheckboxListTile(
                    value: selected,
                    title: Text(s.name),
                    subtitle: Text('Roll: ${s.rollNumber}'),
                    onChanged: (v) => setState(() {
                      if (!_groupMode) _selectedStudentIds.clear();
                      if (v == true) {
                        _selectedStudentIds.add(s.id);
                      } else {
                        _selectedStudentIds.remove(s.id);
                      }
                    }),
                  );
                }).toList(),
              ),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Card(child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Failed to load students'),
              )),
        ),
      ],
    );
  }

  Widget _buildDimensionCard(ThemeData theme, RubricDimension dimension) {
    final selectedLevel = _dimensionSelections[dimension.id];
    if (!_dimensionNotes.containsKey(dimension.id)) {
      _dimensionNotes[dimension.id] = TextEditingController();
    }
    final noteController = _dimensionNotes[dimension.id]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dimension.name,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: dimension.descriptorLevels.map((level) {
                final selected = selectedLevel?.id == level.id;
                return ChoiceChip(
                  selected: selected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MasteryLevelIndicator(
                        numericValue: level.numericValue,
                        stageCode:
                            _selectedTemplate?.stage ?? 'FOUNDATIONAL',
                        size: MasteryIndicatorSize.small,
                        showLabel: false,
                      ),
                      const SizedBox(width: 4),
                      Text(level.label),
                    ],
                  ),
                  onSelected: (_) => setState(
                      () => _dimensionSelections[dimension.id] = level),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Notes for ${dimension.name} (optional)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
