/// Model for available course in the selection system
class AvailableCourse {
  final String sids;       // Selection ID (used for submitting)
  final String code;       // Course code (e.g. "091M4001H")
  final String name;       // Course name
  final String teacher;    // Teacher name(s)
  final String time;       // Schedule (e.g. "周一 1-2节")
  final String location;   // Classroom location
  final int enrolled;      // Current enrollment count
  final int capacity;      // Max capacity
  final String type;       // Course type (公选/专业)

  AvailableCourse({
    required this.sids,
    required this.code,
    required this.name,
    required this.teacher,
    required this.time,
    required this.location,
    required this.enrolled,
    required this.capacity,
    this.type = '',
  });

  bool get isFull => enrolled >= capacity;
  
  String get enrollmentStatus => '$enrolled/$capacity';

  @override
  String toString() => '$name ($code)';
}

/// Model for course in the selection cart
class CartCourse {
  final String code;
  final String name;
  final String sids;
  bool selected = false;  // Whether successfully selected

  CartCourse({
    required this.code,
    required this.name,
    required this.sids,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'sids': sids,
  };

  factory CartCourse.fromJson(Map<String, dynamic> json) => CartCourse(
    code: json['code'] as String,
    name: json['name'] as String,
    sids: json['sids'] as String,
  );
}

/// Result of a course selection attempt
enum SelectionResult {
  success,      // 选课成功
  captchaError, // 验证码错误
  timeConflict, // 时间冲突
  courseFull,   // 课程已满
  alreadySelected, // 已选过该课
  unknownError, // 其他错误
}

extension SelectionResultExtension on SelectionResult {
  String get message {
    switch (this) {
      case SelectionResult.success:
        return '选课成功';
      case SelectionResult.captchaError:
        return '验证码错误';
      case SelectionResult.timeConflict:
        return '时间冲突';
      case SelectionResult.courseFull:
        return '课程已满';
      case SelectionResult.alreadySelected:
        return '已选过该课';
      case SelectionResult.unknownError:
        return '未知错误';
    }
  }
}
