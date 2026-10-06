import 'package:chtohochu/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvConfig', () {
    test('без dart-define dev-сборка идёт на локальный стек', () {
      final env = EnvConfig.fromEnvironment();

      expect(env.apiBaseUrl, 'https://api.chtohochu.test');
      expect(env.reverbAppKey, 'local-app-key');
      expect(env.environment, 'dev');
    });
  });
}
