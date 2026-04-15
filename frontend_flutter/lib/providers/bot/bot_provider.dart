import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:frontend_flutter/models/bot_model.dart';
import 'package:frontend_flutter/services/bot_services.dart';
import 'package:frontend_flutter/services/feature_services.dart';
import 'package:frontend_flutter/utils/error_handler/snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BotProvider with ChangeNotifier {
  static const String _customBotsStorageKey = 'custom_bots';

  final List<Bot> _customBots = [];
  List<Bot> _bots = [];
  bool _isLoading = false;

  List<Bot> get bots => _bots;
  List<Bot> get customBots => List.unmodifiable(_customBots);
  bool get isLoading => _isLoading;

  Future<void> fetchBots(BuildContext context, {String? userId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final botList = await BotService.getBots();

      await _loadCustomBots();
      if (userId != null && userId.isNotEmpty) {
        await _loadRemoteCustomBots(userId);
      }

      if (botList.isNotEmpty) {
        final remoteBots = botList.map((b) => Bot.fromJson(b)).toList();
        _bots = [...remoteBots, ..._customBots];
      } else {
        _bots = [..._customBots];
        if (context.mounted) {
          SnackbarHelper.show(context, "No bots found");
        }
      }
    } catch (e) {
      debugPrint("Error fetching bots: $e");
      await _loadCustomBots();
      _bots = [..._customBots];
      if (context.mounted) {
        SnackbarHelper.show(context, "Error: Unable to fetch bots");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCustomBot({
    required String name,
    required String personality,
    required String description,
    required String avatarEmoji,
    String? userId,
  }) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) return;

    final bot = Bot(
      botname: cleanedName,
      personality: personality.trim().isEmpty ? 'Custom personality' : personality,
      description: description.trim().isEmpty
          ? 'User-created companion'
          : description,
      isCustom: true,
      avatarEmoji: avatarEmoji.trim().isEmpty ? '🤖' : avatarEmoji.trim(),
    );

    _customBots.removeWhere(
      (existing) => existing.botname.toLowerCase() == bot.botname.toLowerCase(),
    );
    _customBots.add(bot);
    await _persistCustomBots();
    if (userId != null && userId.isNotEmpty) {
      await FeatureService.saveCustomBot(
        userId: userId,
        botName: bot.botname,
        personality: bot.personality,
        description: bot.description,
        avatarEmoji: bot.avatarEmoji ?? '🤖',
      );
    }
    _rebuildBotList();
    notifyListeners();
  }

  Future<void> _loadCustomBots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_customBotsStorageKey) ?? [];
    _customBots
      ..clear()
      ..addAll(
        raw
            .map(
              (entry) {
                try {
                  return Bot.fromJson(
                    Map<String, dynamic>.from(
                      jsonDecode(entry) as Map<String, dynamic>,
                    ),
                  );
                } catch (_) {
                  return null;
                }
              },
            )
            .whereType<Bot>()
            .where((bot) => bot.isCustom),
      );
  }

  Future<void> _persistCustomBots() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _customBots.map((bot) => jsonEncode(bot.toJson())).toList();
    await prefs.setStringList(_customBotsStorageKey, encoded);
  }

  void _rebuildBotList() {
    final nonCustom = _bots.where((bot) => !bot.isCustom).toList();
    _bots = [...nonCustom, ..._customBots];
  }

  Future<void> _loadRemoteCustomBots(String userId) async {
    try {
      final response = await FeatureService.getCustomBots(userId);
      final raw = response['bots'];
      if (raw is! List) return;

      for (final item in raw) {
        final row = Map<String, dynamic>.from(item as Map);
        final bot = Bot(
          botname: (row['bot_name'] ?? 'Custom').toString(),
          personality: (row['personality'] ?? 'Custom personality').toString(),
          description: (row['description'] ?? 'User-created companion').toString(),
          isCustom: true,
          avatarEmoji: row['avatar_emoji']?.toString(),
        );

        _customBots.removeWhere(
          (existing) =>
              existing.botname.toLowerCase() == bot.botname.toLowerCase(),
        );
        _customBots.add(bot);
      }
      await _persistCustomBots();
    } catch (_) {
      // Keep local fallback if backend feature tables are unavailable.
    }
  }
}
