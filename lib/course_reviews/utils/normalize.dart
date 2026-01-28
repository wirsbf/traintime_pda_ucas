/// Normalizes text by trimming and collapsing whitespace.
String normalizeText(String input) {
  return input
      .trim()
      .replaceAll(RegExp(r'\u00A0'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// Splits a string of instructors into a list.
List<String> splitInstructors(String input) {
  final s = normalizeText(
    input,
  ).replaceAll(RegExp(r'[，、；;／/|]+'), ',').replaceAll(RegExp(r'\s*,\s*'), ',');
  if (s.isEmpty) return [];
  return s
      .split(',')
      .map((x) => normalizeText(x))
      .where((x) => x.isNotEmpty)
      .toList();
}

/// Returns a canonical string for instructors (sorted and joined by '、').
String canonicalInstructors(String input) {
  final parts = splitInstructors(input);
  if (parts.length <= 1) return parts.join('');
  parts.sort(
    (a, b) => a.compareTo(b),
  ); // Simple string sort for now (zh-CN locale sort is harder in Dart)
  return parts.toSet().toList().join('、');
}

/// Generates a unique key for a course (Name + Instructors).
String makeCourseKey(String courseName, String instructors) {
  final cn = normalizeText(courseName);
  final ci = canonicalInstructors(instructors);
  return '${cn}__$ci';
}
