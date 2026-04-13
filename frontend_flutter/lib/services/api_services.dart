import 'dart:convert';
import 'package:frontend_flutter/core/api_config.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Map<String, dynamic>? _tryDecodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// Handles GET requests
  static Future<dynamic> getRequest(String endpoint, {String? token}) async {
    final headers = {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    final url = Uri.parse("$baseUrl$endpoint");
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("⚠️ [GET] ${response.statusCode}: ${response.body}");
      final decoded = _tryDecodeBody(response.body);
      if (decoded != null) return decoded;
      return {"detail": "GET failed with status ${response.statusCode}"};
    }
  }

  /// Handles POST requests
  static Future<dynamic> postRequest(
    String endpoint, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final headers = {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    final url = Uri.parse("$baseUrl$endpoint");

    print("➡️ [POST] $url");
    print("📦 Body: ${jsonEncode(body)}");

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      print("⚠️ [POST] ${response.statusCode}: ${response.body}");
      final decoded = _tryDecodeBody(response.body);
      if (decoded != null) return decoded;
      return {"detail": "POST failed with status ${response.statusCode}"};
    }
  }

  /// Handles DELETE requests
  static Future<dynamic> deleteRequest(String endpoint, {String? token}) async {
    final headers = {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };

    final url = Uri.parse("$baseUrl$endpoint");
    final response = await http.delete(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("⚠️ [DELETE] ${response.statusCode}: ${response.body}");
      final decoded = _tryDecodeBody(response.body);
      if (decoded != null) return decoded;
      return {"detail": "DELETE failed with status ${response.statusCode}"};
    }
  }
}
