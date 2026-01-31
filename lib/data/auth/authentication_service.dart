import 'dart:io';
import 'dart:typed_data';
import 'session_manager.dart';

/// Authentication credentials
class Credentials {
  const Credentials({
    required this.username,
    required this.password,
    this.captchaCode,
  });

  final String username;
  final String password;
  final String? captchaCode;

  Credentials copyWith({String? captchaCode}) {
    return Credentials(
      username: username,
      password: password,
      captchaCode: captchaCode ?? this.captchaCode,
    );
  }
}

/// Authentication result
class AuthResult {
  const AuthResult({
    required this.success,
    this.cookies,
    this.errorMessage,
    this.captchaImage,
  });

  final bool success;
  final List<Cookie>? cookies;
  final String? errorMessage;
  final Uint8List? captchaImage;

  factory AuthResult.success(List<Cookie> cookies) {
    return AuthResult(success: true, cookies: cookies);
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult(success: false, errorMessage: errorMessage);
  }

  factory AuthResult.captchaRequired(Uint8List captchaImage) {
    return AuthResult(
      success: false,
      captchaImage: captchaImage,
      errorMessage: 'Captcha required',
    );
  }
}

/// Abstract authentication service interface
/// 
/// Each UCAS system (SEP, JWXK, XKGO) implements this interface
/// to provide system-specific authentication logic.
abstract class AuthenticationService {
  /// Authenticate with the system
  /// 
  /// Returns [AuthResult] containing cookies on success,
  /// or error/captcha information on failure.
  Future<AuthResult> authenticate(Credentials credentials);

  /// Validate if current session is still valid
  /// 
  /// Returns true if session is active, false otherwise.
  Future<bool> validateSession();

  /// Get the session type this service manages
  SessionType get type;

  /// Get base URL for this service
  String get baseUrl => type.baseUrl;
}
