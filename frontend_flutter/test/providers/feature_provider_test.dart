import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/models/message_model.dart';
import 'package:frontend_flutter/providers/feature/feature_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeatureProvider', () {
    test('stores daily check-in and returns recommendation', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = FeatureProvider();
      await provider.initialize();

      await provider.completeDailyCheckIn('happy');

      expect(provider.isTodayCheckInDone(), isTrue);
      expect(provider.recommendationForMood(), contains('momentum'));
    });

    test('builds memory stats from provider and chat data', () {
      final provider = FeatureProvider();
      final messages = [
        Message(
          sender: 'user',
          content: 'hello',
          timestamp: DateTime.parse('2026-01-01T12:00:00.000Z'),
        ),
        Message(
          sender: 'bot',
          content: 'hi',
          timestamp: DateTime.parse('2026-01-01T12:00:10.000Z'),
        ),
      ];

      final stats = provider.buildMemoryStats(
        messages: messages,
        emotionStats: const {'happy': 1, 'neutral': 2},
      );

      expect(stats['messages'], 2);
      expect(stats['tracked_emotions'], 3);
      expect(stats['journal_entries'], 0);
      expect(stats['uploaded_files'], 0);
    });
  });
}
