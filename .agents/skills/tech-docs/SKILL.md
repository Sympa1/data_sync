---
name: tech-docs
description: Erstellt und pflegt die technische Entwickler-, API- und Architektur-Dokumentation in Markdown inklusive nativer UML- und Three-Way-Merge-Diagramme (Mermaid.js) und führt Docs/JOURNAL.md fort.
---

# SKILL: Technische Architektur-Dokumentation & Mermaid-UML (`tech-docs`)

> **Rolle & Einsatzzweck:**
> Dieser Skill standardisiert die Erstellung und Pflege der technischen Entwickler-Dokumentation für `data_sync` unter `Docs/` sowie des chronologischen Projekt-Journals (`Docs/JOURNAL.md`) mit reichhaltigen, direkt in Markdown gerenderten Architektur- und UML-Diagrammen.

---

## 1. Ausgabeformat, Struktur & Datenschutz

- **Format:** Reines GitHub-Flavored Markdown (GFM) auf **Deutsch** (Code-Bezeichner, Klassennamen und Methoden bleiben auf **Englisch**).
- **Ablageort:** `Docs/` (z. B. `Docs/backend_system_design.md`, `Docs/datenbank_design.md`, `Docs/api_usage.md`) sowie `Docs/JOURNAL.md`.
- **Pflicht-Inhalte:**
  1. **Three-Way-Merge & Client-Server-Architektur:** Visualisierung des Zusammenspiels von Dateisystem, lokaler SQLite (`LastSyncState`) und Server-MariaDB (`SyncFiles`).
  2. **API-Schnittstellen:** Spezifikation von `/api/sync/manifest`, `/api/sync/upload`, `/api/sync/download` und `/api/sync/delete`.
  3. **Puffer-Konzepte:** Einhaltung der Namenskonventionen (`sBuffy` für String-Puffer, `iBuffy` für Integer-/Zähler-Puffer).
  4. **Strikter Datenschutz (Public-Repo-Konformität):** Keine absoluten Entwickler-Systempfade (`/home/...` oder `C:\Users\...`). Ausschließlich Komponenten- und relative Pfade.

---

## 2. Verbindliche Architektur- & UML-Diagramme (Mermaid.js)

### A) Client-Server- & Schichtenarchitektur (`flowchart TD`)
```mermaid
flowchart TD
    subgraph Clients["Clients (CLI / Flutter GUI)"]
        Scanner["FileScanner (SHA-256)"]
        LocalDB[("SQLite: LastSyncState & Files")]
        SyncMgr["SyncStateManager / CommandHandler"]
    end

    subgraph Backend["data_sync.API (ASP.NET Core)"]
        API["SyncController (/api/sync)"]
        Storage["Server Storage (uploads/)"]
        ServerDB[("MariaDB: SyncFiles & SyncEvents")]
    end

    Scanner --> SyncMgr
    LocalDB <--> SyncMgr
    SyncMgr -->|"REST HTTPS"| API
    API --> Storage
    API --> ServerDB
```

### B) Sequenzdiagramm für den Synchronisations-Ablauf (`sequenceDiagram`)
```mermaid
sequenceDiagram
    autonumber
    actor User as Benutzer / Sync-Job
    participant Client as Client (CLI / Flutter)
    participant LocalDB as SQLite (cli_db.db)
    participant API as ASP.NET Core API
    participant ServerDB as MariaDB

    User->>Client: Starte Sync
    Client->>Client: Scanne lokales Verzeichnis (Hashes)
    Client->>LocalDB: Lese LastSyncState
    Client->>API: POST /api/sync/manifest (Lokale Dateiliste)
    activate API
    API->>ServerDB: Lese Server-Zustand (SyncFiles)
    API->>API: Three-Way-Merge Diff-Berechnung
    API-->>Client: SyncActions (Upload, Download, Delete, Conflict)
    deactivate API

    loop Für jede SyncAction
        alt UploadAction
            Client->>API: POST /api/sync/upload
        else DownloadAction
            Client->>API: GET /api/sync/download
        else DeleteAction
            Client->>API: DELETE /api/sync/delete
        end
    end

    Client->>LocalDB: Aktualisiere LastSyncState
    Client-->>User: Sync abgeschlossen
```

### C) Datenmodell / Entity-Relationship-Diagramm (`erDiagram`)
```mermaid
erDiagram
    SYNC_FILES ||--o{ SYNC_EVENTS : "protokolliert"
    SYNC_FILES {
        int id PK
        string file_path
        string file_hash
        datetime server_modified
        boolean is_deleted
    }
    SYNC_EVENTS {
        int id PK
        int file_id FK
        string event_type
        datetime event_timestamp
        string client_info
    }
```

---

## 3. Lückenlose Pflege des Projekt-Journals (`Docs/JOURNAL.md`)

Jeder abgeschlossene Entwicklungsschritt wird chronologisch **ganz oben** in `Docs/JOURNAL.md` nach folgendem Schema ergänzt:

```markdown
## [YYYY-MM-DD HH:MM] – [Kurztitel des Meilensteins / Features]
- **Durchgeführte Änderungen:** [Präzise Beschreibung der umgesetzten Komponenten]
- **Architekturentscheidungen (Warum):** [Fachliche und technische Begründung]
- **Verifikation:** `[Tests PASSED | Whitelist/Security PASSED | Docs UPDATED]`
- **Offene Punkte / Nächste Schritte:** [To-Dos für die Folgesitzung]
```
