import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/ui/streaming/go_live/viewmodel/active_stream_controller.dart';

/// Thin wrapper that exposes the persistent [ActiveStreamController] state
/// so existing [GoLiveScreen] references still work.
final goLiveViewModelProvider = Provider<ActiveStreamController>((ref) {
  return ref.read(activeStreamControllerProvider.notifier);
});

final goLiveStateProvider = Provider<ActiveStreamState>((ref) {
  return ref.watch(activeStreamControllerProvider);
});
