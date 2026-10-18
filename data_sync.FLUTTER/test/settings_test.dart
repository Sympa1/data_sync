import 'package:data_sync_flutter/models/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Settings Model Tests', () {
    test('Standard-Settings sind nicht authentifiziert', () {
      final settings = Settings();
      expect(settings.isAuthenticated, isFalse);
      expect(settings.authToken, isNull);
      expect(settings.username, isNull);
      expect(settings.userId, isNull);
      expect(settings.isAdmin, isFalse);
    });

    test('copyWith uebernimmt Auth-Parameter korrekt', () {
      final sBuffyToken = 'test-token-12345';
      final sBuffyUser = 'max_mustermann';
      final iBuffyId = 42;

      final initialSettings = Settings(
        syncPath: '/tmp/sync',
        apiUrl: 'https://example.test',
      );

      final updatedSettings = initialSettings.copyWith(
        authToken: sBuffyToken,
        username: sBuffyUser,
        userId: iBuffyId,
        isAdmin: true,
      );

      expect(updatedSettings.isAuthenticated, isTrue);
      expect(updatedSettings.authToken, equals(sBuffyToken));
      expect(updatedSettings.username, equals(sBuffyUser));
      expect(updatedSettings.userId, equals(iBuffyId));
      expect(updatedSettings.isAdmin, isTrue);
      expect(updatedSettings.syncPath, equals('/tmp/sync'));
      expect(updatedSettings.apiUrl, equals('https://example.test'));
    });

    test('isAuthenticated wird false bei leerem Token', () {
      final sBuffyEmptyToken = '   ';
      final settings = Settings(authToken: sBuffyEmptyToken);
      expect(settings.isAuthenticated, isFalse);
    });
  });
}
