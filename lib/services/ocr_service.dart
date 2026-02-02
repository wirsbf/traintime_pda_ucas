import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class OcrService {
  OrtSession? _session;
  List<String> _vocab = [];
  
  /// Initialize the model
  Future<void> init() async {
    if (_session != null) return;
    
    try {
      // 1. Load Vocab
      String jsonString = await rootBundle.loadString('assets/ddddocr_vocab.json');
      _vocab = List<String>.from(json.decode(jsonString));
      
      // 2. Load Model
      // Use original 54MB Common/Beta Model
      final data = await rootBundle.load('assets/ddddocr.onnx');
      final bytes = data.buffer.asUint8List();

      // 3. Load Session from bytes directly
      final sessionOptions = OrtSessionOptions();
      try {
        _session = OrtSession.fromBuffer(bytes, sessionOptions);
        print("ddddocr 54MB (Beta/Common) Model Loaded Successfully from bytes. Vocab size: ${_vocab.length}");
      } catch (e) {
        print("[OCR] OrtSession.fromBuffer failed: $e");
        rethrow;
      }
    } catch (e) {
      print("Error initializing OCR model: $e");
      rethrow;
    }
  }

  /// Initialize with provided bytes (useful for testing)
  void initWithBytes(Uint8List modelBytes, List<String> vocab) {
    _vocab = vocab;
    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
    print("ddddocr Initialized with manual bytes. Vocab size: ${_vocab.length}");
  }

  /// Predict text from image bytes
  Future<String> predict(Uint8List imageBytes, {String? allowedChars, String? debugSavePath}) async {
    if (_session == null) await init();

    try {
      // ... (existing code omitted) ...
      // 1. Initial Processing
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) throw Exception("Failed to decode image");
      
      // A. Grayscale + Basic Contrast
      // A. Manual Grayscale Conversion (To ensure consistent L channel)
      var gray = img.Image(width: decoded.width, height: decoded.height, numChannels: 1);
      for (final p in decoded) {
        // Luminance: 0.299 R + 0.587 G + 0.114 B
        final l = p.luminance.toInt();
        gray.setPixelRgb(p.x, p.y, l, l, l);
      }
      
      // Simple Autocontrast
      int minL = 255;
      int maxL = 0;
      for (final p in gray) {
        final l = p.r.toInt();
        if (l < minL) minL = l;
        if (l > maxL) maxL = l;
      }
      
      if (maxL > minL) {
        for (final p in gray) {
          final l = p.r.toInt();
          final val = ((l - minL) * 255 / (maxL - minL)).clamp(0, 255).toInt();
          p.r = val; p.g = val; p.b = val;
        }
      }

      // B. Robust Inversion (BG is usually corner color)
      final corners = [
        gray.getPixel(0, 0).luminance.toInt(),
        gray.getPixel(gray.width - 1, 0).luminance.toInt(),
        gray.getPixel(0, gray.height - 1).luminance.toInt(),
        gray.getPixel(gray.width - 1, gray.height - 1).luminance.toInt(),
      ];
      final avgCorner = corners.reduce((a, b) => a + b) / 4;
      
      if (avgCorner < 128) {
        gray = img.invert(gray);
      }
      final thresholds = [127, 160, 100, 200];
      img.Image? bestCleaned;
      
      for (var thresh in thresholds) {
        final binarized = img.Image(width: gray.width, height: gray.height);
        for (final p in gray) {
          final v = p.r < thresh ? 0 : 255;
          binarized.setPixelRgb(p.x, p.y, v, v, v);
        }

        final visited = Uint8List(gray.width * gray.height);
        final keptPixels = <(int, int)>[];
        final totalArea = gray.width * gray.height;
        int componentCount = 0;

        for (int y = 0; y < gray.height; y++) {
          for (int x = 0; x < gray.width; x++) {
            final idx = y * gray.width + x;
            if (visited[idx] == 0 && binarized.getPixel(x, y).r < 128) {
              componentCount++;
              final component = <(int, int)>[];
              final queue = <(int, int)>[(x, y)];
              visited[idx] = 1;
              int minX = x, maxX = x, minY = y, maxY = y;

              while (queue.isNotEmpty) {
                final curr = queue.removeAt(0);
                component.add(curr);
                for (final n in [(curr.$1 - 1, curr.$2), (curr.$1 + 1, curr.$2), (curr.$1, curr.$2 - 1), (curr.$1, curr.$2 + 1)]) {
                  if (n.$1 >= 0 && n.$1 < gray.width && n.$2 >= 0 && n.$2 < gray.height) {
                    final nIdx = n.$2 * gray.width + n.$1;
                    if (visited[nIdx] == 0 && binarized.getPixel(n.$1, n.$2).r < 128) {
                      visited[nIdx] = 1;
                      queue.add(n);
                      if (n.$1 < minX) minX = n.$1; if (n.$1 > maxX) maxX = n.$1;
                      if (n.$2 < minY) minY = n.$2; if (n.$2 > maxY) maxY = n.$2;
                    }
                  }
                }
              }

              final cw = maxX - minX + 1;
              final ch = maxY - minY + 1;
              final area = component.length;

              // Filter Logic (Enhanced for solidity)
              bool keep = true;
              
              // 1. Remove background blocks
              if (area > totalArea * 0.8) keep = false;
              
              // 2. Remove "Dots" (Noise) - increased threshold
              if (area < 15) keep = false;
              
              // 3. Remove "Isolated Horizontal Lines"
              // Long thin lines (interference)
              if (cw > gray.width * 0.5 && ch < 10) keep = false;
              // Shorter but very thin lines
              if (cw > 20 && ch < 4) keep = false;
              // Short horizontal lines (e.g. 12x4, 9x3 in 01364)
              if (cw >= 8 && ch < 5) keep = false;

              if (keep) keptPixels.addAll(component);
            }
          }
        }
        
        // Python: if len(current_kept) > 40: break
        if (keptPixels.length > 20) {
          final cleaned = img.Image(width: gray.width, height: gray.height);
          img.fill(cleaned, color: img.ColorRgb8(255, 255, 255));
          for (final p in keptPixels) {
             // Python: out_pixels[x, y] = 0 (Black)
             cleaned.setPixelRgb(p.$1, p.$2, 0, 0, 0);
          }
          bestCleaned = cleaned;
          print("  [CCA] Selected Threshold $thresh with ${keptPixels.length} kept pixels (found $componentCount components).");
          break;
        } else {
          // print("  [CCA] Threshold $thresh failed: ${keptPixels.length} kept pixels (found $componentCount components).");
        }
      }

      final finalInput = bestCleaned ?? gray;
      
      // D. Dilation (Cross Filter 3x3) - Milder than square to avoid merging 54917 features
      final dilated = img.Image.from(finalInput); // Copy
      for (int y = 1; y < finalInput.height - 1; y++) {
        for (int x = 1; x < finalInput.width - 1; x++) {
          int minVal = finalInput.getPixel(x, y).r.toInt();
          // Check 4 neighbors (Up, Down, Left, Right)
          if (finalInput.getPixel(x - 1, y).r < minVal) minVal = finalInput.getPixel(x - 1, y).r.toInt();
          if (finalInput.getPixel(x + 1, y).r < minVal) minVal = finalInput.getPixel(x + 1, y).r.toInt();
          if (finalInput.getPixel(x, y - 1).r < minVal) minVal = finalInput.getPixel(x, y - 1).r.toInt();
          if (finalInput.getPixel(x, y + 1).r < minVal) minVal = finalInput.getPixel(x, y + 1).r.toInt();
          
          dilated.setPixelRgb(x, y, minVal, minVal, minVal);
        }
      }
      
      // E. Pad to 64px height
      final targetHeight = 64;
      final padded = img.Image(width: dilated.width, height: targetHeight);
      img.fill(padded, color: img.ColorRgb8(255, 255, 255));
      final dstY = (targetHeight - dilated.height) ~/ 2;
      img.compositeImage(padded, dilated, dstX: 0, dstY: dstY);
      
      if (debugSavePath != null) {
        try {
          final f = File(debugSavePath);
          if (!f.parent.existsSync()) f.parent.createSync(recursive: true);
          f.writeAsBytesSync(img.encodePng(padded));
          print("Saved debug image: $debugSavePath");
        } catch (e) {
          print("Failed to save debug image: $e");
        }
      }

      // Convert to Float32 List [1, 1, 64, width] (NCHW)

      
      // DEBUG: Save processed image
      /*
      try {
        final tempDir = Directory.systemTemp;
        File('${tempDir.path}/ocr_debug.png').writeAsBytesSync(img.encodePng(padded));
        print("DEBUG IMAGE SAVED: ${tempDir.path}/ocr_debug.png");
      } catch (e) { print("Debug save failed: $e"); }
      */


      // Convert to Float32 List [1, 1, 64, width] (NCHW)
      final Float32List inputData = Float32List(1 * 1 * padded.height * padded.width);
      int pixelIndex = 0;
      for (int y = 0; y < padded.height; y++) {
        for (int x = 0; x < padded.width; x++) {
          final pixel = padded.getPixel(x, y);
          final r = pixel.r;
          // Normalization: -1..1 for ddddocr
          final val = (r / 255.0 - 0.5) * 2.0;
          inputData[pixelIndex++] = val;
        }
      }
      
      // 2. Inference
      final inputOrt = OrtValueTensor.createTensorWithDataList(
          inputData, [1, 1, padded.height, padded.width]);
          
      final runOptions = OrtRunOptions();
      final inputs = {'input1': inputOrt};
      
      final outputs = _session!.run(runOptions, inputs);
      final outputTensor = outputs[0];
      final outputData = outputTensor?.value;
      
      // Decode
      String result = _decodeDdddocrOutput(outputData, allowedChars: allowedChars);
      
      inputOrt.release();
      runOptions.release();
      for (var o in outputs) o?.release();
      
      return result;
      
    } catch (e) {
      print("Inference error: $e");
      return "Error";
    }
  }
  
  /// Decode ddddocr output [SeqLen, Batch, NumChars]
  String _decodeDdddocrOutput(dynamic outputData, {String? allowedChars}) {
    try {
      if (outputData is! List) return "DecodeError1";
      
      // Output structure: [SeqLen][Batch][NumClasses]
      // Checked via python: [24, 1, 8210]
      // In Dart's ONNX Runtime, multidimensional arrays are often flattened or nested lists.
      // Assuming nested lists based on standard behavior.
      
      // Pre-compute allowed indices if allowedChars is set
      Set<int>? allowedIndices;
      if (allowedChars != null && allowedChars.isNotEmpty) {
        allowedIndices = {};
        for (int i = 0; i < _vocab.length; i++) {
          if (allowedChars.contains(_vocab[i])) {
            allowedIndices.add(i);
          }
        }
        // Always include blank (idx 0) if not already there
        allowedIndices.add(0); 
      }

      String result = "";
      int prevIdx = -1;
      
      // Iterate over Sequence Length
      for (var batchList in outputData) {
        // bathList is [Batch][NumClasses], here Batch=1, so [1][8210]
        if (batchList is! List || batchList.isEmpty) continue;
        
        var logits = batchList[0]; // [8210]
        
        if (logits is! List) continue;
        
        // Find Argmax
        int maxIdx = 0;
        double maxVal = -double.infinity;
        
        for (int i = 0; i < logits.length; i++) {
          // If filtering, skip disallowed indices
          if (allowedIndices != null && !allowedIndices.contains(i)) {
             continue;
          }

          double val = (logits[i] as num).toDouble();
          if (val > maxVal) {
            maxVal = val;
            maxIdx = i;
          }
        }
        
        // CTC Decoding
        // 0 is Blank. 
        if (maxIdx != 0 && maxIdx != prevIdx) {
          if (maxIdx > 0 && maxIdx < _vocab.length) {
             result += _vocab[maxIdx];
          }
        }
        prevIdx = maxIdx;
      }
      
      return result;
    } catch (e) {
      print("Decode error: $e");
      return "DecodeErr";
    }
  }
  



  
  void dispose() {
    _session?.release();
  }
}
