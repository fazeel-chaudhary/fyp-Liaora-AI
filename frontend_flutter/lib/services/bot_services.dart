import 'package:frontend_flutter/services/api_services.dart';

class BotService {
  static Future<List<dynamic>> getBots() async {
    final response = await ApiService.getRequest("/bots");

    // ✅ Your API returns: { "bots": [ {...}, {...} ] }
    if (response is Map<String, dynamic> && response.containsKey("bots")) {
      return response["bots"];
    }

    // fallback
    return [];
  }
}
