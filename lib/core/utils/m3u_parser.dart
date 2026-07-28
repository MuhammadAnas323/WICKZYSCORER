import 'package:sportyapp/data/models/m3u_channel_model.dart';

class M3uParser {
  static const List<String> supportedExtensions = ['.m3u8', '.mpd', '.mp4'];

  static bool isM3uPlaylist(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.m3u') || lower.endsWith('.m3u?') || lower.contains('.m3u?');
  }

  static bool isPlayableStream(String url) {
    final lower = url.toLowerCase();
    return supportedExtensions.any((ext) => lower.contains(ext));
  }

  static M3uPlaylist parse(String raw, String sourceUrl) {
    final lines = raw.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) {
      return M3uPlaylist(sourceUrl: sourceUrl, channels: [], parsedAt: DateTime.now());
    }

    final title = _extractTitle(lines.first);
    final channels = <M3uChannel>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.startsWith('#EXTINF:')) {
        final info = _parseExtInf(line);
        String? url;
        int j = i + 1;
        while (j < lines.length) {
          final next = lines[j].trim();
          if (next.startsWith('#EXTINF:')) {
            break;
          }
          if (next.isNotEmpty && !next.startsWith('#')) {
            url = _resolveUrl(next, sourceUrl);
            i = j;
            break;
          }
          j++;
        }

        if (url != null) {
          channels.add(M3uChannel(
            name: info['name'] ?? 'Unknown',
            logo: info['logo'],
            group: info['group'],
            url: url,
            isAvailable: isPlayableStream(url),
          ));
        }
      }
      i++;
    }

    return M3uPlaylist(
      sourceUrl: sourceUrl,
      title: title,
      channels: channels,
      parsedAt: DateTime.now(),
      totalChannels: channels.length,
      availableChannels: channels.where((c) => c.isAvailable).length,
    );
  }

  static String _extractTitle(String firstLine) {
    if (firstLine.trim() == '#EXTM3U') return '';
    final match = RegExp(r'#EXTM3U\s+.*?title="([^"]*)"').firstMatch(firstLine);
    return match?.group(1) ?? '';
  }

  static Map<String, String?> _parseExtInf(String line) {
    final result = <String, String?>{'name': null, 'logo': null, 'group': null};

    final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
    result['logo'] = logoMatch?.group(1);

    final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
    result['group'] = groupMatch?.group(1);

    final nameMatch = RegExp(r',([^,]*)$').firstMatch(line);
    result['name'] = nameMatch?.group(1)?.trim();

    return result;
  }

  static String _resolveUrl(String raw, String baseUrl) {
    raw = raw.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    try {
      final base = Uri.parse(baseUrl);
      return base.resolve(raw).toString();
    } catch (_) {
      return raw;
    }
  }
}
