import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  // Base API URL — localhost for web, emulator loopback for Android
  static String get baseUrl =>
      kIsWeb ? "http://localhost:8000" : "http://127.0.0.1:8000";

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
      return {"error": "GET failed with status ${response.statusCode}"};
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
      return {"error": "POST failed with status ${response.statusCode}"};
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
      return {"error": "DELETE failed with status ${response.statusCode}"};
    }
  }
}
