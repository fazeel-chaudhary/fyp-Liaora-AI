import 'package:flutter/material.dart';
import 'package:frontend_flutter/models/message_model.dart';
import 'package:frontend_flutter/services/chat_services.dart';
import 'package:frontend_flutter/utils/error_handler/snackbar.dart';

String _chatApiErrorMessage(Map<String, dynamic> res) {
  final detail = res['detail'];
  final error = res['error'];

  bool hasQuotaSignal(String text) {
    final lower = text.toLowerCase();
    return lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('429') ||
        lower.contains('resource_exhausted');
  }

  if (detail is String && hasQuotaSignal(detail)) {
    return 'AI is temporarily busy. Please wait a moment and send again.';
  }
  if (error is String && hasQuotaSignal(error)) {
    return 'AI is temporarily busy. Please wait a moment and send again.';
  }

  if (detail is String && detail.isNotEmpty) return detail;
  if (detail is List) {
    return detail
        .map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString())
        .join('; ');
  }
  if (error is String && error.isNotEmpty) return error;
  return 'Request failed';
}

class ChatProvider with ChangeNotifier {
  List<Message> _messages = [];
  bool _isLoading = false;
  String _detectedEmotion = 'neutral';
  DateTime? _lastSyncedAt;
  bool _adaptiveSwitching = true;
  String _activePersonality = 'Balanced';
  final Map<String, int> _emotionStats = {};
  final Map<String, List<Message>> _branches = {'main': []};
  String _activeBranch = 'main';

  static const List<String> personalityModes = [
    'Balanced',
    'Coach',
    'Empath',
    'Playful',
    'Analytical',
    'Calm',
    'Direct',
    'Creative',
  ];

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String get detectedEmotion => _detectedEmotion;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get adaptiveSwitching => _adaptiveSwitching;
  String get activePersonality => _activePersonality;
  Map<String, int> get emotionStats => Map.unmodifiable(_emotionStats);
  List<String> get branches => _branches.keys.toList();
  String get activeBranch => _activeBranch;

  void setAdaptiveSwitching(bool value) {
    _adaptiveSwitching = value;
    notifyListeners();
  }

  void setActivePersonality(String value) {
    if (!personalityModes.contains(value)) return;
    _activePersonality = value;
    notifyListeners();
  }

  void createBranch(String branchName) {
    final trimmed = branchName.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.toLowerCase();
    if (_branches.containsKey(normalized)) return;
    _branches[normalized] = List<Message>.from(_messages);
    _activeBranch = normalized;
    _messages = _branches[_activeBranch] ?? [];
    notifyListeners();
  }

  void switchBranch(String branchName) {
    if (!_branches.containsKey(branchName)) return;
    _activeBranch = branchName;
    _messages = _branches[branchName] ?? [];
    notifyListeners();
  }

  void markSyncedNow() {
    _lastSyncedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> loadMessages(
    BuildContext context,
    String userId,
    String botName,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ChatService.getMessages(userId, botName);
      final raw = res['chat'];
      if (raw is! List) {
        _messages = [];
        _branches['main'] = [];
        _activeBranch = 'main';
        if (context.mounted) {
          SnackbarHelper.show(context, _chatApiErrorMessage(res));
        }
        return;
      }
      final loadedMessages = raw
          .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
          .map(
            (msg) => msg.sender == userId || msg.sender.startsWith("user::")
                ? Message(
                    sender: "user",
                    content: msg.content,
                    timestamp: msg.timestamp,
                  )
                : msg,
          )
          .where((msg) => !_isLegacyVerboseBotMessage(msg))
          .toList();
      final trimmedMessages = loadedMessages.length > 40
          ? loadedMessages.sublist(loadedMessages.length - 40)
          : loadedMessages;
      _branches['main'] = trimmedMessages;
      _activeBranch = 'main';
      _messages = _branches[_activeBranch] ?? [];
      _lastSyncedAt = DateTime.now();
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.show(context, "Failed to load messages: $e");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(
    BuildContext context,
    String userId,
    String botName,
    String content,
    String token,
  ) async {
    // Force main branch for production chat flow to avoid local synthetic replies.
    if (_activeBranch != 'main') {
      _activeBranch = 'main';
      _messages = _branches['main'] ?? _messages;
    }

    _detectedEmotion = _detectEmotion(content);
    _emotionStats[_detectedEmotion] = (_emotionStats[_detectedEmotion] ?? 0) + 1;
    if (_adaptiveSwitching) {
      _activePersonality = _personalityFromEmotion(_detectedEmotion);
    }

    final message = Message(
      sender: "user",
      content: content,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    _branches[_activeBranch] = _messages;
    notifyListeners();

    try {
      final res = await ChatService.sendMessage(
        userId,
        botName,
        content,
        token,
      );
      final reply = res['bot_response'];
      if (reply is! String) {
        if (context.mounted) {
          SnackbarHelper.show(context, _chatApiErrorMessage(res));
        }
        return;
      }
      final botResponse = Message(
        sender: "bot",
        content: reply,
        timestamp: DateTime.now(),
      );
      _messages.add(botResponse);
      _branches['main'] = _messages;
      _lastSyncedAt = DateTime.now();
      notifyListeners();
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.show(context, "Failed to send message: $e");
      }
    }
  }

  Future<void> deleteAllMessages(BuildContext context, String userId) async {
    try {
      await ChatService.deleteAllMessages(userId);
      _messages.clear();
      _branches
        ..clear()
        ..['main'] = [];
      _activeBranch = 'main';
      notifyListeners();
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.show(context, "Failed to delete all messages: $e");
      }
    }
  }

  Future<void> deleteBotMessages(
    BuildContext context,
    String userId,
    String botName,
  ) async {
    try {
      await ChatService.deleteBotMessages(userId, botName);
      _messages.clear();
      _branches
        ..clear()
        ..['main'] = [];
      _activeBranch = 'main';
      notifyListeners();
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.show(context, "Failed to delete bot messages: $e");
      }
    }
  }

  String _detectEmotion(String text) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, ['sad', 'lonely', 'down', 'upset'])) return 'sad';
    if (_containsAny(lower, ['happy', 'excited', 'great', 'awesome'])) {
      return 'happy';
    }
    if (_containsAny(lower, ['stress', 'anxious', 'overwhelmed', 'panic'])) {
      return 'stressed';
    }
    if (_containsAny(lower, ['angry', 'mad', 'frustrated'])) return 'angry';
    return 'neutral';
  }

  bool _containsAny(String source, List<String> words) {
    return words.any(source.contains);
  }

  String _personalityFromEmotion(String emotion) {
    switch (emotion) {
      case 'sad':
        return 'Empath';
      case 'stressed':
        return 'Calm';
      case 'happy':
        return 'Playful';
      case 'angry':
        return 'Coach';
      default:
        return 'Balanced';
    }
  }

  bool _isLegacyVerboseBotMessage(Message msg) {
    if (msg.sender == "user") return false;
    final text = msg.content.trim();
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();

    const legacyPhrases = [
      "i understand you're feeling",
      "i apologize if my previous responses",
      "could you tell me more about what you mean",
      "i'm still learning",
      "it seems like there might be a misunderstanding",
    ];

    if (legacyPhrases.any(lower.contains)) return true;
    return text.length > 280;
  }

}
