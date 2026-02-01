import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../auth/jwxk_authentication_service.dart';
import '../utils/http_helper.dart';
import '../../model/exam.dart';

/// Exam service for fetching exam schedules from JWXK system
class ExamService {
  ExamService({
    required Dio dio,
    required JwxkAuthenticationService jwxkAuth,
  })  : _jwxkAuth = jwxkAuth,
        _httpHelper = HttpHelper(dio);

  final JwxkAuthenticationService _jwxkAuth;
  final HttpHelper _httpHelper;

  static const String _selectedCoursePath = '/courseManage/selectedCourse';

  /// Fetch all exams for the student
  Future<List<Exam>> fetchExams() async {
    // Ensure JWXK authentication
    if (!await _jwxkAuth.validateSession()) {
      throw Exception('JWXK session not valid. Please authenticate first.');
    }

    // Access selected course page
    final response = await _httpHelper.getFollow(
      '${_jwxkAuth.baseUrl}$_selectedCoursePath',
    );

    final content = response.data ?? '';

    // Validate we got the selected course page
    if (!content.contains('已选择的课程')) {
      throw Exception('Failed to access selected course page');
    }

    return await _parseSelectedCourses(content);
  }

  /// Parse selected courses table and fetch exam details
  Future<List<Exam>> _parseSelectedCourses(String html) async {
    final document = html_parser.parse(html);
    final table = document.querySelector('table');
    
    if (table == null) {
      return [];
    }

    final exams = <Exam>[];
    final rows = table.querySelectorAll('tbody tr');

    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      
      // Expected columns: 序号 | 课程编码 | 课程名称 | 学分 | 学位课 | 学期 | 考试时间
      if (cells.length < 7) continue;

      final courseName = cells[2].text.trim();
      final semester = cells[5].text.trim();

      // Get exam time link
      final examLink = cells[6].querySelector('a');
      final examHref = examLink?.attributes['href'];

      if (examHref == null || examHref.isEmpty) {
        // No exam link - add placeholder
        exams.add(_createPlaceholderExam(courseName, semester, '无考试信息'));
        continue;
      }

      try {
        final exam = await _fetchExamDetail(examHref, courseName, semester);
        exams.add(exam);
      } catch (e) {
        exams.add(_createPlaceholderExam(courseName, semester, '获取失败'));
      }
    }

    return exams;
  }

  /// Fetch exam detail from detail page
  Future<Exam> _fetchExamDetail(
    String href,
    String courseName,
    String semester,
  ) async {
    // Build full URL
    final fullUrl = href.startsWith('http')
        ? href
        : (href.startsWith('/')
            ? '${_jwxkAuth.baseUrl}$href'
            : '${_jwxkAuth.baseUrl}/$href');

    final detailResponse = await _httpHelper.getFollow(fullUrl);
    final detailContent = detailResponse.data ?? '';

    final exam = _parseExamDetail(detailContent, courseName);
    
    return exam ?? _createPlaceholderExam(courseName, semester, '未安排');
  }

  /// Parse exam detail page
  Exam? _parseExamDetail(String html, String courseName) {
    if (html.isEmpty) return null;

    // Check if exam is not scheduled
    if (html.contains('未安排') && !html.contains('考试开始时间')) {
      return null;
    }

    final document = html_parser.parse(html);
    final table = document.querySelector('table');

    if (table == null) return null;

    final rows = table.querySelectorAll('tr');
    String location = '';
    String startTime = '';
    String endTime = '';

    for (final row in rows) {
      final th = row.querySelector('th');
      final td = row.querySelector('td');
      
      if (th == null || td == null) continue;

      final key = th.text.trim();
      final value = td.text.trim();

      if (key.contains('地点')) {
        location = value;
      } else if (key.contains('开始时间')) {
        startTime = value;
      } else if (key.contains('结束时间')) {
        endTime = value;
      }
    }

    // Parse and format time
    if (startTime.isEmpty) return null;

    final (date, timeDisplay) = _parseExamTime(startTime, endTime);

    return Exam(
      courseName: courseName,
      date: date,
      time: timeDisplay,
      location: location,
      seat: '', // Seat info usually not in this table
    );
  }

  /// Parse exam time into date and time range
  (String, String) _parseExamTime(String startTime, String endTime) {
    String date = '';
    String timeDisplay = '';

    final startParts = startTime.split(' ');
    
    if (startParts.length >= 2) {
      date = startParts[0];
      
      // Remove seconds if present
      String startH = startParts[1];
      if (startH.split(':').length > 2) {
        startH = startH.substring(0, startH.lastIndexOf(':'));
      }

      timeDisplay = startH;

      // Add end time if available
      if (endTime.isNotEmpty) {
        final endParts = endTime.split(' ');
        if (endParts.length >= 2) {
          String endH = endParts[1];
          if (endH.split(':').length > 2) {
            endH = endH.substring(0, endH.lastIndexOf(':'));
          }
          timeDisplay = '$startH-$endH';
        }
      }
    } else {
      // Couldn't parse, use original
      date = startTime;
      timeDisplay = startTime;
    }

    return (date, timeDisplay);
  }

  /// Create placeholder exam when info is not available
  Exam _createPlaceholderExam(String courseName, String semester, String message) {
    return Exam(
      courseName: courseName,
      date: semester,
      time: message,
      location: '@',
      seat: '',
    );
  }
}


