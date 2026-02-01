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

  factory ReviewRow.fromJson(Map<String, dynamic> json) {
    return ReviewRow(
      id: json['id'] as int? ?? 0,
      courseCode: json['courseCode'] as String?,
      courseName: json['courseName'] as String? ?? '',
      instructors: json['instructors'] as String? ?? '',
      credits: json['credits'] as num? ?? 0,
      isDegreeCourse: json['isDegreeCourse'] as bool? ?? false,
      term: json['term'] as String? ?? '',
      college: json['college'] as String?,
      value: json['value'] as int? ?? 3,
      passDifficulty: json['passDifficulty'] as int? ?? 2,
      highScoreDifficulty: json['highScoreDifficulty'] as int? ?? 3,
      remark: json['remark'] as String?,
    );
  }
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
  
  // Percentiles (0-100)
  final double valuePercentile; 
  final double passPercentile;
  final double highScorePercentile;

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
    this.valuePercentile = 0,
    this.passPercentile = 0,
    this.highScorePercentile = 0,
    required this.reviews,
  });
}
