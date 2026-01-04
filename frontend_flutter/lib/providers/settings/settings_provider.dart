import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth/auth_provider.dart';
import 'package:provider/provider.dart';

class SettingsProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  // Retrieve user info from AuthProvider
  Map<String, String?> getUserInfo(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return {
      "name":
          auth.userId ??
          "Unknown User", // Placeholder — replace with profile data if available
      "email": auth.token != null
          ? "user@liora.ai"
          : "Not Logged In", // mock fallback
    };
  }

  Future<void> logout(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout(context);
  }
}
