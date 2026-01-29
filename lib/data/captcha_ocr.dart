import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'rust_ocr.dart';
import '../services/ocr_service.dart';

/// Unified captcha OCR service that selects implementation based on platform.
/// - Desktop (Windows, Linux, macOS): Uses Rust OCR (ddddocr)
/// - Mobile (Android): Uses custom trained ONNX CRNN model
/// - iOS: Uses Rust OCR (static linking) - may need separate handling if issues arise
class CaptchaOcr {
  static CaptchaOcr? _instance;
  static CaptchaOcr get instance {
    _instance ??= CaptchaOcr._();
    return _instance!;
  }

  CaptchaOcr._();

  String? _lastError;
  String? get lastError => _lastError;

  OcrService? _onnxService;

  /// Solve captcha from image bytes.
  /// Returns the recognized text, or null if recognition failed.
  Future<String?> solveCaptcha(Uint8List imageBytes) async {
    _lastError = null;

    if (Platform.isAndroid) {
      return _solveCaptchaWithOnnx(imageBytes);
    } else {
      // Windows, Linux, macOS, iOS - use Rust
      return _solveCaptchaWithRust(imageBytes);
    }
  }

  /// Use Rust OCR (ddddocr) for captcha recognition.
  String? _solveCaptchaWithRust(Uint8List imageBytes) {
    try {
      final result = RustOcr.instance.solveCaptcha(imageBytes);
      if (result == null) {
        _lastError = RustOcr.instance.getLastError() ?? 'Rust OCR returned null';
      }
      return result;
    } catch (e) {
      _lastError = 'Rust OCR exception: $e';
      return null;
    }
  }

  /// Use custom trained ONNX CRNN model for Android.
  Future<String?> _solveCaptchaWithOnnx(Uint8List imageBytes) async {
    try {
      // Initialize service if needed
      _onnxService ??= OcrService();
      await _onnxService!.init();

      final result = await _onnxService!.predict(imageBytes);
      
      if (result.isEmpty || result == "Error") {
        _lastError = 'ONNX model returned empty or error';
        return null;
      }

      debugPrint('[CaptchaOcr] ONNX recognized: $result');
      return result;
    } catch (e) {
      _lastError = 'ONNX exception: $e';
      debugPrint('[CaptchaOcr] ONNX error: $e');
      return null;
    }
  }

  /// Dispose resources.
  void dispose() {
    _onnxService?.dispose();
    _onnxService = null;
  }
}

