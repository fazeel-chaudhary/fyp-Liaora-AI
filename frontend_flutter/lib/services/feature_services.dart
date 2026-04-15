import 'package:frontend_flutter/services/api_services.dart';

class FeatureService {
  static Future<Map<String, dynamic>> saveCustomBot({
    required String userId,
    required String botName,
    required String personality,
    required String description,
    required String avatarEmoji,
  }) async {
    final response = await ApiService.postRequest(
      "/custom-bots/$userId",
      body: {
        "user_id": userId,
        "bot_name": botName,
        "personality": personality,
        "description": description,
        "avatar_emoji": avatarEmoji,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> getCustomBots(String userId) async {
    final response = await ApiService.getRequest("/custom-bots/$userId");
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> saveJournalEntry({
    required String userId,
    required String content,
  }) async {
    final response = await ApiService.postRequest(
      "/journal/$userId",
      body: {
        "user_id": userId,
        "content": content,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> getJournalEntries(String userId) async {
    final response = await ApiService.getRequest("/journal/$userId");
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> saveDailyCheckIn({
    required String userId,
    required String mood,
    required String checkInDate,
  }) async {
    final response = await ApiService.postRequest(
      "/checkins/$userId",
      body: {
        "user_id": userId,
        "mood": mood,
        "check_in_date": checkInDate,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> getLatestDailyCheckIn(String userId) async {
    final response = await ApiService.getRequest("/checkins/$userId");
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> saveMemoryFile({
    required String userId,
    required String fileName,
  }) async {
    final response = await ApiService.postRequest(
      "/memory-files/$userId",
      body: {
        "user_id": userId,
        "file_name": fileName,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> getMemoryFiles(String userId) async {
    final response = await ApiService.getRequest("/memory-files/$userId");
    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> getMemoryDashboard(String userId) async {
    final response = await ApiService.getRequest("/memory-dashboard/$userId");
    return Map<String, dynamic>.from(response as Map);
  }
}
