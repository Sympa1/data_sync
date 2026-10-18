namespace data_sync.API.Models;

public class SyncFile
{
    public int FileId { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string FilePath { get; set; } = string.Empty;
    public long FileSize { get; set; }
    public DateTime? LastModified { get; set; }
    public DateTime CreatedAt { get; set; }
    public string HashValue { get; set; } = string.Empty;
    public FileState FileState { get; set; } = FileState.Modified;


    // Navigation Property
    public ICollection<SyncEvent> SyncEvents { get; set; } = new List<SyncEvent>();
}