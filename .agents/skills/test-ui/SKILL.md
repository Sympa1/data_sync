---
name: test-ui
description: Führt automatisierte Flutter-GUI-, Widget- und State-Machine-Tests für data_sync.FLUTTER headless aus, beachtet die Fail-Fast-Regel und dokumentiert die Ergebnisse in Docs/ui_test_report.md.
---

# SKILL: Automatisierte UI- & Widget-Tests für Flutter (`test-ui`)

> **Rolle & Einsatzzweck:**
> Dieser Skill wird vom **`tester`-Agenten** genutzt, um die Flutter-Benutzeroberfläche (`data_sync.FLUTTER`) headless zu verifizieren (Widget-Tree, Benutzerinteraktionen, Zustandsübergänge des Synchronisationsvorgangs und Fehler-Dialoge).

---

## 1. Testsuite headless ausführen & Fail-Fast-Regel

1. **Flutter-Widget-Tests starten:**
   ```bash
   cd data_sync.FLUTTER && flutter test test/widget_test.dart
   ```
2. **Fail-Fast-Kopplung im 4-Agenten-Workflow:**
   Schlägt ein UI- oder Widget-Test fehl, bricht der `tester`-Agent das parallel laufende Security-Audit des `security-specialist`-Agenten **sofort ab (`manage_subagents(Action="kill")`)** und meldet den Fehler direkt an den `coder`-Agenten zurück!

---

## 2. Prüfschwerpunkte für data_sync.FLUTTER

- **Zustandsübergänge (Sync State Machine):**
  - Korrekte Darstellung von `IDLE` ➔ `SCANNING` ➔ `SYNCING` ➔ `COMPLETED` / `ERROR`.
- **Einstellungs-Persistenz:**
  - Speichern und Laden von Server-URL, Sync-Pfad und API-Token in SQLite (`sqflite`).
- **Fehler-Feedback:**
  - Korrekte Anzeige von Verbindungsfehlern (z. B. `HandshakeException`, `Connection refused`) und Konflikten.
- **Plattform-Unabhängigkeit:**
  - Responsives Verhalten auf Desktop (Linux/Windows) und Mobile (Android).

---

## 3. Verbindlicher UI-Testbericht (`Docs/ui_test_report.md`)

Erstelle oder aktualisiere nach jedem Durchlauf zwingend die Datei `Docs/ui_test_report.md` (ohne persönliche Entwickler-Systempfade).

```markdown
# UI- & Widget-Testbericht: data_sync.FLUTTER

- **Datum & Uhrzeit:** [YYYY-MM-DD HH:MM:SS]
- **Plattform:** [Linux / Headless Runner]
- **Geprüfte Screens/Widgets:** [SyncPage, SettingsPage, FileScannerWidget]
- **Gesamtergebnis:** `[PASSED / FAILED]`

## 1. Ausgeführte Widget-Tests
| Testfall | Status | Geprüftes Verhalten |
| :--- | :--- | :--- |
| `test_sync_page_initial_state` | `PASSED` | Initialer Zustand (Bereit / IDLE) |
| `test_server_url_validation` | `PASSED` | Validierung der Server-URL Eingabe |
| `test_sync_trigger_progress` | `PASSED` | Progress-Indikator während Synchronisation |

## 2. Fazit
`[Zusammenfassung des Widget-Testlaufs]`
```
