---
name: code-refactoring
description: Strukturierter Leitfaden für verhaltensbewahrendes Code-Refactoring nach Clean-Code- und SOLID-Prinzipien für data_sync im isolierten Branch.
---

# SKILL: Sicheres & Verhaltensbewahrendes Code-Refactoring (`code-refactoring`)

> **Rolle & Einsatzzweck:**
> Dieser Skill unterstützt den **`researcher`-** und **`coder`-Agenten** dabei, technische Schulden im Projekt `data_sync` (z. B. zu komplexe Three-Way-Merge-Verzweigungen, redundante Pfadnormalisierungen oder Monolithen in API/CLI/Flutter) strukturiert abzubauen, **ohne das bestehende Synchronisationsverhalten oder API-Verträge zu brechen**.

---

## 1. Grundregeln des Refactorings im 4-Agenten-Workflow

1. **Strikte Trennung von Refactoring und Feature-Änderung:**
   Verhaltensänderungen (z. B. neue REST-Endpunkte oder geänderte Hash-Verfahren) und rein strukturelle Bereinigungen dürfen niemals im selben Commit vermischt werden.
2. **Sicherheitsnetz durch bestehende Tests:**
   Vor jedem Umbau müssen bestehende Tests (`dotnet test`, Python-Unittests, `flutter test`) grün sein.
3. **Keine neuen externen Bibliotheken:**
   Refactorings dürfen niemals durch das Hinzufügen neuer Third-Party-Libraries gelöst werden; nutze bestehende Standardbibliotheken oder freigegebene Whitelist-Pakete.
4. **Abstimmung mit dem `researcher`-Agenten:**
   Weicht der `coder`-Agent während des Refactorings vom Architektur-Konzept ab, muss er den `researcher` via `send_message` konsultieren.

---

## 2. Refactoring-Schwerpunkte in data_sync

- **Three-Way-Merge-Logik:** Komplexe Entscheidungsbäume zwischen lokalem Dateisystem, lokaler SQLite (`LastSyncState`) und Server-MariaDB (`SyncFiles`) in lesbare, modulare Command- oder Strategie-Objekte kapseln.
- **Pfad-Normalisierung & Plattform-Konsistenz:** Windows-Backslashes (`\`) und Linux-/Android-Slashes (`/`) konsequent vereinheitlichen.
- **Puffer- & Variablenkonventionen (`sBuffy` / `iBuffy`):** Bei Umbauten sicherstellen, dass String-Puffer (`sBuffy`) und Integer-Zähler (`iBuffy`) standardisiert sind.
- **ADO.NET- & SQLite-Zugriff:** Direkten Datenbankzugriff ohne ORM schlank und frei von SQL-Injection halten (parametrisierte Queries).

---

## 3. Checkliste vor Übergabe an `tester` & `security-specialist`

- `[ ]` Alle REST-Endpunkte (`/api/sync/manifest`, `/api/sync/upload`, `/api/sync/download`, `/api/sync/delete`) bleiben API-kompatibel.
- `[ ]` Deutsche Inline-Kommentare & Docstrings erklären das fachliche *Warum*.
- `[ ]` Englische Bezeichner & `sBuffy`/`iBuffy`-Konventionen sind durchgängig eingehalten.
- `[ ]` Paralleler Start von `tester` und `security-specialist` wird nach Fertigstellung ausgelöst.
