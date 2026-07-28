import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:sportyapp/data/models/iptv_channel.dart';
import 'package:sportyapp/data/models/iptv_settings.dart';
import 'package:sportyapp/data/repositories/iptv_repository.dart';
import 'package:sportyapp/core/utils/iptv_parser.dart';

class IptvService {
  final IptvRepository _repository;
  static const Duration _fetchTimeout = Duration(seconds: 30);

  IptvService(this._repository);

  Future<DownloadResult> downloadAndSave(String url) async {
    final response = await http
        .get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': '*/*',
        })
        .timeout(_fetchTimeout);

    if (response.statusCode != 200) {
      throw IptvException('Download failed: HTTP ${response.statusCode}');
    }

    final channels = IptvParser.parse(response.body, url);
    if (channels.isEmpty) {
      throw IptvException('No channels found in playlist.');
    }

    final playable = channels.where((c) => c.isAvailable).length;

    await _repository.clearAllChannels();
    await _repository.saveChannels(channels);
    await _repository.cacheChannelsLocally(channels);

    final settings = IptvSettings(
      playlistUrl: url,
      lastUpdated: DateTime.now(),
      channelCount: channels.length,
    );
    await _repository.saveSettings(settings);

    return DownloadResult(
      totalChannels: channels.length,
      playableChannels: playable,
      channels: channels,
    );
  }

  Future<List<IptvChannel>> loadChannels() async {
    try {
      return await _repository.loadChannels();
    } catch (_) {
      final cached = await _repository.loadCachedChannels();
      return cached ?? [];
    }
  }

  Stream<List<IptvChannel>> watchChannels() {
    return _repository.watchChannels();
  }

  Future<IptvSettings> loadSettings() async {
    return _repository.loadSettings();
  }

  Future<void> deleteChannel(String channelId) async {
    await _repository.deleteChannel(channelId);
  }

  Future<void> clearAll() async {
    await _repository.clearAllChannels();
    await _repository.clearSettings();
    await _repository.clearLocalCache();
  }

  Future<DownloadResult> refresh(String url) async {
    return downloadAndSave(url);
  }
}

class DownloadResult {
  final int totalChannels;
  final int playableChannels;
  final List<IptvChannel> channels;

  const DownloadResult({
    required this.totalChannels,
    required this.playableChannels,
    required this.channels,
  });
}

class IptvException implements Exception {
  final String message;
  const IptvException(this.message);
  @override
  String toString() => message;
}
