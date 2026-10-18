---
name: database-migration
description: Verwaltet versionierte Schema-Migrationen für MariaDB (Backend) und SQLite (Clients) ohne ORM, erzwingt Backups und garantiert Abwärtskompatibilität.
---

# SKILL: Datenbank-Migration & Sichere Schema-Verwaltung (`database-migration`)

> **Rolle & Einsatzzweck:**
> Dieser Skill leitet den **`researcher`-** und **`coder`-Agenten** bei Änderungen an Datenmodellen und Schemata von `data_sync` an:
> - **Server:** MariaDB (Tabellen `SyncFiles`, `SyncEvents`) über direktes ADO.NET (`MySql.Data` – **kein ORM**).
> - **Clients:** SQLite (Tabellen `Files`, `LastSyncState`) in Python (`cli_db.db`) und Flutter (`sqflite`).

---

## 1. Harte Sicherheits-Leitplanken

1. **Kein ORM-Einsatz:** Es werden weder EF Core noch SQLAlchemy verwendet. Alle Migrationen erfolgen über explizite, versionierte `.sql`-Skripte in `Docs/`.
2. **Pflicht-Backup vor Schema-Eingriffen:**
   - Vor jeder Schemaänderung ist zwingend eine Sicherungskopie der Bestandsdatenbank anzulegen (z. B. `cp data_sync.CLI/cli_db.db data_sync.CLI/cli_db.db.backup`).
3. **Parametrisierte Abfragen (SQLi-Schutz):** Auch in Datenmigrationsskripten dürfen Werte niemals ungeprüft in SQL-Strings konkateniert werden.
4. **Abwärtskompatibilität:** Neue Tabellenspalten müssen `NULL`-fähig sein oder einen sinnvollen `DEFAULT`-Wert besitzen, damit bestehende Clients weiter synchronisieren können.

---

## 2. Standard-Vorgehen für data_sync Migrationen

```bash
# A) Backup der lokalen SQLite-Datenbank erstellen:
cp data_sync.CLI/cli_db.db data_sync.CLI/cli_db.db.backup_$(date +%Y%m%d_%H%M%S)

# B) Neues SQL-Migrationsskript erstellen:
# Namenskonvention: Docs/migration_<YYYYMMDD>_<kurzbeschreibung>.sql
# z. B.: Docs/migration_20260210_fix_duplicates.sql

# C) Migration in C# (MariaDBService) bzw. Python (SqliteHandler) einpflegen:
# - Prüfen auf Schema-Version
# - Ausführung in Transaktion (BEGIN TRANSACTION / COMMIT)
```

---

## 3. Checkliste für Schema-Änderungen

- `[ ]` Neues `.sql`-Skript unter `Docs/` angelegt.
- `[ ]` SQLite-Schemata in `data_sync.CLI` und `data_sync.FLUTTER` identisch synchronisiert.
- `[ ]` MariaDB-Schemata im Backend (`data_sync.API`) angepasst und in `Docs/datenbank_design.md` dokumentiert.
- `[ ]` `sBuffy` / `iBuffy` Variablenkonvention bei Migrations- und Abfrageschleifen eingehalten.
