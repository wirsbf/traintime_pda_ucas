import 'dart:io'; // Added for HttpClient
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/io.dart';
import 'package:encrypter_plus/encrypter_plus.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/asymmetric/api.dart';

import '../model/schedule.dart';
import '../model/score.dart';
import '../model/exam.dart';
import '../model/lecture.dart';

class CaptchaRequiredException implements Exception {
  final Uint8List image;
  const CaptchaRequiredException(this.image);

  @override
  String toString() => 'CaptchaRequiredException: Verification code required';
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}


class _LecturePageResult {
  final List<Lecture> lectures;
  final int? nextPageNum;
  _LecturePageResult(this.lectures, this.nextPageNum);
}

class UcasClient {
  UcasClient({Dio? dio})
    : _dio = dio ?? Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      ) {
    if (dio == null) {
      _dio.interceptors.add(CookieManager(_cookieJar));
      final adapter = _dio.httpClientAdapter;
      // Use IOHttpClientAdapter for non-web (default)
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final client = HttpClient();
          client.findProxy = (_) => 'DIRECT';
          client.badCertificateCallback = (_, __, ___) => true;
          return client;
        };
      }
    }
  }

  final Dio _dio;
  static final CookieJar _cookieJar = CookieJar();
  static bool _isAuthenticated = false;
  
  static Future<List<Cookie>> getCookies(String url) async {
    return _cookieJar.loadForRequest(Uri.parse(url));
  }

  static const String _sepBase = 'https://sep.ucas.ac.cn';
  static const String _xkgodjBase = 'https://xkgodj.ucas.ac.cn';
  static const String _jwxkBase = 'https://jwxk.ucas.ac.cn';

  Future<void> login(String username, String password, {String? captchaCode}) async {
    await _sepLogin(username, password, captchaCode: captchaCode);
  }

  Future<Schedule> fetchSchedule(String username, String password, {String? captchaCode}) async {
    await _sepLogin(username, password, captchaCode: captchaCode);
    final scheduleHtml = await _fetchScheduleHtml();
    final entries = _parseScheduleTable(scheduleHtml);
    if (entries.isEmpty) {
      throw Exception('未解析到课程数据');
    }
    final details = await _fetchCourseDetails(entries);
    return _buildSchedule(entries, details);
  }

  Future<List<Score>> fetchScores(String username, String password, {String? captchaCode}) async {
    final effectiveUsername = username.contains('@') ? username : '$username@mails.ucas.ac.cn';
    await _sepLogin(effectiveUsername, password, captchaCode: captchaCode);
    
    // Use the same JWXK login method as fetchExams
    
    final menuHtml = await _getText('$_sepBase/businessMenu');
    final portalUrl = _findPortalLink(menuHtml);
    
    if (portalUrl == null) {
      return [];
    }
    
    final portalResponse = await _dio.get<String>(
      portalUrl,
      options: Options(
        followRedirects: false,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    
    String? redirectUrl;
    if (portalResponse.statusCode != null &&
        portalResponse.statusCode! >= 300 &&
        portalResponse.statusCode! < 400) {
      redirectUrl = portalResponse.headers.value('location');
    } else {
      redirectUrl = _extractRedirectUrl(portalResponse.data ?? '');
    }
    
    if (redirectUrl == null) {
      return [];
    }
    
    final identityMatch = RegExp(r'Identity=([^&]+)').firstMatch(redirectUrl);
    if (identityMatch == null) {
      return [];
    }
    
    final identity = identityMatch.group(1)!;
    
    // Build JWXK login URL for score page
    final targetPath = '/score/yjs/all';
    final encodedToUrl = _encodeToUrl(targetPath);
    
    final jwxkLoginUrl = '$_jwxkBase/login?Identity=$identity&roleId=xs&fromUrl=1&toUrl=$encodedToUrl';
    
    // Follow the login URL (this may redirect to notice page)
    final loginResponse = await _getFollow(jwxkLoginUrl);
    
    // Always navigate to score page after login
    final scoreResponse = await _getFollow('$_jwxkBase/score/yjs/all');
    
    final content = scoreResponse.data ?? '';
    
    // Check if we got the actual score page (should have table with score data)
    // Look for typical score page indicators
    if (content.contains('课程成绩') || content.contains('学分') || 
        (content.contains('成绩') && content.contains('table'))) {
    } else {
    }
    
    final scores = _parseScores(content);
    
    // Debug: show first 500 chars of content if no scores found or names look wrong
    if (scores.isEmpty || (scores.isNotEmpty && scores.first.name.contains('教务部'))) {
    }
    
    return scores;
  }

  // XOR key extracted from known plaintext-ciphertext pair
  // Plaintext: /courseManage/selectedCourse
  // This key is used to encode the toUrl parameter for JWXK login
  static const List<int> _jwxkXorKey = [
    0xa8, 0xda, 0x0d, 0x67, 0x2e, 0xc1, 0xb5, 0x8b, 
    0xe5, 0x88, 0x7a, 0xfa, 0xc3, 0xfd, 0x5b, 0xe5, 
    0xdb, 0xde, 0x76, 0xbd, 0xc9, 0xcd, 0xd7, 0x0b, 
    0x89, 0x6f, 0x7e, 0x13, 0x64, 0x48, 0x62, 0x75,
    0xf5, 0xe2, 0xd1, 0x50, 0x41, 0x0c, 0xb0, 0xaa,
  ];
  
  String _encodeToUrl(String path) {
    final bytes = path.codeUnits;
    final encoded = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      encoded.add(bytes[i] ^ _jwxkXorKey[i % _jwxkXorKey.length]);
    }
    return encoded.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join('');
  }

  Future<void> _jwxkLogin(String username, String password, {String? toUrl}) async {
    // Ensure SEP login
    await _sepLogin(username, password);
    
    final identity = await _getPortalIdentity();
    if (identity == null) {
      throw Exception('无法获取Identity');
    }

    final targetUrl = toUrl ?? '/subject/lecture';
    final encodedToUrl = _encodeToUrl(targetUrl);
    final jwxkLoginUrl = '$_jwxkBase/login?Identity=$identity&roleId=xs&fromUrl=1&toUrl=$encodedToUrl';
    
    await _getFollow(jwxkLoginUrl);
  }

  Future<List<Lecture>> fetchLectures(String username, String password, {String? captchaCode}) async {
    final effectiveUsername = username.contains('@') ? username : '$username@mails.ucas.ac.cn';
    // Use new helper
    await _jwxkLogin(effectiveUsername, password, toUrl: '/subject/lecture');
    
    // Explicitly navigate to lecture page (Page 1 via GET)
    // JWXK often redirects to Notice page after login regardless of toUrl
    // Page 1
    final response = await _getFollow('$_jwxkBase/subject/lecture');
    final allLectures = <Lecture>[];
    
    // Parse Page 1
    final result = _parseLecturesPage(response.data ?? '');
    allLectures.addAll(result.lectures);
    
    int? nextPage = result.nextPageNum;
    
    // Safety limit to prevent infinite loops (e.g. 10 pages)
    // Loop for subsequent pages
    for (int p = 0; p < 10; p++) {
       if (nextPage == null) break;
       
       // Optimization: Date check (Stop if last lecture < Today)
       // We can check the last lecture of the current batch (from previous iteration or initial page)
       // BUT the 'result' variable is from the previous page.
       if (allLectures.isNotEmpty) {
          final last = allLectures.last; 
          if (last.date.isNotEmpty) {
             try {
               final lastDate = DateTime.parse(last.date);
               // If last lecture of *previous* page is older than today, stop.
               // (Assuming descending order, but usually they are mixed or ascending? 
               // actually lecture lists are often descending by date. 
               // If they are descending, finding an old one means we can stop.
               // If they are ascending, we must continue.
               // Let's assume standard "Latest first" or check logic.)
               // Wait, the user requirement is "fetch current date and future".
               // The HTML shows dates like 2026-01-06, 2026-01-05. It seems descending.
               // So if we hit a date < today, we can stop.
               
               final now = DateTime.now();
               final today = DateTime(now.year, now.month, now.day);
               
               if (lastDate.isBefore(today)) {
                  break;
               }
             } catch (_) {}
          }
       }

       // Fetch Next Page via POST
       final postResponse = await _dio.post<String>(
          '$_jwxkBase/subject/lecture',
          data: {'pageNum': nextPage.toString()},
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.plain,
            headers: {'Referer': '$_jwxkBase/subject/lecture'},
            validateStatus: (status) => status != null && status < 500,
          )
       );
       
       final nextHtml = postResponse.data ?? '';
       final nextResult = _parseLecturesPage(nextHtml);
       
       if (nextResult.lectures.isEmpty) {
         break; 
       }
       
       allLectures.addAll(nextResult.lectures);
       nextPage = nextResult.nextPageNum;
    }

    // Filter: User said "after current date".
    // We interpret as ">= Today".
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return allLectures.where((l) {
        if (l.date.isEmpty) return true; // Keep if no date
        try {
           final d = DateTime.parse(l.date);
           return !d.isBefore(today); // >= Today
        } catch (_) {
           return true; 
        }
    }).toList();
  }

  Future<Map<String, String>> fetchLectureDetail(String path, {String? username, String? password}) async {
    // path is the relative URL from Lecture.id (e.g. /subject/lecture/123)
    try {
      Response<String> response = await _getFollow(
        '$_jwxkBase$path',
        options: Options(
          headers: {'Referer': '$_jwxkBase/subject/lecture'},
        ),
      );
      
      String html = response.data ?? '';
      
      // Check if session invalid
      bool sessionInvalid = html.contains('Identity') || html.contains('login');
      // If we have login indicators and credentials, try to login and retry
      if (sessionInvalid && username != null && password != null) {
          try {
             await _jwxkLogin(username, password, toUrl: path);
             // Retry fetch
             response = await _getFollow(
                '$_jwxkBase$path',
                options: Options(
                  headers: {'Referer': '$_jwxkBase/subject/lecture'},
                ),
             );
             html = response.data ?? '';
          } catch (_) {
             // Login failed, just use original html (will likely fail parse)
          }
      }

      return parseLectureDetailHtml(html);
    } catch (e) {
      print('Error fetching lecture detail: $e');
      return {'content': '获取详情失败: $e'};
    }
  }

  Map<String, String> parseLectureDetailHtml(String html) {
      final doc = html_parser.parse(html);
      final result = <String, String>{};
      String content = '';
      
      // Strategy: Look for the table with lecture details
      // The structure is usually inside <div id="existsfiles"> <table> ...
      final table = doc.querySelector('#existsfiles table');
      if (table != null) {
         final rows = table.querySelectorAll('tr');
         bool nextIsContent = false;
         for (final row in rows) {
            final text = row.text.trim();
            if (nextIsContent) {
               content = text;
               break; // Assuming content is the last thing we want or it occupies the rest
               // Actually content works better if we just capture it.
               // But let's check for location first if we haven't found content yet.
            }
            
            // Regex to extract Main Location: look for "地点" or "主会场" until "分会场" or End.
            if (text.contains('主要地点') || text.contains('讲座地点') || text.contains('主会场地点')) {
               // Match: Label + Colon + (Content) + [lookahead for branch or end]
               final mainMatch = RegExp(r'(主要地点|讲座地点|主会场地点)[:：]\s*(.*?)(?=\s*(分会场|$))').firstMatch(text);
               if (mainMatch != null && mainMatch.groupCount >= 2) {
                  result['main_location'] = mainMatch.group(2)!.trim();
               }
            }
            
            // Regex to extract Branch Location: look for "分会场" until End.
            if (text.contains('分会场地点') || text.contains('分会场')) {
               final branchMatch = RegExp(r'(分会场地点|分会场)[:：]\s*(.*)').firstMatch(text);
               if (branchMatch != null && branchMatch.groupCount >= 2) {
                  result['branch_location'] = branchMatch.group(2)!.trim();
               }
            }

            if (text.contains('讲座介绍') || text.contains('内容简介')) {
               nextIsContent = true;
            }
         }
      } 
      
      // Fallback strategies
      if (content.isEmpty) {
        var container = doc.querySelector('.article-content') 
                   ?? doc.querySelector('.content')
                   ?? doc.querySelector('#content')
                   ?? doc.querySelector('.detail_content');
                   
        if (container != null) {
          content = container.text.trim();
        }
      }
      
      if (content.isEmpty) {
         // Fallback cleaning
         final Body = doc.body;
         if (Body != null) {
             Body.querySelectorAll('script, style, nav, header, footer, .header, .footer').forEach((e) => e.remove());
             content = Body.text.trim();
         }
      }
      
      // Clean up whitespace
      content = content.replaceAll(RegExp(r'\n\s*\n'), '\n\n').trim();
      
      result['content'] = content;
      
      // Combine locations
      final main = result['main_location'] ?? '';
      final branch = result['branch_location'] ?? '';
      
      if (main.isNotEmpty && branch.isNotEmpty) {
         result['location'] = '主会场: $main\n分会场: $branch';
      } else if (main.isNotEmpty) {
         result['location'] = main;
      } else if (branch.isNotEmpty) {
         result['location'] = '分会场: $branch';
      }
      
      return result;
  }

  _LecturePageResult _parseLecturesPage(String html) {
    // Debug save
    try { File('debug_lecture_list.html').writeAsStringSync(html); } catch(_) {}

    // Assuming table structure
    final document = html_parser.parse(html);
    final table = document.querySelector('table');
    if (table == null) {
      return _LecturePageResult([], null);
    }

    final lectures = <Lecture>[];
    final rows = table.querySelectorAll('tr');
    
    Map<String, int> headerMap = {};
    int startIndex = 1;
    if (rows.isNotEmpty) {
      final headerRow = rows.first;
      final headers = headerRow.querySelectorAll('th');
      if (headers.isNotEmpty) {
          for (var i = 0; i < headers.length; i++) {
            final text = headers[i].text.trim();
            if (text.contains('讲座名称')) headerMap['name'] = i;
            else if (text.contains('主讲人')) headerMap['speaker'] = i;
            else if (text.contains('时间')) headerMap['time'] = i;
            else if (text.contains('地点') || text.contains('场所') || text.contains('教室') || text.contains('会议室')) headerMap['location'] = i;
            else if (text.contains('院系') || text.contains('单位') || text.contains('部门')) headerMap['dept'] = i;
            else if (text.contains('操作区')) headerMap['action'] = i;
          }
      }
    }

    for (var i = startIndex; i < rows.length; i++) {
        final cells = rows[i].querySelectorAll('td');
        if (cells.isEmpty) continue;
        
        String name = '';
        String speaker = '';
        String timeStr = '';
        String location = '';
        String dept = '';
        String id = '';

        if (headerMap.isNotEmpty) {
             name = headerMap.containsKey('name') && headerMap['name']! < cells.length ? cells[headerMap['name']!].text.trim() : '';
             speaker = headerMap.containsKey('speaker') && headerMap['speaker']! < cells.length ? cells[headerMap['speaker']!].text.trim() : '';
             timeStr = headerMap.containsKey('time') && headerMap['time']! < cells.length ? cells[headerMap['time']!].text.trim() : '';
             location = headerMap.containsKey('location') && headerMap['location']! < cells.length ? cells[headerMap['location']!].text.trim().replaceAll(RegExp(r'\s+'), ' ') : '';
             dept = headerMap.containsKey('dept') && headerMap['dept']! < cells.length ? cells[headerMap['dept']!].text.trim() : '';
             
             if (headerMap.containsKey('action') && headerMap['action']! < cells.length) {
                 final a = cells[headerMap['action']!].querySelector('a');
                 id = a?.attributes['href'] ?? '';
             }
        }

        if (name.isEmpty) continue;

        String date = '';
        final dateMatch = RegExp(r'\d{4}-\d{1,2}-\d{1,2}').firstMatch(timeStr);
        if (dateMatch != null) {
            date = dateMatch.group(0)!;
            // Normalize to YYYY-MM-DD
            final parts = date.split('-');
            if (parts.length == 3) {
               date = '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
            }
        }

        lectures.add(Lecture(
            id: id,
            name: name,
            speaker: speaker,
            time: timeStr,
            location: location,
            department: dept,
            date: date
        ));
    }

    // Find Next Page
    // Look for "下一页" or "Next"
    // onclick="gotoPage('2');"
    int? nextPageNum;
    final allLinks = document.querySelectorAll('a');
    for (final link in allLinks) {
      if (link.text.contains('下一页') || link.text.contains('Next')) {
         final onclick = link.attributes['onclick'];
         if (onclick != null) {
            final match = RegExp(r"gotoPage\('(\d+)'\)").firstMatch(onclick);
            if (match != null) {
               nextPageNum = int.tryParse(match.group(1)!);
               break;
            }
         }
      }
    }

    return _LecturePageResult(lectures, nextPageNum);
  }

  Future<String?> _getPortalIdentity() async {
    final menuHtml = await _getText('$_sepBase/businessMenu');
    final portalUrl = _findPortalLink(menuHtml);
    
    if (portalUrl == null) return null;
    
    final portalResponse = await _dio.get<String>(
      portalUrl,
      options: Options(
        followRedirects: false,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    
    String? redirectUrl;
    if (portalResponse.statusCode != null &&
        portalResponse.statusCode! >= 300 &&
        portalResponse.statusCode! < 400) {
      redirectUrl = portalResponse.headers.value('location');
    } else {
      redirectUrl = _extractRedirectUrl(portalResponse.data ?? '');
    }
    
    if (redirectUrl == null) return null;
    
    final identityMatch = RegExp(r'Identity=([^&]+)').firstMatch(redirectUrl);
    return identityMatch?.group(1);
  }

  Future<List<Exam>> fetchExams(String username, String password, {String? captchaCode}) async {
    final effectiveUsername = username.contains('@') ? username : '$username@mails.ucas.ac.cn';
    await _sepLogin(effectiveUsername, password, captchaCode: captchaCode);
    
    // JWXK login requires Identity token from portal
    
    final identity = await _getPortalIdentity();
  if (identity == null) {
    return [];
  }
    
    // Build JWXK login URL with proper parameters
    // roleId=xs (学生), fromUrl=1, toUrl=XOR-encoded target path
    final targetPath = '/courseManage/selectedCourse';
    final encodedToUrl = _encodeToUrl(targetPath);
    
    final jwxkLoginUrl = '$_jwxkBase/login?Identity=$identity&roleId=xs&fromUrl=1&toUrl=$encodedToUrl';
    
    // Follow the login URL
    final loginResponse = await _getFollow(jwxkLoginUrl);
    
    // Check if we successfully got to selectedCourse
    final content = loginResponse.data ?? '';
    if (content.contains('已选择的课程')) {
      return await _parseSelectedCourses(content);
    }
    
    // If login redirected somewhere else, try accessing selectedCourse
    final scResponse = await _getFollow('$_jwxkBase/courseManage/selectedCourse');
    final scContent = scResponse.data ?? '';
    
    if (scContent.contains('已选择的课程')) {
      return await _parseSelectedCourses(scContent);
    }
    
    return [];
  }
  
  // Parse the selectedCourse table for exam info and fetch details
  Future<List<Exam>> _parseSelectedCourses(String html) async {
    final document = html_parser.parse(html);
    final table = document.querySelector('table');
    if (table == null) return [];
    
    final exams = <Exam>[];
    final rows = table.querySelectorAll('tbody tr');
    
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length >= 7) {
        // Columns: 序号 | 课程编码 | 课程名称 | 学分 | 学位课 | 学期 | 考试时间
        final courseName = cells[2].text.trim();
        final semester = cells[5].text.trim();
        
        // Get exam time link
        final examLink = cells[6].querySelector('a');
        final examHref = examLink?.attributes['href'];
        
        if (examHref != null && examHref.isNotEmpty) {
          try {
            // Fix: Add base URL ensuring no double slash
            final fullUrl = examHref.startsWith('http') ? examHref : 
                           (examHref.startsWith('/') ? '$_jwxkBase$examHref' : '$_jwxkBase/$examHref');
            
            final detailResponse = await _getFollow(fullUrl);
            final detailContent = detailResponse.data ?? '';
            
            final exam = _parseExamDetail(detailContent, courseName);
            if (exam != null) {
              exams.add(exam);
            } else {
              // Add placeholder if no exam detail found (or not scheduled yet)
              exams.add(Exam(
                courseName: courseName,
                date: semester,
                time: '未安排',
                location: '@',
                seat: '',
              ));
            }
          } catch (e) {
             exams.add(Exam(
                courseName: courseName,
                date: semester,
                time: '获取失败',
                location: '@',
                seat: '',
              ));
          }
        } else {
           exams.add(Exam(
              courseName: courseName,
              date: semester,
              time: '无考试信息',
              location: '@',
              seat: '',
            ));
        }
      }
    }
    return exams;
  }

  // Parse specific exam detail page
  Exam? _parseExamDetail(String html, String courseName) {
    if (html.isEmpty) return null;
    
    // Check if it says "未安排" or empty table (sometimes page exists but empty fields)
    if (html.contains('未安排') && !html.contains('考试开始时间')) {
       return null;
    }

    final document = html_parser.parse(html);
    final table = document.querySelector('table');
    
    if (table != null) {
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
      
      // If we found essential info
      if (startTime.isNotEmpty) {
         // Format: 2026-01-08 13:30 or 2026-01-08 13:30:00
         // We want date = 2026-01-08, time = 13:30 - 15:30 (calculated or just start)
         
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
           date = startTime;
           timeDisplay = startTime;
         }
         
         return Exam(
           courseName: courseName,
           date: date,
           time: timeDisplay,
           location: location,
           seat: '', // Seat usually not in this table, maybe elsewhere or need to check other tables
         );
      }
    }
    
    return null;
  }

  Future<Uint8List> _fetchCaptchaImage() async {
    final response = await _dio.get<List<int>>(
      '$_sepBase/changePic',
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (response.data == null) {
      throw Exception('无法获取验证码图片');
    }
    return Uint8List.fromList(response.data!);
  }

  Future<void> _sepLogin(String username, String password, {String? captchaCode}) async {
    if (_isAuthenticated) return;

    if (await _sepLoggedIn()) {
      _isAuthenticated = true;
      return;
    }
    final loginPage = await _getText(_sepBase);
    final context = _parseLoginContext(loginPage);
    
    if (context.captchaRequired || captchaCode != null) {
      if (captchaCode == null) {
        final image = await _fetchCaptchaImage();
        throw CaptchaRequiredException(image);
      }
    }

    final encrypted = _encryptPassword(password, context.publicKey);
    final params = {
      'userName': username,
      'pwd': encrypted,
      'certCode': captchaCode ?? '',
      'loginFrom': context.loginFrom,
      'sb': 'sb',
    };

    final response = await _dio.post<String>(
      '$_sepBase/slogin',
      data: params,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        headers: {'Origin': _sepBase, 'Referer': _sepBase},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final body = response.data ?? '';

    // Check for specific error messages first
    if (body.contains('用户名或密码错误') || body.contains('密码错误')) {
       throw const AuthException('用户名或密码错误');
    }
    
    if (body.contains('验证码错误')) {
       // This might still happen if we auto-filled (which we don't usually) or if explicit captcha failed.
       // But if we didn't send captcha, it might just say "need captcha"?
       // SEP usually returns to login page with error.
    }

    if (await _sepLoggedIn()) {
      _isAuthenticated = true;
      return;
    }

    // Now check parsing context for next steps (e.g. might need captcha now)
    final newContext = _parseLoginContext(body);
    if (newContext.captchaRequired) {
       final image = await _fetchCaptchaImage();
       throw CaptchaRequiredException(image);
    }
    
    // If we are here, logic failed but no specific error found?
    // Maybe check if we are still on login page
    throw const AuthException('登录失败，请检查网络或重试');
    // Check for "用户名或密码错误" or "Invalid"
    final page = response.data.toString();
    final fallback = _extractSepError(page);
    if (fallback != null) {
      throw AuthException(fallback);
    }
    throw Exception('SEP 登录失败，请检查账号密码或稍后重试');
  }

  Future<bool> _sepLoggedIn() async {
    final response = await _dio.get<String>(
      '$_sepBase/portal/site/226/821',
      options: Options(
        followRedirects: false,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (response.statusCode == 302) {
      final location = response.headers.value('location') ?? '';
      if (location.contains('loginFrom') || location.contains('slogin')) {
        return false;
      }
      return false;
    }
    final body = response.data ?? '';
    if (body.contains('jsePubKey')) {
      return false;
    }
    return response.statusCode == 200;
  }

  Future<String> _fetchScheduleHtml() async {
    final menuHtml = await _getText('$_sepBase/businessMenu');
    final portalUrl = _findPortalLink(menuHtml);
    if (portalUrl == null) {
      throw Exception('未找到选课入口链接，请确认账号有选课权限');
    }

    final portalResponse = await _dio.get<String>(
      portalUrl,
      options: Options(
        followRedirects: false,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    String? redirectUrl;
    if (portalResponse.statusCode != null &&
        portalResponse.statusCode! >= 300 &&
        portalResponse.statusCode! < 400) {
      redirectUrl = portalResponse.headers.value('location');
    } else {
      redirectUrl = _extractRedirectUrl(portalResponse.data ?? '');
    }

    if (redirectUrl == null || redirectUrl.isEmpty) {
      throw Exception('未能解析选课系统跳转地址');
    }
    if (redirectUrl.startsWith('/')) {
      redirectUrl = '$_sepBase$redirectUrl';
    }

    await _getFollow(redirectUrl);
    final scheduleResponse = await _getFollow('$_xkgodjBase/course/personSchedule');
    return scheduleResponse.data ?? '';
  }

  Future<String> _getText(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    return response.data ?? '';
  }

  Future<Response<String>> _getFollow(String url, {Options? options}) async {
    var current = Uri.parse(url);
    final requestOptions = options ?? Options();
    requestOptions.followRedirects = false;
    requestOptions.responseType = ResponseType.plain;
    requestOptions.validateStatus = (status) => status != null && status < 500;

    for (var i = 0; i < 6; i++) {
      final response = await _dio.get<String>(
        current.toString(),
        options: requestOptions,
      );
      if (response.statusCode != null &&
          response.statusCode! >= 300 &&
          response.statusCode! < 400) {
        final location = response.headers.value('location');
        if (location == null) {
          throw Exception('重定向缺少 Location');
        }
        current = current.resolve(location);
        continue;
      }
      return response;
    }
    throw Exception('重定向次数过多');
  }

  _LoginContext _parseLoginContext(String html) {
    final keyMatch =
        RegExp("jsePubKey\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]").firstMatch(html);
    if (keyMatch == null) {
      throw Exception('未能找到 SEP 登录公钥');
    }
    final publicKey = keyMatch.group(1) ?? '';
    final document = html_parser.parse(html);
    final loginFromInput = document.querySelector('input[name="loginFrom"]');
    final loginFrom = loginFromInput?.attributes['value'] ?? '';
    final captchaInput = document.querySelector(
      'input#certCode1, input[name="certCode1"], input#certCode, input[name="certCode"]',
    );
    return _LoginContext(
      publicKey: publicKey,
      loginFrom: loginFrom,
      captchaRequired: captchaInput != null,
    );
  }

  String _encryptPassword(String password, String publicKey) {
    final chunks = <String>[];
    for (var i = 0; i < publicKey.length; i += 64) {
      final end = (i + 64).clamp(0, publicKey.length);
      chunks.add(publicKey.substring(i, end));
    }
    final pem = '-----BEGIN PUBLIC KEY-----\n${chunks.join('\n')}\n-----END PUBLIC KEY-----\n';
    final rsaKey = RSAKeyParser().parse(pem) as RSAPublicKey;
    return Encrypter(RSA(publicKey: rsaKey)).encrypt(password).base64;
  }

  String? _extractSepError(String html) {
    final document = html_parser.parse(html);
    final alert = document.querySelector('.alert');
    if (alert != null) {
      final text = alert.text.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    final loginError = document.querySelector('#loginError');
    if (loginError != null) {
      final text = loginError.text.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    final text = document.body?.text ?? '';
    for (final keyword in [
      '用户名或密码错误',
      '用户名或密码不正确',
      '账号或密码错误',
      '密码错误',
      '验证码',
      '锁定',
    ]) {
      final index = text.indexOf(keyword);
      if (index != -1) {
        return keyword;
      }
    }
    return null;
  }

  String? _findPortalLink(String html, {List<String> keywords = const ['选课', '我的课程']}) {
    final document = html_parser.parse(html);
    final links = document.querySelectorAll('a');
    for (final link in links) {
      final text = link.text.trim();
      if (text.isEmpty) {
        continue;
      }
      bool match = false;
      for (final keyword in keywords) {
        if (text.contains(keyword)) {
          match = true;
          break;
        }
      }
      if (!match) {
        continue;
      }
      var href = link.attributes['href'];
      if (href == null) {
        continue;
      }
      if (href.startsWith('/')) {
        href = '$_sepBase$href';
      }
      return href;
    }
    return null;
  }

  String? _extractRedirectUrl(String html) {
    final metaMatch = RegExp(r'url=([^">]+)', caseSensitive: false)
        .firstMatch(html);
    if (metaMatch != null) {
      return metaMatch.group(1)?.trim();
    }
    final jsMatch = RegExp("location\\.href\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]")
        .firstMatch(html);
    if (jsMatch != null) {
      return jsMatch.group(1)?.trim();
    }
    return null;
  }

  List<Score> _parseScores(String html) {
    final document = html_parser.parse(html);
    
    // Find all tables - score data is usually in a table with more than 4 columns
    final allTables = document.querySelectorAll('table');
    
    if (allTables.isEmpty) {
      return [];
    }
    
    // Try to find the score table - it should have headers with 课程/成绩/学分 etc.
    final scores = <Score>[];
    
    for (int tableIdx = 0; tableIdx < allTables.length; tableIdx++) {
      final table = allTables[tableIdx];
      final rows = table.querySelectorAll('tr');
      
      // Check first row for headers
      if (rows.isEmpty) continue;
      
      final headerRow = rows.first;
      final headers = headerRow.querySelectorAll('th');
      final headerText = headers.map((h) => h.text.trim()).join(',');
      
      // If this table has score-like headers, parse it
      if (headerText.contains('课程') || headerText.contains('成绩') || 
          headerText.contains('学分') || headerText.contains('课号')) {
        
        // Determine indices based on headers if possible, or assume standard structure
        // Standard based on debug: 课程名称,英文名称,分数,学分,学位课,学期,评估状态
        int idxName = -1;
        int idxEnName = -1;
        int idxScore = -1;
        int idxCredit = -1;
        int idxDegree = -1;
        int idxSemester = -1;
        int idxEval = -1;

        for (int i = 0; i < headers.length; i++) {
          final h = headers[i].text.trim();
          if (h.contains('课程名称')) idxName = i;
          else if (h.contains('英文名称')) idxEnName = i;
          else if (h.contains('分数') || h.contains('成绩')) idxScore = i;
          else if (h.contains('学分')) idxCredit = i;
          else if (h.contains('学位课')) idxDegree = i;
          else if (h.contains('学期')) idxSemester = i;
          else if (h.contains('评估')) idxEval = i;
        }

        // Parse data rows (skip header)
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          final cells = row.querySelectorAll('td');
          
          if (cells.isNotEmpty) {
             // Helper to safe get text
             String getCell(int idx) => (idx >= 0 && idx < cells.length) ? cells[idx].text.trim() : '';

             final name = getCell(idxName != -1 ? idxName : 0);
             // Verify this is a valid row (sometimes first col is ID or checkbox)
             if (name.isEmpty || name.contains('姓名') || name == '课程名称') continue;
             
             // Fallback for crucial fields if indices failed to map (e.g. strict order)
             // If idxScore is -1, try to find numeric or known string
             
             scores.add(Score(
                name: name,
                englishName: getCell(idxEnName),
                score: getCell(idxScore != -1 ? idxScore : 2), // Default to 2 if mapping failed
                credit: getCell(idxCredit != -1 ? idxCredit : 3),
                isDegree: getCell(idxDegree),
                semester: getCell(idxSemester != -1 ? idxSemester : 5),
                type: '', 
                evaluation: getCell(idxEval),
             ));
          }
        }
        
        // If we found scores, return them
        if (scores.isNotEmpty) {
          return scores;
        }
      }
    }
    
    return scores;
  }

  List<Exam> _parseExams(String html) {
    final document = html_parser.parse(html);
    final table = document.querySelector('table');
    if (table == null) {
      return [];
    }
    
    final exams = <Exam>[];
    final rows = table.querySelectorAll('tbody tr');
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length >= 2) {
        String name = cells[0].text.trim();
        String time = '';
        String location = '';
        
        // Try to find datetime-like string in cells
        for (final cell in cells) {
          final text = cell.text.trim();
          if (text.contains('202') && text.contains('-') && text.contains(':')) {
            time = text;
          }
        }
        
        if (time.isNotEmpty) {
          exams.add(Exam(
            courseName: name,
            date: time.split(' ').first,
            time: time,
            location: location,
            seat: '',
          ));
        }
      }
    }
    return exams;
  }

  List<_CourseEntry> _parseScheduleTable(String html) {
    final document = html_parser.parse(html);
    final table = document.querySelector('table');
    if (table == null) {
      return [];
    }

    List<_Weekday> weekdays = [];
    for (final row in table.querySelectorAll('tr')) {
      final ths = row.querySelectorAll('th');
      final tds = row.querySelectorAll('td');
      if (ths.length > 1 && tds.isEmpty) {
        weekdays = ths
            .skip(1)
            .map((cell) => _weekdayFromCn(cell.text.trim()))
            .whereType<_Weekday>()
            .toList();
        break;
      }
    }
    if (weekdays.isEmpty) {
      return [];
    }

    final idRegex = RegExp(r'/course/coursetime/(\d+)');
    final grouped = <String, _CourseGroup>{};

    for (final row in table.querySelectorAll('tr')) {
      final th = row.querySelector('th');
      if (th == null) {
        continue;
      }
      final sectionText = th.text.trim();
      final section = int.tryParse(sectionText);
      if (section == null) {
        continue;
      }
      final cells = row.querySelectorAll('td');
      for (var i = 0; i < cells.length && i < weekdays.length; i++) {
        final cell = cells[i];
        final weekday = weekdays[i];
        final links = cell.querySelectorAll('a');
        if (links.isEmpty) {
          final text = cell.text.trim();
          if (text.isEmpty) {
            continue;
          }
          _pushCourseGroup(grouped, weekday, text, null, section);
          continue;
        }
        for (final link in links) {
          final name = link.text.trim();
          if (name.isEmpty) {
            continue;
          }
          final href = link.attributes['href'] ?? '';
          final match = idRegex.firstMatch(href);
          final courseId = match?.group(1);
          _pushCourseGroup(grouped, weekday, name, courseId, section);
        }
      }
    }

    final entries = <_CourseEntry>[];
    for (final group in grouped.values) {
      final sortedSections = group.sections.toList()..sort();
      if (sortedSections.isEmpty) continue;
      var start = sortedSections.first;
      var prev = start;
      for (final section in sortedSections.skip(1)) {
        if (section == prev + 1) {
          prev = section;
          continue;
        }
        entries.add(
          _CourseEntry(
            name: group.name,
            weekday: group.weekday,
            startSection: start,
            endSection: prev,
            courseId: group.courseId,
          ),
        );
        start = section;
        prev = section;
      }
      entries.add(
        _CourseEntry(
          name: group.name,
          weekday: group.weekday,
          startSection: start,
          endSection: prev,
          courseId: group.courseId,
        ),
      );
    }

    return entries;
  }

  void _pushCourseGroup(
    Map<String, _CourseGroup> grouped,
    _Weekday weekday,
    String name,
    String? courseId,
    int section,
  ) {
    final key = '${weekday.dayIndex}::$name::${courseId ?? ""}';
    final group = grouped.putIfAbsent(
      key,
      () => _CourseGroup(
        name: name,
        weekday: weekday,
        courseId: courseId,
        sections: {},  // Set literal
      ),
    );
    group.sections.add(section);
  }

  Future<Map<String, _CourseDetail>> _fetchCourseDetails(
    List<_CourseEntry> entries,
  ) async {
    final ids = entries
        .map((entry) => entry.courseId)
        .whereType<String>()
        .toSet();
    final details = <String, _CourseDetail>{};
    for (final id in ids) {
      final response = await _dio.get<String>(
        '$_jwxkBase/course/coursetime/$id',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final detail = _parseCourseDetail(response.data ?? '');
      details[id] = detail;
    }
    return details;
  }

  _CourseDetail _parseCourseDetail(String html) {
    final document = html_parser.parse(html);
    final rows = document.querySelectorAll('tr');
    final detail = _CourseDetail.empty();
    for (final row in rows) {
      final cells = row.querySelectorAll('th, td');
      if (cells.length < 2) {
        continue;
      }
      final label = cells[0].text.trim();
      final value = cells[1].text.trim();
      switch (label) {
        case '上课时间':
          detail.timeText = value;
          break;
        case '上课地点':
          detail.location = value;
          break;
        case '上课周次':
          detail.weeksList.add(value);  // Accumulate all week ranges
          break;
      }
    }
    return detail;
  }

  Schedule _buildSchedule(
    List<_CourseEntry> entries,
    Map<String, _CourseDetail> details,
  ) {
    // First pass: group entries by base key (name + weekday + sections) and merge weeks
    final grouped = <String, _MergedCourse>{};
    var counter = 0;
    
    for (final entry in entries) {
      counter += 1;
      final detail = entry.courseId != null
          ? details[entry.courseId!]
          : null;
      
      // Base key without weeks - courses with same base key will have weeks merged
      final baseKey = '${entry.name}::${entry.weekday.dayIndex}::${entry.startSection}::${entry.endSection}';
      
      final weeks = detail?.weeks ?? '未标注';
      
      if (grouped.containsKey(baseKey)) {
        // Merge weeks
        grouped[baseKey]!.addWeeks(weeks);
      } else {
        grouped[baseKey] = _MergedCourse(
          id: entry.courseId ?? 'remote-$counter',
          name: entry.name,
          weekday: entry.weekday,
          startSection: entry.startSection,
          endSection: entry.endSection,
          teacher: detail?.teacher ?? '待定',
          classroom: detail?.location ?? '待定',
          timeText: detail?.timeText ?? '',
          weeks: weeks,
        );
      }
    }
    
    // Second pass: build Course objects from merged data
    final courses = <Course>[];
    for (final merged in grouped.values) {
      final courseId =
          '${merged.id}-${merged.weekday.dayIndex}-${merged.startSection}-${merged.endSection}';
      courses.add(
        Course(
          id: courseId,
          name: merged.name,
          teacher: merged.teacher,
          classroom: merged.classroom,
          weekday: merged.weekday.english,
          timeSlot: TimeSlot(
            startTime: '第${merged.startSection}节',
            endTime: '第${merged.endSection}节',
          ),
          weeks: merged.getMergedWeeks(),
          notes: merged.timeText,
        ),
      );
    }
    return Schedule(courses: courses);
  }
}

// Helper class for merging course weeks
class _MergedCourse {
  _MergedCourse({
    required this.id,
    required this.name,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.teacher,
    required this.classroom,
    required this.timeText,
    required String weeks,
  }) {
    addWeeks(weeks);
  }

  final String id;
  final String name;
  final _Weekday weekday;
  final int startSection;
  final int endSection;
  final String teacher;
  final String classroom;
  final String timeText;
  final Set<int> _weekSet = {};

  void addWeeks(String weeksStr) {
    if (weeksStr == '未标注') return;
    // Parse weeks string like "2、3、4、5" or "4" into individual week numbers
    final parts = weeksStr.split(RegExp(r'[、,，\s]+'));
    for (final part in parts) {
      final week = int.tryParse(part.trim());
      if (week != null) {
        _weekSet.add(week);
      }
    }
  }

  String getMergedWeeks() {
    if (_weekSet.isEmpty) return '未标注';
    final sorted = _weekSet.toList()..sort();
    return sorted.join('、');
  }
}

class _LoginContext {
  _LoginContext({
    required this.publicKey,
    required this.loginFrom,
    required this.captchaRequired,
  });

  final String publicKey;
  final String loginFrom;
  final bool captchaRequired;
}

class _CourseEntry {
  _CourseEntry({
    required this.name,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.courseId,
  });

  final String name;
  final _Weekday weekday;
  final int startSection;
  final int endSection;
  final String? courseId;
}

class _CourseGroup {
  _CourseGroup({
    required this.name,
    required this.weekday,
    required this.courseId,
    required this.sections,
  });

  final String name;
  final _Weekday weekday;
  final String? courseId;
  final Set<int> sections;  // Use Set to prevent duplicates
}

class _CourseDetail {
  _CourseDetail({
    required this.timeText,
    required this.location,
    required this.weeksList,
    required this.teacher,
  });

  factory _CourseDetail.empty() {
    return _CourseDetail(
      timeText: '',
      location: '',
      weeksList: [],
      teacher: '待定',
    );
  }

  String timeText;
  String location;
  List<String> weeksList;  // List to accumulate multiple week ranges
  String teacher;
  
  // Helper to get merged weeks string
  String get weeks {
    if (weeksList.isEmpty) return '未标注';
    return weeksList.join('、');
  }
}

enum _Weekday {
  monday('周一', 'Monday', 0),
  tuesday('周二', 'Tuesday', 1),
  wednesday('周三', 'Wednesday', 2),
  thursday('周四', 'Thursday', 3),
  friday('周五', 'Friday', 4),
  saturday('周六', 'Saturday', 5),
  sunday('周日', 'Sunday', 6);

  const _Weekday(this.cn, this.english, this.dayIndex);

  final String cn;
  final String english;
  final int dayIndex;
}

_Weekday? _weekdayFromCn(String label) {
  switch (label) {
    case '星期一':
    case '周一':
      return _Weekday.monday;
    case '星期二':
    case '周二':
      return _Weekday.tuesday;
    case '星期三':
    case '周三':
      return _Weekday.wednesday;
    case '星期四':
    case '周四':
      return _Weekday.thursday;
    case '星期五':
    case '周五':
      return _Weekday.friday;
    case '星期六':
    case '周六':
      return _Weekday.saturday;
    case '星期日':
    case '周日':
    case '星期天':
      return _Weekday.sunday;
  }
  return null;
}
