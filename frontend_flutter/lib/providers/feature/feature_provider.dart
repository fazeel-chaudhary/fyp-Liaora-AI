import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend_flutter/models/message_model.dart';
import 'package:frontend_flutter/services/feature_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureProvider with ChangeNotifier {
  static const String _memoryFilesKey = 'memory_files';
  static const String _journalEntriesKey = 'journal_entries';
  static const String _journalPinKey = 'journal_pin';
  static const String _dailyMoodKey = 'daily_mood';
  static const String _dailyDateKey = 'daily_date';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final List<String> _memoryFiles = [];
  final List<Map<String, String>> _journalEntries = [];
  String? _dailyMood;
  String? _lastDailyDate;
  int? _remoteMessageCount;

  List<String> get memoryFiles => List.unmodifiable(_memoryFiles);
  List<Map<String, String>> get journalEntries => List.unmodifiable(_journalEntries);
  String? get dailyMood => _dailyMood;
  int? get remoteMessageCount => _remoteMessageCount;

  Future<void> initialize({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    _memoryFiles
      ..clear()
      ..addAll(prefs.getStringList(_memoryFilesKey) ?? []);

    final rawJournal = prefs.getStringList(_journalEntriesKey) ?? [];
    _journalEntries
      ..clear()
      ..addAll(
        rawJournal
            .map((entry) {
              try {
                return Map<String, String>.from(
                  jsonDecode(entry) as Map<String, dynamic>,
                );
              } catch (_) {
                return null;
              }
            })
            .whereType<Map<String, String>>(),
      );

    _dailyMood = prefs.getString(_dailyMoodKey);
    _lastDailyDate = prefs.getString(_dailyDateKey);

    if (userId != null && userId.isNotEmpty) {
      await _loadRemoteData(userId);
    }

    notifyListeners();
  }

  Future<void> addJournalEntry(String text, {String? userId}) async {
    if (text.trim().isEmpty) return;
    final newEntry = {
      'content': text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    _journalEntries.add(newEntry);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _journalEntriesKey,
      _journalEntries.map((entry) => jsonEncode(entry)).toList(),
    );
    if (userId != null && userId.isNotEmpty) {
      await FeatureService.saveJournalEntry(
        userId: userId,
        content: text.trim(),
      );
    }
    notifyListeners();
  }

  Future<void> setJournalPin(String pin) async {
    final cleaned = pin.trim();
    final pinPattern = RegExp(r'^\d{4,6}$');
    if (!pinPattern.hasMatch(cleaned)) {
      throw ArgumentError('PIN must be 4-6 digits');
    }
    await _secureStorage.write(key: _journalPinKey, value: cleaned);
  }

  Future<bool> verifyJournalPin(String pin) async {
    final savedPin = await _secureStorage.read(key: _journalPinKey);
    return savedPin != null && savedPin == pin;
  }

  Future<bool> hasJournalPin() async {
    final savedPin = await _secureStorage.read(key: _journalPinKey);
    return savedPin != null && savedPin.isNotEmpty;
  }

  Future<void> pickMemoryFile({String? userId}) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final fileName = result.files.first.name;
    if (!_memoryFiles.contains(fileName)) {
      _memoryFiles.add(fileName);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_memoryFilesKey, _memoryFiles);
      if (userId != null && userId.isNotEmpty) {
        await FeatureService.saveMemoryFile(userId: userId, fileName: fileName);
      }
      notifyListeners();
    }
  }

  Future<void> completeDailyCheckIn(String mood, {String? userId}) async {
    _dailyMood = mood;
    _lastDailyDate = DateTime.now().toIso8601String().split('T').first;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyMoodKey, mood);
    await prefs.setString(_dailyDateKey, _lastDailyDate!);
    if (userId != null && userId.isNotEmpty) {
      await FeatureService.saveDailyCheckIn(
        userId: userId,
        mood: mood,
        checkInDate: _lastDailyDate!,
      );
    }
    notifyListeners();
  }

  bool isTodayCheckInDone() {
    final today = DateTime.now().toIso8601String().split('T').first;
    return _lastDailyDate == today;
  }

  String recommendationForMood() {
    switch (_dailyMood) {
      case 'happy':
        return 'Great momentum today. Try a creativity-focused companion chat.';
      case 'sad':
        return 'Take a short reflective journal entry and ask Echo for support.';
      case 'stressed':
        return 'Try a slower breathing prompt and ask Aura for a grounding response.';
      case 'neutral':
        return 'Set one intention and use OrionBot for focused planning.';
      default:
        return 'Complete a check-in to receive a daily recommendation.';
    }
  }

  Map<String, int> buildMemoryStats({
    required List<Message> messages,
    required Map<String, int> emotionStats,
  }) {
    return {
      'messages': _remoteMessageCount ?? messages.length,
      'journal_entries': _journalEntries.length,
      'uploaded_files': _memoryFiles.length,
      'tracked_emotions': emotionStats.values.fold(0, (a, b) => a + b),
    };
  }

  Future<void> _loadRemoteData(String userId) async {
    try {
      final customBotsRes = await FeatureService.getCustomBots(userId);
      final memoryFilesRes = await FeatureService.getMemoryFiles(userId);
      final journalRes = await FeatureService.getJournalEntries(userId);
      final checkInRes = await FeatureService.getLatestDailyCheckIn(userId);
      final dashboardRes = await FeatureService.getMemoryDashboard(userId);

      final remoteFiles = memoryFilesRes['files'];
      if (remoteFiles is List) {
        _memoryFiles
          ..clear()
          ..addAll(
            remoteFiles
                .map((e) => (e as Map<String, dynamic>)['file_name'] as String? ?? '')
                .where((name) => name.isNotEmpty),
          );
      }

      final remoteJournal = journalRes['entries'];
      if (remoteJournal is List) {
        _journalEntries
          ..clear()
          ..addAll(
            remoteJournal.map((e) {
              final row = Map<String, dynamic>.from(e as Map);
              return {
                'content': (row['content'] ?? '').toString(),
                'timestamp': (row['timestamp'] ?? '').toString(),
              };
            }),
          );
      }

      final remoteMood = checkInRes['mood'];
      final remoteDate = checkInRes['check_in_date'];
      if (remoteMood is String && remoteMood.isNotEmpty) {
        _dailyMood = remoteMood;
      }
      if (remoteDate is String && remoteDate.isNotEmpty) {
        _lastDailyDate = remoteDate;
      }

      final dashboardMessages = dashboardRes['messages'];
      if (dashboardMessages is int) {
        _remoteMessageCount = dashboardMessages;
      }

      // Touch custom bot payload to ensure schema compatibility without forcing UI update here.
      customBotsRes['bots'];
    } catch (_) {
      // Keep local fallback when backend tables are unavailable.
    }
  }
}
