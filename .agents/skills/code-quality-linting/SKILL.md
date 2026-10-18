---
name: code-quality-linting
description: Führt statische Code-Analyse, Formatierungs- und Typprüfungen für C# (.NET), Python und Dart (Flutter) nach den Konventionen der AGENTS.md durch.
---

# SKILL: Statische Code-Qualität, Linting & Typüberprüfung (`code-quality-linting`)

> **Rolle & Einsatzzweck:**
> Dieser Skill unterstützt den **`coder`-Agenten** und den **`tester`-Agenten** dabei, sicherzustellen, dass sämtlicher Quellcode im Multi-Language-Projekt `data_sync` (C# Backend, Python CLI, Flutter/Dart GUI) den jeweiligen Sprach-Formatierungsregeln, strengen Typisierungen und den Konventionen der `AGENTS.md` entspricht.

---

## 1. Werkzeuge & Linter je Komponente

- **Backend (`data_sync.API` – C# / .NET 10.0):**
  - `dotnet format --verify-no-changes`: Prüft Formatierung und Stil nach .NET-Standards.
  - C# Compiler Warnings (`Nullable: enable`, `TreatWarningsAsErrors`).
- **CLI-Client (`data_sync.CLI` – Python 3):**
  - `ruff check data_sync.CLI/src/` (oder `flake8`): Prüft PEP-8-Stil, ungenutzte Importe und Logikfehler.
  - Strikte Typprüfung über `typing` (Type-Hints für alle Funktionssignaturen).
- **GUI-Client (`data_sync.FLUTTER` – Flutter / Dart):**
  - `dart analyze data_sync.FLUTTER/lib data_sync.FLUTTER/test`: Statische Analyse mittels `flutter_lints`.

---

## 2. Standard-Befehle zur Prüfung

```bash
# 1. C# Backend (API) Format & Linting prüfen:
dotnet format data_sync.API/data_sync.API.csproj --verify-no-changes

# 2. Python CLI Linting & Typisierung prüfen:
ruff check data_sync.CLI/src/ || flake8 data_sync.CLI/src/

# 3. Flutter / Dart Analyse:
dart analyze data_sync.FLUTTER/lib/ data_sync.FLUTTER/test/
```

---

## 3. Verbindliche Prüf-Checkliste (Clean Code & `AGENTS.md`)

1. **Sprach- & Namenskonventionen:**
   - `[ ]` Alle Bezeichner (Klassen `PascalCase`, Methoden/Funktionen `snake_case` in Python bzw. `camelCase` in Dart/C#, Variablen, Konstanten) sind auf **Englisch** verfasst.
   - `[ ]` Alle Code-Kommentare, Docstrings und XML-Docs (`///`) sind auf **Deutsch** verfasst und erklären das fachliche *Warum*.
2. **Puffer- & Zählvariablen (`sBuffy` / `iBuffy` – Verbindlich):**
   - `[ ]` Temporäre String-Puffer und Zeichenketten-Zwischenspeicher heißen zwingend `sBuffy` (oder `sBuffer...`).
   - `[ ]` Temporäre Integer-Puffer und Schleifenzähler heißen zwingend `iBuffy` (oder `iBuffer...`).
3. **Bibliotheken-Whitelist (Keine neuen Libraries):**
   - `[ ]` Keine neuen Pakete in `data_sync.API.csproj`, `data_sync.CLI` oder `pubspec.yaml` hinzugefügt.
4. **Code-Hygiene:**
   - `[ ]` Keine ungenutzten Importe oder auskommentierten Code-Leichen.
   - `[ ]` Keine Magic Numbers oder Magic Strings im Code.
   - `[ ]` Single Responsibility Principle (SRP): Kurze, modulare Klassen und Methoden.
