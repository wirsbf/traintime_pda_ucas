import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/ucas_client.dart';
import '../data/settings_controller.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key, required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    // Sync cookies from UcasClient (SEP session)
    // Sync cookies from UcasClient (SEP session)
    try {
      final cookieManager = WebViewCookieManager();
      
      // 1. Get SEP cookies (Auth Source)
      final sepCookies = await UcasClient.getCookies('https://sep.ucas.ac.cn');
      for (final c in sepCookies) {
        // Set for SEP domain (Auth)
        await cookieManager.setCookie(WebViewCookie(name: c.name, value: c.value, domain: 'sep.ucas.ac.cn', path: '/'));
        await cookieManager.setCookie(WebViewCookie(name: c.name, value: c.value, domain: '.ucas.ac.cn', path: '/'));
      }

      // 2. Get Target URL cookies (if any exist in jar)
      if (!widget.url.contains('sep.ucas.ac.cn')) {
         final targetCookies = await UcasClient.getCookies(widget.url);
         final host = Uri.parse(widget.url).host;
         for (final c in targetCookies) {
            await cookieManager.setCookie(WebViewCookie(name: c.name, value: c.value, domain: host, path: '/'));
         }
      }
    } catch (e) {
      debugPrint('Error syncing cookies: $e');
    }

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
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }
  
  // Auto-fill and submit login form if we land on SEP login page
  Future<void> _handleAutoLogin(String url) async {
    // Check if on login page
    if (url.contains('sep.ucas.ac.cn') && (url.contains('login') || url.contains('slogin'))) {
       final settings = await SettingsController.load();
       if (settings.username.isNotEmpty && settings.password.isNotEmpty) {
          final u = settings.username;
          final p = settings.password;
          
          // JS to fill and submit
          // Note: The form usually has name='userName', name='pwd', id='sb' (submit button)
          final js = """
             (function() {
                var u = document.querySelector('input[name="userName"]');
                var p = document.querySelector('input[name="pwd"]');
                var btn = document.getElementById('sb');
                
                if (u && p && btn) {
                   u.value = '$u';
                   p.value = '$p';
                   // Small delay to ensure value is registered?
                   setTimeout(function() {
                      btn.click();
                   }, 500);
                }
             })();
          """;
          
          await _controller.runJavaScript(js);
          
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在尝试自动登录...'), duration: Duration(seconds: 1)),
             );
          }
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
