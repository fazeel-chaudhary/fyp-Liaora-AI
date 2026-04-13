import 'package:flutter/material.dart';
import 'package:frontend_flutter/models/message_model.dart';
import 'package:frontend_flutter/services/chat_services.dart';
import 'package:frontend_flutter/utils/error_handler/snackbar.dart';

String _chatApiErrorMessage(Map<String, dynamic> res) {
  final detail = res['detail'];
  if (detail is String && detail.isNotEmpty) return detail;
  if (detail is List) {
    return detail
        .map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString())
        .join('; ');
  }
  final err = res['error'];
  if (err is String && err.isNotEmpty) return err;
  return 'Request failed';
}

class ChatProvider with ChangeNotifier {
  List<Message> _messages = [];
  bool _isLoading = false;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;

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
        if (context.mounted) {
          SnackbarHelper.show(context, _chatApiErrorMessage(res));
        }
        return;
      }
      _messages = raw
          .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      SnackbarHelper.show(context, "Failed to load messages: $e");
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
    final message = Message(
      sender: "user",
      content: content,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    notifyListeners();

    try {
      final res = await ChatService.sendMessage(userId, botName, content, token);
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
      notifyListeners();
    } catch (e) {
      SnackbarHelper.show(context, "Failed to send message: $e");
    }
  }

  Future<void> deleteAllMessages(BuildContext context, String userId) async {
    try {
      await ChatService.deleteAllMessages(userId);
      _messages.clear();
      notifyListeners();
    } catch (e) {
      SnackbarHelper.show(context, "Failed to delete all messages: $e");
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
      notifyListeners();
    } catch (e) {
      SnackbarHelper.show(context, "Failed to delete bot messages: $e");
    }
  }
}
