enum StreamFormat { hls, dash, mp4, unknown }

class StreamUrlValidator {
  static const List<String> _validExtensions = ['.m3u8', '.mpd', '.mp4'];

  static const List<String> _sampleUrls = [
    'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8',
    'https://dash.akamaized.net/envivio/EnvivioDash3/manifest.mpd',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  ];

  static ValidationResult validate(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return ValidationResult.invalid('URL is empty');
    }

    final lower = trimmed.toLowerCase();

    // Must start with http:// or https://
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return ValidationResult.invalid(
        'URL must start with http:// or https://',
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return ValidationResult.invalid('URL is malformed');
    }

    // Detect extension (may be absent for token-based or proxy streams)
    final extension = _getExtension(trimmed);

    // If a known extension is present, validate it
    if (extension != null && extension.isNotEmpty) {
      if (!_validExtensions.contains(extension)) {
        return ValidationResult.invalid(
          'Unsupported format "$extension". Supported: ${_validExtensions.join(", ")}',
        );
      }
      return ValidationResult.valid(extension: extension);
    }

    // No extension — allow it (many live stream proxies, Mux, Cloudflare etc.
    // serve HLS without an explicit .m3u8 suffix in the URL)
    return ValidationResult.valid();
  }

  static StreamFormat detectFormat(String url) {
    final ext = _getExtension(url.toLowerCase());
    switch (ext) {
      case '.m3u8':
        return StreamFormat.hls;
      case '.mpd':
        return StreamFormat.dash;
      case '.mp4':
        return StreamFormat.mp4;
      default:
        return StreamFormat.unknown;
    }
  }

  static String formatLabel(StreamFormat fmt) {
    switch (fmt) {
      case StreamFormat.hls:
        return 'HLS';
      case StreamFormat.dash:
        return 'DASH';
      case StreamFormat.mp4:
        return 'MP4';
      case StreamFormat.unknown:
        return 'Unknown';
    }
  }

  static String? _getExtension(String url) {
    try {
      final path = Uri.parse(url).path;
      final dot = path.lastIndexOf('.');
      if (dot == -1) return null;
      return path.substring(dot).toLowerCase();
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, String>> get sampleStreams => [
    {'name': 'HLS Test (Mux)', 'url': _sampleUrls[0], 'type': 'HLS'},
    {'name': 'HLS Test (Bitdash)', 'url': _sampleUrls[1], 'type': 'HLS'},
    {'name': 'DASH Test', 'url': _sampleUrls[2], 'type': 'DASH'},
    {'name': 'MP4 Test (Big Buck Bunny)', 'url': _sampleUrls[3], 'type': 'MP4'},
  ];
}

class ValidationResult {
  final bool isValid;
  final String? error;
  final String? extension;

  const ValidationResult._({required this.isValid, this.error, this.extension});

  factory ValidationResult.valid({String? extension}) =>
      ValidationResult._(isValid: true, extension: extension);

  factory ValidationResult.invalid(String error) =>
      ValidationResult._(isValid: false, error: error);
}
