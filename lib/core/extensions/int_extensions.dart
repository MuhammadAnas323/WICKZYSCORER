// lib/core/extensions/int_extensions.dart
// Integer convenience extensions.

extension IntExtensions on int {
  /// Format seconds as HH:MM:SS e.g. "01:23:45"
  String get toHMS {
    final h = (this ~/ 3600).toString().padLeft(2, '0');
    final m = ((this % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (this % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Format as abbreviated number e.g. 1247 → "1.2K"
  String get abbreviated {
    if (this >= 1000000) return '${(this / 1000000).toStringAsFixed(1)}M';
    if (this >= 1000) return '${(this / 1000).toStringAsFixed(1)}K';
    return toString();
  }
}
