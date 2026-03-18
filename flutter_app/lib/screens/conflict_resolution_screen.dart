import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sync_conflict.dart';
import '../providers/app_providers.dart';

class ConflictResolutionScreen extends ConsumerWidget {
  const ConflictResolutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(unresolvedConflictsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Conflicts'),
      ),
      body: conflictsAsync.when(
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('No conflicts', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'All sync conflicts have been resolved',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: conflicts.length,
            itemBuilder: (ctx, i) => _ConflictCard(conflict: conflicts[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ConflictCard extends ConsumerStatefulWidget {
  const _ConflictCard({required this.conflict});
  final SyncConflict conflict;

  @override
  ConsumerState<_ConflictCard> createState() => _ConflictCardState();
}

class _ConflictCardState extends ConsumerState<_ConflictCard> {
  bool _expanded = false;
  bool _resolving = false;

  Map<String, dynamic>? get _deviceVersion {
    try {
      return jsonDecode(widget.conflict.deviceVersionJson)
          as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get _serverVersion {
    if (widget.conflict.serverVersionJson == null) return null;
    try {
      return jsonDecode(widget.conflict.serverVersionJson!)
          as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _resolve(String resolution) async {
    setState(() => _resolving = true);
    try {
      final syncService = ref.read(syncServiceProvider);
      final authState = ref.read(authStateProvider);
      await syncService.resolveConflicts(
        draftLocalId: widget.conflict.draftLocalId,
        resolution: resolution,
        resolvedBy: authState.userId,
      );
      ref.invalidate(unresolvedConflictsProvider);
      ref.invalidate(syncStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conflict resolved: $resolution'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflict = widget.conflict;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber,
                  color: Colors.orange.shade800),
            ),
            title: Text(
              conflict.conflictType,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'Draft: ${_truncateId(conflict.draftLocalId)}',
              style: theme.textTheme.labelSmall,
            ),
            trailing: IconButton(
              icon: Icon(_expanded
                  ? Icons.expand_less
                  : Icons.expand_more),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _VersionColumn(
                      title: 'Your Version',
                      icon: Icons.phone_android,
                      color: theme.colorScheme.primary,
                      data: _deviceVersion,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 120,
                    color: theme.colorScheme.outlineVariant,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _VersionColumn(
                      title: 'Server Version',
                      icon: Icons.cloud,
                      color: Colors.teal,
                      data: _serverVersion,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _resolving
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _resolve('KEEP_DEVICE'),
                          icon: const Icon(Icons.phone_android, size: 16),
                          label: const Text('Keep Mine'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _resolve('KEEP_SERVER'),
                          icon: const Icon(Icons.cloud, size: 16),
                          label: const Text('Keep Server'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _resolve('MERGE'),
                          icon: const Icon(Icons.merge_type, size: 16),
                          label: const Text('Merge'),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _truncateId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}…';
  }
}

class _VersionColumn extends StatelessWidget {
  const _VersionColumn({
    required this.title,
    required this.icon,
    required this.color,
    this.data,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (data == null)
          Text('No data available',
              style: theme.textTheme.bodySmall)
        else
          ..._buildDataRows(theme),
      ],
    );
  }

  Iterable<Widget> _buildDataRows(ThemeData theme) {
    final displayKeys = [
      'numericValue',
      'observedAt',
      'timestampSource',
      'observationNote',
    ];
    return displayKeys
        .where((k) => data!.containsKey(k))
        .map((k) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatKey(k),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _formatValue(data![k]),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ));
  }

  String _formatKey(String key) {
    return key
        .replaceAllMapped(
            RegExp(r'[A-Z]'), (m) => ' ${m.group(0)!.toLowerCase()}')
        .trim()
        .replaceFirst(key[0], key[0].toUpperCase());
  }

  String _formatValue(dynamic value) {
    if (value == null) return '—';
    if (value is double) return '${(value * 100).round()}%';
    return value.toString();
  }
}
