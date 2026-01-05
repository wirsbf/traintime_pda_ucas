import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<String?> showCaptchaDialog(BuildContext context, Uint8List image) {
  final codeController = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('请输入验证码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.memory(image, height: 60, fit: BoxFit.contain),
          const SizedBox(height: 12),
          TextField(
            controller: codeController, 
            autofocus: true, 
            decoration: const InputDecoration(labelText: '验证码', border: OutlineInputBorder()),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(context, codeController.text.trim()), child: const Text('确定')),
      ],
    ),
  );
}
