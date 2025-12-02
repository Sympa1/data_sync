namespace data_sync.API.DTOs;

/// <summary>
/// DTO Modell für den POST request des Manifests (Alle Dateien vom CLient) vom Client.
/// </summary>
public class ManifestDto
{
    public int size { get; set; }
    public DateTime? modifactionTime { get; set; }
    public DateTime createdAt { get; set; }
    public string hash { get; set; }
    public string? state { get; set; }
    public DateTime? updatedAt { get; set; }
}