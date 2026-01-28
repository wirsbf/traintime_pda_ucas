import '../utils/normalize.dart';

class ParsedCourseRow {
  final String? courseCode;
  final String courseName;
  final double credits;
  final boolean isDegreeCourse;
  final String term;

  ParsedCourseRow({
    this.courseCode,
    required this.courseName,
    required this.credits,
    required this.isDegreeCourse,
    required this.term,
  });
}

class ParseResult {
  final List<ParsedCourseRow> rows;
  final List<String> warnings;

  ParseResult(this.rows, this.warnings);
}

typedef boolean = bool;

bool _parseBoolCN(String s) {
  final x = normalizeText(s);
  return x == "是" ||
      x.toLowerCase() == "yes" ||
      x == "Y" ||
      x == "y" ||
      x == "1" ||
      x == "true";
}

double _parseCredits(String s) {
  final x = normalizeText(s).replaceAll(',', '');
  return double.tryParse(x) ?? 0.0;
}

List<String> _splitLines(String raw) {
  return raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((l) => l.replaceAll('\u00A0', ' ').trimRight())
      .toList();
}

/// Parse TSV copied from UCAS course selection table.
ParseResult parseSelectedCoursesTSV(String raw) {
  final warnings = <String>[];
  final lines = _splitLines(
    raw,
  ).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  if (lines.isEmpty) {
    return ParseResult([], ["没有检测到任何内容"]);
  }

  List<String> cells(String line) =>
      line.split('\t').map((x) => normalizeText(x)).toList();

  final header = cells(lines[0]);

  int idx(String name) => header.indexWhere((h) => normalizeText(h) == name);

  final courseCodeIdx = idx("课程编码");
  final courseNameIdx = idx("课程名称");
  final creditsIdx = idx("学分");
  final degreeIdx = idx("学位课");
  final termIdx = idx("学期");

  final hasHeader = courseNameIdx >= 0 && creditsIdx >= 0 && termIdx >= 0;
  final startLine = hasHeader ? 1 : 0;

  if (!hasHeader) {
    warnings.add("未识别到表头（课程名称/学分/学期）。将按列顺序尝试解析。");
  }

  final rows = <ParsedCourseRow>[];

  for (var i = startLine; i < lines.length; i++) {
    final row = cells(lines[i]);
    if (row.every((x) => x.isEmpty)) continue;

    String get(int j, [String fallback = ""]) =>
        (j >= 0 && j < row.length) ? row[j] : fallback;

    // Fallback indices: 0 序号, 1 课程编码, 2 课程名称, 3 学分, 4 学位课, 5 学期
    final cc = normalizeText(get(courseCodeIdx >= 0 ? courseCodeIdx : 1));
    final cn = normalizeText(get(courseNameIdx >= 0 ? courseNameIdx : 2));
    final cr = _parseCredits(get(creditsIdx >= 0 ? creditsIdx : 3));
    final dg = _parseBoolCN(get(degreeIdx >= 0 ? degreeIdx : 4));
    final tm = normalizeText(get(termIdx >= 0 ? termIdx : 5));

    if (cn.isEmpty) continue;

    rows.add(
      ParsedCourseRow(
        courseCode: cc.isEmpty ? null : cc,
        courseName: cn,
        credits: cr,
        isDegreeCourse: dg,
        term: tm,
      ),
    );
  }

  if (rows.isEmpty) {
    warnings.add("解析结果为空：请确认复制内容包含课程行（含课程名称/学期等列）");
  }

  return ParseResult(rows, warnings);
}
