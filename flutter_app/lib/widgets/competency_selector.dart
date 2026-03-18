import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/competency.dart';
import '../providers/app_providers.dart';

/// Competency picker grouped by domain with search and domain color coding.
class CompetencySelector extends ConsumerStatefulWidget {
  const CompetencySelector({
    super.key,
    this.stageFilter,
    required this.onSelected,
    this.selectedId,
  });

  final String? stageFilter;
  final ValueChanged<Competency> onSelected;
  final String? selectedId;

  @override
  ConsumerState<CompetencySelector> createState() => _CompetencySelectorState();
}

class _CompetencySelectorState extends ConsumerState<CompetencySelector> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final domainsAsync = ref.watch(domainsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search competencies…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: domainsAsync.when(
            data: (domains) => _buildDomainList(context, domains),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Failed to load competencies',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDomainList(BuildContext context, List<Domain> domains) {
    final filtered = _filterDomains(domains);
    if (filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No competencies found'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, i) => _buildDomainGroup(context, filtered[i]),
    );
  }

  List<Domain> _filterDomains(List<Domain> domains) {
    return domains
        .map((domain) {
          final filtered = domain.competencies.where((c) {
            if (widget.stageFilter != null &&
                c.stage.toUpperCase() != widget.stageFilter!.toUpperCase()) {
              return false;
            }
            if (_search.isNotEmpty) {
              return c.name.toLowerCase().contains(_search) ||
                  c.code.toLowerCase().contains(_search) ||
                  domain.name.toLowerCase().contains(_search);
            }
            return true;
          }).toList();
          return Domain(
            id: domain.id,
            name: domain.name,
            color: domain.color,
            competencies: filtered,
          );
        })
        .where((d) => d.competencies.isNotEmpty)
        .toList();
  }

  Widget _buildDomainGroup(BuildContext context, Domain domain) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: domain.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: domain.color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: domain.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    domain.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: domain.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${domain.competencies.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: domain.color.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...domain.competencies.map((c) => _buildCompetencyTile(context, c)),
        ],
      ),
    );
  }

  Widget _buildCompetencyTile(BuildContext context, Competency comp) {
    final isSelected = comp.id == widget.selectedId;
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      margin: const EdgeInsets.only(top: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          child: Text(
            comp.code.isNotEmpty
                ? comp.code.substring(0, comp.code.length.clamp(0, 2))
                : '?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        title: Text(
          comp.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(comp.code, style: theme.textTheme.labelSmall),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
            : null,
        onTap: () => widget.onSelected(comp),
      ),
    );
  }
}

/// Compact modal bottom sheet for competency selection.
Future<Competency?> showCompetencyPicker(
  BuildContext context, {
  String? stageFilter,
  String? selectedId,
}) {
  return showModalBottomSheet<Competency>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Column(
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
          Text(
            'Select Competency',
            style: Theme.of(ctx).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CompetencySelector(
              stageFilter: stageFilter,
              selectedId: selectedId,
              onSelected: (comp) => Navigator.of(ctx).pop(comp),
            ),
          ),
        ],
      ),
    ),
  );
}
