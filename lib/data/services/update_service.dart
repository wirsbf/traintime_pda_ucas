import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;
  final String url;
  final String body;
  final bool hasUpdate;

  UpdateInfo({
    required this.version,
    required this.url,
    required this.body,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const String _releasesUrl =
      'https://api.github.com/repos/wirsbf/traintime_pda_ucas/releases/latest';

  final Dio _dio = Dio();

  Future<UpdateInfo?> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get<String>(
        _releasesUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200 && response.data != null) {
        final json = jsonDecode(response.data!);
        final String tagName = json['tag_name'] ?? '';
        final String htmlUrl = json['html_url'] ?? '';
        final String body = json['body'] ?? '';

        // Remove 'v' prefix if present
        final remoteVersion = tagName.startsWith('v')
            ? tagName.substring(1)
            : tagName;

        if (_compareVersions(remoteVersion, currentVersion) > 0) {
          return UpdateInfo(
            version: remoteVersion,
            url: htmlUrl,
            body: body,
            hasUpdate: true,
          );
        } else {
           return UpdateInfo(
            version: remoteVersion,
            url: htmlUrl,
            body: body,
            hasUpdate: false,
          );
        }
      }
    } catch (e) {
      print('Update check failed: $e');
    }
    return null;
  }

  int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final v2Parts = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
        final p1 = i < v1Parts.length ? v1Parts[i] : 0;
        final p2 = i < v2Parts.length ? v2Parts[i] : 0;
        if (p1 > p2) return 1;
        if (p1 < p2) return -1;
    }
    return 0;
  }
}
