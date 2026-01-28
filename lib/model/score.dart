class Score {
  final String name; // 课程名称
  final String englishName; // 英文名称
  final String score; // 分数
  final String credit; // 学分
  final String isDegree; // 学位课 (是/否)
  final String semester; // 学期
  final String type; // 课程属性 (unused/legacy but kept for compat)
  final String evaluation; // 评估状态 (e.g. 未评估)

  Score({
    required this.name,
    required this.englishName,
    required this.score,
    required this.credit,
    required this.isDegree,
    required this.semester,
    required this.type,
    required this.evaluation,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'englishName': englishName,
    'score': score,
    'credit': credit,
    'isDegree': isDegree,
    'semester': semester,
    'type': type,
    'evaluation': evaluation,
  };

  factory Score.fromJson(Map<String, dynamic> json) {
    return Score(
      name: json['name'] ?? '',
      englishName: json['englishName'] ?? '',
      score: json['score'] ?? '',
      credit: json['credit'] ?? '',
      isDegree: json['isDegree'] ?? '',
      semester: json['semester'] ?? '',
      type: json['type'] ?? '',
      evaluation: json['evaluation'] ?? '',
    );
  }
}
