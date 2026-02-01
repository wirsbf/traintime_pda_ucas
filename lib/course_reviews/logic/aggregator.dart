import 'dart:math';
import '../models/review_model.dart';
import '../utils/normalize.dart';
import '../utils/term.dart';

double _avg(List<num> nums) {
  if (nums.isEmpty) return 0;
  return nums.fold<num>(0, (a, b) => a + b) / nums.length;
}

List<CourseGroup> aggregateCourses(List<ReviewRow> rows) {
  final byKey = <String, List<ReviewRow>>{};

  for (final r in rows) {
    // In TS: const courseName = normalizeText(r.courseName);
    // But r.courseName should arguably be normalized already or we normalize here.
    // The original logic normalized it then grouped.
    // We will follow the logic:
    final courseName = normalizeText(r.courseName);
    final season = termSeason(r.term);

    // key = courseName + instructors + season
    final key = '${makeCourseKey(courseName, r.instructors)}__${season.index}';

    byKey.putIfAbsent(key, () => []).add(r);
  }

  final groups = <CourseGroup>[];

  for (final entry in byKey.entries) {
    final key = entry.key;
    final reviews = entry.value;
    if (reviews.isEmpty) continue;

    final first = reviews.first;
    final courseName = normalizeText(first.courseName);
    final instructorsCanonical = canonicalInstructors(first.instructors);
    final season = termSeason(first.term);

    // Colleges: unique, distinct, sorted
    final colleges =
        reviews
            .map((r) => normalizeText(r.college ?? ''))
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort(); // Lexicographical sort

    // Terms: unique
    final terms = reviews
        .map((r) => normalizeTerm(r.term).label)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    // Note: Original logic also normalized term text if label failed?
    // In TS: .map((r) => normalizeTerm(r.term).label || normalizeText(r.term))
    // Our normalizeTerm always returns a label (sometimes raw).

    final List<double> credits = reviews
        .map((r) => r.credits.toDouble())
        .toList();

    // Sort reviews inside group
    // 1. Term Sort Key desc
    // 2. Term String desc
    // 3. ID desc
    reviews.sort((a, b) {
      final sa = termSortKey(a.term) ?? -1;
      final sb = termSortKey(b.term) ?? -1;
      if (sa != sb) return sb - sa; // desc

      final ta = normalizeText(a.term);
      final tb = normalizeText(b.term);
      if (ta != tb) return tb.compareTo(ta); // desc string

      return b.id - a.id; // desc id
    });

    final valAvg = _avg(reviews.map((r) => r.value).toList());
    final passAvg = _avg(reviews.map((r) => r.passDifficulty).toList());
    final highAvg = _avg(reviews.map((r) => r.highScoreDifficulty).toList());

    groups.add(
      CourseGroup(
        key: key,
        courseName: courseName,
        instructorsCanonical: instructorsCanonical,
        termSeason: season,
        colleges: colleges,
        terms: terms,
        creditsMin: credits.isEmpty ? 0 : credits.reduce((a, b) => min(a, b)),
        creditsMax: credits.isEmpty ? 0 : credits.reduce((a, b) => max(a, b)),
        isDegreeCourseAny: reviews.any((r) => r.isDegreeCourse),
        reviewCount: reviews.length,
        valueAvg: valAvg,
        passDifficultyAvg: passAvg,
        highScoreDifficultyAvg: highAvg,
        reviews: reviews, // Sorted copy
      ),
    );
  }

  // Calculate stats for all groups
  final total = groups.length;
  if (total > 0) {
    // Extract lists for faster comparison (optimization optional but good for clarity)
    final values = groups.map((g) => g.valueAvg).toList();
    final passDiffs = groups.map((g) => g.passDifficultyAvg).toList();
    final highDiffs = groups.map((g) => g.highScoreDifficultyAvg).toList();

    // Re-map groups with percentiles
    for (var i = 0; i < total; i++) {
        final g = groups[i];
        
        // Value: Higher is better. Percentile = % of courses with LOWER value.
        final betterThanValue = values.where((v) => v < g.valueAvg).length;
        
        // Difficulty: Lower is better (easier). Percentile = % of courses with HIGHER difficulty.
        final easierThanPass = passDiffs.where((v) => v > g.passDifficultyAvg).length;
        final easierThanHigh = highDiffs.where((v) => v > g.highScoreDifficultyAvg).length;

        groups[i] = CourseGroup(
            key: g.key,
            courseName: g.courseName,
            instructorsCanonical: g.instructorsCanonical,
            termSeason: g.termSeason,
            colleges: g.colleges,
            terms: g.terms,
            creditsMin: g.creditsMin,
            creditsMax: g.creditsMax,
            isDegreeCourseAny: g.isDegreeCourseAny,
            reviewCount: g.reviewCount,
            valueAvg: g.valueAvg,
            passDifficultyAvg: g.passDifficultyAvg,
            highScoreDifficultyAvg: g.highScoreDifficultyAvg,
            valuePercentile: (betterThanValue / total) * 100,
            passPercentile: (easierThanPass / total) * 100,
            highScorePercentile: (easierThanHigh / total) * 100,
            reviews: g.reviews,
        );
    }
  }

  // Default order: value high -> review count -> name
  groups.sort((a, b) {
    if (a.valueAvg != b.valueAvg) {
      return (b.valueAvg - a.valueAvg).sign.toInt(); // This is rough for double
    }
    // Better double comparison
    if ((b.valueAvg - a.valueAvg).abs() > 0.0001) {
      return b.valueAvg.compareTo(a.valueAvg);
    }

    if (a.reviewCount != b.reviewCount) return b.reviewCount - a.reviewCount;
    return a.courseName.compareTo(b.courseName);
  });

  return groups;
}
