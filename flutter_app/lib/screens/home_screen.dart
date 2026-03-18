import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../widgets/sync_status_banner.dart';
import 'mastery_dashboard_screen.dart';
import 'settings_screen.dart';
import 'student_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  String get _title {
    switch (_selectedIndex) {
      case 0:
        return 'ReadlePress';
      case 1:
        return 'Students';
      case 2:
        return 'Capture';
      case 3:
        return 'Mastery Dashboard';
      case 4:
        return 'Settings';
      default:
        return 'ReadlePress';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        centerTitle: _selectedIndex == 0,
        actions: _buildActions(),
      ),
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Capture',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  List<Widget>? _buildActions() {
    if (_selectedIndex == 0) {
      final syncStatus = ref.watch(syncStatusProvider);
      final pending = syncStatus.when(
        data: (s) => s.totalPending,
        loading: () => 0,
        error: (_, __) => 0,
      );
      return [
        if (pending > 0)
          Badge(
            label: Text('$pending'),
            child: IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () => _triggerSync(),
              tooltip: 'Sync now',
            ),
          ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {},
          tooltip: 'Notifications',
        ),
      ];
    }
    return null;
  }

  Future<void> _triggerSync() async {
    final authState = ref.read(authStateProvider);
    final syncService = ref.read(syncServiceProvider);
    try {
      await syncService.syncPendingEvidence(storageProviderId: 'local');
      await syncService.syncPendingDrafts(teacherId: authState.userId);
      ref.invalidate(syncStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync complete'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _HomeDashboard(
          onNavigateToTab: (i) => setState(() => _selectedIndex = i),
        );
      case 1:
        return const StudentListScreen(embedded: true);
      case 2:
        return const _CaptureEntryView();
      case 3:
        return const MasteryDashboardScreen(embedded: true);
      case 4:
        return const SettingsScreen(embedded: true);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard({required this.onNavigateToTab});

  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(syncStatusProvider);
        ref.invalidate(studentsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeCard(context, theme, authState),
          const SizedBox(height: 16),
          _buildSyncStatusCard(context, theme, syncStatus),
          const SizedBox(height: 20),
          Text('Quick Actions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildActionGrid(context, theme),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(
      BuildContext context, ThemeData theme, AuthState authState) {
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                authState.teacherName.isNotEmpty
                    ? authState.teacherName[0].toUpperCase()
                    : 'T',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${authState.teacherName}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (authState.schoolName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      authState.schoolName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withOpacity(0.8),
                      ),
                    ),
                  ],
                  if (authState.classSection.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Class ${authState.classSection}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(
    BuildContext context,
    ThemeData theme,
    AsyncValue<SyncStatus> syncAsync,
  ) {
    final status = syncAsync.when(
      data: (s) => s,
      loading: () => const SyncStatus(),
      error: (_, __) => const SyncStatus(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              status.totalPending == 0
                  ? Icons.cloud_done
                  : Icons.cloud_upload_outlined,
              color: status.totalPending == 0
                  ? Colors.green
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.totalPending == 0
                        ? 'All synced'
                        : '${status.totalPending} pending',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${status.pendingDrafts} drafts · ${status.pendingEvidence} evidence',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            if (status.conflictCount > 0)
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/conflicts'),
                child: Text('${status.conflictCount} conflicts'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, ThemeData theme) {
    final actions = [
      _ActionItem(
        icon: Icons.camera_alt,
        label: 'Capture\nObservation',
        color: theme.colorScheme.primary,
        onTap: () => Navigator.of(context).pushNamed('/capture'),
      ),
      _ActionItem(
        icon: Icons.people,
        label: 'View\nStudents',
        color: Colors.teal,
        onTap: () => onNavigateToTab(1),
      ),
      _ActionItem(
        icon: Icons.assessment,
        label: 'Rubric\nAssessment',
        color: Colors.deepPurple,
        onTap: () => Navigator.of(context).pushNamed('/rubric'),
      ),
      _ActionItem(
        icon: Icons.dashboard,
        label: 'Mastery\nDashboard',
        color: Colors.amber.shade800,
        onTap: () => onNavigateToTab(3),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: actions.map((a) => _buildActionCard(theme, a)).toList(),
    );
  }

  Widget _buildActionCard(ThemeData theme, _ActionItem action) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, size: 32, color: action.color),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _CaptureEntryView extends StatelessWidget {
  const _CaptureEntryView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Capture Observation',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Record student mastery levels with evidence.\nWorks fully offline.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/capture'),
              icon: const Icon(Icons.add),
              label: const Text('New Observation'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/rubric'),
              icon: const Icon(Icons.assessment),
              label: const Text('Rubric Assessment'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
