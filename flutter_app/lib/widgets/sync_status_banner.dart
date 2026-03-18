import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Top banner showing offline/online status, pending draft count, last sync time.
/// Yellow when offline, green when synced, red when sync errors.
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    final isOnline = connectivity.when(
      data: (online) => online,
      loading: () => true,
      error: (_, __) => true,
    );

    final status = syncStatus.when(
      data: (s) => s,
      loading: () => const SyncStatus(),
      error: (_, __) => const SyncStatus(),
    );

    if (isOnline && status.totalPending == 0 && !status.hasErrors) {
      return const SizedBox.shrink();
    }

    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String message;

    if (!isOnline) {
      bgColor = Colors.amber.shade100;
      fgColor = Colors.amber.shade900;
      icon = Icons.cloud_off;
      message = 'Offline'
          '${status.totalPending > 0 ? ' · ${status.totalPending} pending' : ''}';
    } else if (status.hasErrors) {
      bgColor = Colors.red.shade50;
      fgColor = Colors.red.shade800;
      icon = Icons.sync_problem;
      message =
          '${status.failedDrafts} sync error${status.failedDrafts != 1 ? 's' : ''}';
    } else {
      bgColor = Colors.blue.shade50;
      fgColor = Colors.blue.shade800;
      icon = Icons.sync;
      message = '${status.totalPending} pending sync';
    }

    return Material(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (status.conflictCount > 0)
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/conflicts'),
                  icon: Icon(Icons.warning_amber, size: 14, color: fgColor),
                  label: Text(
                    '${status.conflictCount} conflict${status.conflictCount != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: fgColor),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
