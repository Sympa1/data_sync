# Sicherheits- & Supply-Chain-Auditbericht: data_sync

- **Datum & Uhrzeit:** 2026-10-18 13:30:00 UTC
- **Prüfer:** `security-specialist` (Skill: `security-audit` + `check_downloads.py`)
- **Gesamtbewertung:** `SECURE (PASSED)`
- **Scope:** `data_sync.API`, `data_sync.CLI`, `data_sync.FLUTTER`

---

## 1. Whitelist-Konformität & Supply-Chain

Der automatisierte Scan mittels `check_downloads.py` sowie die manuelle Überprüfung der Projektabhängigkeiten ergaben vollständige Konformität mit den Projektrichtlinien (0 Befunde / 0 Verstöße):

- **.NET NuGet (`data_sync.API/data_sync.API.csproj`):** `[PASSED - nur Whitelist]`
  - `DotNetEnv` (Version 3.1.1)
  - `Microsoft.Data.Sqlite` (Version 10.0.13)
  - `xunit` (Version 2.9.3)
  - Keine unerlaubten ORMs (Entity Framework Core) oder Drittanbieter-JSON-Bibliotheken im Einsatz; ausschließlich BCL (`System.Text.Json`, `System.Security.Cryptography`).
- **Python CLI (`data_sync.CLI`):** `[PASSED - nur requests & Stdlib]`
  - Einzige externe Abhängigkeit: `requests`
  - Alle weiteren Module entstammen ausnahmslos der Python-Standardbibliothek (`sqlite3`, `hashlib`, `pathlib`, `json`, `os`, `sys`, `argparse`, `getpass`, `typing`).
- **Flutter pub.dev (`data_sync.FLUTTER/pubspec.yaml`):** `[PASSED - nur Whitelist]`
  - Verifizierte Pakete: `cupertino_icons`, `sqflite`, `sqflite_common_ffi`, `path_provider`, `path`, `file_picker`, `http`, `crypto`, `google_fonts`, `permission_handler` sowie Dev-Dependencies (`flutter_lints`, `flutter_launcher_icons`, `flutter_test`).
- **Neue Bibliotheken hinzugefügt:** `[NEIN]` (0 unautorisierte Pakete erkannt).

---

## 2. Injection-, Path-Traversal- & Authentifizierungs-Prüfung

### 2.1 Path Traversal Schutz (API Upload / Download / Delete)
- **Status:** `[PASSED]`
- **Prüfgegenstand:** `SyncController` (`GetSecureUserFilePath`)
- **Mechanismus:**
  - Trennung und Isolation nach Benutzer-ID (`uploads/{userId}/`).
  - Normalisierung von Dateipfaden (Konvertierung von Backslashes zu Forward-Slashes, Entfernen führender Slashes).
  - Auflösung des absoluten Zielpfads über `Path.GetFullPath` und Validierung gegen die Verzeichnisgrenze (`StartsWith(sBuffyBoundary, StringComparison.Ordinal)`).
  - Traversal-Versuche mit `../` oder `..\` lösen eine `UnauthorizedAccessException` aus und verwehren den Zugriff zuverlässig.

### 2.2 SQL-Injection-Sicherheit (SQLite & MariaDB)
- **Status:** `[PASSED]`
- **Prüfgegenstand:** `SqliteService`, `AuthService`, `GetFilesToSyncService`, `SyncStateService`, `UpdateMetadataService`, `DbErrorLogService` sowie `SqliteHandler` (CLI)
- **Mechanismus:**
  - Ausnahmslose Verwendung parametrisierter Queries (`@userId`, `@filePath`, `@hashValue`, `@tokenHash` etc. im Backend; `?` mit Parameter-Tupeln in Python).
  - Strikter Verzicht auf String-Konkatenation oder String-Interpolation bei SQL-Statements.

### 2.3 Secrets, API-Keys & Passwort-Sicherheit
- **Status:** `[PASSED]`
- **Prüfgegenstand:** Konfigurationsdateien (`appsettings.json`, `config.json`), Quellcode
- **Mechanismus:**
  - Keine Produktiv-Secrets, API-Keys oder Zugangsdaten im Versionskontrollbereich hinterlegt.
  - Sichere Authentifizierung in `AuthService`:
    - Passwörter werden mit PBKDF2 (`Rfc2898DeriveBytes`, SHA-256, 100.000 Iterationen, 16-Byte kryptografisches Salt) gehasht.
    - Passwortverifikation erfolgt via zeitkonstantem Byte-Vergleich (`CryptographicOperations.FixedTimeEquals`), um Timing-Angriffe zu verhindern.
    - Bearer-Tokens werden clientseitig übergeben, in der Datenbank jedoch ausschließlich als kryptografischer SHA-256-Hash gespeichert.

### 2.4 Python CLI Security & Authentifizierung
- **Status:** `[PASSED]`
- **Prüfgegenstand:** `ApiClient`, `AuthCommand`, `main.py`, `config.json`
- **Mechanismen & Befunde:**
  1. **Keine Klartext-Passwort-Speicherung:**
     - Bei der Anmeldung (`--login`) und Registrierung (`--register`) wird das Passwort interaktiv über `getpass.getpass()` abgefragt (kein Terminal-Echo, keine Historien-Speicherung).
     - Das Passwort wird ausschließlich im Speicher für den einmaligen HTTP-Aufruf gehalten und zu keinem Zeitpunkt in `config.json` oder der lokalen SQLite-Datenbank persistiert.
  2. **Bearer-Token-Handhabung:**
     - Nach erfolgreichem Login wird ausschließlich das vom Server signierte Bearer-Token zusammen mit `user_id` und `username` in `config.json` gespeichert.
     - Der `ApiClient` übergibt das Token standardkonform über den HTTP-Header `Authorization: Bearer <token>` und schützt vor Token-Leaks in URL-Query-Parametern.
     - Beim Abmelden (`--logout`) wird das Token auf dem Server invalidiert (`/api/auth/logout`) und lokal aus `config.json` restlos entfernt (`None`).
  3. **Netzwerk- & URL-Sicherheit:**
     - Saubere Pfadtrennung zwischen Auth-Routen (`/api/auth/*`) und Sync-Routen (`/api/sync/*`).
     - Verbindliche Timeouts bei allen HTTP-Aufrufen (15s für Auth, 30s für Metadaten, 60s für Manifest, 120s für Binärübertragungen), um DoS durch hängende Sockets zu verhindern.
     - Unterstützung von SSL-Verifikation mit konfigurierbarem Flag (`verify_ssl`).

---

## 3. Fazit & Freigabe

- [x] **FREIGEGEBEN (PASSED)**
- [ ] **ZURÜCKGEWIESEN (FAILED)**

Alle Sicherheitsanforderungen, Whitelist-Vorgaben und Datenschutz-Richtlinien (Public-Repo-Konformität ohne absolute Entwicklerpfade) wurden vollständig erfüllt. Es wurden keine Schwachstellen identifiziert.
