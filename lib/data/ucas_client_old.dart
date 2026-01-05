import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/io.dart';
import 'package:encrypter_plus/encrypter_plus.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/asymmetric/api.dart';

import '../model/schedule.dart';

class UcasClient {
  UcasClient()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      ) {
    _dio.interceptors.add(CookieManager(CookieJar()));
    final adapter = _dio.httpClientAdapter;
    if (adapter is DefaultHttpClientAdapter) {
      adapter.onHttpClientCreate = (client) {
        client.findProxy = (_) => 'DIRECT';
        client.badCertificateCallback = (_, __, ___) => true;
        return client;
      };
    }
  }

  final Dio _dio;

  static const String _sepBase = 'https://sep.ucas.ac.cn';
  static const String _xkgodjBase = 'https://xkgodj.ucas.ac.cn';
  static const String _jwxkBase = 'https://jwxk.ucas.ac.cn';

  Future<Schedule> fetchSchedule(String username, String password) async {
    await _sepLogin(username, password);
    final scheduleHtml = await _fetchScheduleHtml();
    final entries = _parseScheduleTable(scheduleHtml);
    if (entries.isEmpty) {
      throw Exception('未解析到课程数据');
    }
    final details = await _fetchCourseDetails(entries);
    return _buildSchedule(entries, details);
  }

  Future<void> _sepLogin(String username, String password) async {
    if (await _sepLoggedIn()) {
      return;
    }
    final loginPage = await _getText(_sepBase);
    final context = _parseLoginContext(loginPage);
    if (context.captchaRequired) {
      throw Exception('检测到验证码要求，请先在网页端完成一次登录');
    }

    final encrypted = _encryptPassword(password, context.publicKey);
    final params = {
      'userName': username,
      'pwd': encrypted,
      'certCode': '',
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

    if (await _sepLoggedIn()) {
      return;
    }

    final error = _extractSepError(body);
    if (error != null) {
      throw Exception('SEP 登录失败: $error');
    }

    final failedPage = await _getText(_sepBase);
    final failedContext = _parseLoginContext(failedPage);
    if (failedContext.captchaRequired) {
      throw Exception('检测到验证码要求，请先在网页端完成一次登录');
    }
    final fallback = _extractSepError(failedPage);
    if (fallback != null) {
      throw Exception('SEP 登录失败: $fallback');
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

  Future<Response<String>> _getFollow(String url) async {
    var current = Uri.parse(url);
    for (var i = 0; i < 6; i++) {
      final response = await _dio.get<String>(
        current.toString(),
        options: Options(
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
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

  String? _findPortalLink(String html) {
    final document = html_parser.parse(html);
    final links = document.querySelectorAll('a');
    for (final link in links) {
      final text = link.text.trim();
      if (text.isEmpty) {
        continue;
      }
      if (!text.contains('选课') && !text.contains('我的课程')) {
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
      group.sections.sort();
      var start = group.sections.first;
      var prev = start;
      for (final section in group.sections.skip(1)) {
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
        sections: [],
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
          detail.weeks = value;
          break;
      }
    }
    return detail;
  }

  Schedule _buildSchedule(
    List<_CourseEntry> entries,
    Map<String, _CourseDetail> details,
  ) {
    final courses = <Course>[];
    var counter = 0;
    for (final entry in entries) {
      counter += 1;
      final detail = entry.courseId != null
          ? details[entry.courseId!]
          : null;
      final id = entry.courseId ?? 'remote-$counter';
      final courseId =
          '$id-${entry.weekday.dayIndex}-${entry.startSection}-${entry.endSection}';
      courses.add(
        Course(
          id: courseId,
          name: entry.name,
          teacher: detail?.teacher ?? '待定',
          classroom: detail?.location ?? '待定',
          weekday: entry.weekday.english,
          timeSlot: TimeSlot(
            startTime: '第${entry.startSection}节',
            endTime: '第${entry.endSection}节',
          ),
          weeks: detail?.weeks ?? '未标注',
          notes: detail?.timeText ?? '',
        ),
      );
    }
    return Schedule(courses: courses);
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
  final List<int> sections;
}

class _CourseDetail {
  _CourseDetail({
    required this.timeText,
    required this.location,
    required this.weeks,
    required this.teacher,
  });

  factory _CourseDetail.empty() {
    return _CourseDetail(
      timeText: '',
      location: '',
      weeks: '',
      teacher: '待定',
    );
  }

  String timeText;
  String location;
  String weeks;
  String teacher;
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
