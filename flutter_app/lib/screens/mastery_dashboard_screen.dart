import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/student.dart';
import '../providers/app_providers.dart';
class MasteryDashboardScreen extends ConsumerStatefulWidget {
  const MasteryDashboardScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<MasteryDashboardScreen> createState() =>
      _MasteryDashboardScreenState();
}

class _MasteryDashboardScreenState
    extends ConsumerState<MasteryDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _domainFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Mastery Dashboard')),
      body: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final domainsAsync = ref.watch(domainsProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Heatmap'),
          ],
        ),
        Expanded(
          child: studentsAsync.when(
            data: (students) => domainsAsync.when(
              data: (domains) => TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(
                    students: students,
                    domains: domains,
                    domainFilter: _domainFilter,
                    onDomainFilterChanged: (d) =>
                        setState(() => _domainFilter = d),
                  ),
                  _HeatmapTab(students: students),
                ],
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => _buildEmpty(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_outlined,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('No mastery data available',
              style: theme.textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(
            'Data will appear after observations are captured and synced',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.students,
    required this.domains,
    this.domainFilter,
    required this.onDomainFilterChanged,
  });

  final List<Student> students;
  final List<dynamic> domains;
  final String? domainFilter;
  final ValueChanged<String?> onDomainFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined,
                size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('No student data available',
                style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    final domainNames = <String>{};
    for (final s in students) {
      domainNames.addAll(s.domainMastery.keys);
    }
    final sortedDomains = domainNames.toList()..sort();

    final domainAverages = <String, double>{};
    for (final domain in sortedDomains) {
      final values = students
          .where((s) => s.domainMastery.containsKey(domain))
          .map((s) => s.domainMastery[domain]!)
          .toList();
      if (values.isNotEmpty) {
        domainAverages[domain] =
            values.reduce((a, b) => a + b) / values.length;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildClassSummary(context, theme),
        const SizedBox(height: 16),
        if (sortedDomains.length > 1) ...[
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: domainFilter == null,
                  onSelected: (_) => onDomainFilterChanged(null),
                ),
                const SizedBox(width: 8),
                ...sortedDomains.map((d) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(d),
                        selected: domainFilter == d,
                        onSelected: (_) => onDomainFilterChanged(
                            domainFilter == d ? null : d),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('Domain Averages', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...domainAverages.entries
            .where(
                (e) => domainFilter == null || e.key == domainFilter)
            .map((entry) => _DomainAggregateCard(
                  domainName: entry.key,
                  averageValue: entry.value,
                  studentCount: students
                      .where(
                          (s) => s.domainMastery.containsKey(entry.key))
                      .length,
                )),
      ],
    );
  }

  Widget _buildClassSummary(BuildContext context, ThemeData theme) {
    final studentsWithMastery =
        students.where((s) => s.overallMastery != null).toList();
    final avgMastery = studentsWithMastery.isNotEmpty
        ? studentsWithMastery
                .map((s) => s.overallMastery!)
                .reduce((a, b) => a + b) /
            studentsWithMastery.length
        : 0.0;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Class Overview',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    '${students.length} students · '
                    '${studentsWithMastery.length} assessed',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  '${(avgMastery * 100).round()}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'Avg Mastery',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer
                        .withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainAggregateCard extends StatelessWidget {
  const _DomainAggregateCard({
    required this.domainName,
    required this.averageValue,
    required this.studentCount,
  });

  final String domainName;
  final double averageValue;
  final int studentCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (averageValue * 100).round();
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
                Text(
                  '$pct%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _color(averageValue),
                  ),
                ),
                const SizedBox(width: 8),
                _trendIcon(averageValue),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: averageValue,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: _color(averageValue),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$studentCount students assessed',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Color _color(double v) {
    if (v >= 0.75) return Colors.green.shade600;
    if (v >= 0.5) return Colors.blue.shade500;
    if (v >= 0.25) return Colors.orange.shade400;
    return Colors.red.shade400;
  }

  Widget _trendIcon(double v) {
    if (v >= 0.6) {
      return const Icon(Icons.trending_up, color: Colors.green, size: 20);
    }
    if (v >= 0.3) {
      return const Icon(Icons.trending_flat, color: Colors.orange, size: 20);
    }
    return const Icon(Icons.trending_down, color: Colors.red, size: 20);
  }
}

class _HeatmapTab extends StatelessWidget {
  const _HeatmapTab({required this.students});
  final List<Student> students;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_on, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('No data for heatmap', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    final allDomains = <String>{};
    for (final s in students) {
      allDomains.addAll(s.domainMastery.keys);
    }
    final sortedDomains = allDomains.toList()..sort();

    if (sortedDomains.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_on, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('No mastery data recorded yet',
                style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Student × Domain Heatmap',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('Tap a cell to view details',
              style: theme.textTheme.labelSmall),
          const SizedBox(height: 12),
          _buildLegend(theme),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 48,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 40,
              columnSpacing: 4,
              columns: [
                const DataColumn(label: Text('Student')),
                ...sortedDomains.map((d) => DataColumn(
                      label: RotatedBox(
                        quarterTurns: -1,
                        child: Text(
                          d.length > 10 ? '${d.substring(0, 10)}…' : d,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    )),
              ],
              rows: students.map((student) {
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          student.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    ...sortedDomains.map((domain) {
                      final value = student.domainMastery[domain];
                      return DataCell(
                        _HeatmapCell(value: value),
                        onTap: () {
                          Navigator.of(context)
                              .pushNamed('/students/${student.id}');
                        },
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    return Row(
      children: [
        _legendItem(Colors.red.shade400, '0–25%'),
        const SizedBox(width: 12),
        _legendItem(Colors.orange.shade400, '25–50%'),
        const SizedBox(width: 12),
        _legendItem(Colors.blue.shade500, '50–75%'),
        const SizedBox(width: 12),
        _legendItem(Colors.green.shade600, '75–100%'),
        const SizedBox(width: 12),
        _legendItem(Colors.grey.shade300, 'N/A'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({this.value});
  final double? value;

  @override
  Widget build(BuildContext context) {
    final color = _cellColor(value);
    return Container(
      width: 36,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: value != null
          ? Text(
              '${(value! * 100).round()}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: value! > 0.5 ? Colors.white : Colors.black87,
              ),
            )
          : const Text('—', style: TextStyle(fontSize: 10, color: Colors.grey)),
    );
  }

  Color _cellColor(double? v) {
    if (v == null) return Colors.grey.shade200;
    if (v >= 0.75) return Colors.green.shade600;
    if (v >= 0.5) return Colors.blue.shade500;
    if (v >= 0.25) return Colors.orange.shade400;
    return Colors.red.shade400;
  }
}
