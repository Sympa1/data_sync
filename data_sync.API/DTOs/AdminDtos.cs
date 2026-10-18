namespace data_sync.API.DTOs;

/// <summary>
/// Statistische Kennzahlen für das Admin-Dashboard.
/// </summary>
public class AdminStatsDto
{
    public int TotalUsers { get; set; }
    public int TotalFiles { get; set; }
    public long TotalStorageBytes { get; set; }
    public long DatabaseSizeBytes { get; set; }
    public string ServerTime { get; set; } = string.Empty;
}

/// <summary>
/// Detailinformationen eines Benutzers für die Admin-Übersicht.
/// </summary>
public class AdminUserItemDto
{
    public int UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public bool IsAdmin { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? LastLogin { get; set; }
    public int FileCount { get; set; }
    public long StorageBytes { get; set; }
}

/// <summary>
/// Anfrage zum Anlegen eines neuen Benutzers durch den Administrator.
/// </summary>
public class AdminCreateUserDto
{
    public required string Username { get; set; }
    public required string Password { get; set; }
    public bool IsAdmin { get; set; }
}

/// <summary>
/// Datei-Übersicht für Administratoren über alle Benutzer hinweg.
/// </summary>
public class AdminFileItemDto
{
    public int SyncFileId { get; set; }
    public int UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public string FilePath { get; set; } = string.Empty;
    public long FileSize { get; set; }
    public string HashValue { get; set; } = string.Empty;
    public DateTime LastModified { get; set; }
    public string FileState { get; set; } = string.Empty;
}

/// <summary>
/// System- und Fehlerprotokoll-Eintrag.
/// </summary>
public class AdminLogItemDto
{
    public int Id { get; set; }
    public int? UserId { get; set; }
    public string? Username { get; set; }
    public string Description { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; }
}
