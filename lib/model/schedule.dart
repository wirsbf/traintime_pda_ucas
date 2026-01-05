class Schedule {
  final List<Course> courses;

  Schedule({required this.courses});

  Map<String, dynamic> toJson() => {
        'courses': courses.map((e) => e.toJson()).toList(),
      };

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      courses: (json['courses'] as List<dynamic>)
          .map((e) => Course.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Course {
  final String id;
  final String name;
  final String teacher;
  final String classroom;
  final String weekday;
  final TimeSlot timeSlot;
  final String weeks;
  final String notes;
  final String displayTime; // New field for original time string

  Course({
    required this.id,
    required this.name,
    required this.teacher,
    required this.classroom,
    required this.weekday,
    required this.timeSlot,
    required this.weeks,
    required this.notes,
    this.displayTime = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teacher': teacher,
        'classroom': classroom,
        'weekday': weekday,
        'timeSlot': timeSlot.toJson(),
        'weeks': weeks,
        'notes': notes,
        'displayTime': displayTime,
      };

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      teacher: json['teacher'] ?? '',
      classroom: json['classroom'] ?? '',
      weekday: json['weekday'] ?? '',
      timeSlot: TimeSlot.fromJson(json['timeSlot'] ?? {}),
      weeks: json['weeks'] ?? '',
      notes: json['notes'] ?? '',
      displayTime: json['displayTime'] ?? '',
    );
  }

  int get day {
    final tryInt = int.tryParse(weekday);
    if (tryInt != null) return tryInt;
    switch (weekday) {
      case 'Monday': return 1;
      case 'Tuesday': return 2;
      case 'Wednesday': return 3;
      case 'Thursday': return 4;
      case 'Friday': return 5;
      case 'Saturday': return 6;
      case 'Sunday': return 7;
    }
    return 0;
  }
}

class TimeSlot {
  final String startTime;
  final String endTime;

  TimeSlot({required this.startTime, required this.endTime});

  Map<String, dynamic> toJson() => {
        'startTime': startTime,
        'endTime': endTime,
      };

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
    );
  }
}
