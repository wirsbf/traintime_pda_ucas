import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Native FFI bindings for rust_ocr.dll
class RustOcr {
  static RustOcr? _instance;
  late final DynamicLibrary _lib;
  late final _SolveCaptcha _solveCaptcha;
  late final _FreeString _freeString;
  late final _GetLastError _getLastError;

  RustOcr._() {
    _lib = _loadLibrary();
    _solveCaptcha = _lib.lookupFunction<_SolveCaptchaNative, _SolveCaptcha>('solve_captcha');
    _freeString = _lib.lookupFunction<_FreeStringNative, _FreeString>('free_string');
    _getLastError = _lib.lookupFunction<_GetLastErrorNative, _GetLastError>('get_last_error');
  }

  static RustOcr get instance {
    _instance ??= RustOcr._();
    return _instance!;
  }

  static DynamicLibrary _loadLibrary() {
    if (Platform.isWindows) {
      return DynamicLibrary.open('rust_ocr.dll');
    } else if (Platform.isLinux || Platform.isAndroid) {
      return DynamicLibrary.open('librust_ocr.so');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('librust_ocr.dylib');
    } else if (Platform.isIOS) {
       // iOS uses static linking
      return DynamicLibrary.process();
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Get last error from Rust
  String? getLastError() {
    final resultPtr = _getLastError();
    if (resultPtr == nullptr) return null;
    final result = resultPtr.cast<Utf8>().toDartString();
    _freeString(resultPtr);
    return result;
  }

  /// Solve captcha from image bytes
  /// Returns null if OCR fails (call getLastError for details)
  String? solveCaptcha(Uint8List imageBytes) {
    final imagePtr = calloc<Uint8>(imageBytes.length);

    try {
      for (int i = 0; i < imageBytes.length; i++) {
        imagePtr[i] = imageBytes[i];
      }

      final resultPtr = _solveCaptcha(imagePtr, imageBytes.length);

      if (resultPtr == nullptr) {
        return null;
      }

      final result = resultPtr.cast<Utf8>().toDartString();
      _freeString(resultPtr);
      return result;
    } finally {
      calloc.free(imagePtr);
    }
  }
}

// Native function typedefs
typedef _SolveCaptchaNative = Pointer<Int8> Function(Pointer<Uint8> imagePtr, IntPtr imageLen);
typedef _SolveCaptcha = Pointer<Int8> Function(Pointer<Uint8> imagePtr, int imageLen);

typedef _FreeStringNative = Void Function(Pointer<Int8> s);
typedef _FreeString = void Function(Pointer<Int8> s);

typedef _GetLastErrorNative = Pointer<Int8> Function();
typedef _GetLastError = Pointer<Int8> Function();
