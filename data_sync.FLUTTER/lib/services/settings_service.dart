import 'package:data_sync_flutter/models/settings.dart';
import 'package:data_sync_flutter/handlers/sqlite_handler.dart';

/// SettingsService ist der Dienst für alle Einstellungs-Operationen
/// 
/// Verantwortlichkeiten:
/// - Einstellungen aus der Datenbank lesen
/// - Einstellungen in die Datenbank schreiben
/// - Einzelne Settings oder alle Settings verwalten
/// - Fehlerbehandlung
/// 
/// Singleton-Pattern: Es gibt nur eine Instanz dieser Klasse für die ganze App.
/// Das verhindert mehrfache Datenbankzugriffe und sichert die Konsistenz.
class SettingsService {
  // Statische Variable - speichert die einzige Instanz
  // _ am Anfang bedeutet: Diese Variable ist privat (nur für diese Klasse)
  static final SettingsService _instance = SettingsService._internal();

  // Referenz zum SqliteHandler (um Datenbank-Operationen durchzuführen)
  // final bedeutet: Kann nach der Initialisierung nicht mehr geändert werden
  final SqliteHandler _db = SqliteHandler();

  /// Privater Konstruktor
  /// Der Unterstrich (_internal) ist eine Konvention für "interne Konstruktoren"
  /// Ein privater Konstruktor verhindert, dass man von außen "new SettingsService()" aufrufen kann
  SettingsService._internal();

  /// Factory-Konstruktor - gibt immer die gleiche Instanz zurück
  /// 
  /// Ein factory-Konstruktor ist speziell für das Singleton-Pattern.
  /// Jedes Mal, wenn man SettingsService() aufruft, bekommt man die GLEICHE Instanz.
  /// 
  /// Nutzung:
  /// ```dart
  /// final service1 = SettingsService();  // Erste Instanz
  /// final service2 = SettingsService();  // Gleiche Instanz wie service1!
  /// print(identical(service1, service2)); // true - es ist das gleiche Objekt
  /// ```
  factory SettingsService() {
    return _instance;
  }

  /// Liest eine einzelne Einstellung aus der Datenbank
  /// 
  /// Parameter:
  /// - [key]: Der Name der Einstellung (z.B. 'syncPath', 'apiUrl')
  /// 
  /// Rückgabe:
  /// - String: Der Wert der Einstellung
  /// - null: Wenn die Einstellung nicht existiert
  /// 
  /// Beispiel:
  /// ```dart
  /// final syncPath = await SettingsService().getSetting('syncPath');
  /// if (syncPath != null) {
  ///   print('Sync-Verzeichnis: $syncPath');
  /// }
  /// ```
  /// 
  /// Fehlerbehandlung:
  /// - Wenn die DB einen Fehler wirft, wird eine Exception geworfen
  /// - Der Aufrufer muss diese Exception mit try/catch abfangen
  Future<String?> getSetting(String key) async {
    try {
      // Führe eine SQL-Abfrage aus:
      // "SELECT value FROM settings WHERE key = ?"
      // Das ? ist ein Platzhalter für den key-Parameter (verhindert SQL-Injection)
      final results = await _db.executeQuery(
        'SELECT value FROM settings WHERE key = ?',
        params: [key],
      );

      // Wenn Ergebnisse existieren: gib den value zurück
      // results ist eine Liste von Maps. Jede Map = eine Zeile aus der DB.
      // Falls mehrere Zeilen zurückommen würden, nehmen wir nur die erste ([0])
      if (results.isNotEmpty) {
        // Konvertiere die erste Zeile (Map) in einen String
        return results[0]['value'] as String;
      }

      // Keine Ergebnisse gefunden = Einstellung existiert nicht
      return null;
    } catch (e) {
      // Wenn ein Fehler passiert, gebe ihn an den Aufrufer weiter
      // Der Aufrufer kann dann entscheiden, wie damit umgegangen wird
      throw Exception('Fehler beim Lesen der Einstellung "$key": $e');
    }
  }

  /// Speichert eine einzelne Einstellung in der Datenbank
  /// 
  /// Parameter:
  /// - [key]: Der Name der Einstellung (z.B. 'syncPath', 'apiUrl')
  /// - [value]: Der neue Wert als String
  /// 
  /// Rückgabe:
  /// - Gibt nichts zurück (void), aber wirft Exception bei Fehler
  /// 
  /// Beispiel:
  /// ```dart
  /// await SettingsService().saveSetting('syncPath', '/home/user/Sync');
  /// print('Einstellung gespeichert!');
  /// ```
  /// 
  /// Logik:
  /// - Wenn die Einstellung schon existiert: UPDATE (überschreibe)
  /// - Wenn sie nicht existiert: INSERT (erstelle neu)
  Future<void> saveSetting(String key, String value) async {
    try {
      // Erst prüfen: Existiert diese Einstellung schon?
      final existing = await getSetting(key);

      if (existing != null) {
        // UPDATE: Die Einstellung existiert, überschreibe sie
        // "UPDATE settings SET value = ? WHERE key = ?"
        // Das erste ? ist der neue Wert, das zweite ? ist der key
        await _db.executeQuery(
          'UPDATE settings SET value = ? WHERE key = ?',
          params: [value, key],
          returnResult: false, // UPDATE braucht keine Ergebnisse zurück
        );
      } else {
        // INSERT: Die Einstellung existiert noch nicht, erstelle sie neu
        // "INSERT INTO settings (key, value) VALUES (?, ?)"
        // Das erste ? ist der key, das zweite ? ist der Wert
        await _db.executeQuery(
          'INSERT INTO settings (key, value) VALUES (?, ?)',
          params: [key, value],
          returnResult: false, // INSERT braucht keine Ergebnisse zurück
        );
      }
    } catch (e) {
      // Fehlerbehandlung: Gib den Fehler an den Aufrufer weiter
      throw Exception('Fehler beim Speichern der Einstellung "$key": $e');
    }
  }

  /// Liest ALLE Einstellungen auf einmal
  /// 
  /// Rückgabe:
  /// - Settings: Ein Objekt mit allen bekannten Einstellungen
  /// - Werte, die nicht in der DB existieren, sind null
  /// 
  /// Beispiel:
  /// ```dart
  /// final settings = await SettingsService().getAllSettings();
  /// print('Sync-Pfad: ${settings.syncPath}');
  /// print('API-URL: ${settings.apiUrl}');
  /// ```
  /// 
  /// Praktischer Nutzen:
  /// - Wird beim App-Start aufgerufen, um alle Einstellungen zu laden
  /// - Reduziert mehrfache DB-Abfragen
  Future<Settings> getAllSettings() async {
    try {
      // Lese syncPath aus der DB
      final syncPath = await getSetting('syncPath');

      // Lese apiUrl aus der DB
      final apiUrl = await getSetting('apiUrl');

      // Lese die lokale TLS-Ausnahme aus der DB
      final allowInsecureTlsForLocalhost =
          await getSetting('allowInsecureTlsForLocalhost');

      // Lese Authentifizierungs-Daten aus der DB
      final authToken = await getSetting('authToken');
      final username = await getSetting('username');
      final userIdStr = await getSetting('userId');
      final isAdminStr = await getSetting('isAdmin');

      int? userId;
      if (userIdStr != null) {
        userId = int.tryParse(userIdStr);
      }

      // Erstelle ein Settings-Objekt mit den gelesenen Werten
      return Settings(
        syncPath: syncPath,
        apiUrl: apiUrl,
        allowInsecureTlsForLocalhost:
            allowInsecureTlsForLocalhost?.toLowerCase() == 'true',
        authToken: authToken,
        username: username,
        userId: userId,
        isAdmin: isAdminStr?.toLowerCase() == 'true',
      );
    } catch (e) {
      // Bei Fehler: Werfe Exception mit aussagekräftiger Meldung
      throw Exception('Fehler beim Laden aller Einstellungen: $e');
    }
  }

  /// Speichert die Authentifizierungs-Sitzung in der lokalen Datenbank
  Future<void> saveAuthSession({
    required String token,
    required String username,
    required int userId,
    required bool isAdmin,
  }) async {
    await saveSetting('authToken', token);
    await saveSetting('username', username);
    await saveSetting('userId', userId.toString());
    await saveSetting('isAdmin', isAdmin.toString());
  }

  /// Löscht die Authentifizierungs-Sitzung aus der lokalen Datenbank
  Future<void> clearAuthSession() async {
    await deleteSetting('authToken');
    await deleteSetting('username');
    await deleteSetting('userId');
    await deleteSetting('isAdmin');
  }

  /// Löscht eine Einstellung aus der Datenbank
  /// 
  /// Parameter:
  /// - [key]: Der Name der Einstellung, die gelöscht werden soll
  /// 
  /// Beispiel:
  /// ```dart
  /// await SettingsService().deleteSetting('syncPath');
  /// // syncPath ist jetzt weg
  /// ```
  Future<void> deleteSetting(String key) async {
    try {
      // SQL: "DELETE FROM settings WHERE key = ?"
      // Das ? ist der key-Parameter
      await _db.executeQuery(
        'DELETE FROM settings WHERE key = ?',
        params: [key],
        returnResult: false, // DELETE braucht keine Ergebnisse zurück
      );
    } catch (e) {
      // Fehlerbehandlung
      throw Exception('Fehler beim Löschen der Einstellung "$key": $e');
    }
  }
}
