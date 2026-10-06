import 'package:chtohochu/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvConfig', () {
    test('без dart-define приложение идёт на production API', () {
      final env = EnvConfig.fromEnvironment();

      expect(env.apiBaseUrl, 'https://api.chtohochu.ru');
      expect(env.reverbAppKey, '34c7a5e068b7da49a052bdf1e260cebe');
      expect(env.environment, 'dev');
    });
  });
}
