import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/providers/localization/localization_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalizationProvider', () {
    test('loads default language when storage is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = LocalizationProvider();

      await provider.loadLanguage();

      expect(provider.languageCode, 'en');
      expect(provider.t('settings'), 'Settings');
    });

    test('persists and restores selected language', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = LocalizationProvider();

      await provider.setLanguage('ms');
      final restored = LocalizationProvider();
      await restored.loadLanguage();

      expect(restored.languageCode, 'ms');
      expect(restored.t('online'), 'Dalam talian');
    });
  });
}
