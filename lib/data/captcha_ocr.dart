import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'rust_ocr.dart';

/// Unified captcha OCR service that selects implementation based on platform.
/// - Desktop (Windows, Linux, macOS): Uses Rust OCR (ddddocr)
/// - Mobile (Android): Uses Google ML Kit Text Recognition
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

  TextRecognizer? _mlKitRecognizer;

  /// Solve captcha from image bytes.
  /// Returns the recognized text, or null if recognition failed.
  Future<String?> solveCaptcha(Uint8List imageBytes) async {
    _lastError = null;

    if (Platform.isAndroid) {
      return _solveCaptchaWithMlKit(imageBytes);
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

  /// Use Google ML Kit Text Recognition for Android.
  Future<String?> _solveCaptchaWithMlKit(Uint8List imageBytes) async {
    try {
      // ML Kit requires an InputImage, which can be created from a file path.
      // Write the bytes to a temporary file.
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/captcha_temp_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(imageBytes);

      // Initialize recognizer if needed
      _mlKitRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final RecognizedText recognizedText = await _mlKitRecognizer!.processImage(inputImage);

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}

      // Extract text - captchas are usually simple, take all text
      final text = recognizedText.text.replaceAll(RegExp(r'\s+'), ''); // Remove whitespace
      
      if (text.isEmpty) {
        _lastError = 'ML Kit recognized no text';
        return null;
      }

      debugPrint('[CaptchaOcr] ML Kit recognized: $text');
      return text;
    } catch (e) {
      _lastError = 'ML Kit exception: $e';
      debugPrint('[CaptchaOcr] ML Kit error: $e');
      return null;
    }
  }

  /// Dispose resources.
  void dispose() {
    _mlKitRecognizer?.close();
    _mlKitRecognizer = null;
  }
}
