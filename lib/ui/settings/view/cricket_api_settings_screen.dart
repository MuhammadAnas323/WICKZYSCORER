import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import 'package:sportyapp/data/models/cricket_api_config.dart';
import 'package:sportyapp/data/providers/cricket_api_provider.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class CricketApiSettingsScreen extends ConsumerWidget {
  const CricketApiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cricketApiProvider);
    final notifier = ref.read(cricketApiProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cricket API Settings',
            style: AppTextStyles.headlineSmall(cs.onBackground)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh All APIs',
            onPressed: () => notifier.refreshFeeds(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'clear_all') {
                _confirmClearAll(context, ref);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Clear All APIs', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditApiDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Cricket API'),
        backgroundColor: AppColors.pitchGreen,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => notifier.refreshFeeds(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Top Summary Stats Banner ──────────────────────────────────
            _buildSummaryBanner(context, state),
            const Gap(16),

            // ── Section Header ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CONNECTED API ENDPOINTS (${state.apis.length})',
                  style: AppTextStyles.labelSmall(cs.primary).copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Multi-API Active',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Gap(10),

            if (state.apis.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.api_rounded,
                        size: 48, color: Colors.grey),
                    const Gap(12),
                    Text('No Connected Cricket APIs',
                        style: AppTextStyles.titleMedium(cs.onBackground)),
                    const Gap(4),
                    Text(
                      'Tap "Add Cricket API" to connect your live channel endpoints.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                    const Gap(16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditApiDialog(context, ref),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add First API'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pitchGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...state.apis.map((api) => _CricketApiCard(
                    api: api,
                    isTesting: state.testingMap[api.id] == true,
                    onToggleActive: (val) =>
                        notifier.toggleApiActive(api.id, val),
                    onTest: () => notifier.testConnection(api.id),
                    onEdit: () =>
                        _showAddEditApiDialog(context, ref, existing: api),
                    onDelete: () => _confirmDeleteApi(context, ref, api),
                  )),

            const Gap(80), // Padding for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBanner(BuildContext context, CricketApiState state) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E3A2B), const Color(0xFF0F241A)]
              : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.pitchGreenLight.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pitchGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hub_rounded,
                color: AppColors.pitchGreenLight, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Multi-API System Active',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    )),
                const SizedBox(height: 2),
                Text(
                  'Fetching data simultaneously from active endpoints',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black.withOpacity(0.64),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Text(
                '${state.connectedCount}/${state.activeCount}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.pitchGreenLight,
                ),
              ),
              const Text(
                'Connected',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteApi(
      BuildContext context, WidgetRef ref, CricketApiConfig api) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete API Endpoint'),
        content: Text('Are you sure you want to remove "${api.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(cricketApiProvider.notifier).deleteApi(api.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted API "${api.name}"')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All APIs'),
        content: const Text(
            'Are you sure you want to remove all connected API configurations?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(cricketApiProvider.notifier).clearAllApis();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cleared all connected APIs')),
              );
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddEditApiDialog(BuildContext context, WidgetRef ref,
      {CricketApiConfig? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.endpointUrl ?? '');
    final keyCtrl = TextEditingController(text: existing?.apiKey ?? '');
    String selectedType = existing?.apiType ?? 'restJson';
    bool isActive = existing?.isActive ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      existing == null ? 'Add Cricket API' : 'Edit API Endpoint',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Gap(12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'API Name',
                    hintText: 'e.g. Cricbuzz Live API',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Endpoint URL',
                    hintText: 'https://api.example.com/cricket/live',
                    prefixIcon: Icon(Icons.link_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: keyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key (Optional)',
                    hintText: 'Enter API key or bearer token',
                    prefixIcon: Icon(Icons.key_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const Gap(12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'API Response Format',
                    prefixIcon: Icon(Icons.code_rounded),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'restJson', child: Text('REST JSON API')),
                    DropdownMenuItem(
                        value: 'cricbuzz', child: Text('Cricbuzz Feed Format')),
                    DropdownMenuItem(
                        value: 'm3uPlaylist', child: Text('M3U Live Stream')),
                    DropdownMenuItem(
                        value: 'customFeed', child: Text('Custom Feed')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedType = val);
                  },
                ),
                const Gap(12),
                SwitchListTile(
                  title: const Text('Active Endpoint'),
                  subtitle: const Text('Enable fetching data from this API'),
                  value: isActive,
                  onChanged: (val) => setModalState(() => isActive = val),
                ),
                const Gap(16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pitchGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final url = urlCtrl.text.trim();

                      if (name.isEmpty || url.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter API name and URL')),
                        );
                        return;
                      }

                      final config = CricketApiConfig(
                        id: existing?.id ?? const Uuid().v4(),
                        name: name,
                        endpointUrl: url,
                        apiKey: keyCtrl.text.trim(),
                        apiType: selectedType,
                        isActive: isActive,
                        isPreset: existing?.isPreset ?? false,
                        status: existing?.status ?? CricketApiStatus.idle,
                      );

                      if (existing == null) {
                        ref.read(cricketApiProvider.notifier).addApi(config);
                      } else {
                        ref.read(cricketApiProvider.notifier).updateApi(config);
                      }

                      Navigator.pop(ctx);
                    },
                    child: Text(existing == null ? 'Save API' : 'Update API',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
}

class _CricketApiCard extends StatelessWidget {
  final CricketApiConfig api;
  final bool isTesting;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CricketApiCard({
    required this.api,
    required this.isTesting,
    required this.onToggleActive,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (!api.isActive) {
      statusColor = Colors.grey;
      statusLabel = 'INACTIVE';
      statusIcon = Icons.power_settings_new_rounded;
    } else if (isTesting || api.status == CricketApiStatus.testing) {
      statusColor = Colors.orange;
      statusLabel = 'TESTING';
      statusIcon = Icons.sync_rounded;
    } else if (api.status == CricketApiStatus.connected) {
      statusColor = Colors.green;
      statusLabel = 'CONNECTED';
      statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = Colors.red;
      statusLabel = 'ERROR';
      statusIcon = Icons.error_rounded;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: api.isActive
              ? statusColor.withOpacity(0.3)
              : (isDark ? Colors.white10 : Colors.black12),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status dot indicator
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    api.name,
                    style: AppTextStyles.titleMedium(cs.onBackground)
                        .copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch(
                  value: api.isActive,
                  activeColor: AppColors.pitchGreen,
                  onChanged: onToggleActive,
                ),
              ],
            ),
            const Gap(6),
            Text(
              api.endpointUrl,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        api.apiType.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (api.apiKey.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.key_rounded, size: 10, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              'KEYED',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (api.errorMessage != null && api.errorMessage!.isNotEmpty) ...[
              const Gap(8),
              Text(
                'Error: ${api.errorMessage}',
                style: const TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ],
            const Divider(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isTesting ? null : onTest,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded, size: 16),
                  label: Text(isTesting ? 'Testing...' : 'Test Connection'),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      tooltip: 'Edit',
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: Colors.red),
                      tooltip: 'Delete',
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
