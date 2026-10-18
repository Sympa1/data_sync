---
name: gitignore-analyzer
description: Analysiert die Verzeichnisstruktur des Projekts data_sync, erkennt ungetrackte Artefakte aus C#-, Python- und Flutter-Builds, Caches, Datenbank-Dumps und Secrets und hält die .gitignore sauber.
---

# SKILL: Gitignore Analyzer & Repository-Hygiene (`gitignore-analyzer`)

> **Rolle & Einsatzzweck:**
> Dieser Skill verhindert das versehentliche Einchecken von temporären Build-Artefakten aus .NET-, Python- und Flutter-Builds, lokalen Datenbank-Dumps, Sync-Testdateien und sensiblen Konfigurationen (`.env`) in das Git-Repository von `data_sync`.

---

## 1. Verzeichnis- und Status-Inspektion

1. **Nicht ignorierte & ungetrackte Dateien ermitteln:**
   ```bash
   git status --porcelain -uall
   ```
2. **Große Dateien & Binär-Artefakte aufspüren (> 5 MB):**
   Prüfe auf `.dll`, `.exe`, `.so`, `.apk`, `.tar.gz`, `.log` oder große Datenbankdateien (`*.db`), die nicht in Git gehören.

---

## 2. Pflicht-Kategorien für die `.gitignore` von data_sync

```gitignore
# 1. Credentials, Umgebungsvariablen & Zertifikate (KRITISCH!)
.env
.env.local
!.env.example
*.key
*.pfx

# 2. .NET / C# Build-Artefakte & IDE-Caches
bin/
obj/
*.DotSettings.user
.vs/
*.suo

# 3. Python Bytecode & virtuelle Umgebungen
__pycache__/
*.py[cod]
.venv/
venv/
.pytest_cache/
.ruff_cache/

# 4. Flutter / Dart Artefakte
data_sync.FLUTTER/.dart_tool/
data_sync.FLUTTER/build/
data_sync.FLUTTER/.flutter-plugins
data_sync.FLUTTER/.flutter-plugins-dependencies
data_sync.FLUTTER/ephemeral/

# 5. Lokale Sync-Daten, Test-Uploads & Logs
db_error.log
*.log
uploads/*
!uploads/.gitkeep
uploads/.trash/*
!uploads/.trash/.gitkeep
```

---

## 3. Checkliste für den Agenten
- `[ ]` Keine `.env`-Dateien mit echten Zugangsdaten getrackt.
- `[ ]` Keine `bin/`, `obj/`, `build/` oder `__pycache__` Verzeichnisse im Index.
- `[ ]` Test-Uploads aus `data_sync.API/uploads/` werden nicht unbeabsichtigt comittet.
- `[ ]` Keine absoluten Entwickler-Systempfade in Berichten unter `Docs/`.
