import 'dart:typed_data';
import 'package:dio/dio.dart';

import 'package:html/parser.dart' as html_parser;

import '../auth/xkgo_authentication_service.dart';
import '../../model/selected_course.dart';

/// Course selection service (auto-robber) for XKGO system
class CourseSelectionService {
  CourseSelectionService({
    required Dio dio,
    required XkgoAuthenticationService xkgoAuth,
  })  : _dio = dio,
        _xkgoAuth = xkgoAuth;

  final Dio _dio;
  final XkgoAuthenticationService _xkgoAuth;

  static const String _selectCoursePath = '/courseManage/selectCourse';
  static const String _saveCoursePath = '/courseManage/saveCourse';
  static const String _captchaPath = '/captchaImage';
  static const String _mainPath = '/courseManage/main';

  // Department IDs (hardcoded from original implementation)
  static const List<String> _deptIds = [
    '0', '0', '0', '0', '0', '0', '0', '0', '0', '0',
    '0', '0', '0', '0', '0', '0', '0', '0', '0', '0',
    '0', '0', '0', '0', '0', '0', '0', '0', '0', '0',
    '0', '0', '0', '0', '0', '0', '0', '0',
    '910', '911', '957', '912', '928', '913', '914', '921',
    '951', '952', '958', '917', '945', '927', '964', '915',
    '954', '955', '959', '946', '961', '962', '963', '968',
    '969', '970', '971', '972', '967', '973', '974', '975',
    '977', '987', '989', '950', '965', '990', '988',
  ];

  /// Search for courses by name or code
  Future<String> searchCourse(String query, {bool isCode = false}) async {
    // Ensure authentication
    if (!await _xkgoAuth.validateSession()) {
      throw Exception('XKGO session not valid. Please authenticate first.');
    }

    final data = {
      'type': '',
      'deptIds1': '',
      'courseType1': '',
      'courseCode': isCode ? query : '',
      'courseName': isCode ? '' : query,
    };

    final response = await _dio.post<String>(
      '${_xkgoAuth.baseUrl}$_selectCoursePath',
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        headers: {'Referer': '${_xkgoAuth.baseUrl}$_mainPath'},
      ),
    );

    return response.data ?? '';
  }

  /// Get captcha image for course selection
  Future<Uint8List> getCaptcha() async {
    // Ensure authentication
    if (!await _xkgoAuth.validateSession()) {
      throw Exception('XKGO session not valid. Please authenticate first.');
    }

    final response = await _dio.get<List<int>>(
      '${_xkgoAuth.baseUrl}$_captchaPath',
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.data == null) {
      throw Exception('Failed to fetch captcha image');
    }

    return Uint8List.fromList(response.data!);
  }

  /// Submit course selection
  Future<String> saveCourse(String sids, String vcode) async {
    // Ensure authentication
    if (!await _xkgoAuth.validateSession()) {
      throw Exception('XKGO session not valid. Please authenticate first.');
    }

    final data = {
      'vcode': vcode,
      'deptIds': _deptIds,
      'sids': sids,
    };

    final response = await _dio.post<String>(
      '${_xkgoAuth.baseUrl}$_saveCoursePath',
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        headers: {'Referer': '${_xkgoAuth.baseUrl}$_selectCoursePath'},
      ),
    );

    return response.data ?? '';
  }
  /// Fetch the main page content (contains selected course list with instructors)
  Future<String> fetchMainPage() async {
    // Ensure authentication
    if (!await _xkgoAuth.validateSession()) {
      throw Exception('XKGO session not valid. Please authenticate first.');
    }

    final response = await _dio.get<String>(
      '${_xkgoAuth.baseUrl}$_mainPath',
      options: Options(
        responseType: ResponseType.plain,
      ),
    );

    return response.data ?? '';
  }

  /// Fetch full details of selected courses from XKGO (includes instructors)
  Future<List<SelectedCourse>> fetchSelectedCoursesDetails() async {
    final html = await fetchMainPage();
    return _parseSelectedCoursesFromMain(html);
  }

  List<SelectedCourse> _parseSelectedCoursesFromMain(String html) {
    final document = html_parser.parse(html);
    
    // 1. Extract Semester
    String semester = '';
    final semesterElement = document.querySelectorAll('p').firstWhere(
      (e) => e.text.contains('当前选课学期'),
      orElse: () => document.createElement('p'),
    );
    if (semesterElement.text.isNotEmpty) {
      semester = semesterElement.text.replaceAll('当前选课学期：', '').trim();
    }

    // 2. Parse Table
    // Look for "已选择的课程" section or just the table
    // The table is usually the second one or inside .mc-body
    // Best to look for the specific header "主讲教师"
    
    final tables = document.querySelectorAll('table');
    for (final table in tables) {
      final headerText = table.querySelector('thead')?.text ?? '';
      if (!headerText.contains('主讲教师')) continue;

      // Found the right table
      final rows = table.querySelectorAll('tbody tr');
      final courses = <SelectedCourse>[];

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 7) continue;

        // Index mapping based on observation:
        // 0: Code, 1: Name, 2: Hours, 3: Credits, 4: Degree, 5: Exam, 6: Teacher, 7: Cross, 8: Delete
        
        final code = cells[0].text.trim();
        final name = cells[1].text.trim();
        final credits = double.tryParse(cells[3].text.trim()) ?? 0.0;
        final degree = cells[4].text.contains('是');
        final teacher = cells[6].text.trim();

        courses.add(SelectedCourse(
          code: code,
          name: name,
          instructors: teacher,
          credits: credits,
          isDegree: degree,
          semester: semester.isNotEmpty ? semester : '未知学期', // Fallback
        ));
      }
      return courses;
    }

    return [];
  }
}
