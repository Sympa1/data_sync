using data_sync.API.DTOs;
using Microsoft.Extensions.Logging;

namespace data_sync.API.Services;

/// <summary>
/// Ermittelt anhand des übermittelten Client-Manifests die Synchronisations-Aktionen (Upload, Download, Delete, Konflikt)
/// für einen bestimmten Benutzer in SQLite.
/// </summary>
public class GetFilesToSyncService
{
    private readonly SqliteService _dbService;
    private readonly ILogger<GetFilesToSyncService> _logger;

    public GetFilesToSyncService(SqliteService sqliteService, ILogger<GetFilesToSyncService> logger)
    {
        _dbService = sqliteService;
        _logger = logger;
    }

    /// <summary>
    /// Ermittelt die Synchronisations-Aktionen je Datei für den angegebenen Benutzer.
    /// </summary>
    /// <param name="iBuffyUserId">ID des authentifizierten Benutzers</param>
    /// <param name="manifests">Vom Client übermittelte Dateiliste</param>
    /// <returns>Liste von Manifest-Entscheidungen für den Client</returns>
    public async Task<List<ManifestResponseDto>> GetFilesToSync(int iBuffyUserId, List<ManifestEntryDto> manifests)
    {
        var filesToSync = new List<ManifestResponseDto>();

        await using var connection = await _dbService.OpenConnectionAsync();
        if (connection == null)
        {
            throw new InvalidOperationException("SQLite-Verbindung nicht verfügbar.");
        }

        foreach (var manifest in manifests)
        {
            var manifestOut = new ManifestResponseDto
            {
                FileName = manifest.FileName,
                FilePath = manifest.FilePath,
                FileSize = manifest.FileSize,
                Hashvalue = manifest.Hashvalue,
                CreatedAt = manifest.CreatedAt,
                LastModified = manifest.LastModified,
                FileState = manifest.FileState,
                ToUpload = false,
                ToDelet = false,
                ToDownload = false
            };

            await using (var dbCommand = connection.CreateCommand())
            {
                // Suche nach Dateipfad in DB für diesen spezifischen Benutzer
                dbCommand.CommandText = @"
                    SELECT hash_value, last_modified, file_state 
                    FROM SyncFiles 
                    WHERE user_id = @userId AND file_path = @filePath;";
                dbCommand.Parameters.AddWithValue("@userId", iBuffyUserId);
                dbCommand.Parameters.AddWithValue("@filePath", manifest.FilePath);

                await using (var reader = await dbCommand.ExecuteReaderAsync())
                {
                    if (await reader.ReadAsync())
                    {
                        string? sBuffyServerHash = reader.IsDBNull(0) ? null : reader.GetString(0);
                        DateTime? modifiedAtFromDb = reader.IsDBNull(1) ? null : reader.GetDateTime(1);
                        string? sBuffyFileState = reader.IsDBNull(2) ? null : reader.GetString(2);

                        _logger.LogInformation("Vergleiche Datei: {FilePath} (User {UserId})", manifest.FilePath, iBuffyUserId);

                        // Prüfe ob Datei auf dem Server als gelöscht markiert ist
                        if (string.Equals(sBuffyFileState, "Deleted", StringComparison.OrdinalIgnoreCase))
                        {
                            manifestOut.ToDelet = true;
                            manifestOut.FileState = FileChangeState.Deleted;
                        }
                        else if (sBuffyServerHash == manifest.Hashvalue)
                        {
                            // Hashes sind identisch -> Datei ist unverändert
                            manifestOut.FileState = FileChangeState.Unchanged;
                        }
                        else
                        {
                            // Hashes unterscheiden sich -> Konfliktauflösung per Zeitstempel
                            if (modifiedAtFromDb.HasValue && manifest.LastModified > modifiedAtFromDb.Value)
                            {
                                manifestOut.ToUpload = true;
                            }
                            else if (modifiedAtFromDb.HasValue && manifest.LastModified < modifiedAtFromDb.Value)
                            {
                                manifestOut.ToDownload = true;
                            }
                            else
                            {
                                manifestOut.FileState = FileChangeState.Conflict;
                            }
                        }
                    }
                    else
                    {
                        // Kein Eintrag mit diesem Pfad -> Reader schließen und nach Hash für Verschiebung suchen
                        await reader.CloseAsync();
                        dbCommand.Parameters.Clear();

                        dbCommand.CommandText = @"
                            SELECT file_path, last_modified 
                            FROM SyncFiles 
                            WHERE user_id = @userId AND hash_value = @hashValue;";
                        dbCommand.Parameters.AddWithValue("@userId", iBuffyUserId);
                        dbCommand.Parameters.AddWithValue("@hashValue", manifest.Hashvalue);

                        await using var reader2 = await dbCommand.ExecuteReaderAsync();
                        if (await reader2.ReadAsync())
                        {
                            string sBuffyExistingPath = reader2.GetString(0);
                            DateTime? modifiedAtFromDb = reader2.IsDBNull(1) ? null : reader2.GetDateTime(1);

                            string sBuffyExistingName = Path.GetFileName(sBuffyExistingPath);
                            string sBuffyManifestName = Path.GetFileName(manifest.FilePath);

                            if (sBuffyExistingName == sBuffyManifestName)
                            {
                                // Verschiebung erkannt
                                if (modifiedAtFromDb.HasValue && manifest.LastModified > modifiedAtFromDb.Value)
                                {
                                    manifestOut.ToUpload = true;
                                }
                                else if (modifiedAtFromDb.HasValue && manifest.LastModified < modifiedAtFromDb.Value)
                                {
                                    manifestOut.ToDownload = true;
                                }
                                else
                                {
                                    manifestOut.ToUpload = true;
                                }
                            }
                            else
                            {
                                // Neuer Dateiname bei gleichem Inhalt (Duplikat)
                                manifestOut.ToUpload = true;
                            }
                        }
                        else
                        {
                            // Weder Pfad noch Hash beim Benutzer vorhanden -> neue oder gelöschte Datei
                            if (manifest.FileState == FileChangeState.Deleted)
                            {
                                manifestOut.ToDelet = true;
                            }
                            else
                            {
                                manifestOut.ToUpload = true;
                            }
                        }
                    }
                }
            }

            filesToSync.Add(manifestOut);
        }

        // Finde Server-Dateien des Benutzers, die nicht im Client-Manifest enthalten sind
        await using (var dbCommand = connection.CreateCommand())
        {
            dbCommand.CommandText = @"
                SELECT file_path, file_name, file_size, hash_value, created_at, last_modified, file_state 
                FROM SyncFiles 
                WHERE user_id = @userId;";
            dbCommand.Parameters.AddWithValue("@userId", iBuffyUserId);

            await using var reader = await dbCommand.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                string sBuffyFilePathDb = reader.GetString(0);

                bool existsInManifest = manifests.Any(m => m.FilePath == sBuffyFilePathDb);
                if (!existsInManifest)
                {
                    string sBuffyFileNameDb = reader.GetString(1);
                    long lFileSizeDb = reader.GetInt64(2);
                    string sBuffyHashDb = reader.IsDBNull(3) ? string.Empty : reader.GetString(3);
                    DateTime createdAtDb = reader.IsDBNull(4) ? DateTime.MinValue : reader.GetDateTime(4);
                    DateTime modifiedAtDb = reader.IsDBNull(5) ? DateTime.MinValue : reader.GetDateTime(5);
                    string sBuffyStateDb = reader.IsDBNull(6) ? "Unchanged" : reader.GetString(6);

                    bool isDeleted = sBuffyStateDb.Equals("deleted", StringComparison.OrdinalIgnoreCase);

                    var serverFile = new ManifestResponseDto
                    {
                        FileName = sBuffyFileNameDb,
                        FilePath = sBuffyFilePathDb,
                        FileSize = lFileSizeDb,
                        Hashvalue = sBuffyHashDb,
                        CreatedAt = createdAtDb,
                        LastModified = modifiedAtDb,
                        FileState = Enum.Parse<FileChangeState>(sBuffyStateDb, ignoreCase: true),
                        ToUpload = false,
                        ToDelet = isDeleted,
                        ToDownload = !isDeleted
                    };

                    filesToSync.Add(serverFile);
                }
            }
        }

        return filesToSync;
    }
}