import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/network/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';

class AdminWebviewScreen extends StatefulWidget {
  const AdminWebviewScreen({super.key});

  @override
  State<AdminWebviewScreen> createState() => _AdminWebviewScreenState();
}

class _AdminWebviewScreenState extends State<AdminWebviewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final url = ApiService.instance.baseUrl ?? '219.92.246.237';
    final fullUrl = url.startsWith('http') ? url : 'http://$url';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.bgColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) {
            AppLog.w(
              'WebView error',
              tag: 'AdminWebView',
              fields: {'description': error.description},
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(fullUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADMIN PORTAL', style: TextStyle(letterSpacing: 1.2, fontSize: 13, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen)),
        ],
      ),
    );
  }
}
