import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/core/constants/app_constants.dart';
import 'package:sportyapp/data/models/comment_model.dart';
import 'package:sportyapp/ui/notifications/viewmodel/notifications_viewmodel.dart';
import 'package:sportyapp/shared_widgets/empty_state.dart';
import 'package:sportyapp/shared_widgets/skeleton_loader.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsViewModelProvider);
    final cs = Theme.of(context).colorScheme;
    final unread = state.notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: AppTextStyles.headlineSmall(cs.onSurface)),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => ref.read(notificationsViewModelProvider.notifier).markAllRead(),
              child: Text('Mark all read', style: AppTextStyles.labelMedium(cs.primary)),
            ),
        ],
      ),
      body: state.isLoading
        ? const MatchListSkeleton()
        : state.notifications.isEmpty
            ? const EmptyState(emoji: '🔔', title: 'No Notifications',
                subtitle: 'You\'re all caught up! Notifications about live matches, wickets, and results will appear here.')
            : ListView.separated(
                itemCount: state.notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = state.notifications[i];
                  return GestureDetector(
                    onTap: () => ref.read(notificationsViewModelProvider.notifier).markRead(n.id),
                    child: Container(
                      color: n.isRead ? null : cs.primary.withValues(alpha: 0.05),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Center(child: Text(n.iconEmoji,
                              style: const TextStyle(fontSize: 20))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title,
                                  style: AppTextStyles.bodyMedium(cs.onSurface).copyWith(
                                    fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(n.body,
                                  style: AppTextStyles.bodySmall(cs.onSurfaceVariant),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(_timeAgo(n.timestamp),
                                  style: AppTextStyles.labelSmall(cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          if (!n.isRead)
                            Container(
                              width: 8, height: 8,
                              margin: const EdgeInsets.only(top: 4, left: 8),
                              decoration: const BoxDecoration(
                                color: AppColors.liveRed, shape: BoxShape.circle),
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
