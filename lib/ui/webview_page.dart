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
    try {
      final cookieManager = WebViewCookieManager();
      // Get cookies for SEP (where auth happens)
      final cookies = await UcasClient.getCookies('https://sep.ucas.ac.cn');
      for (final cookie in cookies) {
        await cookieManager.setCookie(
          WebViewCookie(
            name: cookie.name,
            value: cookie.value,
            domain: 'ucas.ac.cn', // Set for root domain to suffice
            path: '/',
          ),
        );
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
