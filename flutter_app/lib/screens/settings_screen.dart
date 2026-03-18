import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedLanguage = 'English';
  bool _wifiOnly = false;
  int _syncIntervalMinutes = 15;

  static const _languages = [
    'English',
    'हिन्दी (Hindi)',
    'বাংলা (Bengali)',
    'తెలుగు (Telugu)',
    'मराठी (Marathi)',
    'தமிழ் (Tamil)',
    'ગુજરાતી (Gujarati)',
    'ಕನ್ನಡ (Kannada)',
    'ଓଡ଼ିଆ (Odia)',
    'മലയാളം (Malayalam)',
    'ਪੰਜਾਬੀ (Punjabi)',
    'অসমীয়া (Assamese)',
    'मैथिली (Maithili)',
    'سنڌي (Sindhi)',
    'संस्कृतम् (Sanskrit)',
    'डोगरी (Dogri)',
    'नेपाली (Nepali)',
    'कोंकणी (Konkani)',
    'मणिपुरी (Manipuri)',
    'بوڈو (Bodo)',
    'संताली (Santali)',
    'کشمیری (Kashmiri)',
  ];

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildProfileSection(theme, authState),
        const Divider(),
        _buildLanguageSection(theme),
        const Divider(),
        _buildSyncSection(theme, syncStatus),
        const Divider(),
        _buildDeviceSection(theme),
        const Divider(),
        _buildLogoutSection(theme),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProfileSection(ThemeData theme, AuthState authState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      authState.teacherName.isNotEmpty
                          ? authState.teacherName[0].toUpperCase()
                          : 'T',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.teacherName,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (authState.schoolName.isNotEmpty)
                          Text(authState.schoolName,
                              style: theme.textTheme.bodySmall),
                        Text(
                          'Role: ${authState.role}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Language',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: const Text('App Language'),
              subtitle: Text(_selectedLanguage),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguagePicker(theme),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
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
            Text('Select Language',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: _languages.length,
                itemBuilder: (ctx, i) {
                  final lang = _languages[i];
                  final selected = lang == _selectedLanguage;
                  return ListTile(
                    title: Text(lang),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() => _selectedLanguage = lang);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSection(
      ThemeData theme, AsyncValue<SyncStatus> syncAsync) {
    final status = syncAsync.when(
      data: (s) => s,
      loading: () => const SyncStatus(),
      error: (_, __) => const SyncStatus(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sync',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Pending Sync'),
                  trailing: Badge(
                    label: Text('${status.totalPending}'),
                    child: const Icon(Icons.cloud_upload_outlined),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Auto-sync Interval'),
                  subtitle: Text('Every $_syncIntervalMinutes minutes'),
                  trailing: DropdownButton<int>(
                    value: _syncIntervalMinutes,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 min')),
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _syncIntervalMinutes = v);
                      }
                    },
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.wifi),
                  title: const Text('WiFi Only'),
                  subtitle: const Text('Sync only on WiFi'),
                  value: _wifiOnly,
                  onChanged: (v) => setState(() => _wifiOnly = v),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _triggerManualSync(),
                      icon: const Icon(Icons.sync),
                      label: Text(
                        'Sync Now (${status.totalPending} pending)',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerManualSync() async {
    final authState = ref.read(authStateProvider);
    final syncService = ref.read(syncServiceProvider);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syncing…')),
      );
      await syncService.syncPendingEvidence(storageProviderId: 'local');
      await syncService.syncPendingDrafts(teacherId: authState.userId);
      ref.invalidate(syncStatusProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sync complete'), backgroundColor: Colors.green),
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

  Widget _buildDeviceSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Device',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.phone_android),
                  title: Text('Device ID'),
                  subtitle: Text('Auto-generated'),
                ),
                ListTile(
                  leading: Icon(Icons.gps_fixed),
                  title: Text('Last GPS Fix'),
                  subtitle: Text('Pending…'),
                ),
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('App Version'),
                  subtitle: Text('0.1.0+1'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _confirmLogout(),
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Logout', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.red),
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? '
          'Unsynced observations will be kept locally.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authStateProvider.notifier).logout();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
