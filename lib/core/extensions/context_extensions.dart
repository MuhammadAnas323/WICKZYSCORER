// lib/core/extensions/context_extensions.dart
// BuildContext convenience extensions for theme/media access.

import 'package:flutter/material.dart';
import 'package:sportyapp/core/localization/app_localizations.dart';

extension ContextExtensions on BuildContext {
  /// Localized strings provider.
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Convenient string lookup translation method.
  String tr(String key) => AppLocalizations.of(this).translate(key);

  /// Current theme data.
  ThemeData get theme => Theme.of(this);

  /// Current color scheme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Current text theme.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Screen size.
  Size get screenSize => MediaQuery.of(this).size;

  /// Screen width.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Screen height.
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Safe area padding.
  EdgeInsets get padding => MediaQuery.of(this).padding;

  /// Is dark mode.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
