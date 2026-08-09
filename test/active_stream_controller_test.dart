import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sportyapp/data/models/comment_model.dart';
import 'package:sportyapp/data/models/live_match_data.dart';
import 'package:sportyapp/data/models/stream_model.dart';
import 'package:sportyapp/data/repositories/live_match_repository.dart';
import 'package:sportyapp/data/repositories/streaming_repository.dart';
import 'package:sportyapp/ui/streaming/go_live/viewmodel/active_stream_controller.dart';

class FakeStreamingRepository implements StreamingRepository {
  @override
  Future<List<StreamModel>> getActiveStreams() async => [];

  @override
  Future<StreamModel?> getStreamById(String id) async => null;

  @override
  Future<List<CommentModel>> getCommentsForStream(String streamId) async => [];

  @override
  Stream<CommentModel> watchComments(String streamId) => const Stream.empty();

  @override
  Stream<int> watchViewerCount(String streamId) => const Stream.empty();

  @override
  Future<void> postComment(String streamId, String text) async {}

  @override
  Future<void> addStream(StreamModel stream) async {}

  @override
  Future<void> removeStream(String id) async {}

  @override
  Stream<List<StreamModel>> watchActiveStreams() => const Stream.empty();
}

class FakeLiveMatchRepository implements LiveMatchRepository {
  @override
  Future<void> createLiveMatch(String matchId) async {}

  @override
  Future<void> updateLiveMatch(
      String matchId, Map<String, dynamic> data) async {}

  @override
  void dispose() {}

  @override
  Stream<LiveMatchData> watchLiveMatch(String matchId) => const Stream.empty();

  @override
  Future<List<String>> getAllLiveMatchIds() async => [];
}

void main() {
  test('clears the previous stream summary when a new broadcast starts',
      () async {
    final controller = ActiveStreamController(
      FakeStreamingRepository(),
      FakeLiveMatchRepository(),
    );

    await controller.startStream(existingMatchId: 'match-1');
    await controller.endStream();

    expect(controller.state.summary, isNotNull);

    await controller.startStream(existingMatchId: 'match-2');

    expect(controller.state.summary, isNull);
    expect(controller.state.isLive, isTrue);
    expect(controller.state.currentStreamId, isNotNull);
  });
}
