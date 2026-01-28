import '../models/review_model.dart';
import 'normalize.dart';

class ParsedTerm {
  final String label;
  final int? sortKey;
  final List<String> warnings;

  ParsedTerm({
    required this.label,
    required this.sortKey,
    required this.warnings,
  });
}

const Map<String, int> _seasonToIndex = {'秋': 1, '春': 2, '夏': 3};

const Map<int, TermSeason> _indexToSeasonEnum = {
  1: TermSeason.autumn,
  2: TermSeason.spring,
  3: TermSeason.summer,
};

const Map<int, String> _indexToSeasonString = {1: '秋', 2: '春', 3: '夏'};

int? _toFourDigitYear(String y) {
  final s = normalizeText(y);
  if (s.isEmpty) return null;
  final n = int.tryParse(s);
  if (n == null) return null;
  if (s.length == 4) return n;
  if (s.length == 2) return 2000 + n;
  return null;
}

String? _detectSeason(String termRaw) {
  if (termRaw.contains('秋')) return '秋';
  if (termRaw.contains('春')) return '春';
  if (termRaw.contains('夏')) return '夏';
  return null;
}

int? _detectSemesterIndex(String termRaw) {
  if (RegExp(r'第一学期|第1学期|一学期').hasMatch(termRaw)) return 1;
  if (RegExp(r'第二学期|第2学期|二学期').hasMatch(termRaw)) return 2;
  if (RegExp(r'第三学期|第3学期|三学期').hasMatch(termRaw)) return 3;
  return null;
}

TermSeason termSeason(String term) {
  final raw = normalizeText(term);
  if (raw.isEmpty) return TermSeason.unknown;
  final s = raw.replaceAll(RegExp(r'[—–]'), '-');

  final seasonDetected = _detectSeason(s);
  if (seasonDetected != null) {
    if (seasonDetected == '秋') return TermSeason.autumn;
    if (seasonDetected == '春') return TermSeason.spring;
    if (seasonDetected == '夏') return TermSeason.summer;
  }

  final idxDetected = _detectSemesterIndex(s);
  if (idxDetected != null) {
    return _indexToSeasonEnum[idxDetected] ?? TermSeason.unknown;
  }

  return TermSeason.unknown;
}

ParsedTerm normalizeTerm(String term) {
  final raw = normalizeText(term);
  final warnings = <String>[];
  if (raw.isEmpty) {
    return ParsedTerm(label: "", sortKey: null, warnings: ["学期为空"]);
  }

  // Normalize separators
  final s = raw.replaceAll(RegExp(r'[—–]'), '-');

  // Prefer explicit year range like 2021-2022 / 21-22
  final rangeMatch = RegExp(r'(\d{2,4})\s*-\s*(\d{2,4})').firstMatch(s);
  final seasonDetected = _detectSeason(s);
  final idxDetected = _detectSemesterIndex(s);

  int? startYear;

  if (rangeMatch != null) {
    final a = _toFourDigitYear(rangeMatch.group(1)!);
    final b = _toFourDigitYear(rangeMatch.group(2)!);
    if (a != null && b != null) {
      if (a == b) {
        if (seasonDetected == null && idxDetected == null) {
          warnings.add("学期年份为同一年且缺少季节/学期序号，无法确定学年");
        } else {
          final seasonStr =
              seasonDetected ?? _indexToSeasonString[idxDetected ?? 1];
          startYear = seasonStr == '秋' ? a : a - 1;
          warnings.add("学期年份为同一年，已按季节推断所属学年");
        }
      } else {
        startYear = a;
        if (b != a + 1) warnings.add("学年跨度不为 1 年，已按起始年处理");
      }
    }
  }

  if (startYear == null) {
    final yearMatch = RegExp(r'(\d{4}|\d{2})').firstMatch(s);
    final y = yearMatch != null ? _toFourDigitYear(yearMatch.group(1)!) : null;
    if (y != null) {
      final seasonStr =
          seasonDetected ??
          (idxDetected != null ? _indexToSeasonString[idxDetected] : null);
      if (seasonStr != null) {
        startYear = seasonStr == '秋' ? y : y - 1;
      } else {
        warnings.add("只解析到年份，缺少季节/学期序号");
      }
    }
  }

  final seasonStr =
      seasonDetected ??
      (idxDetected != null ? _indexToSeasonString[idxDetected] : null);
  final seasonClean = seasonStr?.trim();
  final semesterIndex = seasonClean != null
      ? _seasonToIndex[seasonClean]
      : idxDetected;

  if (seasonClean == null || semesterIndex == null) {
    return ParsedTerm(
      label: raw,
      sortKey: null,
      warnings: ["无法识别季节/学期序号：保留原文"],
    );
  }

  if (startYear == null) {
    return ParsedTerm(label: raw, sortKey: null, warnings: ["无法识别学年：保留原文"]);
  }

  final label =
      '$startYear-${startYear + 1}学年 · $seasonClean（第$semesterIndex学期）';
  final sortKey = startYear * 10 + semesterIndex;
  return ParsedTerm(label: label, sortKey: sortKey, warnings: warnings);
}

int? termSortKey(String term) {
  return normalizeTerm(term).sortKey;
}
