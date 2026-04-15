import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/providers/chat/chat_provider.dart';

void main() {
  group('ChatProvider', () {
    test('updates personality only for supported modes', () {
      final provider = ChatProvider();

      provider.setActivePersonality('Coach');
      expect(provider.activePersonality, 'Coach');

      provider.setActivePersonality('InvalidMode');
      expect(provider.activePersonality, 'Coach');
    });

    test('creates and switches branches safely', () {
      final provider = ChatProvider();

      expect(provider.activeBranch, 'main');
      provider.createBranch('Experiment');

      expect(provider.branches, contains('experiment'));
      expect(provider.activeBranch, 'experiment');

      provider.switchBranch('main');
      expect(provider.activeBranch, 'main');
    });
  });
}
