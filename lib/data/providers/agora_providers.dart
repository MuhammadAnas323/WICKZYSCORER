import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/services/agora_service.dart';
import 'package:sportyapp/data/services/agora_token_service.dart';
import 'package:sportyapp/data/services/streaming_service.dart';

final agoraTokenServiceProvider = Provider<AgoraTokenService>((ref) {
  return AgoraTokenService(FirebaseFunctions.instance);
});

final agoraServiceProvider = Provider<AgoraService>((ref) {
  final tokenService = ref.read(agoraTokenServiceProvider);
  final service = AgoraService(tokenService);
  ref.onDispose(() => service.dispose());
  return service;
});

final streamingServiceProvider = Provider<StreamingService>((ref) {
  return ref.read(agoraServiceProvider);
});
