// lib/core/responsive.dart
//
// F-011.2: Breakpoint-Helfer für responsives Layout.
//
// Alle Schwellwerte kommen aus AppConfig — dort zentral anpassbar.
// Diese Datei enthält nur Logik, keine Magic Numbers.

import 'package:flutter/widgets.dart';
import '../config/app_config.dart';

enum ScreenSize { mobile, tablet, desktop }

class Responsive {
  Responsive._();

  /// Gibt die aktuelle Bildschirmgröße als [ScreenSize] zurück.
  static ScreenSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return _fromWidth(width);
  }

  /// Gibt die aktuelle Bildschirmgröße aus [BoxConstraints] zurück.
  /// Für Verwendung innerhalb eines [LayoutBuilder].
  static ScreenSize fromConstraints(BoxConstraints constraints) {
    return _fromWidth(constraints.maxWidth);
  }

  static ScreenSize _fromWidth(double width) {
    if (width < AppConfig.breakpointMobile) return ScreenSize.mobile;
    if (width < AppConfig.breakpointTablet) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }

  static bool isMobile(BuildContext context) =>
      of(context) == ScreenSize.mobile;

  static bool isTablet(BuildContext context) =>
      of(context) == ScreenSize.tablet;

  static bool isDesktop(BuildContext context) =>
      of(context) == ScreenSize.desktop;
}