import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth/auth_provider.dart';
import 'package:frontend_flutter/services/auth_services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String _themeStorageKey = 'is_dark_mode';

  bool _isDarkMode = false;
  bool _isProfileLoading = false;
  String? _profileName;
  String? _profileEmail;
  String? _profileError;

  bool get isDarkMode => _isDarkMode;
  bool get isProfileLoading => _isProfileLoading;
  String? get profileError => _profileError;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeStorageKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeStorageKey, value);
    notifyListeners();
  }

  Map<String, String> getUserInfo(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final fallbackName = auth.userId ?? "Unknown User";
    final fallbackEmail = auth.token != null ? "user@liora.ai" : "Not Logged In";

    return {
      "name": _profileName ?? fallbackName,
      "email": _profileEmail ?? fallbackEmail,
    };
  }

  Future<void> loadUserProfile(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.userId;
    if (userId == null || userId.isEmpty) {
      _profileError = "User not signed in";
      notifyListeners();
      return;
    }

    _isProfileLoading = true;
    _profileError = null;
    notifyListeners();

    try {
      final response = await AuthService.getProfile(userId);
      final name = response["name"];
      final email = response["email"];

      if (name is String && name.isNotEmpty) {
        _profileName = name;
      }
      if (email is String && email.isNotEmpty) {
        _profileEmail = email;
      }
    } catch (_) {
      _profileError = "Unable to load profile";
    } finally {
      _isProfileLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout(context);
  }
}
