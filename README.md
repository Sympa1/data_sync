# Data Sync
Dieses Projekt ist daraus entstanden, dass ich Dateien -in meinem Fall Obsidian Notizen- Zwischen meinen verschieden Endgeräten synchronisieren möchte. Dafür muss ich verschiedene Betriebssysteme, Windows, Linux (Manjaro) und Android bedienen.
Ich verspreche mir davon zusätzlich, einiges im Bereich DevOPS bzw. CI/CD, Mobile und Desktopapp zu lernen. Aber auch beim Datenbankdesign und bei der REST API, bin ich sicher viel hinzu zu lernen.
Mein Hauptentwicklungssystem ist Manjaro (Linux), wobei die Android App aller voraussiecht nach unter Windows entwickelt werden wird.
## Technische Details
**Geplante Technologien/Frameworks:**
- C# ASP .NET Core für das Backend
- C# MAUI für die Android- und nach Möglichkeit Windows App
- Python /CustomTKinter/QT für das Manjaro (Linux) Frontend
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
    - MySQL Schema erstellen ✅
    - MySQL Accounts (Admin & Client) anlegeb und Berechtigungen erteilen ✅
    - Create Table erstellen ✅
- 0.0.2 Implementierung der REST API
    - Grundlegende REST API Endpunkte ⌛
    - Erstellen der SQL Statements ⌛
    - Postman Collection ⌛
    - Implementierung File Up- und Download 🕓
    - Implementierung Python CLI zum Testen 🕓
    - Vorrübergehendes speichern der DB Logindaten in einem .env File 🕓
- 0.0.3 Linux GUI
    - Lokale SQLite Datenbank 🕓
    - GUI Framework: CustomTkinter oder QT 🕓
    - Lokale Berechnung des Dateihashes 🕓
    - Kommunikation, inkl. Manifest, mit der REST API zum Synchronisieren 🕓
- 0.0.4 Android / Windows GUI
    - Lokale SQLite Datenbank 🕓
    - GUI Framework: MAUI 🕓
    - Lokale Berechnung des Dateihashes 🕓
    - Kommunikation, inkl. Manifest, mit der REST API zum Synchronisieren 🕓
- 0.1.0 Testing
    - Unittest 💭
- 0.9.0 Release-Vorbereitung
    - Erstellen des automatischen Deployment 🕓
    - Sicheres Speichern von Datenbanklogin und Passwort 🕓
- 1.0.0 Release und Deployment Version 1.0.0
    - Release durchführen 💭

## Geplante Funktionen der ersten Version
- Ausgewähltes Verzeichnis wird synchronisiert
- Basis REST API **ohne** Authentifizierung
- Einfache Konfliktlösung - letzte Änderung wird übernommen
- Manuelle Synchronisation - der User startet den Vorgang (Download / Upload Buttons)
## Zukünftige Features
- Ein Backupsystem
- Eine Authentifizierung 
- Biometrie Login bei der Android App
- Auto Sync
- Intelligente Konfliktlösung
## ~~Lessons Learned~~
~~Work in Progress.~~
## ~~Voraussetzungen~~
~~Work in Progress.~~
## Verzeichnisstruktur
```
data_sync/
├── Database/
│   ├── MySQL/
│   │   └── Schema.sql
│   └── SQLite/
│       └── Schema.sql
│
├── Docker/
│   └── Placeholder
│
├── Docs/
│   ├── android_mokup_2.png
│   ├── ausgangslage_technologien.md
│   ├── backend_system_design.md
│   ├── datenbank_design.md
│   └── grundlegende_funktionen.md
│
├── data_sync.API/
│   └── data_sync.API.csproj
|
├── data_sync.CLI/
│   └── main.py
|
├── data_sync.GUI/
│   └── main.py    
|
├── data_sync.MAUI/
│   └── data_sync.MAUI.csproj
│
├── Tests/
│   └── Postman/
|       ├── Manifest.json
│       └── data_sync.postman_collection.json
│
├── README.md
└── data_sync.sln
```
## ~~Installation~~
~~Work in Progress.~~
## ~~Verwendung~~
~~Work in Progress.~~
## Bekannte Probleme
Keine bekannten Probleme.
## ~~Abhängigkeiten~~
~~Work in Progress.~~
## Lizenz
Dieses Projekt ist unter der GPL-3.0 lizenziert - siehe die [LICENSE](LICENSE)-Datei für Details.



