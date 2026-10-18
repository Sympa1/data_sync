# Sicherheits- & Supply-Chain-Auditbericht: data_sync

- **Datum & Uhrzeit:** 2026-10-18 15:15:00 UTC
- **Prüfer:** `security-specialist` (Skill: `security-audit` + `check_downloads.py`)
- **Gesamtbewertung:** `SECURE (PASSED)`
- **Scope:** `data_sync.API` (inkl. Web-Dashboard & `AdminController`), `data_sync.CLI`, `data_sync.FLUTTER` (inkl. `AdminPage`, `SettingsPage`, `SyncApiService`, `SettingsService`, `SqliteHandler`)

---

## 1. Whitelist-Konformität & Supply-Chain

Der automatisierte Scan mittels `check_downloads.py` sowie die manuelle Überprüfung sämtlicher Projekt- und Paketkonfigurationen ergaben vollständige Konformität mit den Projektrichtlinien (0 Befunde / 0 Verstöße):

- **.NET NuGet (`data_sync.API/data_sync.API.csproj`):** `[PASSED - nur Whitelist]`
  - `DotNetEnv` (Version 3.1.1)
  - `Microsoft.Data.Sqlite` (Version 10.0.13)
  - `xunit` (Version 2.9.3)
  - Keine unerlaubten ORMs (Entity Framework Core) oder Drittanbieter-JSON-Bibliotheken im Einsatz; ausschließlich BCL (`System.Text.Json`, `System.Security.Cryptography`).
- **Web-Dashboard Frontend (`data_sync.API/wwwroot/`):** `[PASSED - keine externen CDNs/Libs]`
  - Autarkes, lokal ausgeliefertes Vanilla HTML5, CSS3 und ES6 JavaScript (`index.html`, `styles.css`, `app.js`).
  - Keine externen CDNs, Tracker oder Drittanbieter-Frontend-Bibliotheken (React/Vue/jQuery/Bootstrap).
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
  - Traversal-Versuche mit `../` oder `..\` lösen eine `ArgumentException` / `BadRequestObjectResult` aus und verwehren den Zugriff zuverlässig.

### 2.2 SQL-Injection-Sicherheit (SQLite & MariaDB)
- **Status:** `[PASSED]`
- **Prüfgegenstand:** `SqliteService`, `AuthService`, `AdminController`, `GetFilesToSyncService`, `SyncStateService`, `UpdateMetadataService`, `DbErrorLogService` (Backend), `SqliteHandler` (CLI) sowie `SqliteHandler` und `SettingsService` (Flutter).
- **Mechanismus:**
  - Ausnahmslose Verwendung parametrisierter Queries (`@userId`, `@filePath`, `@hashValue`, `@tokenHash` etc. im Backend; `?` mit Parameter-Tupeln in Python und Dart).
  - Strikter Verzicht auf String-Konkatenation oder String-Interpolation bei SQL-Statements in allen Controllern und Handlern.

### 2.3 Secrets, API-Keys & Passwort-Sicherheit
- **Status:** `[PASSED]`
- **Prüfgegenstand:** Konfigurationsdateien (`appsettings.json`, `config.json`), Quellcode
- **Mechanismus:**
  - Keine Produktiv-Secrets, API-Keys oder Zugangsdaten im Versionskontrollbereich hinterlegt.
  - Sichere Authentifizierung in `AuthService`:
    - Passwörter werden mit PBKDF2 (`Rfc2898DeriveBytes`, SHA-256, 100.000 Iterationen, 16-Byte kryptografisches Salt) gehasht.
    - Passwortverifikation erfolgt via zeitkonstantem Byte-Vergleich (`CryptographicOperations.FixedTimeEquals`), um Timing-Angriffe zu verhindern.
    - Bearer-Tokens werden clientseitig übergeben, in der Datenbank jedoch ausschließlich als kryptografischer SHA-256-Hash gespeichert.

### 2.4 Web-Dashboard & Admin-Sicherheit (`wwwroot` & `AdminController`)
- **Status:** `[PASSED]`
- **Prüfgegenstand:** `AdminController.cs`, `index.html`, `js/app.js`
- **Mechanismen & Befunde:**
  1. **Rollenbasierte Zugriffskontrolle (RBAC):**
     - Der gesamte `AdminController` ist auf Klassenebene durch `[Authorize(Roles = "Admin")]` geschützt. Unauthentifizierte oder reguläre Benutzer-Token werden mit HTTP 401 Unauthorized bzw. HTTP 403 Forbidden abgewiesen.
  2. **Selbstlöschungs-Schutz:**
     - `AdminController.DeleteUser` vergleicht die Claim-ID des angemeldeten Administrators mit der Ziel-Benutzer-ID (`iBuffyCurrentUid == userId`) und verhindert die Löschung des eigenen Administrator-Kontos.
  3. **XSS-Schutz (Cross-Site Scripting):**
     - Sämtliche dynamisch über die Admin-API empfangenen Daten (Benutzernamen, Dateipfade, Dateinamen, Fehlerbeschreibungen) werden vor dem Einfügen in das DOM stringent durch die Funktion `escapeHtml()` abgesichert.
  4. **Statischer Datei-Schutz:**
     - Das Web-Dashboard liegt isoliert in `wwwroot/` und wird über `app.UseStaticFiles()` bereitgestellt. Es sind keine sensiblen Backend-Dateien oder Konfigurationen über den statischen Fileserver erreichbar.

### 2.5 Python CLI Security & Authentifizierung
- **Status:** `[PASSED]`
- **Prüfgegenstand:** `ApiClient`, `AuthCommand`, `main.py`, `config.json`
- **Mechanismen & Befunde:**
  1. **Keine Klartext-Passwort-Speicherung:**
     - Bei der Anmeldung (`--login`) und Registrierung (`--register`) wird das Passwort interaktiv über `getpass.getpass()` abgefragt (kein Terminal-Echo, keine Historien-Speicherung).
     - Das Passwort wird ausschließlich im Speicher für den einmaligen HTTP-Aufruf gehalten und zu keinem Zeitpunkt in `config.json` persistiert.
  2. **Bearer-Token-Handhabung:**
     - Nach erfolgreichem Login wird ausschließlich das vom Server signierte Bearer-Token zusammen mit `user_id` und `username` in `config.json` gespeichert.
     - Der `ApiClient` übergibt das Token standardkonform über den HTTP-Header `Authorization: Bearer <token>`.
     - Beim Abmelden (`--logout`) wird das Token auf dem Server invalidiert (`/api/auth/logout`) und lokal aus `config.json` entfernt.
  3. **Netzwerk- & URL-Sicherheit:**
     - Saubere Pfadtrennung zwischen Auth-Routen (`/api/auth/*`), Admin-Routen (`/api/admin/*`) und Sync-Routen (`/api/sync/*`).
     - Verbindliche Timeouts bei allen HTTP-Aufrufen zur Vermeidung von Socket-Hanging.

---

## 3. Flutter-App Sicherheitsprüfung (`data_sync.FLUTTER`)

- **Status:** `[PASSED]`
- **Prüfgegenstand:** `SettingsService`, `SqliteHandler`, `SyncApiService`, `SyncService`, `SettingsPage`, `AdminPage`

### 3.1 Sichere Speicherung des Auth-Tokens in SQLite (`SettingsService` & `SqliteHandler`)
- **Ablageort:** Die SQLite-Datenbank (`data_sync_app.db`) wird via `getApplicationSupportDirectory()` im isolierten, privaten Anwendungsdatenbereich des Betriebssystems abgelegt (kein ungeschützter Speicherort wie `Documents` oder `Downloads`).
- **Parametrisierte Speicherung:**
  - Sämtliche Zugriffe in `SettingsService` (`getSetting`, `saveSetting`, `deleteSetting`) und `SqliteHandler` erfolgen über parametrisierte SQL-Befehle (`?` Platzhalter mit Parameterliste). SQL-Injections sind ausgeschlossen.
- **Sitzungs-Lifecycle:**
  - `saveAuthSession` persistiert ausschließlich das Auth-Token, Benutzernamen, User-ID und Admin-Status. Passwörter werden **niemals** lokal persistiert.
  - `clearAuthSession` löscht das Token und alle Identitätsdaten bei der Abmeldung rückstandsfrei aus der `settings`-Tabelle.

### 3.2 Übertragung des Bearer-Tokens in HTTP-Headern (`SyncApiService`)
- **Header-Struktur:**
  - In `SyncApiService._buildHeaders` wird das Token standardkonform als `Authorization: Bearer <token>` in den HTTP-Request-Headern übermittelt.
  - Bei Datei-Uploads (`uploadFile`) wird das Bearer-Token explizit in den Headern des `http.MultipartRequest` gesetzt (`HttpHeaders.authorizationHeader = 'Bearer $authToken'`).
- **Verhinderung von Token-Leaks:**
  - Tokens werden niemals über URL-Query-Parameter übertragen, wodurch Leaks in Server-Access-Logs oder Browser-Historien unterbunden sind.
- **TLS-Härtung:**
  - Lokale Zertifikatsausnahmen (`allowInsecureTlsForLocalhost`) sind strikt auf Loopback- (`localhost`, `127.0.0.1`, `::1`) und private RFC1918-Netzwerkadressen (`10.x`, `172.16-31.x`, `192.168.x`) beschränkt. Öffentliche HTTPS-Ziele erzwingen immer eine strikte Zertifikatsketten-Prüfung.

### 3.3 Absicherung der Admin-Aktionen & Fehlerbehandlung (`AdminPage`)
- **Zugriffskontrolle & Sichtbarkeit:**
  - Der Menüeintrag "Server-Administration" in `SettingsPage` wird ausschließlich eingeblendet, wenn `settings.isAdmin == true` gilt.
  - Die Server-Endpunkte (`/api/admin/*`) sind backendseitig mit `[Authorize(Roles = "Admin")]` geschützt; Manipulationsversuche an Client-Flags scheitern am Server mit HTTP 403 Forbidden.
- **Schutz vor Selbstlöschung:**
  - `_confirmDeleteUser` in `AdminPage` prüft `userId == widget.settings.userId` und verweigert das Löschen des eigenen Accounts clientseitig; der Server erzwingt dieselbe Barriere redundant.
- **Eingabe-Validierung & Bestätigungen:**
  - Benutzeranlage erzwingt Mindestlänge für Passwörter (`password.length >= 6`) und einen nicht-leeren Benutzernamen. Passwörter werden in Dialogen maskiert (`obscureText: true`).
  - Kritische Löschvorgänge erfordern eine explizite Bestätigung über einen modalen Sicherheitsdialog (`_confirmDeleteUser`).
- **Robuste Fehlerbehandlung:**
  - Alle Netzwerk- und Admin-Aktionen sind in `try/catch`-Blöcke gekapselt und geben verständliche Fehlermeldungen per SnackBar oder Error-View aus, ohne interne Stacktraces oder sensible Daten preiszugeben.

### 3.4 Einhaltung der Puffer- und Zählvariablen-Konventionen (`sBuffy` / `iBuffy`)
- Sämtliche temporären String-Zwischenspeicher und Schleifen-/Zählvariablen in den Flutter-Modulen und Tests halten die Namenskonvention strikt ein:
  - `sBuffyApiUrl`, `sBuffyAuthToken`, `sBuffyUsername`, `sBuffyPassword`, `sBuffyRelPath`
  - `iBuffyDownloadCount`, `iBuffyUploadCount`, `iBuffyDeleteCount`, `iBuffyRemoteDeleteCount`, `iBuffyUserId`, `iBuffy`
  - In `SettingsTest`: `sBuffyToken`, `sBuffyUser`, `iBuffyId`, `sBuffyEmptyToken`.

---

## 4. Fazit & Freigabe

- [x] **FREIGEGEBEN (PASSED)**
- [ ] **ZURÜCKGEWIESEN (FAILED)**

Alle Sicherheitsanforderungen, Whitelist-Vorgaben, die Pufferkonventionen (`sBuffy` / `iBuffy`) sowie die Datenschutz-Richtlinien (Public-Repo-Konformität ohne absolute Entwicklerpfade) wurden vollständig erfüllt. Die Flutter-App (`data_sync.FLUTTER`) sowie das Backend und die CLI sind sicher und für den produktiven Betrieb freigegeben.
