import 'package:cookie_jar/cookie_jar.dart';

/// Session types for different UCAS systems
enum SessionType {
  sep('https://sep.ucas.ac.cn'),
  jwxk('https://jwxk.ucas.ac.cn'),
  xkgo('https://xkgo.ucas.ac.cn:3000'); // Will be dynamic in XkgoAuthService

  const SessionType(this.baseUrl);
  final String baseUrl;
}

/// Exception thrown when session is expired or invalid
class SessionExpiredException implements Exception {
  const SessionExpiredException(this.type);
  final SessionType type;

  @override
  String toString() => 'SessionExpiredException: ${type.name} session expired';
}

/// Manages cookie lifecycle for all UCAS authentication systems
/// 
/// Provides thread-safe cookie storage, retrieval, validation and cleanup.
/// Uses CookieJar as the underlying storage mechanism.
class SessionManager {
  SessionManager({CookieJar? cookieJar})
      : _cookieJar = cookieJar ?? CookieJar();

  final CookieJar _cookieJar;
  final Map<SessionType, bool> _validationCache = {};
  final Map<SessionType, DateTime> _lastValidationTime = {};
  
  // Cache duration before re-validation (5 minutes)
  static const Duration _validationCacheDuration = Duration(minutes: 5);

  /// Save session cookies for a specific system
  Future<void> saveSession(SessionType type, List<Cookie> cookies) async {
    if (cookies.isEmpty) return;
    
    final uri = Uri.parse(type.baseUrl);
    await _cookieJar.saveFromResponse(uri, cookies);
    
    // Mark as valid after successful save
    _validationCache[type] = true;
    _lastValidationTime[type] = DateTime.now();
  }

  /// Get session cookies for a specific system
  Future<List<Cookie>> getSession(SessionType type, {String? customUrl}) async {
    final url = customUrl ?? type.baseUrl;
    final uri = Uri.parse(url);
    return await _cookieJar.loadForRequest(uri);
  }

  /// Validate if session is still valid
  /// 
  /// Uses cached validation result if within cache duration.
  /// Override [forceValidation] to bypass cache.
  Future<bool> validateSession(
    SessionType type, {
    required Future<bool> Function() validator,
    bool forceValidation = false,
  }) async {
    // Check cache first
    if (!forceValidation) {
      final lastValidation = _lastValidationTime[type];
      final cachedResult = _validationCache[type];
      
      if (lastValidation != null && cachedResult != null) {
        final elapsed = DateTime.now().difference(lastValidation);
        if (elapsed < _validationCacheDuration) {
          return cachedResult;
        }
      }
    }

    // Perform actual validation
    final isValid = await validator();
    
    _validationCache[type] = isValid;
    _lastValidationTime[type] = DateTime.now();
    
    return isValid;
  }

  /// Clear session for a specific system
  Future<void> clearSession(SessionType type) async {
    final uri = Uri.parse(type.baseUrl);
    await _cookieJar.delete(uri);
    
    _validationCache.remove(type);
    _lastValidationTime.remove(type);
  }

  /// Clear all sessions
  Future<void> clearAllSessions() async {
    await _cookieJar.deleteAll();
    _validationCache.clear();
    _lastValidationTime.clear();
  }

  /// Invalidate validation cache (force next validateSession to re-check)
  void invalidateCache(SessionType type) {
    _validationCache.remove(type);
    _lastValidationTime.remove(type);
  }

  /// Get cookies as a static helper (for backward compatibility)
  static Future<List<Cookie>> getCookies(String url, CookieJar cookieJar) async {
    return cookieJar.loadForRequest(Uri.parse(url));
  }
}
