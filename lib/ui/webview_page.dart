import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/settings_controller.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key, required this.url, required this.title, this.settings});

  final String url;
  final String title;
  final SettingsController? settings;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    
    // Create controller synchronously
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _loading = false);
            _handleAutoLogin(url);
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handleAutoLogin(String url) async {
    if (widget.settings == null) return;
    
    // Check if on SEP Login page
    if (url.contains('sep.ucas.ac.cn') && (url.contains('login') || url.contains('slogin'))) {
      final u = widget.settings!.username;
      final p = widget.settings!.password;
      
      if (u.isNotEmpty && p.isNotEmpty) {
        final js = """
          (function() {
            var u = document.querySelector('input[name="userName"]');
            var p = document.querySelector('input[name="pwd"]');
            var btn = document.getElementById('sb');
            
            if (u && p && btn) {
              u.value = '$u';
              p.value = '$p';
              setTimeout(function() {
                btn.click();
              }, 500);
            }
          })();
        """;
        try {
          await _controller.runJavaScript(js);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('正在自动登录...'), duration: Duration(seconds: 1)),
            );
          }
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
