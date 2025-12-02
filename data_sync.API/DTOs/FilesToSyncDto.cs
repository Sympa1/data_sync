namespace data_sync.API.DTOs;

/// <summary>
/// DTO Modell für die zu synchronisierenden Dateien.
/// </summary>
public class FilesToSyncDto
{
    public int size { get; set; }
    public DateTime? modifactionTime { get; set; }
    public DateTime createdAt { get; set; }
    public string hash { get; set; }
    public string? state { get; set; }
    public DateTime? updatedAt { get; set; }
}