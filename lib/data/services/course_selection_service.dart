import 'dart:typed_data';
import 'package:dio/dio.dart';

import '../auth/xkgo_authentication_service.dart';

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
}
