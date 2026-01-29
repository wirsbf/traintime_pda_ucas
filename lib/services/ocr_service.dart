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
      
      // 2. Copy asset to file system
      final data = await rootBundle.load('assets/ddddocr.onnx');
      final bytes = data.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ddddocr.onnx');
      await file.writeAsBytes(bytes);
  
      // 3. Load Session
      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromFile(file, sessionOptions);
      print("ddddocr Model Loaded Successfully. Vocab size: ${_vocab.length}");
    } catch (e) {
      print("Error initializing OCR model: $e");
      rethrow;
    }
  }

  /// Predict text from image bytes
  Future<String> predict(Uint8List imageBytes) async {
    if (_session == null) await init();

    try {
      // 1. Preprocess (ddddocr style)
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception("Failed to decode image");
      
      // Calculate new width maintaining aspect ratio
      final targetHeight = 64;
      final aspectRatio = image.width / image.height;
      final targetWidth = (targetHeight * aspectRatio).round();
      
      final resized = img.copyResize(image, width: targetWidth, height: targetHeight);
      final grayscale = img.grayscale(resized);
  
      // Convert to Float32 List [1, 1, 64, width] (NCHW)
      final Float32List inputData = Float32List(1 * 1 * targetHeight * targetWidth);
      int pixelIndex = 0;
      
      // Iterate H then W (Row Major)
      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
          final pixel = grayscale.getPixel(x, y);
          // ddddocr normalization: (pixel/255.0 - 0.5) * 2.0
          final r = pixel.r;
          final val = (r / 255.0 - 0.5) * 2.0;
          inputData[pixelIndex++] = val;
        }
      }
      
      // 2. Inference
      final inputOrt = OrtValueTensor.createTensorWithDataList(
          inputData, [1, 1, targetHeight, targetWidth]);
          
      final runOptions = OrtRunOptions();
      final inputs = {'input1': inputOrt};
      
      final outputs = _session!.run(runOptions, inputs);
      final outputTensor = outputs[0];
      
      final outputData = outputTensor?.value;
      
      // Decode
      String result = _decodeDdddocrOutput(outputData);
      
      inputOrt.release();
      runOptions.release();
      for(var o in outputs) o?.release();
      
      return result;
      
    } catch (e) {
      print("Inference error: $e");
      return "Error";
    }
  }
  
  /// Decode ddddocr output [SeqLen, Batch, NumChars]
  String _decodeDdddocrOutput(dynamic outputData) {
    try {
      if (outputData is! List) return "DecodeError1";
      
      // Output structure: [SeqLen][Batch][NumClasses]
      // Checked via python: [24, 1, 8210]
      // In Dart's ONNX Runtime, multidimensional arrays are often flattened or nested lists.
      // Assuming nested lists based on standard behavior.
      
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
          double val = (logits[i] as num).toDouble();
          if (val > maxVal) {
            maxVal = val;
            maxIdx = i;
          }
        }
        
        // CTC Decoding
        // 0 is usually blank in ddddocr (checking indices: 0 appeared frequently in output)
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
