import 'package:flutter/material.dart';
import 'package:frontend_flutter/models/bot_model.dart';
import 'package:frontend_flutter/services/bot_services.dart';
import 'package:frontend_flutter/utils/error_handler/snackbar.dart';

class BotProvider with ChangeNotifier {
  List<Bot> _bots = [];
  bool _isLoading = false;

  List<Bot> get bots => _bots;
  bool get isLoading => _isLoading;

  Future<void> fetchBots(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      final botList = await BotService.getBots();

      if (botList.isNotEmpty) {
        _bots = botList.map((b) => Bot.fromJson(b)).toList();
      } else {
        if (context.mounted) {
          SnackbarHelper.show(context, "No bots found");
        }
      }
    } catch (e) {
      debugPrint("Error fetching bots: $e");
      if (context.mounted) {
        SnackbarHelper.show(context, "Error: Unable to fetch bots");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
