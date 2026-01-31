import 'package:flutter/foundation.dart';
import 'ucas_client.dart';
import 'captcha_ocr.dart';

/// Helper class for login operations with auto-captcha solving.
/// Retries OCR up to [maxOcrRetries] times before returning the image
/// for manual input.
class LoginHelper {
  static const int maxOcrRetries = 3;

  final UcasClient _client;

  LoginHelper({UcasClient? client}) : _client = client ?? UcasClient();

  /// Attempts to login with auto-captcha solving.
  /// 
  /// Returns:
  /// - `null` if login succeeded
  /// - `Uint8List` (captcha image) if OCR failed after retries and manual input is needed
  /// 
  /// Throws:
  /// - `AuthException` if username/password is wrong
  /// - Other exceptions for network errors
  Future<Uint8List?> loginWithAutoOcr(
    String username,
    String password, {
    Future<String?> Function(Uint8List image)? onManualCaptchaNeeded,
  }) async {
    // First attempt without captcha (in case not required)
    try {
      await _client.login(username, password);
      return null; // Success
    } on CaptchaRequiredException catch (e) {
      debugPrint('[LoginHelper] Captcha required, starting auto-OCR...');
      return _attemptWithOcr(username, password, e.image, onManualCaptchaNeeded);
    }
  }

  Future<Uint8List?> _attemptWithOcr(
    String username,
    String password,
    Uint8List imageBytes,
    Future<String?> Function(Uint8List image)? onManualCaptchaNeeded,
  ) async {
    Uint8List currentImage = imageBytes;
    
    for (int attempt = 1; attempt <= maxOcrRetries; attempt++) {
      debugPrint('[LoginHelper] OCR attempt $attempt/$maxOcrRetries...');
      
      try {
        final code = await CaptchaOcr.instance.solveCaptcha(currentImage);
        
        if (code != null && code.length >= 4) {
          debugPrint('[LoginHelper] OCR result: $code, attempting login...');
          
          try {
            await _client.login(username, password, captchaCode: code);
            debugPrint('[LoginHelper] Login successful with OCR captcha');
            return null; // Success
          } on CaptchaRequiredException catch (e) {
            // Captcha was wrong, need to retry
            debugPrint('[LoginHelper] Captcha incorrect, refreshing...');
            currentImage = e.image;
          } on AuthException {
            // Wrong password - don't retry
            rethrow;
          }
        } else {
          debugPrint('[LoginHelper] OCR failed to recognize captcha');
          // Get fresh captcha for next attempt
          if (attempt < maxOcrRetries) {
            try {
              await _client.login(username, password);
            } on CaptchaRequiredException catch (e) {
              currentImage = e.image;
            }
          }
        }
      } catch (e) {
        debugPrint('[LoginHelper] OCR exception: $e');
        if (attempt < maxOcrRetries) {
          // Get fresh captcha
          try {
            await _client.login(username, password);
          } on CaptchaRequiredException catch (e) {
            currentImage = e.image;
          }
        }
      }
    }
    
    debugPrint('[LoginHelper] All $maxOcrRetries OCR attempts failed');
    
    // All OCR attempts failed, try manual input if callback provided
    if (onManualCaptchaNeeded != null) {
      final manualCode = await onManualCaptchaNeeded(currentImage);
      if (manualCode != null && manualCode.isNotEmpty) {
        await _client.login(username, password, captchaCode: manualCode);
        return null; // Success with manual input
      }
    }
    
    // Return image for caller to handle manual input
    return currentImage;
  }
}
