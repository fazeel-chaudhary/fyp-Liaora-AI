import 'package:frontend_flutter/services/api_services.dart';

class AuthService {
  static Future<Map<String, dynamic>> signup(
    String email,
    String password,
    String name,
  ) async {
    return await ApiService.postRequest(
      "/auth/signup",
      body: {"email": email, "password": password, "username": name},
    );
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    return await ApiService.postRequest(
      "/auth/login",
      body: {"email": email, "password": password},
    );
  }

  static Future<Map<String, dynamic>> logout() async {
    return await ApiService.postRequest("/auth/logout");
  }

  static Future<Map<String, dynamic>> authGate(String token) async {
    return await ApiService.getRequest("/auth/gate", token: token);
  }

  static Future<Map<String, dynamic>> getProfile(String userId) async {
    return await ApiService.getRequest("/profile/$userId");
  }
}
