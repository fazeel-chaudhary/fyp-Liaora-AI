import 'package:flutter/material.dart';
import 'package:frontend_flutter/models/message_model.dart';
import 'package:frontend_flutter/services/chat_services.dart';
import 'package:frontend_flutter/utils/error_handler/snackbar.dart';

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
      _messages = (res["chat"] as List)
          .map((e) => Message.fromJson(e))
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
  ) async {
    final message = Message(
      sender: "user",
      content: content,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    notifyListeners();

    try {
      final res = await ChatService.sendMessage(userId, botName, content);
      final botResponse = Message(
        sender: "bot",
        content: res["bot_response"],
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
