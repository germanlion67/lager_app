//lib/utils/dokumente_utils.dart

/// Sortiert eine Liste von Dateinamen alphabetisch (case-insensitive).
///
/// - [ascending]: true = A→Z, false = Z→A
/// - Gibt eine neue Liste zurück, das Original bleibt unverändert.
List<String> sortFilesByName(
  List<String> files, {
  bool ascending = true,
}) {
  final copy = List<String>.from(files);
  copy.sort((a, b) {
    final cmp = a.toLowerCase().compareTo(b.toLowerCase());
    return ascending ? cmp : -cmp;
  });
  return copy;
}

/// Sortiert eine Liste von Dateinamen nach Typ (Erweiterung), dann alphabetisch.
///
/// Typ-Reihenfolge (aufsteigend):
///   1. Bilder  (jpg, jpeg, png, gif, bmp, webp)
///   2. PDF
///   3. Dokumente (doc, docx, odt)
///   4. Alles andere
///
/// - [ascending]: true = Bilder zuerst / A→Z, false = umgekehrt
/// - Gibt eine neue Liste zurück, das Original bleibt unverändert.
List<String> sortFilesByTypeThenName(
  List<String> files, {
  bool ascending = true,
}) {
  final copy = List<String>.from(files);

  // Fix: Underscore entfernt — lokale Bezeichner dürfen in Dart
  // nicht mit '_' beginnen (no_leading_underscores_for_local_identifiers)
  String getExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot != -1 ? filename.substring(dot + 1).toLowerCase() : '';
  }

  int getWeight(String filename) {
    final ext = getExtension(filename);
    if (const {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'}.contains(ext)) {
      return 1;
    }
    if (ext == 'pdf') return 2;
    if (const {'doc', 'docx', 'odt'}.contains(ext)) return 3;
    return 4;
  }

  copy.sort((a, b) {
    final wa = getWeight(a);
    final wb = getWeight(b);

    if (wa != wb) {
      final cmp = wa.compareTo(wb);
      return ascending ? cmp : -cmp;
    }

    final nameCmp = a.toLowerCase().compareTo(b.toLowerCase());
    return ascending ? nameCmp : -nameCmp;
  });

  return copy;
}