# Datenbankdesign

Das Datenbankdesign basiert auf Entity Framework Core (EF Core) mit zwei Hauptentitäten: `File` und `SyncEvent`.

## Datei Metadaten

Die wichtigsten Attribute einer Datei werden erfasst:

| Attribut          | Typ       | Bedeutung                                          |
| ----------------- | --------- | -------------------------------------------------- |
| FileId            | int       | Eindeutige Kennung (Primary Key)                  |
| Path              | string    | Dateipfad vom Sync-Root-Verzeichnis               |
| Size              | long      | Dateigröße in Bytes                               |
| ModificationTime  | DateTime? | Zeitstempel der letzten Änderung                  |
| CreatedAt         | DateTime  | Zeitstempel der Dateierstellung                   |
| Hash              | string    | SHA256-Fingerabdruck der Datei                    |
| State             | FileState | Zustand der Datei (synced, modified, etc.)       |
| UpdatedAt         | DateTime? | Zeitstempel der letzten Aktualisierung im System  |

## Entity Framework Core Entities

### FileState Enum
```csharp
public enum FileState
{
    Synced,      // Datei ist synchronisiert
    Modified,    // Datei wurde lokal geändert
    Conflict,    // Konflikt erkannt
    Deleted      // Datei wurde gelöscht
}
```

### File Entity
```csharp
public class File
{
    public int FileId { get; set; }
    
    public string Path { get; set; } = string.Empty;
    
    public long Size { get; set; }
    
    public DateTime? ModificationTime { get; set; }
    
    public DateTime CreatedAt { get; set; }
    
    public string Hash { get; set; } = string.Empty;
    
    public FileState State { get; set; } = FileState.Modified;
    
    public DateTime? UpdatedAt { get; set; }
    
    // Navigation Property
    public ICollection<SyncEvent> SyncEvents { get; set; } = new List<SyncEvent>();
}
```

### SyncAction Enum
```csharp
public enum SyncAction
{
    Download,  // Datei heruntergeladen
    Upload,    // Datei hochgeladen
    Conflict,  // Konflikt aufgelöst
    Delete,    // Datei gelöscht
    Error      // Fehler bei Synchronisierung
}
```

### SyncEvent Entity
```csharp
public class SyncEvent
{
    public int LogId { get; set; }
    
    public int FileId { get; set; }
    
    public SyncAction Action { get; set; }
    
    public DateTime Timestamp { get; set; }
    
    public string Details { get; set; } = string.Empty;
    
    // Foreign Key Navigation
    public File File { get; set; } = null!;
}
```

## Datenbankinitialisierung

Die Datenbank wird automatisch durch EF Core Migrations verwaltet:

```bash
# Migration erstellen
dotnet ef migrations add InitialCreate

# Datenbank aktualisieren
dotnet ef database update
```