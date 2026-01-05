import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/ucas_client.dart';
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
    _initWebView();
  }

  Future<void> _initWebView() async {
    // 1. Configure User Agent to match UcasClient (consistent session)
    // UcasClient uses: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36
    const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(userAgent)
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
      );

    // 2. Sync Cookies
    try {
      final cookieManager = WebViewCookieManager();
      
      // Get all cookies from Client
      final sepCookies = await UcasClient.getCookies('https://sep.ucas.ac.cn');
      
      // Inject for multiple domains to ensure coverage
      final domains = ['sep.ucas.ac.cn', 'ucas.ac.cn', '.ucas.ac.cn', Uri.parse(widget.url).host];
      final uniqueCookies = <String, Cookie>{};
      
      for (final c in sepCookies) {
         uniqueCookies[c.name] = c;
      }
      
      // Also get target URL cookies if different
      if (!widget.url.contains('sep.ucas.ac.cn')) {
         final targetCookies = await UcasClient.getCookies(widget.url);
         for (final c in targetCookies) {
            uniqueCookies[c.name] = c;
         }
      }

      for (final domain in domains) {
          if (domain.isEmpty) continue;
          for (final c in uniqueCookies.values) {
              try {
                await cookieManager.setCookie(
                  WebViewCookie(
                    name: c.name,
                    value: c.value,
                    domain: domain,
                    path: '/',
                  ),
                );
              } catch (_) {}
          }
      }
    } catch (e) {
      debugPrint('Error syncing cookies: $e');
    }

    _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handleAutoLogin(String url) async {
    // Fallback: If Cookie Sync failed and we are at login page, try to auto-fill
    if (widget.settings == null) return;
    
    // Check if on SEP Login page
    if (url.contains('sep.ucas.ac.cn') && (url.contains('login') || url.contains('slogin'))) {
       // Access properties directly
       final u = widget.settings!.username;
       final p = widget.settings!.password;
       
       if (u.isNotEmpty && p.isNotEmpty) {
          // JS to fill and submit
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
