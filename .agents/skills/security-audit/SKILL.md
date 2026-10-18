---
name: security-audit
description: Umfassendes Security-, Supply-Chain-, Secret- & Whitelist-Audit für data_sync. Prüft externe Bibliotheken (strikte Whitelist, keine neuen Pakete!), scannt auf Hardcoded Secrets, SQL-Injection, Path Traversal und API-Angriffsvektoren und generiert Docs/security_audit_report.md.
---

# SKILL: Comprehensive Security, Supply-Chain & Whitelist Audit (`security-audit`)

> **Rolle & Einsatzzweck im 4-Agenten-Workflow:**
> Dieser Skill ist das verbindliche Prüfprotokoll für den **`security-specialist`-Agenten** (Read-Only, `enable_write_tools=False`).
> Er wird parallel zum `tester`-Agenten gestartet, sobald der `coder`-Agent seine Implementierung im Branch abgeschlossen hat.
> **Fail-Fast-Regel:** Meldet der parallel laufende `tester`-Agent einen Testfehler, wird dieser Security-Audit-Lauf **sofort abgebrochen (`kill`)**.

---

## 0. Automatisierter Vorab-Scan (`check_downloads.py`)

Führe zu Beginn jedes Audits das Prüfskript aus:

```bash
python3 .agents/skills/security-audit/scripts/check_downloads.py
```

---

## 1. Strikte Whitelist-Prüfung (KEINE NEUEN LIBRARIES!)

Überprüfe sämtliche Abhängigkeitsdateien (`data_sync.API.csproj`, `data_sync.CLI/src/`, `pubspec.yaml`):
1. **.NET Backend (`data_sync.API`):**
   - Erlaubt: `MySql.Data`, `DotNetEnv`, `xunit`.
   - **Verboten:** Entity Framework Core oder sonstige ORMs, fremde JSON-Parser (nur `System.Text.Json`).
2. **Python CLI (`data_sync.CLI`):**
   - Erlaubt: `requests`.
   - Alle anderen Module müssen aus der Python Standard-Bibliothek stammen (`sqlite3`, `hashlib`, `pathlib`, `json`, `os`, `sys`, `argparse`).
3. **Flutter GUI (`data_sync.FLUTTER`):**
   - Erlaubt: `cupertino_icons`, `sqflite`, `sqflite_common_ffi`, `path_provider`, `path`, `file_picker`, `http`, `crypto`, `google_fonts`, `permission_handler`, `flutter_lints`, `flutter_launcher_icons`, `flutter_test`.
   - Jedes weitere Paket erfordert die vorherige explizite Genehmigung des Nutzers.

---

## 2. API- & Dateisystem-Sicherheit in data_sync

1. **Path Traversal Schutz (KRITISCH):**
   - Endpunkte `/api/sync/upload`, `/api/sync/download` und `/api/sync/delete` nehmen relative Pfade entgegen.
   - Es muss sichergestellt sein, dass Pfade wie `../../etc/passwd` oder manipulierte relative Pfade niemals das Zielverzeichnis (`uploads/`) verlassen (`Path.GetFullPath`, `Path.Combine` Absicherung).
2. **Hash-Integrität (SHA-256):**
   - Manipulationen an Datei-Hashes müssen erkannt werden. Hashes sind einheitlich in Kleinbuchstaben (`lowercase`) zu normalisieren.
3. **SQL-Injection (MariaDB & SQLite):**
   - Alle Datenbankabfragen in C# (`MySqlCommand`) und Python (`sqlite3.Cursor`) müssen ausnahmslos parametrisiert sein (`@param` bzw. `?`). Konkatenation ist strengstens untersagt.
4. **Secrets & Credentials:**
   - Keine fest hinterlegten Passwörter oder Verbindungszeichenketten in `appsettings.json`, Quellcode oder `config.json`. Passwörter nur via `.env` oder sichere Eingabe.

---

## 3. Verbindlicher Audit-Bericht (`Docs/security_audit_report.md`)

> **Datenschutz-Pflicht (Public-Repo-Konformität):**
> Verwende in `Docs/security_audit_report.md` **niemals absolute Entwickler-Systempfade** (`/home/...` oder `C:\Users\...`). Nutze ausschließlich relative Pfade oder Modulnamen (`SyncController`, `MariaDBService`, `SqliteHandler`, `ApiClient`, `FileScanner`).

```markdown
# Sicherheits- & Supply-Chain-Auditbericht: data_sync

- **Datum & Uhrzeit:** [YYYY-MM-DD HH:MM:SS]
- **Prüfer:** `security-specialist` (Skill: `security-audit` + `check_downloads.py`)
- **Gesamtbewertung:** `[SECURE (PASSED) | ACTION REQUIRED (FAILED)]`
- **Scope:** data_sync.API, data_sync.CLI, data_sync.FLUTTER

---

## 1. Whitelist-Konformität & Supply-Chain
- **.NET NuGet:** `[PASSED - nur Whitelist]`
- **Python CLI:** `[PASSED - nur requests & Stdlib]`
- **Flutter pub.dev:** `[PASSED - nur Whitelist]`
- **Neue Bibliotheken hinzugefügt:** `[NEIN]`

## 2. Injection- & Path-Traversal-Prüfung
- **Path Traversal Schutz (API Upload/Download):** `[PASSED]`
- **SQL-Injection (MariaDB & SQLite):** `[PASSED]`
- **Secrets & API-Keys:** `[PASSED]`

## 3. Fazit & Freigabe
- `[ ]` **FREIGEGEBEN (PASSED)**
- `[ ]` **ZURÜCKGEWIESEN (FAILED)**
```
