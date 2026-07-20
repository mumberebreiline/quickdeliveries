import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin wrapper around package:http for any future non-Firebase API calls
/// (e.g. Google Directions API for real driving-time route data). Nothing
/// in the app depends on this yet — it's here so that when that day comes,
/// the rest of the app calls plain Dart methods instead of package:http
/// directly.
class ApiService {
  Future<Map<String, dynamic>> get(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('GET $url failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('POST $url failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
