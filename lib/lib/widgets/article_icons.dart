import 'package:flutter/material.dart';

/// Icon für "Neuer Artikel"
class AddArticleIcon extends StatelessWidget {
  final Color? color;
  final double? size;
  const AddArticleIcon({super.key, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.add, color: color, size: size);
  }
}

/// Icon für Bild/Platzhalter
class ImageFileIcon extends StatelessWidget {
  final Color? color;
  final double? size;
  const ImageFileIcon({super.key, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.image_outlined, color: color, size: size);
  }
}

/// Icon für Einstellungen
class SettingsIcon extends StatelessWidget {
  final Color? color;
  final double? size;
  const SettingsIcon({super.key, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.settings, color: color, size: size);
  }
}

/// Icon für Logout
class LogoutIcon extends StatelessWidget {
  final Color? color;
  final double? size;
  const LogoutIcon({super.key, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.logout, color: color, size: size);
  }
}
