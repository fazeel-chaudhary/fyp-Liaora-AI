import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend_flutter/services/auth_services.dart';
import 'package:frontend_flutter/utils/error_handler/snackbar.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  String? _token;
  String? _userId;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _lastError;

  String? get token => _token;
  String? get userId => _userId;
  bool get isLoggedIn => _token != null;

  bool get isLogin => _isLogin;
  bool get isLoading => _isLoading;
  bool get obscurePassword => _obscurePassword;
  String? get lastError => _lastError;

  void toggleAuthMode() {
    _isLogin = !_isLogin;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> signup(
    String email,
    String password,
    String name,
    BuildContext context,
  ) async {
    _setLoading(true);
    try {
      final res = await AuthService.signup(email, password, name);
      if (context.mounted) {
        if (res.containsKey("message")) {
          SnackbarHelper.show(context, res["message"], isError: false);
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.show(context, "Signup failed: $e");
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> login(
    String email,
    String password,
    BuildContext context,
  ) async {
    _setLoading(true);
    _lastError = null;
    try {
      final res = await AuthService.login(email, password);

      if (res.containsKey("access_token") && res.containsKey("user_id")) {
        _token = res["access_token"];
        _userId = res["user_id"];
        await _storage.write(key: "token", value: _token);
        await _storage.write(key: "userId", value: _userId);
        notifyListeners();
        if (context.mounted) {
          SnackbarHelper.show(context, "Login successful", isError: false);
        }
      } else {
        throw Exception(res["detail"] ?? "Login failed");
      }
    } catch (e) {
      _lastError = e.toString().replaceFirst('Exception: ', '').trim();
      if (context.mounted) {
        SnackbarHelper.show(context, "Login failed: ${_lastError ?? e}");
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> tryAutoLogin() async {
    _token = await _storage.read(key: "token");
    _userId = await _storage.read(key: "userId");
    if (_token == null) return false;

    try {
      final gate = await AuthService.authGate(_token!);
      final gateSuccess = gate["success"] == true;
      final gateUserId = gate["user_id"]?.toString();
      final storedUserId = _userId?.toString();

      if (gateSuccess &&
          gateUserId != null &&
          storedUserId != null &&
          gateUserId == storedUserId) {
        return true;
      }

      _token = null;
      _userId = null;
      await _storage.deleteAll();
      return false;
    } catch (_) {
      _token = null;
      _userId = null;
      await _storage.deleteAll();
      return false;
    }
  }

  Future<void> logout(BuildContext context) async {
    _setLoading(true);
    try {
      await AuthService.logout();
      _token = null;
      _userId = null;
      await _storage.deleteAll();
      notifyListeners();
      if (context.mounted) {
        SnackbarHelper.show(context, "Logged out successfully", isError: false);
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.show(context, "Logout failed: $e");
      }
    } finally {
      _setLoading(false);
    }
  }
}
