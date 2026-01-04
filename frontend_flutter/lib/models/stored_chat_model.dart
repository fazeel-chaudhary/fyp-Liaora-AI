import 'package:frontend_flutter/models/message_model.dart';

class StoredChat {
  final String userId;
  final String botName;
  final List<Message> chat;

  StoredChat({required this.userId, required this.botName, required this.chat});

  factory StoredChat.fromJson(Map<String, dynamic> json) {
    return StoredChat(
      userId: json["user_id"],
      botName: json["bot_name"],
      chat: (json["chat"] as List).map((e) => Message.fromJson(e)).toList(),
    );
  }
}
