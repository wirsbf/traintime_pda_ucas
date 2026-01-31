import 'dart:io';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../auth/jwxk_authentication_service.dart';
import '../utils/http_helper.dart';
import '../../model/lecture.dart';

/// Result of parsing a single lecture page
class _LecturePageResult {
  const _LecturePageResult(this.lectures, this.nextPageNum);
  
  final List<Lecture> lectures;
  final int? nextPageNum;
}

/// Lecture service for fetching academic lectures from JWXK system
class LectureService {
  LectureService({
    required Dio dio,
    required JwxkAuthenticationService jwxkAuth,
  })  : _dio = dio,
        _jwxkAuth = jwxkAuth,
        _httpHelper = HttpHelper(dio);

  final Dio _dio;
  final JwxkAuthenticationService _jwxkAuth;
  final HttpHelper _httpHelper;

  static const String _lecturePath = '/subject/lecture';
  static const int _maxPages = 10;

  /// Fetch all lectures from current date onwards
  Future<List<Lecture>> fetchLectures() async {
    // Ensure authentication
    if (!await _jwxkAuth.validateSession()) {
      throw Exception('JWXK session not valid. Please authenticate first.');
    }

    // Fetch first page
    final response = await _httpHelper.getFollow(
      '${_jwxkAuth.baseUrl}$_lecturePath',
    );

    final allLectures = <Lecture>[];
    final result = _parseLecturesPage(response.data ?? '');
    allLectures.addAll(result.lectures);

    int? nextPage = result.nextPageNum;

    // Fetch subsequent pages
    for (int p = 0; p < _maxPages; p++) {
      if (nextPage == null) break;

      // Early exit if last lecture is before today
      if (allLectures.isNotEmpty && _shouldStopPagination(allLectures.last)) {
        break;
      }

      // Fetch next page via POST
      final nextResult = await _fetchPage(nextPage);
      if (nextResult.lectures.isEmpty) break;

      allLectures.addAll(nextResult.lectures);
      nextPage = nextResult.nextPageNum;
    }

    // Filter lectures to current date and onwards
    return _filterFutureLectures(allLectures);
  }

  /// Fetch lecture detail page
  Future<Map<String, String>> fetchLectureDetail(
    String path, {
    required String username,
    required String password,
  }) async {
    try {
      var response = await _httpHelper.getFollow(
        '${_jwxkAuth.baseUrl}$path',
        options: Options(
          headers: {'Referer': '${_jwxkAuth.baseUrl}$_lecturePath'},
        ),
      );

      String html = response.data ?? '';

      // Check if session is invalid
      final sessionInvalid = html.contains('Identity') || html.contains('login');
      
      if (sessionInvalid) {
        // Session expired - caller should re-authenticate
        throw Exception('Session expired. Please re-authenticate.');
      }

      return parseLectureDetailHtml(html);
    } catch (e) {
      return {'content': '获取详情失败: $e'};
    }
  }

  /// Parse lecture detail HTML
  Map<String, String> parseLectureDetailHtml(String html) {
    final doc = html_parser.parse(html);
    final result = <String, String>{};
    String content = '';

    final table = doc.querySelector('#existsfiles table');
    if (table != null) {
      final rows = table.querySelectorAll('tr');
      bool nextIsContent = false;

      for (final row in rows) {
        final text = row.text.trim();

        if (nextIsContent) {
          content = text;
          break;
        }

        // Extract main location
        if (_isMainLocationRow(text)) {
          final mainMatch = RegExp(
            r'(主要地点|讲座地点|主会场地点)[:：]\s*(.*?)(?=\s*(分会场|$))',
          ).firstMatch(text);
          
          if (mainMatch != null && mainMatch.groupCount >= 2) {
            result['main_location'] = mainMatch.group(2)!.trim();
          }
        }

        // Extract branch location
        if (text.contains('分会场地点') || text.contains('分会场')) {
          final branchMatch = RegExp(
            r'(分会场地点|分会场)[:：]\s*(.*)',
          ).firstMatch(text);
          
          if (branchMatch != null && branchMatch.groupCount >= 2) {
            result['branch_location'] = branchMatch.group(2)!.trim();
          }
        }

        if (text.contains('讲座介绍') || text.contains('内容简介')) {
          nextIsContent = true;
        }
      }
    }

    // Fallback content extraction
    if (content.isEmpty) {
      content = _extractContentFallback(doc);
    }

    // Clean up whitespace
    content = content.replaceAll(RegExp(r'\n\s*\n'), '\n\n').trim();
    result['content'] = content;

    // Combine locations
    _combineLocations(result);

    return result;
  }

  /// Check if row contains main location info
  bool _isMainLocationRow(String text) {
    return text.contains('主要地点') ||
        text.contains('讲座地点') ||
        text.contains('主会场地点');
  }

  /// Extract content using fallback strategies
  String _extractContentFallback(dynamic doc) {
    var container = doc.querySelector('.article-content') ??
        doc.querySelector('.content') ??
        doc.querySelector('#content') ??
        doc.querySelector('.detail_content');

    if (container != null) {
      return container.text.trim();
    }

    // Last resort: clean body text
    final body = doc.body;
    if (body != null) {
      body.querySelectorAll(
        'script, style, nav, header, footer, .header, .footer',
      ).forEach((e) => e.remove());
      return body.text.trim();
    }

    return '';
  }

  /// Combine main and branch locations
  void _combineLocations(Map<String, String> result) {
    final main = result['main_location'] ?? '';
    final branch = result['branch_location'] ?? '';

    if (main.isNotEmpty && branch.isNotEmpty) {
      result['location'] = '主会场: $main\n分会场: $branch';
    } else if (main.isNotEmpty) {
      result['location'] = main;
    } else if (branch.isNotEmpty) {
      result['location'] = '分会场: $branch';
    }
  }

  /// Fetch a specific page of lectures
  Future<_LecturePageResult> _fetchPage(int pageNum) async {
    final response = await _dio.post<String>(
      '${_jwxkAuth.baseUrl}$_lecturePath',
      data: {'pageNum': pageNum.toString()},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        headers: {'Referer': '${_jwxkAuth.baseUrl}$_lecturePath'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    return _parseLecturesPage(response.data ?? '');
  }

  /// Parse a page of lectures
  _LecturePageResult _parseLecturesPage(String html) {
    // Save for debug
    try {
      File('debug_lecture_list.html').writeAsStringSync(html);
    } catch (_) {}

    final document = html_parser.parse(html);
    final table = document.querySelector('table');
    
    if (table == null) {
      return const _LecturePageResult([], null);
    }

    final lectures = <Lecture>[];
    final rows = table.querySelectorAll('tr');

    // Parse header to find column indices
    final headerMap = _parseHeaderIndices(rows);

    // Parse data rows
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i].querySelectorAll('td');
      if (cells.isEmpty) continue;

      final lecture = _parseLectureRow(cells, headerMap);
      if (lecture != null) {
        lectures.add(lecture);
      }
    }

    // Find next page number
    final nextPageNum = _findNextPageNum(document);

    return _LecturePageResult(lectures, nextPageNum);
  }

  /// Parse header row to get column indices
  Map<String, int> _parseHeaderIndices(List<dynamic> rows) {
    final headerMap = <String, int>{};
    
    if (rows.isEmpty) return headerMap;

    final headerRow = rows.first;
    final headers = headerRow.querySelectorAll('th');
    
    if (headers.isEmpty) return headerMap;

    for (var i = 0; i < headers.length; i++) {
      final text = headers[i].text.trim();
      
      if (text.contains('讲座名称')) {
        headerMap['name'] = i;
      } else if (text.contains('主讲人')) {
        headerMap['speaker'] = i;
      } else if (text.contains('时间')) {
        headerMap['time'] = i;
      } else if (_isLocationHeader(text)) {
        headerMap['location'] = i;
      } else if (_isDepartmentHeader(text)) {
        headerMap['dept'] = i;
      } else if (text.contains('操作区')) {
        headerMap['action'] = i;
      }
    }

    return headerMap;
  }

  /// Check if header is location column
  bool _isLocationHeader(String text) {
    return text.contains('地点') ||
        text.contains('场所') ||
        text.contains('教室') ||
        text.contains('会议室');
  }

  /// Check if header is department column
  bool _isDepartmentHeader(String text) {
    return text.contains('院系') ||
        text.contains('单位') ||
        text.contains('部门');
  }

  /// Parse a single lecture row
  Lecture? _parseLectureRow(List<dynamic> cells, Map<String, int> headerMap) {
    // Helper to safely get cell text
    String getCell(String key) {
      final index = headerMap[key];
      return (index != null && index < cells.length) 
          ? cells[index].text.trim() 
          : '';
    }

    final name = getCell('name');
    if (name.isEmpty) return null;

    final timeStr = getCell('time');
    final location = getCell('location').replaceAll(RegExp(r'\s+'), ' ');
    final speaker = getCell('speaker');
    final dept = getCell('dept');

    // Extract ID from action column
    String id = '';
    final actionIndex = headerMap['action'];
    if (actionIndex != null && actionIndex < cells.length) {
      final a = cells[actionIndex].querySelector('a');
      id = a?.attributes['href'] ?? '';
    }

    // Parse and normalize date
    final date = _parseAndNormalizeDate(timeStr);

    return Lecture(
      id: id,
      name: name,
      speaker: speaker,
      time: timeStr,
      location: location,
      department: dept,
      date: date,
    );
  }

  /// Parse and normalize date from time string
  String _parseAndNormalizeDate(String timeStr) {
    final dateMatch = RegExp(r'\d{4}-\d{1,2}-\d{1,2}').firstMatch(timeStr);
    
    if (dateMatch == null) return '';

    final date = dateMatch.group(0)!;
    final parts = date.split('-');
    
    if (parts.length != 3) return date;

    // Normalize to YYYY-MM-DD
    return '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
  }

  /// Find next page number from pagination links
  int? _findNextPageNum(dynamic document) {
    final allLinks = document.querySelectorAll('a');
    
    for (final link in allLinks) {
      if (link.text.contains('下一页') || link.text.contains('Next')) {
        final onclick = link.attributes['onclick'];
        if (onclick == null) continue;

        final match = RegExp(r"gotoPage\('(\d+)'\)").firstMatch(onclick);
        if (match != null) {
          return int.tryParse(match.group(1)!);
        }
      }
    }

    return null;
  }

  /// Check if pagination should stop (last lecture is before today)
  bool _shouldStopPagination(Lecture lastLecture) {
    if (lastLecture.date.isEmpty) return false;

    try {
      final lastDate = DateTime.parse(lastLecture.date);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      return lastDate.isBefore(today);
    } catch (_) {
      return false;
    }
  }

  /// Filter lectures to keep only current date and future
  List<Lecture> _filterFutureLectures(List<Lecture> lectures) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return lectures.where((lecture) {
      if (lecture.date.isEmpty) return true; // Keep if no date

      try {
        final date = DateTime.parse(lecture.date);
        return !date.isBefore(today); // Keep if >= today
      } catch (_) {
        return true; // Keep if parse fails
      }
    }).toList();
  }
}
