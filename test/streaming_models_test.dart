import 'package:flutter_test/flutter_test.dart';
import 'package:sportyapp/data/models/stream_model.dart';

void main() {
  group('StreamModel copyWith', () {
    test('preserves unchanged fields through copyWith', () {
      const stream = StreamModel(
        id: 'stream_1',
        title: 'Championship Live',
        description: 'Live stream',
        broadcasterId: 'user_1',
        broadcasterName: 'Ava',
        broadcasterAvatar: 'https://example.com/avatar.png',
        thumbnailUrl: 'https://example.com/thumbnail.png',
        status: StreamStatus.live,
        matchId: 'match_1',
        channelName: 'match_1',
        saveReplay: true,
      );

      final updated = stream.copyWith(viewerCount: 42);

      expect(updated.title, 'Championship Live');
      expect(updated.matchId, 'match_1');
      expect(updated.channelName, 'match_1');
      expect(updated.saveReplay, true);
      expect(updated.viewerCount, 42);
    });

    test('keeps live status intact for streamed content', () {
      const stream = StreamModel(
        id: 'legacy_1',
        title: 'Legacy Live',
        description: 'Legacy',
        broadcasterId: 'u1',
        broadcasterName: 'Tester',
        broadcasterAvatar: '',
        thumbnailUrl: '',
        status: StreamStatus.live,
      );

      expect(stream.status, StreamStatus.live);
    });
  });
}
