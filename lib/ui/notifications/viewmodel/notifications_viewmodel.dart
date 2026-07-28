import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/models/comment_model.dart';
import 'package:sportyapp/data/repositories/notification_repository.dart';
import 'package:sportyapp/data/providers/repository_providers.dart';

class NotificationsState {
  final bool isLoading;
  final List<NotificationModel> notifications;
  const NotificationsState({this.isLoading = true, this.notifications = const []});
  NotificationsState copyWith({bool? isLoading, List<NotificationModel>? notifications}) =>
    NotificationsState(isLoading: isLoading ?? this.isLoading,
      notifications: notifications ?? this.notifications);
}

class NotificationsViewModel extends StateNotifier<NotificationsState> {
  final NotificationRepository _repo;
  NotificationsViewModel(this._repo) : super(const NotificationsState()) { load(); }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final data = await _repo.getNotifications();
    state = state.copyWith(isLoading: false, notifications: data);
  }

  Future<void> markRead(String id) async {
    await _repo.markAsRead(id);
    await load();
  }

  Future<void> markAllRead() async {
    await _repo.markAllAsRead();
    await load();
  }
}

final notificationsViewModelProvider =
    StateNotifierProvider<NotificationsViewModel, NotificationsState>(
  (ref) => NotificationsViewModel(ref.read(notificationRepositoryProvider)));
