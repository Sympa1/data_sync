---
name: test-e2e
description: Führt einen vollständigen End-to-End-Systemtest über die gesamte Synchronisationspipeline (Client-Scan -> API Manifest -> Transfer -> SQLite Update) aus, prüft sBuffy/iBuffy-Konventionen und dokumentiert das Ergebnis in Docs/e2e_test_report.md.
---

# SKILL: End-to-End (E2E) System- & Sync-Pipeline-Test (`test-e2e`)

> **Rolle & Einsatzzweck:**
> Dieser Skill wird vom **`tester`-Agenten** ausgeführt, um das Zusammenspiel der gesamten Synchronisations-Kette unter realitätsnahen Bedingungen Ende-zu-Ende zu verifizieren (Dateisystem ➔ Hashing ➔ Manifest-Abgleich ➔ Dateiübertragung ➔ SQLite/MariaDB-Zustandsaktualisierung).

---

## 1. Testvorbereitung & Pipeline-Durchlauf

1. **Test-Fixtures bereitstellen:** Erstelle ein isoliertes Testverzeichnis mit neuen, geänderten und zu löschenden Dateien (z. B. `test_data/unterverzeichnis/`).
2. **E2E-Testablauf:**
   - Schritt 1: Lokaler Scan erfasst alle Dateien und berechnet korrekte SHA-256-Hashes (`lowercase`).
   - Schritt 2: Client (`CLI` oder `FLUTTER`) sendet Manifest an `POST /api/sync/manifest`.
   - Schritt 3: API berechnet Three-Way-Merge gegen MariaDB und antwortet mit `SyncActions`.
   - Schritt 4: Client führt Aktionen aus (`Upload`, `Download`, `Delete`).
   - Schritt 5: Lokale SQLite (`cli_db.db` / `LastSyncState`) wird aktualisiert.
   - Schritt 6: Zweiter Scan bestätigt Zustand `IN_SYNC` (0 offene Aktionen).
3. **Fail-Fast im 4-Agenten-Workflow:**
   Schlägt ein E2E-Schritt fehl, bricht der `tester`-Agent das parallel laufende Security-Audit **sofort ab (`manage_subagents(Action="kill")`)**.

---

## 2. Verifikationspunkte entlang der E2E-Kette

- **SHA-256 Hash-Konsistenz:** Dateiinhalte auf Client und Server müssen bitgenau übereinstimmen.
- **Konfliktbehandlung:** Wenn Datei lokal und auf dem Server gleichzeitig modifiziert wurde, darf kein stiller Datenverlust auftreten (Konfliktmeldung oder `.conflict`-Kopie).
- **Lösch-Synchronisation (Bidirektional):** Gelöschte Dateien werden sauber über den Soft-Delete / `.trash`-Mechanismus behandelt.
- **Puffer- & Variablenkonventionen (`sBuffy` / `iBuffy`):** Pufferung während Datei-Streaming und Hashing.

---

## 3. Verbindlicher E2E-Testbericht (`Docs/e2e_test_report.md`)

```markdown
# E2E Synchronisations-Testbericht: data_sync

- **Datum & Uhrzeit:** [YYYY-MM-DD HH:MM:SS]
- **Plattform:** [Linux / Windows / Android]
- **Getesteter Client:** [data_sync.CLI / data_sync.FLUTTER]
- **Backend-Status:** `API online (HTTP 200)`
- **Gesamtergebnis:** `[PASSED / FAILED]`

## 1. Pipeline-Phasen & Latenzen
| Phase | Ausführende Komponente | Status | Dauer (ms) |
| :--- | :--- | :--- | :--- |
| 1. Lokaler Scan & SHA-256 | `FileScanner` | `OK` | `...` |
| 2. Manifest-Abgleich | `ManifestHandler` -> `/api/sync/manifest` | `OK` | `...` |
| 3. Dateiübertragung | `UploadCommand` / `DownloadCommand` | `OK` | `...` |
| 4. SQLite-Zustandsupdate | `SyncStateManager` -> `LastSyncState` | `OK` | `...` |
| 5. Re-Sync Validierung | `In-Sync Check (0 Aktionen)` | `OK` | `...` |

## 2. Fazit
`[Detaillierte Bestätigung des fehlerfreien E2E-Sync-Laufs]`
```
