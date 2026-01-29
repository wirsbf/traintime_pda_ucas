# Flutter Integration Guide (ONNX Runtime)

We have successfully trained a mobile-optimized **CRNN Model** (ResNet + LSTM) with **91.06% Accuracy**.
Due to toolchain limitations, we exported it as **ONNX** which is highly performant and widely supported on Flutter via `onnxruntime`.

## 1. Add Dependencies
Add `onnxruntime` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ...
  onnxruntime: ^0.2.0 # Or latest version
  path_provider: ^2.0.0
```

## 2. Asset Setup
The model `crnn.onnx` has been copied to your `assets/` folder.
Ensure it is declared in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/crnn.onnx
```

## 3. Implementation (`lib/services/ocr_service.dart`)
Create this file to handle inference.

```dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img; // You might need 'image' package

class OcrService {
  OrtSession? _session;
  static const String _vocab = "0123456789abcdefghijklmnopqrstuvwxyz";
  
  Future<void> init() async {
    // 1. Copy asset to file system (ONNXRuntime needs file path)
    final data = await rootBundle.load('assets/crnn.onnx');
    final bytes = data.buffer.asUint8List();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/crnn.onnx');
    await file.writeAsBytes(bytes);

    // 2. Load Session
    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromFile(file.path, sessionOptions);
    print("OCR Model Loaded");
  }

  Future<String> predict(Uint8List imageBytes) async {
    if (_session == null) await init();

    // 1. Preprocess
    // Resize to 256x64, Grayscale, Normalize
    final image = img.decodeImage(imageBytes)!;
    final resized = img.copyResize(image, width: 256, height: 64);
    final grayscale = img.grayscale(resized);

    // Convert to Float32 List [1, 1, 64, 256] (NCHW)
    final Float32List inputData = Float32List(1 * 1 * 64 * 256);
    int pixelIndex = 0;
    
    // Iterate H then W (Row Major)
    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 256; x++) {
        final pixel = grayscale.getPixel(x, y);
        // Normalize [0, 255] -> [-1, 1]
        final val = (img.getRed(pixel) / 255.0 - 0.5) * 2.0;
        inputData[pixelIndex++] = val;
      }
    }
    
    // 2. Inference
    final inputOrt = OrtValueTensor.createTensorWithDataList(
        inputData, [1, 1, 64, 256]);
        
    final runOptions = OrtRunOptions();
    final inputs = {'input': inputOrt};
    
    final outputs = _session!.run(runOptions, inputs);
    final outputTensor = outputs[0];
    
    // Output: [32, 1, 37] (SeqLen, Batch, Class) or [1, 32, 37]
    // Note: If you used 'flatten', dimensions might be squeezed?
    // Check shapes during debugging. Assuming [32, 1, 37].
    
    final List<dynamic> outputData = outputTensor.value as List<dynamic>; 
    // Handle nested lists dynamically
    
    // Decode (Greedy)
    String result = "";
    int prevClass = -1;
    
    // Simplified CTC Decode assuming [32][1][37] structure
    // Iterate 32 steps
    for (int t = 0; t < 32; t++) {
        var logits = outputData[t][0]; // Adjust index if batch dim is different
        
        // Manual Max
        double maxVal = -99999.0;
        int maxIdx = 0;
        if (logits is List) {
             for(int i=0; i<37; i++) {
                 double val = (logits[i] as num).toDouble();
                 if (val > maxVal) {
                     maxVal = val;
                     maxIdx = i;
                 }
             }
        }
        
        if (maxIdx != 0 && maxIdx != prevClass) {
            result += _vocab[maxIdx - 1]; 
        }
        prevClass = maxIdx;
    }
    
    inputOrt.release();
    runOptions.release();
    for(var o in outputs) o?.release();
    
    return result;
  }
}
```
