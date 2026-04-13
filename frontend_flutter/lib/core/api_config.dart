import 'package:flutter/foundation.dart';

/// Resolves the FastAPI base URL for each platform.
///
/// **Override (physical device / staging):**
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000`
///
/// **Backend:** run `run_dev.sh` (or `uvicorn ... --host 0.0.0.0`) so the Android
/// emulator and LAN devices can reach your machine.
class ApiConfig {
  ApiConfig._();

  static const String _fromDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_fromDefine.isNotEmpty) {
      return _fromDefine.replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) {
      // Avoid `localhost` → IPv6 (::1) when the API is only on IPv4.
      return 'http://127.0.0.1:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}
