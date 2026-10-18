---
name: unit-testing
description: Verbindlicher QA-Skill für den tester-Agenten (Core/Unit-Tests). Führt Unit-Tests für C# (.NET xUnit), Python (unittest) und Flutter (flutter test) aus, setzt das Fail-Fast-Gate durch und generiert Docs/unit_test_report.md.
---

# SKILL: Automatisierte Core- & Unit-Tests, Fail-Fast-Gate & Reporting (`unit-testing`)

> **Rolle & Einsatzzweck:**
> Dieser Skill wird vom **`tester`-Agenten** (sowie zur Pflicht-Selbstprüfung vom `coder`-Agenten nach jedem Schritt) ausgeführt, um Kernmodule, Services und Konfigurationen headless zu testen und das Ergebnis in `Docs/unit_test_report.md` zu dokumentieren.

---

## 1. Fail-Fast-Protokoll im 4-Agenten-Workflow (KRITISCH)

Sobald der `coder`-Agent seine Arbeit im Branch beendet hat, starten der **`tester`-Agent** und der **`security-specialist`-Agent** parallel. Dabei gilt folgende **verbindliche Fail-Fast-Regel**:

1. **Sofortiger Abbruch des Security-Audits bei Testfehlern:**
   Stellt der `tester`-Agent fest, dass:
   - ein Unit- oder Integrationstest in C#, Python oder Flutter fehlschlägt (`Exit-Code != 0`),
   - ein Syntax-, Kompilierungs- oder Typfehler die Testausführung verhindert, oder
   - für neu implementierte Logik Pflicht-Unit-Tests fehlen,
   dann wird das parallel laufende **Security-Audit des `security-specialist`-Agenten sofort abgebrochen** (`manage_subagents(Action="kill", ConversationIds=["<security_specialist_id>"])`).
2. **Direkte Rückgabe an den `coder`:**
   Der Fehlerbericht geht ohne Umwege **direkt zurück an den `coder`-Agenten**.
3. **Absolutes Verbot der Test-Manipulation:**
   Bestehende Tests dürfen niemals gelöscht, übersprungen oder aufgeweicht werden.

---

## 2. Standard-Befehle zur Testausführung

```bash
# A) C# Backend Unit-Tests (xUnit):
dotnet test data_sync.API/data_sync.API.csproj --verbosity normal

# B) Python CLI Unit-Tests (Standard-Unittest):
python3 -m unittest discover -s data_sync.CLI/src -p "*test*.py" -v

# C) Flutter / Dart Unit- & Service-Tests:
cd data_sync.FLUTTER && flutter test test/file_scanner_service_test.dart
```

---

## 3. Qualitätskriterien für Unit-Tests

1. **AAA-Struktur (Arrange – Act – Assert):** Klare Dreiteilung jedes Tests mit sprechendem englischen Methodennamen und deutschem Docstring/XML-Doc (fachliches *Warum*).
2. **Konventionsprüfung (`sBuffy` / `iBuffy`):** Verifiziere, dass temporäre String-Puffer (`sBuffy`) und Schleifenzähler (`iBuffy`) sowohl im Produktions- als auch im Testcode eingehalten werden.
3. **Isolation & Mocking:** Externe Seiteneffekte (Netzwerk-Requests, Server-Verbindung) über Mocking isolieren.

---

## 4. Verbindlicher Testbericht (`Docs/unit_test_report.md`)

Erstelle oder aktualisiere nach jedem erfolgreichen Durchlauf zwingend die Datei `Docs/unit_test_report.md` (ohne persönliche Entwickler-Systempfade).

```markdown
# Unit- & Core-Testbericht: data_sync

- **Datum & Uhrzeit:** [YYYY-MM-DD HH:MM:SS]
- **Plattform:** [Linux / Windows / macOS]
- **Geprüfte Komponenten:** [Backend API / CLI / Flutter Client]
- **Gesamtergebnis:** `[PASSED / FAILED]`

## 1. Ausgeführte Test-Suiten
| Komponente / Suite | Status | Ausgeführte Tests | Fehlschläge |
| :--- | :--- | :--- | :--- |
| `data_sync.API (xUnit)` | `OK` | `...` | `0` |
| `data_sync.CLI (unittest)` | `OK` | `...` | `0` |
| `data_sync.FLUTTER (flutter test)` | `OK` | `...` | `0` |

## 2. Fazit & Fail-Fast-Status
- **Fail-Fast-Status:** `Alle Tests bestanden – Security-Audit läuft regulär weiter`
- **Fazit:** `[Zusammenfassung]`
```
