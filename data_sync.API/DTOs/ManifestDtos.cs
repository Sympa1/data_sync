using System.Text.Json.Serialization;

namespace data_sync.API.DTOs;

/// <summary>
/// DTO Modell für den POST request des Manifests vom Client.
/// Mappt JSON-Properties (PascalCase) zu DTO-Properties via JsonPropertyName Attribute.
/// </summary>
public class ManifestEntryDto
{
    [JsonPropertyName("fileName")]
    public string FileName { get; set; } = string.Empty;

    [JsonPropertyName("relativePath")]
    public string FilePath { get; set; } = string.Empty; // kein absoluter Client-Pfad

    [JsonPropertyName("size")]
    public long FileSize { get; set; }

    [JsonPropertyName("sha256")]
    public string Hashvalue { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; }

    [JsonPropertyName("lastModified")]
    public DateTime LastModified { get; set; }

    // FileChangeState-Enum wird automatisch konvertiert (case-insensitive in .NET 5+)
    [JsonPropertyName("changeState")]
    public FileChangeState FileState { get; set; }
}

/// <summary>
/// DTO Modell für die Antwort des Manifests an den Client.
/// </summary>
public class ManifestResponseDto
{
    [JsonPropertyName("fileName")]
    public string FileName { get; set; } = string.Empty;

    [JsonPropertyName("relativePath")]
    public string FilePath { get; set; } = string.Empty; // kein absoluter Client-Pfad

    [JsonPropertyName("size")]
    public long FileSize { get; set; }

    [JsonPropertyName("sha256")]
    public string Hashvalue { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; }

    [JsonPropertyName("lastModified")]
    public DateTime LastModified { get; set; }

    // FileChangeState-Enum wird automatisch konvertiert (case-insensitive in .NET 5+)
    [JsonPropertyName("changeState")]
    public FileChangeState FileState { get; set; }

    [JsonPropertyName("toUpload")]
    public bool ToUpload { get; set; }

    [JsonPropertyName("toDelete")]
    public bool ToDelet { get; set; }

    [JsonPropertyName("toDownload")]
    public bool ToDownload { get; set; }
}

/// <summary>
/// Enum für die Dateistatus-Klassifizierung.
/// Wird case-insensitive aus JSON konvertiert (z.B. "Modified" -> Modified).
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum FileChangeState
{
    New,
    Modified,
    Unchanged,
    Deleted,
    Conflict
}