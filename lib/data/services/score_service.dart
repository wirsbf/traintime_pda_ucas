import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../auth/jwxk_authentication_service.dart';
import '../utils/http_helper.dart';
import '../../model/score.dart';

/// Score service for fetching student grades from JWXK system
class ScoreService {
  ScoreService({
    required Dio dio,
    required JwxkAuthenticationService jwxkAuth,
  })  : _dio = dio,
        _jwxkAuth = jwxkAuth,
        _httpHelper = HttpHelper(dio);

  final Dio _dio;
  final JwxkAuthenticationService _jwxkAuth;
  final HttpHelper _httpHelper;

  static const String _scorePath = '/score/yjs/all';

  /// Fetch all scores for the student
  Future<List<Score>> fetchScores() async {
    // Ensure JWXK authentication
    if (!await _jwxkAuth.validateSession()) {
      throw Exception('JWXK session not valid. Please authenticate first.');
    }

    // Navigate to score page
    final scoreResponse = await _httpHelper.getFollow(
      '${_jwxkAuth.baseUrl}$_scorePath',
    );

    final content = scoreResponse.data ?? '';

    // Validate we got the score page
    if (!_isScorePage(content)) {
      throw Exception('Failed to access score page. Unexpected content.');
    }

    return _parseScores(content);
  }

  /// Check if content is the score page
  bool _isScorePage(String content) {
    return content.contains('课程成绩') ||
        content.contains('学分') ||
        (content.contains('成绩') && content.contains('table'));
  }

  /// Parse scores from HTML table
  List<Score> _parseScores(String html) {
    final document = html_parser.parse(html);
    final allTables = document.querySelectorAll('table');

    if (allTables.isEmpty) {
      return [];
    }

    final scores = <Score>[];

    for (final table in allTables) {
      final rows = table.querySelectorAll('tr');
      if (rows.isEmpty) continue;

      final headerRow = rows.first;
      final headers = headerRow.querySelectorAll('th');
      final headerText = headers.map((h) => h.text.trim()).join(',');

      // Check if this is the score table
      if (!_isScoreTable(headerText)) continue;

      // Parse header indices
      final indices = _parseHeaderIndices(headers);

      // Parse data rows
      for (var i = 1; i < rows.length; i++) {
        final cells = rows[i].querySelectorAll('td');
        if (cells.isEmpty) continue;

        final score = _parseScoreRow(cells, indices);
        if (score != null) {
          scores.add(score);
        }
      }

      // If we found scores, return them
      if (scores.isNotEmpty) {
        return scores;
      }
    }

    return scores;
  }

  /// Check if table header indicates score table
  bool _isScoreTable(String headerText) {
    return headerText.contains('课程') ||
        headerText.contains('成绩') ||
        headerText.contains('学分') ||
        headerText.contains('课号');
  }

  /// Parse header indices for score columns
  Map<String, int> _parseHeaderIndices(List<dynamic> headers) {
    final indices = <String, int>{};

    for (var i = 0; i < headers.length; i++) {
      final headerText = headers[i].text.trim();

      if (headerText.contains('课程名称')) {
        indices['name'] = i;
      } else if (headerText.contains('英文名称')) {
        indices['englishName'] = i;
      } else if (headerText.contains('分数') || headerText.contains('成绩')) {
        indices['score'] = i;
      } else if (headerText.contains('学分')) {
        indices['credit'] = i;
      } else if (headerText.contains('学位课')) {
        indices['degree'] = i;
      } else if (headerText.contains('学期')) {
        indices['semester'] = i;
      } else if (headerText.contains('评估')) {
        indices['evaluation'] = i;
      }
    }

    return indices;
  }

  /// Parse a single score row
  Score? _parseScoreRow(List<dynamic> cells, Map<String, int> indices) {
    // Helper to safely get cell text
    String getCell(String key, int defaultIndex) {
      final index = indices[key] ?? defaultIndex;
      return (index >= 0 && index < cells.length) 
          ? cells[index].text.trim() 
          : '';
    }

    final name = getCell('name', 0);

    // Filter invalid rows (guard clauses)
    if (name.isEmpty) return null;
    if (name.contains('姓名') || name == '课程名称') return null;
    if (name.contains('对不起，博士学位英语（免修考试）的成绩为')) return null;

    return Score(
      name: name,
      englishName: getCell('englishName', -1),
      score: getCell('score', 2),
      credit: getCell('credit', 3),
      isDegree: getCell('degree', -1),
      semester: getCell('semester', 5),
      type: '',
      evaluation: getCell('evaluation', -1),
    );
  }
}
