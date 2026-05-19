import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import './cpanel_api_service.dart';

class AdapterApiService {
  AdapterApiService._();
  static final AdapterApiService instance = AdapterApiService._();

  String get _base => AppConfig.adapterBaseUrl;

  bool get isConfigured => _base.isNotEmpty;

  Future<Map<String, dynamic>?> fetchPue({required int siteId}) async {
    if (!isConfigured) return null;

    final token = CpanelApiService.instance.getAuthTokenInMemory();
    if (token == null || token.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] Missing portal auth token in memory.');
      }
      return null;
    }

    final url = Uri.parse('$_base/v1/sites/$siteId/pue');
    try {
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
              '[AdapterApi] fetchPue non-200 (${res.statusCode}): ${res.body}');
        }
        return null;
      }

      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AdapterApi] fetchPue error: $e');
      }
      return null;
    }
  }
}

