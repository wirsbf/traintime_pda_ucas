class Exam {
  Exam({
    required this.courseName,
    required this.date,
    required this.time,
    required this.location,
    required this.seat,
  });

  Map<String, dynamic> toJson() => {
        'courseName': courseName,
        'date': date,
        'time': time,
        'location': location,
        'seat': seat,
      };

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      courseName: json['courseName'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      location: json['location'] ?? '',
      seat: json['seat'] ?? '',
    );
  }

  final String courseName;
  final String date;
  final String time;
  final String location;
  final String seat;
}
