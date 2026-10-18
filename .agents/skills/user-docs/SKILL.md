---
name: user-docs
description: Erstellt und pflegt ein anschauliches Endbenutzer-Handbuch für data_sync mit leicht verständlichen Bedien-, Workflow- und Troubleshooting-Diagrammen, Einrichtungs-Anleitungen für CLI und Flutter-App sowie autarker Offline-Ausgabe.
---

# SKILL: Endbenutzer-Handbuch & Troubleshooting-Guides (`user-docs`)

> **Rolle & Einsatzzweck:**
> Dieser Skill standardisiert die Erstellung und Aktualisierung der Endanwender-Dokumentation für `data_sync` (`Docs/cli_usage.md`, `Docs/flutter_setup.md`, `Docs/server_setup.md` sowie Gesamthandbücher).

---

## 1. Inhaltliche Struktur der Benutzerdokumentation

1. **Systemüberblick:** Was leistet `data_sync`? (Sichere Synchronisation von Dateien, z. B. Obsidian-Vaults, zwischen Windows, Linux und Android).
2. **Server-Einrichtung:** Schnellstart mit Docker Compose und Caddy (Ports 5000 HTTP / 5001 HTTPS).
3. **Client-Bedienung:**
   - **CLI-Client:** Befehle `init`, `scan`, `manifest`, `upload`, `download`, `delete`.
   - **Flutter-App:** Auswahl des lokalen Sync-Ordners, Eingabe der Server-URL, Zertifikatsinstallation (`caddy-root.crt` auf Android) und Ein-Klick-Synchronisation.
4. **Fehlerbehebung & FAQ:** Typische Verbindungsprobleme (`HandshakeException`, Portkonflikte, DNS/Routing im Heimnetz).

---

## 2. Verbindliche Diagramme für das Benutzerhandbuch

### A) Benutzer-Workflow (User Journey)
```mermaid
flowchart LR
    Start(["🚀 1. App oder CLI starten"]) --> Connect["🔗 2. Verbindung zum Server prüfen"]
    Connect --> Scan["📂 3. Lokalen Ordner scannen"]
    Scan --> Sync["🔄 4. Synchronisation ausführen"]
    Sync --> Done(["✅ 5. Alle Dateien auf aktuellem Stand"])
```

### B) Troubleshooting-Entscheidungsbaum
```mermaid
flowchart TD
    Error(["❓ Synchronisationsfehler"]) --> CheckType{"Fehlermeldung prüfen"}
    CheckType -- "'HandshakeException'" --> FixCert["Caddy Root-Zertifikat (caddy-root.crt) auf Android installieren"]
    CheckType -- "'Connection refused'" --> FixServer["Prüfen, ob Docker-Container läuft (docker ps)"]
    CheckType -- "'WRONG_VERSION_NUMBER'" --> FixPort["Port prüfen: HTTP=5000, HTTPS=5001"]
    CheckType -- "'404 Not Found'" --> FixURL["URL ohne '/api/sync' eintragen (wird automatisch ergänzt)"]
```

---

## 3. Strikte Offline-Fähigkeit & Datenschutz

- **Keine externen Web-CDNs:** Alle Diagramme und Formatierungen werden lokal gerendert (Mermaid in Markdown).
- **Datenschutz:** Keine Entwickler-Pfade (`/home/...`) oder Passwörter in Beispielen abbilden.
