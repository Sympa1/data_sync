# Projekt-Journal: data_sync

Chronologisches Entwicklungs- und Entscheidungsprotokoll gemäß Core Agent Harness.

---

## [2026-10-18 15:50] – Web Dashboard & Administrations-REST-API (Branch: feature/web-dashboard)

- **Durchgeführte Änderungen:**
  - **Branch-Isolation:** Eigenen Arbeitsbranch `feature/web-dashboard` (ausgehend von `rework-cli`) erstellt.
  - **Admin-REST-API (`data_sync.API/Controllers/AdminController.cs` & `DTOs/AdminDtos.cs`):**
    - Abgesichert mit `[Authorize(Roles = "Admin")]` über den bestehenden Token-Authentication-Handler.
    - Endpunkte implementiert:
      - `GET /api/admin/stats`: Liefert Systemkennzahlen (Benutzeranzahl, aktive Dateien, Speicherplatz, SQLite-DB-Dateigröße, Serverzeit).
      - `GET /api/admin/users`: Benutzerliste mit individuellem Speicherverbrauch, Datei-Anzahl, Rollen und Anmeldezeitpunkten.
      - `POST /api/admin/users`: Benutzeranlage mit Administrator-Berechtigungsoption.
      - `DELETE /api/admin/users/{userId}`: Benutzerlöschung mit Kaskadenlöschung in SQLite und Bereinigung des lokalen Dateisystem-Vaults (`uploads/{userId}/`); Schutz gegen versehentliche Selbstlöschung des Administrators.
      - `GET /api/admin/files`: Durchsuchbare Dateiübersicht mit Benutzerfilter.
      - `GET /api/admin/logs`: Protokolleinsicht für System- und Fehlerereignisse (`FehlerProtokoll`).
  - **Autarkes Web-Dashboard Frontend (`data_sync.API/wwwroot/`):**
    - `index.html`: Responsives Dashboard mit Sidebar-Navigation (Übersicht, Benutzerverwaltung, Datei-Explorer, System-Logs) und Anmeldedialog.
    - `css/styles.css`: Elegantes Dark-Mode Design (Anthrazit/Blau), CSS-Grid & Flexbox, Toast-Benachrichtigungen, Status-Badges; 100 % offline-fähig ohne externe CDNs oder Fonts.
    - `js/app.js`: Vanilla ES6 JavaScript mit Session-Management via `localStorage`, XSS-Schutz durch `escapeHtml()`, asynchronen REST-Aufrufen, Benutzeranlage und -löschung.
    - `Program.cs`: `app.UseDefaultFiles()` und `app.UseStaticFiles()` aktiviert.
  - **Erweiterung der Test-Suite (`data_sync.API/Tests/ApiTestSuite.cs`):**
    - Neue Test-Suite für `AdminController`: Statistiken abrufen, Benutzerübersicht mit Speicherverbrauch und Verweigerung von Selbstlöschung.
    - **19/19 Tests bestanden** (15 Backend API + 4 Python CLI, Exit-Code: 0).
  - **Security-Audit (`Docs/security_audit_report.md`):**
    - Whitelist eingehalten (0 neue Bibliotheken), XSS-Schutz verifiziert, parametrisierte SQL-Queries, Status `PASSED`.
- **Architekturentscheidungen (Warum):**
  - **Zero-Dependency Frontend:** Das Dashboard wird direkt als statische Ressource durch die Kestrel-Instanz ausgeliefert. Es werden weder Node.js/NPM noch externe CDN-Bibliotheken benötigt, was maximale Privatsphäre und Zuverlässigkeit im Heimnetz garantiert.
  - **Rollenbasierte Autorisierung:** Normale Benutzer haben über das Dashboard keinen Zugriff auf administrative Daten oder andere Benutzerkonten (`HTTP 403`).
- **Offene Punkte / Nächste Schritte:**
  - Anpassung der Flutter-App (`data_sync.FLUTTER`) an die neue REST-API mit Multi-User-Login, Datei-Isolierung und Administrations-Erweiterung.

---

## [2026-10-18 15:30] – Python CLI Rework: REST-API Multi-User Authentifizierung & Token-Support (Branch: rework-cli)

- **Durchgeführte Änderungen:**
  - **Branch-Isolation:** Eigenen Arbeitsbranch `rework-cli` (ausgehend von `rework-webapi`) erstellt.
  - **API-Client Erweiterung (`data_sync.CLI/src/core/api_client.py`):**
    - Bearer-Token-Unterstützung im `Authorization`-Header für alle REST-Endpunkte.
    - Automatisches URL-Routing für Auth (`/api/auth/*`) und Sync (`/api/sync/*`).
    - Methoden implementiert: `register(username, password)`, `login(username, password)`, `get_me()`, `logout()`.
    - Feste Timeouts und SSL-Zertifikatsvalidierung für alle Requests.
  - **Authentifizierungs-Befehle (`data_sync.CLI/src/core/commands/auth_command.py`):**
    - Neuer `AuthCommand` mit sicherer Passworteingabe via Standardmodul `getpass` (kein Klartext im Speicher oder Terminal).
    - Speicherung des Bearer-Tokens, Benutzer-ID und Benutzernamens in `config.json`.
    - `whoami`-Prüfung gegen `/api/auth/me`.
    - Saubere Abmeldung und Token-Widerruf via `/api/auth/logout`.
  - **Sync-Commands auf Token-Support umgestellt:**
    - `ManifestCommand`, `UploadCommand`, `DownloadCommand`, `DeleteCommand` lesen das hinterlegte Bearer-Token aus und übermitteln es automatisch an die Web-API.
    - Benutzerfreundliche Warnungen bei fehlendem Token mit Aufforderung zur Anmeldung (`--login`).
  - **CLI-Haupteinstiegspunkt (`data_sync.CLI/src/main.py`):**
    - Neue Flags: `--login` (`-l`), `--register` (`-r`), `--whoami` (`-w`), `--logout`.
    - Optionale Argumente `--username` und `--password` für automatisierte Skripte/Pipelines.
  - **Unit-Tests (`data_sync.CLI/src/test_cli.py`):**
    - 4 automatisierte Unit-Tests für `ApiClient` (URL-Routing, Header, Login-Mock) und `ConfigHandler`.
    - Alle 4 Tests bestanden (`4/4 PASS, Exit-Code: 0`).
  - **Verifikation & Berichte:**
    - Gesamte Test-Suite: 16 Tests (12 Backend + 4 Python CLI) vollständig `PASSED` ([`Docs/unit_test_report.md`](file:///home/sympa/Dev/data_sync/Docs/unit_test_report.md)).
    - Sicherheits-Audit: 0 Befunde, Whitelist eingehalten ([`Docs/security_audit_report.md`](file:///home/sympa/Dev/data_sync/Docs/security_audit_report.md)).
- **Architekturentscheidungen (Warum):**
  - **Nahtlose Rückwärtskompatibilität:** Bestehende `config.json`-Dateien mit `api_base_url` bleiben uneingeschränkt funktionsfähig; der Client leitet Endpunkte transparent an den neuen REST-Server weiter.
  - **Sichere Token-Ablage:** Nur das zeitlich begrenzte Sitzungs-Token wird persistiert, niemals das Klartext-Passwort des Benutzers.
- **Offene Punkte / Nächste Schritte:**
  - Anpassung der Flutter-App (`data_sync.FLUTTER`) an die neue REST-API mit Multi-User-Login und getrennten Verzeichnissen.
  - Erweiterung der App um Administrations-Funktionen (User-Management, Sync-Status) und Web-Dashboard.

---

## [2026-10-18 15:10] – Web-API Rework: Vollständige Umstellung auf SQLite & Multi-User-Architektur (Branch: rework-webapi)

- **Durchgeführte Änderungen:**
  - **Branch-Isolation:** Eigenen Arbeitsbranch `rework-webapi` erstellt – kein direkter Commit oder automatischer Merge auf `main`/`master`.
  - **Whitelist-Update (mit Nutzer-Genehmigung):** Aufnahme von `Microsoft.Data.Sqlite` (10.0.13) als offizieller ADO.NET-Provider für SQLite (kein ORM) in `AGENTS.md`, `GEMINI.md`, `check_downloads.py` und `data_sync.API.csproj`. Entfernung von `MySql.Data`.
  - **SQLite Service Layer:**
    - `SqliteService.cs` implementiert: ADO.NET mit `PRAGMA foreign_keys = ON;`, `PRAGMA journal_mode = WAL;`, `PRAGMA busy_timeout = 5000;`, Shared-Cache und automatische Verzeichniserstellung (`data/data_sync.db`).
    - `MariaDBService.cs` vollständig entfernt.
    - `DbStartupCheckService.cs` migriert: Automatische Erstellung der SQLite-Tabellen (`Users`, `UserTokens`, `SyncFiles`, `LastSyncState`, `SyncEvents`, `FehlerProtokoll`) und Indizes.
    - `compose.yaml` & `.env.container.example`: MariaDB-Container und -Netzwerke entfernt, SQLite-Volume (`./data:/app/data`) konfiguriert.
  - **Multi-User Authentifizierung & Mandantentrennung:**
    - `DTOs/AuthDtos.cs`: `RegisterRequestDto`, `LoginRequestDto`, `AuthResponseDto`, `UserProfileDto`.
    - `Services/IAuthService.cs` & `AuthService.cs`: Passwort-Hashing mit PBKDF2-SHA256 (100.000 Iterationen, 16-Byte Salt), zeitkonstanter Vergleich via `CryptographicOperations.FixedTimeEquals` und Bearer-Tokens mit SHA-256 Hash-Speicherung in SQLite. Keine externen JWT-Drittbibliotheken!
    - `Authentication/TokenAuthenticationHandler.cs`: ASP.NET Core Authentication-Handler für `Bearer <token>` Header.
    - `Controllers/AuthController.cs`: Endpunkte `/api/auth/register`, `/api/auth/login`, `/api/auth/me` und `/api/auth/logout`.
  - **Multi-User Synchronisations-Engine:**
    - `GetFilesToSyncService.cs`, `UpdateMetadataService.cs`, `SyncStateService.cs`: Vollständig auf Multi-User mit `iBuffyUserId` und SQLite UPSERT (`ON CONFLICT(...) DO UPDATE SET ...`) umgestellt.
    - `Controllers/SyncController.cs`: Mit `[Authorize]` geschützt. Isoliertes Speicherverzeichnis je Benutzer unter `uploads/{userId}/`.
    - **Path-Traversal-Schutz:** Strikte Boundary-Prüfung (`GetSecureUserFilePath`) blockiert Directory-Traversal-Angriffe (`../`, `..\`, absolute Pfade) nachweislich.
  - **Verifikation & Test-Suite:**
    - `Tests/ApiTestSuite.cs`: 12 automatisierte Unit- und Integrationstests (AuthService, Multi-User Isolation, Three-Way-Merge, Path-Traversal).
    - Alle 12 Tests bestanden (`12 Bestanden, 0 Fehlgeschlagen, Exit-Code: 0`).
    - `dotnet format data_sync.API/data_sync.API.csproj --verify-no-changes`: Exit-Code 0.
    - Security-Audit mit `check_downloads.py`: 17 Pakete verifiziert, 0 Verstöße, Status `PASSED`.
    - Berichte in `Docs/unit_test_report.md` und `Docs/security_audit_report.md` abgelegt.
- **Architekturentscheidungen (Warum):**
  - **Schlanke SQLite-Architektur:** Ermöglicht den autarken Betrieb daheim ohne MariaDB-Serverinstanz bei voller Datenintegrität über SQLite WAL-Modus.
  - **Zero-Third-Party Auth:** Passworthash und Tokens basieren zu 100 % auf der .NET Base Class Library (`System.Security.Cryptography`), wodurch Sicherheitsrisiken und Supply-Chain-Abhängigkeiten minimiert werden.
  - **Strikte Mandantentrennung:** Weder in der Datenbank (`WHERE user_id = @userId`) noch im Dateisystem (`uploads/{userId}/`) können Benutzerdaten vermischt oder gegenseitig eingesehen werden.
- **Offene Punkte / Nächste Schritte:**
  - Anpassung des Python CLI-Clients (`data_sync.CLI`) an die neue REST-API (Login, Token-Handling, User-spezifische Synchronisation).
  - Anpassung der Flutter-App (`data_sync.FLUTTER`) an die neue REST-API.
  - Web-Dashboard / Administrations-Erweiterung.

---

## [2026-10-18 11:45] – Synchronisation & Anpassung von GEMINI.md, AGENTS.md und Spezial-Skills aus ai_dev_sample

- **Durchgeführte Änderungen:**
  - `GEMINI.md` und `AGENTS.md` aus dem Referenz-Repository (`ai_dev_sample`) importiert und vollständig auf das Projekt `data_sync` angepasst.
  - Vollständige Suite von 10 Spezial-Skills in `.agents/skills/` integriert und maßgeschneidert konfiguriert:
    1. `code-quality-linting`: Multi-Language Linter & Formatter (.NET C#, Python ruff/flake8, Dart analyze).
    2. `code-refactoring`: Sauberes Refactoring für Three-Way-Merge, Pfad-Normalisierung und GPL-3.0.
    3. `database-migration`: Versionierte SQL-Migrationen für MariaDB (`MySql.Data` ADO.NET, **kein ORM**) und SQLite (`cli_db.db`, `sqflite`).
    4. `gitignore-analyzer`: Multi-Framework Repository-Hygiene (.NET, Python, Flutter, Caddy/Secrets, Uploads).
    5. `security-audit`: Umfassendes Sicherheits- und Whitelist-Audit inklusive automatisiertem Prüfskript `check_downloads.py` (scannt `.csproj`, Python und `pubspec.yaml`).
    6. `tech-docs`: Technische Architektur- und UML-Dokumentation mit Mermaid.js (Three-Way-Merge, Client-Server-Sequenzen, ER-Diagramme).
    7. `test-e2e`: Ende-zu-Ende Verifikation der gesamten Synchronisations-Pipeline.
    8. `test-ui`: Headless Flutter Widget- und State-Machine-Tests (`data_sync.FLUTTER`).
    9. `unit-testing`: Headless Unit-Tests für C# (xUnit), Python (unittest) und Flutter (flutter_test) mit verbindlicher Fail-Fast-Abbruchregel.
    10. `user-docs`: Endbenutzer-Handbücher und Troubleshooting-Entscheidungsbäume (Offline, Zero-CDN).
  - Veraltetes Verzeichnis `.agent` durch Symlink auf `.agents` konsolidiert.
  - Strikte Whitelist aller bestehenden Abhängigkeiten (KEINE NEUEN LIBRARIES) und Puffer-Konventionen (`sBuffy` / `iBuffy`) in allen Regeln verankert.
- **Architekturentscheidungen (Warum):**
  - **Deduplizierung & Standardisierung:** Durch die Vorlagen aus `ai_dev_sample` besitzt `data_sync` denselben einheitlichen Multi-Agenten-Harness und dieselbe Skill-Architektur wie das Referenzprojekt.
  - **Multi-Language Whitelist Enforcement:** Der Security-Scanner `check_downloads.py` prüft nun automatisiert alle 3 Teilprojekte (.NET C#, Python, Flutter/Dart) gegen die fest definierte Bibliotheken-Whitelist.
- **Verifikation:**
  - `python3 .agents/skills/security-audit/scripts/check_downloads.py`: 17 Pakete erkannt und geprüft, 0 Verstöße, `PASSED`.
  - Skill-Verzeichnisstruktur und Symlinks verifiziert.
- **Offene Punkte / Nächste Schritte:**
  - Phase 3: Fertigstellung und End-to-End-Testing der Flutter GUI-App (`data_sync.FLUTTER`).
  - Bereitstellung automatisierter Tests für die REST-API.
