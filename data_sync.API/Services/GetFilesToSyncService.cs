using data_sync.API.DTOs;
namespace data_sync.API.Services;

public class GetFilesToSyncService
{
    private readonly MySQLService _mySqlService;

    /// <summary>
    /// Konstruktor für GetFilesToSyncService, der MySQLService injiziert.
    /// </summary>
    /// <param name="mySqlService"></param>
    public GetFilesToSyncService(MySQLService mySqlService)
    {
        _mySqlService = mySqlService;
    }
    
    /// <summary>
    /// Ermittelt, anhand der Manifestliste, die zu synchronisierenden Dateien.
    /// </summary>
    /// <param name="manifests">Liste: ManifestDto</param>
    /// <returns>Liste: filesToSync</returns>
    public async Task<List<FilesToSyncDto>> GetFilesToSync(List<ManifestDto> manifests)
    {
        List<FilesToSyncDto> filesToSync = new List<FilesToSyncDto>();
        
        // Ab .NET 8 sind keine geschweiften Klammern mehr notwendig. Dispose automatisch am Methodenende.
        using var dbConnection = _mySqlService.OpenConnection();

        foreach (var manifest in manifests)
        {
            using var dbCommand = dbConnection.CreateCommand();

            if (manifest.state == "modified")
            {
                dbCommand.CommandText = "SELECT COUNT(file_id) FROM file WHERE state = 'modified' AND hash != @hash";
                dbCommand.Parameters.AddWithValue("@hash", manifest.hash);

                // await hinzufügen
                var count = dbCommand.ExecuteScalar();

                if (count != null && Convert.ToInt32(count) > 0)
                {
                    filesToSync.Add(new FilesToSyncDto
                    {
                        hash = manifest.hash,
                        state = manifest.state,
                        size = manifest.size
                    });
                }
            }
        }
        
        return filesToSync;
    }
}