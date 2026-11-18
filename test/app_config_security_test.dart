import 'package:fixwise/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig environment & transport security validation', () {
    test('allows local HTTP emulator URL in development debug builds', () {
      expect(
        AppConfig.validateApiBaseUrl(
          'http://10.0.2.2:8000',
          env: AppEnvironment.development,
          releaseMode: false,
        ),
        isNull,
      );
      expect(
        AppConfig.validateApiBaseUrl(
          'http://localhost:8000',
          env: AppEnvironment.development,
          releaseMode: false,
        ),
        isNull,
      );
    });

    test('blocks localhost and cleartext HTTP in production or release builds', () {
      expect(
        AppConfig.validateApiBaseUrl(
          'http://localhost:8000',
          env: AppEnvironment.production,
          releaseMode: true,
        ),
        isNotNull,
      );
      expect(
        AppConfig.validateApiBaseUrl(
          'https://localhost:8443',
          env: AppEnvironment.production,
          releaseMode: true,
        ),
        contains('Localhost'),
      );
      expect(
        AppConfig.validateApiBaseUrl(
          'https://10.0.2.2:8443',
          env: AppEnvironment.production,
          releaseMode: true,
        ),
        contains('Localhost'),
      );
      expect(
        AppConfig.validateApiBaseUrl(
          'http://api.fixwise.example.com',
          env: AppEnvironment.production,
          releaseMode: true,
        ),
        contains('HTTPS'),
      );
    });

    test('accepts verified HTTPS production backend URL', () {
      expect(
        AppConfig.validateApiBaseUrl(
          'https://api.fixwise.example.com',
          env: AppEnvironment.production,
          releaseMode: true,
        ),
        isNull,
      );
    });
  });
}
