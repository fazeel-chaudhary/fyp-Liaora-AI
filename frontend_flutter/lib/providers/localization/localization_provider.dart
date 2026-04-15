import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationProvider with ChangeNotifier {
  static const String _languageStorageKey = 'app_language_code';

  String _languageCode = 'en';

  String get languageCode => _languageCode;
  Locale get locale => Locale(_languageCode);

  final Map<String, Map<String, String>> _dictionary = {
    'en': {
      'app_name': 'Liora AI',
      'choose_companion': 'Choose Your AI Companion',
      'features_lab': 'AI Feature Lab',
      'settings': 'Settings',
      'chat_placeholder': 'Type a message...',
      'online': 'Online',
    },
    'es': {
      'app_name': 'Liora AI',
      'choose_companion': 'Elige tu companero de IA',
      'features_lab': 'Laboratorio de Funciones IA',
      'settings': 'Configuracion',
      'chat_placeholder': 'Escribe un mensaje...',
      'online': 'En linea',
    },
    'ms': {
      'app_name': 'Liora AI',
      'choose_companion': 'Pilih Rakan AI Anda',
      'features_lab': 'Makmal Ciri AI',
      'settings': 'Tetapan',
      'chat_placeholder': 'Taip mesej...',
      'online': 'Dalam talian',
    },
  };

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString(_languageStorageKey) ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!_dictionary.containsKey(code)) return;
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageStorageKey, code);
    notifyListeners();
  }

  String t(String key) {
    return _dictionary[_languageCode]?[key] ?? _dictionary['en']?[key] ?? key;
  }

  List<String> get supportedLanguages => _dictionary.keys.toList();
}
