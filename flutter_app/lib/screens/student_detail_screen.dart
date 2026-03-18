import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mastery_event_draft.dart';
import '../models/student.dart';
import '../providers/app_providers.dart';
import '../widgets/mastery_level_indicator.dart';

class StudentDetailScreen extends ConsumerWidget {
  const StudentDetailScreen({super.key, required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);

    return studentsAsync.when(
      data: (students) {
        final matches = students.where((s) => s.id == studentId);
        final student = matches.isNotEmpty ? matches.first : null;
        if (student == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Student')),
            body: const Center(child: Text('Student not found')),
          );
        }
        return _StudentDetailView(student: student);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Student')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Student')),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StudentDetailView extends ConsumerWidget {
  const _StudentDetailView({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(student.name),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Overview'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Mastery'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(student: student),
            _MasteryTab(student: student),
            _HistoryTab(studentId: student.id),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).pushNamed('/capture'),
          icon: const Icon(Icons.add),
          label: const Text('New Observation'),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  student.name,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Roll Number: ${student.rollNumber}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _InfoRow(label: 'Class', value: student.classSection),
        _InfoRow(label: 'Stage', value: student.stage),
        _InfoRow(label: 'Enrolment Status', value: student.enrolmentStatus),
        _InfoRow(
          label: 'APAAR ID',
          value: student.apaarId != null ? student.maskedApaarId : 'Not assigned',
        ),
        _InfoRow(
          label: 'APAAR Verified',
          value: student.apaarVerified ? 'Yes ✓' : 'Pending',
          valueColor: student.apaarVerified ? Colors.green : Colors.orange,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryTab extends StatelessWidget {
  const _MasteryTab({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final domains = student.domainMastery;

    if (domains.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('No mastery data yet',
                style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              'Capture observations to see mastery levels',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (student.overallMastery != null) ...[
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Overall Mastery', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  MasteryLevelIndicator(
                    numericValue: student.overallMastery!,
                    stageCode: student.stage,
                    size: MasteryIndicatorSize.large,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...domains.entries.map((entry) => _DomainMasteryCard(
              domainName: entry.key,
              value: entry.value,
              stage: student.stage,
            )),
      ],
    );
  }
}

class _DomainMasteryCard extends StatelessWidget {
  const _DomainMasteryCard({
    required this.domainName,
    required this.value,
    required this.stage,
  });

  final String domainName;
  final double value;
  final String stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (value * 100).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    domainName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                MasteryLevelIndicator(
                  numericValue: value,
                  stageCode: stage,
                  size: MasteryIndicatorSize.small,
                  showLabel: false,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: _barColor(value),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$pct%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _barColor(value),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _barColor(double v) {
    if (v >= 0.75) return Colors.green.shade600;
    if (v >= 0.5) return Colors.blue.shade500;
    if (v >= 0.25) return Colors.orange.shade400;
    return Colors.red.shade400;
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.studentId});
  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(allDraftsProvider);
    final theme = Theme.of(context);

    return draftsAsync.when(
      data: (allDrafts) {
        final drafts = allDrafts
            .where((d) => d.studentId == studentId)
            .toList()
          ..sort((a, b) => b.observedAt.compareTo(a.observedAt));

        if (drafts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history,
                    size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 12),
                Text('No observations yet',
                    style: theme.textTheme.bodyLarge),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drafts.length,
          itemBuilder: (ctx, i) => _HistoryEventCard(draft: drafts[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _HistoryEventCard extends StatelessWidget {
  const _HistoryEventCard({required this.draft});
  final MasteryEventDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncIcon = _syncIcon(draft.syncStatus);
    final syncColor = _syncColor(draft.syncStatus);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Competency: ${draft.competencyId}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(draft.observedAt),
                    style: theme.textTheme.labelSmall,
                  ),
                  if (draft.observationNote != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      draft.observationNote!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  '${(draft.numericValue * 100).round()}%',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Icon(syncIcon, size: 16, color: syncColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _syncIcon(String status) {
    switch (status) {
      case 'SYNCED':
        return Icons.cloud_done;
      case 'PENDING':
        return Icons.cloud_upload;
      case 'FAILED':
        return Icons.cloud_off;
      case 'CONFLICT':
        return Icons.warning;
      default:
        return Icons.cloud_queue;
    }
  }

  Color _syncColor(String status) {
    switch (status) {
      case 'SYNCED':
        return Colors.green;
      case 'PENDING':
        return Colors.blue;
      case 'FAILED':
        return Colors.red;
      case 'CONFLICT':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}
