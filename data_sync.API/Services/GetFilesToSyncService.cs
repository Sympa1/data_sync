using data_sync.API.DTOs;

namespace data_sync.API.Services;

public class GetFilesToSyncService
{
    /// <summary>
    /// Ermittelt, anhand der Manifestliste, die zu synchronisierenden Dateien.
    /// TODO: Mit Entity Framework Core und PostgreSQL implementieren
    /// </summary>
    /// <param name="manifests">Liste: ManifestDto</param>
    /// <returns>Liste: filesToSync</returns>
    public async Task<List<FilesToSyncDto>> GetFilesToSync(List<ManifestDto> manifests)
    {
        // TODO: EF Core Implementation
        List<FilesToSyncDto> filesToSync = new List<FilesToSyncDto>();
        
        return filesToSync;
    }
}