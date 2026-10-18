# Data Sync
Dieses Projekt ist daraus entstanden, dass ich Dateien – in meinem Fall Obsidian Notizen – zwischen meinen verschiedenen Endgeräten synchronisieren möchte. Dafür muss ich verschiedene Betriebssysteme, Windows, Linux (Manjaro) und Android bedienen.
Ich verspreche mir davon zusätzlich, einiges im Bereich DevOps bzw. CI/CD, Mobile- und Desktop-App-Entwicklung zu lernen. Aber auch beim Datenbankdesign und bei der REST API bin ich sicher, viel hinzuzulernen.
Mein Hauptentwicklungssystem ist Manjaro (Linux).

## Technische Details
**Geplante Technologien/Frameworks:**
- C# ASP .NET Core für das Backend
- Direkter Zugriff auf MariaDB (MySQL‑Protokoll) über ADO.NET (`MySql.Data`) statt eines ORMs
- Flutter/Dart für die Android-, Linux- und Windows-App
- Python für das CLI Tool (Linux)

## Einsatz von KI im Projekt

Ich nutze KI in diesem Projekt bewusst als **Lern- und Sparringspartner**. Mir ist wichtig, dass ich mir die Loesungen **nicht einfach vorkauen lasse**, sondern sie mit gezielten Hinweisen, einfachen Beispielen und Erklaerungen selbst erarbeite.

- Ich nutze KI vor allem fuer Denkimpulse statt fuer komplette Fertigloesungen.
- Ich lasse mir lieber den naechsten sinnvollen Schritt oder ein vereinfachtes Beispiel zeigen, damit ich die eigentliche Loesung selbst herleiten kann.
- Ich nutze KI, um Zusammenhaenge zwischen Code, API, Datenbank und Dokumentation besser zu verstehen.
- Ich nutze KI auch als Feedbackgeber, um Unklarheiten, Inkonsistenzen und Verbesserungsmoeglichkeiten frueher zu erkennen.
- Ich pruefe Vorschlaege immer kritisch und passe sie an mein Projekt und meinen Lernstand an.

Das ist für mich wichtig, weil das Projekt nicht nur ein Werkzeug werden soll, sondern auch ein **Lernprojekt** und ein **nachvollziehbares Portfolio-Element**.

## Roadmap
**Status-Legende:**
- ✅ Abgeschlossen
- ⌛ In Arbeit
- 🕓 Geplant
- 💭 Konzeptphase

### Versionen
- 0.0.0 - Planung
    - [Feststellen der technischen Ausgangslage, der zu nutzenden Technologien & Architektur](Docs/ausgangslage_technologien.md) ✅
    - [Feststellen der Funktionen nach der MVP Methode](Docs/grundlegende_funktionen.md) ✅
    - [Erarbeiten des Datenbank Designs](Docs/datenbank_design.md) ✅
    - [Entwurf des Backend System Design](Docs/backend_system_design.md) ✅
    - [Entwurf des Client-Mockups für die Mobile App (Analog auch für die Desktop Apps)](https://github.com/Sympa1/project_sleipnir-data_sync/blob/master/Docs/android_mokup_2.png) ✅
- 0.0.1 Datenbankentwicklung
    - MariaDB Schema erstellen ✅
    - MariaDB Accounts (Admin & Client) anlegen und Berechtigungen erteilen ✅
    - Create Table SQL‑Skripte erstellen ✅
- 0.0.2 Implementierung der REST API
    - Datenbankzugriff via `MySql.Data` implementieren (MariaDB nutzt die MySQL Schnittstelle) ✅
    - Grundlegende REST API Endpunkte ✅
    - Entity Models / DTOs erstellen ✅
    - Postman Collection ✅
    - Implementierung File Up- und Download ✅
- 0.0.3 Linux CLI Tool
    - Lokale SQLite Datenbank ✅
    - CLI Framework: argparse - Verschiedene Flags für unterschiedliche Funktionen ✅
    - Lokale SQLite Datenbank ✅
    - Lokale Berechnung des Dateihashes ✅
    - Kommunikation, inkl. Manifest, mit der REST API zum Synchronisieren ✅
    - Testing der REST API mit dem CLI Tool ✅
- 0.0.4 Android / Linux / Windows App - GUI Framework Flutter
    - Einarbeitung in Flutter ✅
    - Lokale SQLite Datenbank ✅
    - Lokale Berechnung des Dateihashes ✅
    - Kommunikation, inkl. Manifest, mit der REST API zum Synchronisieren ✅
- 0.1.0 Testing
    - End to End Test ✅
- 0.9.0 Release-Vorbereitung
    - Containersinierung der Web API mit Docker ✅
    - Erstellen des automatischen Deployment 🕓
    - Sicheres Speichern von Datenbanklogin und Passwort 🕓
- 1.0.0 Release und Deployment Version 1.0.0
    - Release durchführen 💭

## Geplante Funktionen der ersten Version
- Ausgewähltes Verzeichnis wird synchronisiert
- Basis REST API **ohne** Authentifizierung
- Einfache Konfliktlösung - letzte Änderung wird übernommen
- Manuelle Synchronisation - der User startet den Vorgang (Download / Upload Buttons)

## Zukünftige mögliche Features
- Ein Backupsystem
- Eine Authentifizierung
- Biometrie Login bei der Android App
- Auto Sync
- Intelligente Konfliktlösung
- Windows Forms Admin-App (optional)
- Admin Dashboard mit Statistiken und später User Management (optional)

## Branching \& GitLab Flow

Kurz: Wir nutzen GitLab Flow. Detaillierte Regeln zu Branch-Namen, Merge-Requests und Deploys sind in `Docs/gitlab_flow.md` dokumentiert.

- Wichtige Branches: `main` / `production`, `feature/*`, `hotfix/*`, `bugfix/*`, `release/*`
- Merge-Requests: Review erforderlich, CI-Pipeline muss erfolgreich sein
- Deploy: `production` ist der Deployment-Branch (automatisiert)
- Weitere Hinweise: Siehe `Docs/gitlab_flow.md` für Beispiele und Regeln


## Verwendung

### CLI Tool
Detaillierte Informationen zur Verwendung des CLI Tools findest du in [Docs/cli_usage.md](Docs/cli_usage.md) – inklusive Alias-Einrichtung (`ds` / `data_sync`).

**Schnellstart:**
```bash
# Datenbank initialisieren
cd data_sync.CLI
python src/main.py --init

# Verzeichnis scannen
python src/main.py --scan

# Vollständige Synchronisation (Scan + Download + Upload + Delete)
python src/main.py --sync
```

### Flutter App
Einrichtung, APK-Build und HTTPS-Zertifikat-Installation: [Docs/flutter_setup.md](Docs/flutter_setup.md)

> Das Caddy-Zertifikat wird **nur von der Flutter App** benötigt, nicht vom CLI Tool.

### API
Die REST API ist das Backend fuer die Synchronisation und laeuft lokal im Development-Modus standardmaessig unter `https://localhost:7169`.

**Quickstart:**

```bash
cd data_sync.API
dotnet run
```

Die ausfuehrliche API-Anleitung mit Voraussetzungen, `.env`, Docker-Setup und Troubleshooting findest du in [Docs/api_usage.md](Docs/api_usage.md).

Die Einrichtung auf einem Raspberry Pi oder Linux-Server (inkl. Caddy & HTTPS) findest du in [Docs/server_setup.md](Docs/server_setup.md).

- `POST /api/sync/manifest` - Manifest-Abgleich mit Three-Way-Merge
- `POST /api/sync/upload` - Datei-Upload
- `GET /api/sync/download` - Datei-Download
- `DELETE /api/sync/delete` - Datei-Löschung

## Voraussetzungen

**Für das CLI Tool:**
- Python 3.8 oder höher
- `requests` Bibliothek: `pip install requests`
- `config.json` im Projektverzeichnis (siehe [cli_usage.md](Docs/cli_usage.md))

**Für die API:**
- .NET 10.0 SDK oder höher
- MariaDB Server (MySQL-kompatibel)
- `MySql.Data` NuGet Package
## Verzeichnisstruktur

```
data_sync/
├── Docs/                            # Projekt-Dokumentation
│   ├── android_mokup_2.png
│   ├── api_usage.md                  # Ausfuehrliche API Anleitung
│   ├── ausgangslage_technologien.md
│   ├── backend_system_design.md
│   ├── cli_usage.md                  # CLI Benutzerhandbuch
│   ├── datenbank_design.md
│   ├── gitlab_flow.md
│   └── grundlegende_funktionen.md
│
├── data_sync.API/                   # ASP.NET Core REST API
│   ├── data_sync.API.csproj
│   ├── appsettings.json
│   ├── Program.cs
│   │
│   ├── Controllers/                 # API Endpoints
│   │   └── SyncController.cs
│   │
│   ├── DTOs/                        # Data Transfer Objects
│   │   ├── ConfirmDownloadDtos.cs
│   │   ├── ConfirmUploadDtos.cs
│   │   └── ManifestDtos.cs
│   │
│   ├── Models/                      # Entity Models & Enums
│   │   ├── SyncFile.cs
│   │   ├── SyncEvent.cs
│   │   ├── FileState.cs
│   │   └── SyncAction.cs
│   │
│   ├── Services/                    # Business Logic Services
│   │   ├── DbErrorLogService.cs
│   │   ├── DbStartupCheckService.cs
│   │   ├── EnvLoadeService.cs
│   │   ├── FileLogService.cs
│   │   ├── GetFilesToSyncService.cs
│   │   ├── MariaDBService.cs        # ADO.NET Service für MariaDB
│   │   ├── SyncStateService.cs
│   │   ├── UpdateMetadataService.cs
│   │   └── UtilsService.cs
│   │
│   ├── MariaDB/                     # MariaDB Schema
│   │   └── CreateTable.sql
│   │
│   ├── Tests/                       # Test-Dateien
│   │   ├── Postman/                 # Postman Collections
│   │   ├── DbErrorLogServiceTests.cs
│   │   └── TestService.cs
│   │
│   └── Properties/
│       └── launchSettings.json
│
├── data_sync.CLI/                   # Python CLI Tool
│   ├── src/
│   │   ├── main.py                  # Entry Point
│   │   └── core/                    # Core-Logik
│   │       ├── commands/            # Command Pattern Implementation
│   │       │   ├── base_command.py
│   │       │   ├── init_command.py
│   │       │   ├── scan_command.py
│   │       │   ├── manifest_command.py
│   │       │   ├── upload_command.py
│   │       │   ├── download_command.py
│   │       │   └── delete_command.py
│   │       ├── handlers/            # Hilfsfunktionen
│   │       │   ├── config_handler.py
│   │       │   ├── sqlite_handler.py
│   │       │   ├── manifest_handler.py
│   │       │   ├── db_logger.py
│   │       │   └── file_logger.py
│   │       ├── api_client.py        # REST API Client
│   │       ├── file_scanner.py      # Verzeichnis-Scanner
│   │       ├── sync_state_manager.py # LastSyncState Verwaltung
│   │       ├── db_setup.py          # DB-Initialisierung
│   │       └── models.py            # Datenmodelle
│   ├── SQLite/
│   │   └── CreateTable.sql          # SQLite Schema
│   └── test_data/                   # Test-Verzeichnis
│
├── data_sync.FLUTTER/               # Flutter App (Android, Linux, Windows)
│   ├── lib/
│   ├── android/
│   ├── linux/
│   ├── windows/
│   └── pubspec.yaml
│
├── config.json                      # CLI Konfiguration
├── cli_db.db                        # SQLite Datenbank (generiert)
├── README.md
└── data_sync.sln                    # Visual Studio Solution
```

## Installation

### CLI Tool installieren
```bash
# 1. Repository klonen
git clone <repository-url>
cd data_sync

# 2. Python-Abhängigkeiten installieren
pip install requests

# 3. Konfiguration erstellen
cat > config.json << EOF
{
  "sync_path": "/pfad/zum/sync/verzeichnis",
  "api_base_url": "https://localhost:7169/api/sync",
  "verify_ssl": false
}
EOF

# 4. Datenbank initialisieren
cd data_sync.CLI/src
python main.py --init
```

### API Backend starten
Kurze Version:

```bash
cd data_sync.API
dotnet run
```

Die ausfuehrliche Einrichtung findest du in [Docs/api_usage.md](Docs/api_usage.md).

### API im Docker-Container starten
Die Docker-Anleitung fuer die API findest du in [Docs/api_usage.md](Docs/api_usage.md).

Detaillierte Informationen zur CLI-Verwendung: [Docs/cli_usage.md](Docs/cli_usage.md)

## Abhängigkeiten

### CLI Tool (Python)
- `requests` - HTTP-Bibliothek für API-Kommunikation
- Python Standard Library (`os`, `hashlib`, `sqlite3`, `json`, `argparse`)

### API Backend (ASP.NET Core)
- .NET 10.0
- `MySql.Data` - MariaDB/MySQL Datenbankzugriff
- `DotNetEnv` - .env Datei Support

## Lizenz
Dieses Projekt ist unter der GPL-3.0 lizenziert - siehe die [LICENSE](LICENSE)-Datei für Details.
