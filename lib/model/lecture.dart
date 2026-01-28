class Lecture {
  final String id;
  final String name;
  final String speaker;
  final String time;
  final String location;
  final String department;
  final String date;

  Lecture({
    required this.id,
    required this.name,
    required this.speaker,
    required this.time,
    required this.location,
    required this.department,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'speaker': speaker,
    'time': time,
    'location': location,
    'department': department,
    'date': date,
  };

  factory Lecture.fromJson(Map<String, dynamic> json) {
    return Lecture(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      speaker: json['speaker'] ?? '',
      time: json['time'] ?? '',
      location: json['location'] ?? '',
      department: json['department'] ?? '',
      date: json['date'] ?? '',
    );
  }

  @override
  String toString() {
    return 'Lecture{name: $name, speaker: $speaker, date: $date}';
  }
}
