# GEMINI.md - Projektrichtlinien für Antigravity / Gemini CLI

> **Projektname:** `data_sync`  
> **Projektziel / Kernfunktion:** Plattformübergreifendes Dateisynchronisations-System (Cross-Platform Data Sync, u. a. für Obsidian-Notizen) zwischen Windows, Linux (Manjaro) und Android über einen zentralen Server mittels Three-Way-Merge-Manifestabgleich und SHA-256-Hashing.  
> **Tech-Stack:** C# ASP.NET Core 10.0 Web API (Backend mit MariaDB via ADO.NET), Python 3 (CLI mit SQLite `cli_db.db`), Flutter / Dart (GUI mit SQLite `sqflite`), Docker & Caddy.  
> **Freigegebene externe Bibliotheken (Whitelist):** `Microsoft.Data.Sqlite`, `MySql.Data`, `DotNetEnv`, `xunit` (Backend); `requests` (CLI); `cupertino_icons`, `sqflite`, `sqflite_common_ffi`, `path_provider`, `path`, `file_picker`, `http`, `crypto`, `google_fonts`, `permission_handler`, `flutter_lints`, `flutter_launcher_icons`, `flutter_test` (Flutter).  
> **Test-Befehle:**  
> - Backend: `dotnet test data_sync.API/data_sync.API.csproj`  
> - CLI: `python3 -m unittest discover -s data_sync.CLI/src -v`  
> - Flutter: `cd data_sync.FLUTTER && flutter test`  
> **Lint- & Format-Befehle:**  
> - Backend: `dotnet format data_sync.API/data_sync.API.csproj --verify-no-changes`  
> - CLI: `ruff check data_sync.CLI/src/ || flake8 data_sync.CLI/src/`  
> - Flutter: `dart analyze data_sync.FLUTTER/lib/ data_sync.FLUTTER/test/`  
> **Zweck:** Hierarchisch geladene Workspace-Regeln für Antigravity- und Gemini-Agenten.

---

## 1. Projektziel, Bibliotheken-Whitelist & Journal-Pflicht
- **Projektziel:** Zuverlässige, plattformübergreifende Synchronisation lokaler Verzeichnisse (z. B. Obsidian-Vaults) zwischen Linux, Windows und Android über einen zentralen Server mit Three-Way-Merge und SHA-256-Hashing.
- **Bibliotheken-Whitelist (KEINE NEUEN LIBRARIES):** Standardmodule der jeweiligen Plattformen sind frei nutzbar (.NET BCL, Python Stdlib, Flutter SDK). Externe Pakete sind **strikt auf die oben genannte Whitelist beschränkt**. Kein Entity Framework Core, keine sonstigen ORMs, keine ungefragten Paketinstallationen.
- **Projekt-Journal (`Docs/JOURNAL.md`):** Zu Beginn jeder Sitzung zuerst `Docs/JOURNAL.md` einlesen. Jeden abgeschlossenen Schritt und jede Architekturentscheidung chronologisch oben in `Docs/JOURNAL.md` eintragen.

---

## 2. Core Agent Harness, Workspace & Public-Repo-Datenschutz
- **Plan-Act-Verify & Test-Zwang:** Erst analysieren, dann isoliert im Branch umsetzen, anschließend zwingend durch automatisierte Tests und Security-Audit verifizieren.
- **Workspace-Richtlinie:** Innerhalb des Projektverzeichnisses (`data_sync`) dürfen Befehle und Tests frei ausgeführt werden; außerhalb des Workspaces besteht strikte Rückfragepflicht. Berichte und Artefakte liegen unter `Docs/`.
- **Datenschutz in Berichten (`Docs/*_report.md`):** Keine persönlichen Systempfade (`/home/<username>/...` oder `C:\Users\<username>\...`) in Berichten oder Dokumentationen verwenden; nutze Komponentenbezeichner (z. B. `SyncController`, `MariaDBService`, `FileScanner`, `SqliteHandler`) oder relative Pfade.
- **Absolute No-Gos:** Keine Tests löschen/deaktivieren, keine Hardcoded Secrets/Passwörter im Code, kein ORM/EF Core, keine ungefragten Downloads oder Installationen, **kein automatischer Merge auf `main`** (Merge erfolgt immer manuell durch den Nutzer!).

---

## 3. Programmier-, Namens-, Git- & Clean-Code-Standards (`sBuffy` / `iBuffy`)
- **Englische Bezeichner:** Klassen (`PascalCase`), Methoden/Funktionen (`camelCase` in C#/Dart, `snake_case` in Python) und Variablen auf **Englisch** benennen.
- **Buffer- & Zählvariablen (`sBuffy` / `iBuffy`):** Temporäre String-Puffer verbindlich mit `sBuffy` (oder `sBuffer...`) und Integer-Puffer/Schleifenzähler verbindlich mit `iBuffy` (oder `iBuffer...`) benennen.
- **Deutsche Kommentare & Docstrings:** Kurz, präzise und auf **Deutsch** – Fokus auf das fachliche *Warum*, nicht auf triviale Syntax.
- **Git-Branches & Deutsche Commit-Nachrichten:**
  - Auf extra Branches wird **ausschließlich im neuen Arbeits-Branch committed** (niemals automatisch auf `main` mergen!).
  - Alle Commit-Nachrichten werden **auf Deutsch** mit Präfix verfasst: `feat: <Neues Feature>`, `bugfix: <Behobener Fehler>`, `refactor: <Umbau>`, `test: <Tests>`, `docs: <Doku>`, `chore: <Wartung>`.
- **Clean Code & OOP:** Single Responsibility Principle (SRP), Kapselung, keine Magic Numbers und direkte SQL-Abfragen mit parametrisierten Queries.

---

## 4. Verbindlicher 4-Agenten-Workflow
1. **`researcher` (Read-Only):** Analysiert Code, `Docs/JOURNAL.md` & Abhängigkeiten (Whitelist) und erstellt das Übergabe-Konzept (Handover-Spec) für den `coder`.
2. **`coder` (Eigener Branch `Workspace="branch"`):** Setzt das Konzept im isolierten Branch um und committet ausschließlich dort mit deutschen Commit-Nachrichten (`feat: ...`, `bugfix: ...`; kein Merge auf `main`!).
   - **Fachliche Rückfragen** ➔ Direkt an den **Nutzer (User)**.
   - **Technische Abweichung vom Konzept** ➔ Rückfrage nach einer Alternative an den **`researcher`** (`send_message`).
   - **Nach Fertigstellung** ➔ Paralleler Start von **`tester`** UND **`security-specialist`**.
3. **`tester` (Skill: `.agents/skills/unit-testing/SKILL.md`):** Führt Tests aus. **Fail-Fast-Regel:** Bei einem Testfehler wird der parallel laufende `security-specialist` **sofort abgebrochen (`kill`)** und der Fehler direkt an den `coder` zurückgespielt.
4. **`security-specialist` (Read-Only, Skill: `.agents/skills/security-audit/SKILL.md`):** Führt `check_downloads.py` und das Voll-Audit durch (Whitelist-Prüfung, Secrets, Path Traversal bei REST-Endpunkten, SQL-Injection in MariaDB/SQLite).
