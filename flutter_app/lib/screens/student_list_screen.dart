import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/student.dart';
import '../providers/app_providers.dart';
import '../widgets/mastery_level_indicator.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: studentsAsync.when(
            data: (students) => _buildStudentList(context, students),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _buildError(context, e),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentList(BuildContext context, List<Student> students) {
    final filtered = students
        .where((s) =>
            _searchQuery.isEmpty ||
            s.name.toLowerCase().contains(_searchQuery) ||
            s.rollNumber.toLowerCase().contains(_searchQuery))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              students.isEmpty ? 'No students found' : 'No matching students',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (students.isEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Students will appear after sync',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(studentsProvider),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (ctx, i) => _StudentTile(student: filtered[i]),
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text('Unable to load students',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.invalidate(studentsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        title: Text(
          student.name,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Text('Roll: ${student.rollNumber}'),
            if (student.apaarId != null) ...[
              const SizedBox(width: 8),
              Text(
                'APAAR: ${student.maskedApaarId}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (student.lastObservationDate != null) ...[
              Text(
                _formatDate(student.lastObservationDate!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
            ],
            MasteryDot(numericValue: student.overallMastery),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: () =>
            Navigator.of(context).pushNamed('/students/${student.id}'),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}
