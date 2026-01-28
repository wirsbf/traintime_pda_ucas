import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/captcha_ocr.dart';

Future<String?> showCaptchaDialog(BuildContext context, Uint8List image) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CaptchaDialogHelper(image: image),
  );
}

class _CaptchaDialogHelper extends StatefulWidget {
  final Uint8List image;
  const _CaptchaDialogHelper({required this.image});

  @override
  State<_CaptchaDialogHelper> createState() => _CaptchaDialogHelperState();
}

class _CaptchaDialogHelperState extends State<_CaptchaDialogHelper> {
  final _codeController = TextEditingController();
  bool _recognizing = true;
  String _statusText = '正在识别验证码...';

  @override
  void initState() {
    super.initState();
    _startRecognition();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _startRecognition() async {
    // Run OCR in a microtask or delay slightly to allow UI to render
    await Future.delayed(Duration.zero);
    
    String? result;
    try {
      result = await CaptchaOcr.instance.solveCaptcha(widget.image);
    } catch (e) {
      debugPrint("CaptchaOcr Exception: $e");
    }

    if (!mounted) return;

    setState(() {
      _recognizing = false;
      if (result != null && result.isNotEmpty) {
        _codeController.text = result;
        _statusText = '识别成功';
      } else {
        final err = CaptchaOcr.instance.lastError;
        _statusText = '识别失败: ${err ?? "未知错误"}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('请输入验证码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.memory(widget.image, height: 60),
          const SizedBox(height: 16),
          if (_recognizing)
            const Row(
               children: [
                 SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                 SizedBox(width: 8),
                 Text("正在识别..."),
               ]
            )
          else 
            Text(_statusText, style: TextStyle(
              color: _statusText.contains('失败') ? Colors.red : Colors.green,
              fontSize: 12
            )),
          const SizedBox(height: 8),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '验证码',
            ),
            autofocus: true,
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                Navigator.pop(context, val.trim());
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_codeController.text.trim().isNotEmpty) {
              Navigator.pop(context, _codeController.text.trim());
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
