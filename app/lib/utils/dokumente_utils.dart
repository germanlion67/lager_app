List<String> sortFilesByName(List<String> files, {bool ascending = true}) {
  final copy = List<String>.from(files);
  copy.sort((a, b) => ascending ? a.toLowerCase().compareTo(b.toLowerCase()) : b.toLowerCase().compareTo(a.toLowerCase()));
  return copy;
}

List<String> sortFilesByTypeThenName(List<String> files, {bool ascending = true}) {
  final copy = List<String>.from(files);

  int weight(String f) {
    final ext = f.contains('.') ? f.split('.').last.toLowerCase() : '';
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) return 1;
    if (ext == 'pdf') return 2;
    if (['doc', 'docx', 'odt'].contains(ext)) return 3;
    return 4;
  }

  copy.sort((a, b) {
    final wa = weight(a);
    final wb = weight(b);
    if (wa != wb) return ascending ? wa.compareTo(wb) : wb.compareTo(wa);
    return ascending ? a.toLowerCase().compareTo(b.toLowerCase()) : b.toLowerCase().compareTo(a.toLowerCase());
  });

  return copy;
}