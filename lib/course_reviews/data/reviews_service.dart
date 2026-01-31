import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/review_model.dart';
import 'reviews_data.dart'; // Fallback local data

/// Service for fetching course reviews from remote or falling back to local.
class ReviewsService {
  static const String _remoteUrl =
      'https://raw.githubusercontent.com/2654400439/UCAS-Course-Reviews/main/src/data/reviews.generated.ts';

  static final Dio _dio = Dio();

  /// Fetches reviews from the remote source.
  /// If fetch fails (offline, server error), returns the local hardcoded data.
  static Future<List<ReviewRow>> fetchReviews() async {
    try {
      final response = await _dio.get(
        _remoteUrl,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as String;
        return _parseTypeScriptData(data);
      }
    } catch (e) {
      debugPrint('[ReviewsService] Fetch error: $e');
    }

    // Fallback to local data
    debugPrint('[ReviewsService] Using local fallback data');
    return REVIEWS;
  }

  /// Parses the TypeScript array export format.
  /// The file looks like:
  /// ```
  /// export const REVIEWS: ReviewRow[] = [
  ///   { "id": 1, ... },
  ///   ...
  /// ];
  /// ```
  static List<ReviewRow> _parseTypeScriptData(String tsContent) {
    try {
      // Find the JSON array by locating the first '[' and last ']'
      final startIdx = tsContent.indexOf('[');
      final endIdx = tsContent.lastIndexOf(']');

      if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) {
        throw FormatException('Could not find JSON array in TS content');
      }

      final jsonArrayStr = tsContent.substring(startIdx, endIdx + 1);
      final List<dynamic> jsonList = jsonDecode(jsonArrayStr);

      return jsonList
          .map((item) => ReviewRow.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ReviewsService] Parse error: $e');
      return REVIEWS; // Fallback on parse error
    }
  }
}
