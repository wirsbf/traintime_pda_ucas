class SelectedCourse {
  final String code;
  final String name;
  final String instructors;
  final double credits;
  final bool isDegree;
  final String semester;

  SelectedCourse({
    required this.code,
    required this.name,
    required this.instructors,
    required this.credits,
    required this.isDegree,
    required this.semester,
  });

  @override
  String toString() {
    return 'SelectedCourse(name: $name, instructors: $instructors)';
  }
}
