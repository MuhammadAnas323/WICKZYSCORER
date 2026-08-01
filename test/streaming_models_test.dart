import 'package:flutter_test/flutter_test.dart';
import 'package:sportyapp/data/models/stream_model.dart';

void main() {
  group('StreamModel live branding', () {
    test('preserves branding metadata through copyWith', () {
      final stream = StreamModel(
        id: 'stream_1',
        title: 'Championship Live',
        description: 'Live stream',
        broadcasterId: 'user_1',
        broadcasterName: 'Ava',
        broadcasterAvatar: 'https://example.com/avatar.png',
        thumbnailUrl: 'https://example.com/thumbnail.png',
        status: StreamStatus.live,
        appName: 'SPORTYAPP',
        appLogoUrl: 'assets/images/app_icon.png',
        streamLogoUrl: 'assets/images/app_icon.png',
      );

      final updated = stream.copyWith(viewerCount: 42);

      expect(updated.appName, 'SPORTYAPP');
      expect(updated.appLogoUrl, 'assets/images/app_icon.png');
      expect(updated.streamLogoUrl, 'assets/images/app_icon.png');
      expect(updated.viewerCount, 42);
    });

    test('keeps live status intact for streamed content', () {
      final stream = StreamModel(
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
