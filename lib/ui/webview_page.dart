import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/ucas_client.dart';

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
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
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
