import 'package:frontend_flutter/services/api_services.dart';

class ChatService {
  /// Fetches all messages between the user and a bot
  static Future<Map<String, dynamic>> getMessages(
    String userId,
    String botName,
  ) async {
    return await ApiService.getRequest("/messages/$userId/$botName");
  }

  /// Sends a message from the user to the bot
  static Future<Map<String, dynamic>> sendMessage(
    String userId,
    String botName,
    String message,
  ) async {
    return await ApiService.postRequest(
      "/chat/$userId/$botName",
      body: {"user_id": userId, "sender": "user", "content": message},
    );
  }

  /// Deletes all messages from all bots for a user
  static Future<Map<String, dynamic>> deleteAllMessages(String userId) async {
    return await ApiService.deleteRequest("/messages/$userId/all");
  }

  /// Deletes messages with a specific bot
  static Future<Map<String, dynamic>> deleteBotMessages(
    String userId,
    String botName,
  ) async {
    return await ApiService.deleteRequest("/messages/$userId/$botName");
  }
}
