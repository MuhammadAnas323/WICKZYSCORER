import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/data/models/live_stream_model.dart';
import 'package:sportyapp/data/repositories/live_stream_repository.dart';
import 'package:sportyapp/data/providers/live_providers.dart';

class HostStreamState {
  final bool isConnecting;
  final bool isLive;
  final String? channelId;
  final String? error;
  final int durationSeconds;

  const HostStreamState({
    this.isConnecting = false,
    this.isLive = false,
    this.channelId,
    this.error,
    this.durationSeconds = 0,
  });

  HostStreamState copyWith({
    bool? isConnecting,
    bool? isLive,
    String? channelId,
    String? error,
    int? durationSeconds,
    bool clearError = false,
  }) =>
      HostStreamState(
        isConnecting: isConnecting ?? this.isConnecting,
        isLive: isLive ?? this.isLive,
        channelId: channelId ?? this.channelId,
        error: clearError ? null : (error ?? this.error),
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );
}

class HostStreamViewModel extends StateNotifier<HostStreamState> {
  final LiveStreamRepository _repository;

  Timer? _durationTimer;

  HostStreamViewModel(this._repository) : super(const HostStreamState());

  /// Start a new live stream: create Firestore doc.
  Future<void> startStream({
    required String channelId,
    required String title,
    required bool useFrontCamera,
  }) async {
    state = state.copyWith(isConnecting: true, clearError: true);

    final user = FirebaseAuth.instance.currentUser;
    final streamId = 'live_${DateTime.now().millisecondsSinceEpoch}';

    final doc = LiveStreamModel(
      id: streamId,
      channelId: channelId,
      hostUid: 0,
      hostId: user?.uid ?? 'anonymous',
      hostName: user?.displayName ?? 'Anonymous',
      hostAvatar: user?.photoURL ?? 'https://ui-avatars.com/api/?name=Anonymous',
      title: title,
      createdAt: DateTime.now(),
    );

    try {
      await _repository.createStream(doc);
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: 'Failed to create stream: ${AppErrorHandler.getUserFriendlyMessage(e)}',
      );
      return;
    }

    state = state.copyWith(
      isConnecting: false,
      isLive: true,
      channelId: streamId,
    );

    final startedAt = DateTime.now();
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        state = state.copyWith(
          durationSeconds: DateTime.now().difference(startedAt).inSeconds,
        );
      }
    });

    debugPrint('[HostVM] Stream live: $channelId');
  }

  /// End the stream: update Firestore.
  Future<void> endStream() async {
    _durationTimer?.cancel();

    final streamId = state.channelId;
    if (streamId != null) {
      await _repository.endStream(streamId);
    }

    state = state.copyWith(
      isLive: false,
      channelId: null,
      durationSeconds: 0,
    );

    debugPrint('[HostVM] Stream ended');
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }
}

final hostStreamViewModelProvider =
    StateNotifierProvider<HostStreamViewModel, HostStreamState>((ref) {
  final repo = ref.read(liveStreamRepositoryProvider);
  return HostStreamViewModel(repo);
});
