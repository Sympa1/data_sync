# Feststellen der technischen Ausgangslage & der zu nutzenden Technologien
Als ich eine Grobe Idee dessen hatte, was ich realisieren will, habe ich geschaut was denn meine technische Ausgangslage ist. Also welche Geräte will ich bedienen und wie kann ich das an Hardware nutzen, was mir zur Verfügung steht, um das Ziel zu erreichen.
Zum anderen habe ich auch meine Fähigkeiten betrachtet.

## Technische Ausgangslage
- Windows Desktop PC
- Manjaro (Linux) Laptop
- Aktuell ein Google Pixel 7 (Android 16)
- Webserver (Ubuntu)

## Meine Fähigkeiten
- C# - Erfahrungen in den Frameworks .NET, Blazor. 
- Python - Erfahrungen in div. Frameworks, z.B. CustomTKinter

## Geplante Architektur
Basierend auf meiner technischen Ausgangslage und meinen Fähigkeiten, habe ich mir die Architektur überlegt.
#### Backend
Da ich beruflich viele Berührungspunkte mit C# habe, habe ich mir für das Backend das Framework "*ASP .NET Core*" näher angeschaut.
Es soll zuverlässig und schnell sein.
Einen ersten Test mit einer einfachen "*Libary*" REST API konnte ich gut umsetzen. 
Außerdem ist "*ASP .NET Core*" von Microsoft sehr gut dokumentiert.

Also werden ich als Backend eine *REST API* mit "*ASP .NET Core*" entwickeln, die ich dann nach Möglichkeit als *Docker Container* auf einen Ubuntu Webserver laufen lasse.

**Datenbankzugriff:** Für den Datenbankzugriff nutze ich "*Entity Framework Core*" (EF Core) von Microsoft. EF Core ist ein moderner ORM (Object-Relational Mapper), der sich ideal für CRUD-Operationen eignet und die Datenzugriffs-Logik vereinfacht. Dies ermöglicht eine saubere Architektur mit automatischer Datenbankmigrationen und typstarker Abfrage-Unterstützung.

In bisherigen eigenen Projekten habe ich Erfahrungen mit MySQL und SQLite gesammelt. Da auf dem Ubuntu Server bereits MySQL läuft werde ich MySQL als Datenbanksystem für die REST API nutzen.
SQLite werde ich für die Frontend Anwendungen nutzen. Das begründet sich daraus, das ich bei meiner Recherche herausgefunden habe, dass es wohl gängig ist SQLite für Mobile Apps, als lokales Datenbanksystem zu nutzen.
#### Frontend
Da ich in Zukunft beruflich Berührungspunkte mit dem C# Framework MAUI haben werde, liegt die Entscheidung nahe, die Android App mit diesem Framework zu entwickeln.
Nach Möglichkeit, möchte ich die MAUI App auch für den Windows Client nutzen.
Für den Linux Laptop, ist das ganze etwas schwerer. Es gibt zwar Avalonia als GUI Framework, aber ich habe bereits Erfahrungen mit TKinter & CustomTKinter. Aber auch QT wäre spannend. Zuerst, zum testen, werde ich jedoch auf eine CLI entwickeln.