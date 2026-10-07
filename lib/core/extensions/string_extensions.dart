// lib/core/extensions/string_extensions.dart

extension StringCasingExtension on String {
  /// Capitalize the first letter of every word (Title Case)
  /// e.g. "scorer" -> "Scorer", "john doe" -> "John Doe"
  String get toTitleCase {
    if (isEmpty) return this;
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(this)) return this;
    return split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }
}
