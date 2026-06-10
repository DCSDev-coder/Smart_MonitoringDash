import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://dcstack.site/docs/index.php?action=get_remote_access_logs';
  print('Fetching: $url');
  
  final res = await http.post(
    Uri.parse(url),
    headers: {
      'Content-Type': 'application/json',
      // We need a valid token to test, but we can just see if it returns 401 or 400
    },
    body: jsonEncode({
      'action': 'get_remote_access_logs',
      'site_id': 1
    }),
  );
  
  print('Status Code: ${res.statusCode}');
  print('Body: ${res.body}');
}
