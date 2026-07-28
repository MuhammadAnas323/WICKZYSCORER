import 'package:sportyapp/data/models/iptv_channel.dart';

class IptvParser {
  static const List<String> supportedExtensions = ['.m3u8', '.mpd', '.mp4'];

  static bool isPlayable(String url) {
    final lower = url.toLowerCase();
    return supportedExtensions.any((ext) => lower.contains(ext));
  }

  static List<IptvChannel> parse(String raw, String playlistUrl) {
    final lines = raw.split(RegExp(r'\r?\n'));
    final channels = <IptvChannel>[];
    final seen = <String>{};
    int i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.startsWith('#EXTINF:')) {
        final info = _parseExtInf(line);
        String? streamUrl;
        int j = i + 1;
        while (j < lines.length) {
          final next = lines[j].trim();
          if (next.startsWith('#EXTINF:')) break;
          if (next.isNotEmpty && !next.startsWith('#')) {
            streamUrl = _resolveUrl(next, playlistUrl);
            i = j;
            break;
          }
          j++;
        }
        if (streamUrl != null && !seen.contains(streamUrl)) {
          seen.add(streamUrl);
          channels.add(IptvChannel(
            channelId: _generateId(playlistUrl, streamUrl),
            channelName: info['name'] ?? 'Unknown',
            tvgName: info['tvgName'],
            logo: info['logo'],
            group: info['group'],
            country: info['country'],
            streamUrl: streamUrl,
            playlistUrl: playlistUrl,
            createdAt: DateTime.now(),
            isAvailable: isPlayable(streamUrl),
          ));
        }
      }
      i++;
    }

    return channels;
  }

  static Map<String, String?> _parseExtInf(String line) {
    return {
      'tvgName': RegExp(r'tvg-name="([^"]*)"').firstMatch(line)?.group(1),
      'logo': RegExp(r'tvg-logo="([^"]*)"').firstMatch(line)?.group(1),
      'group': RegExp(r'group-title="([^"]*)"').firstMatch(line)?.group(1),
      'country': RegExp(r'tvg-country="([^"]*)"').firstMatch(line)?.group(1),
      'name': RegExp(r',([^,]*)$').firstMatch(line)?.group(1)?.trim(),
    };
  }

  static String _resolveUrl(String raw, String baseUrl) {
    raw = raw.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    try {
      return Uri.parse(baseUrl).resolve(raw).toString();
    } catch (_) {
      return raw;
    }
  }

  static String _generateId(String playlistUrl, String streamUrl) {
    final hash = (playlistUrl + streamUrl).hashCode;
    return '${hash.abs()}';
  }
}
