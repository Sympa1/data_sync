using System.Text.Json.Serialization;

namespace data_sync.API.DTOs;

public class ConfirmDownloadResponseDto
{
    [JsonPropertyName("fileName")]
    public required string FileName { get; set; }

    [JsonPropertyName("relativePath")]
    public required string FilePath { get; set; } // kein absoluter Client-Pfad

    [JsonPropertyName("size")]
    public long FileSize { get; set; }

    [JsonPropertyName("lastModifiedUtc")]
    public DateTime LastModified { get; set; }

    [JsonPropertyName("createdAt")]
    public DateTime CreatedAt { get; set; }

    [JsonPropertyName("sha256")]
    public required string Hashvalue { get; set; }

    // FileChangeState-Enum wird automatisch konvertiert (case-insensitive in .NET 5+)
    [JsonPropertyName("changeState")]
    public FileChangeState FileState { get; set; }
}