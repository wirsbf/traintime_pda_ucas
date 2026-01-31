import 'package:dio/dio.dart';

/// HTTP utility methods shared across services
class HttpHelper {
  const HttpHelper(this.dio);

  final Dio dio;

  /// Get text content from URL
  Future<String> getText(String url) async {
    final response = await dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    return response.data ?? '';
  }

  /// Follow redirects manually up to maxRedirects times
  Future<Response<String>> getFollow(
    String url, {
    Options? options,
    int maxRedirects = 6,
  }) async {
    var current = Uri.parse(url);
    final requestOptions = options ?? Options();
    requestOptions.followRedirects = false;
    requestOptions.responseType = ResponseType.plain;
    requestOptions.validateStatus = (status) => status != null && status < 500;

    for (var i = 0; i < maxRedirects; i++) {
      final response = await dio.get<String>(
        current.toString(),
        options: requestOptions,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 300 &&
          response.statusCode! < 400) {
        final location = response.headers.value('location');
        if (location == null) {
          throw Exception('Redirect missing Location header');
        }
        current = current.resolve(location);
        continue;
      }

      return response;
    }

    throw Exception('Too many redirects (limit: $maxRedirects)');
  }
}
