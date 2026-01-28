/// Represents a single review row from the source data.
class ReviewRow {
  final int id;
  final String? courseCode;
  final String courseName;
  final String instructors;
  final num credits;
  final bool isDegreeCourse;
  final String term;
  final String? college;

  // 1-5 stars
  final int value;
  final int passDifficulty;
  final int highScoreDifficulty;

  final String? remark;

  const ReviewRow({
    required this.id,
    this.courseCode,
    required this.courseName,
    required this.instructors,
    required this.credits,
    required this.isDegreeCourse,
    required this.term,
    this.college,
    required this.value,
    required this.passDifficulty,
    required this.highScoreDifficulty,
    this.remark,
  });
}

enum TermSeason { spring, autumn, summer, unknown }

/// Represents a group of reviews aggregated by Course + Instructor + Season.
class CourseGroup {
  final String key;
  final String courseName;
  final String instructorsCanonical;
  final TermSeason termSeason;
  final List<String> colleges;
  final List<String> terms;
  final num creditsMin;
  final num creditsMax;
  final bool isDegreeCourseAny;
  final int reviewCount;
  final double valueAvg;
  final double passDifficultyAvg;
  final double highScoreDifficultyAvg;
  final List<ReviewRow> reviews;

  const CourseGroup({
    required this.key,
    required this.courseName,
    required this.instructorsCanonical,
    required this.termSeason,
    required this.colleges,
    required this.terms,
    required this.creditsMin,
    required this.creditsMax,
    required this.isDegreeCourseAny,
    required this.reviewCount,
    required this.valueAvg,
    required this.passDifficultyAvg,
    required this.highScoreDifficultyAvg,
    required this.reviews,
  });
}
