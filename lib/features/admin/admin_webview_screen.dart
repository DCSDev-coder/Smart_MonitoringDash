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
  WebViewController? _controller;
  bool _loading = true;
  String? _errorMessage;

  Uri? _resolveAdminUri(String? rawUrl) {
    final cleaned = (rawUrl ?? '').trim();
    if (cleaned.isEmpty) return null;

    final candidate = cleaned.contains('://') ? cleaned : 'https://$cleaned';
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme.toLowerCase() != 'https') return null;
    return uri;
  }

  @override
  void initState() {
    super.initState();
    final adminUri = _resolveAdminUri(ApiService.instance.baseUrl);
    if (adminUri == null) {
      _loading = false;
      _errorMessage =
          'Admin portal requires a valid HTTPS URL. Sign in to the rack using an HTTPS host before opening this screen.';
      AppLog.w(
        'Blocked admin portal load without valid HTTPS URL',
        tag: 'AdminWebView',
        fields: {'baseUrl': ApiService.instance.baseUrl ?? ''},
      );
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.bgColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final isHttps = uri != null && uri.scheme.toLowerCase() == 'https';
            if (!isHttps) {
              AppLog.w(
                'Blocked non-HTTPS admin navigation',
                tag: 'AdminWebView',
                fields: {'url': request.url},
              );
              if (mounted) {
                setState(() {
                  _errorMessage =
                      'Blocked non-HTTPS admin page. This screen now requires HTTPS only.';
                  _loading = false;
                });
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            AppLog.w(
              'WebView error',
              tag: 'AdminWebView',
              fields: {'description': error.description},
            );
            if (mounted) {
              setState(() {
                _loading = false;
                _errorMessage =
                    'Unable to load the admin portal over HTTPS. Check the rack admin URL and certificate.';
              });
            }
          },
        ),
      )
      ..loadRequest(adminUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADMIN PORTAL',
            style: TextStyle(
                letterSpacing: 1.2, fontSize: 13, fontWeight: FontWeight.bold)),
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
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
            ),
          if (_loading)
            Center(
                child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }
}
