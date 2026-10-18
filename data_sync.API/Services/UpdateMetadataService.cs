using data_sync.API.DTOs;
using data_sync.API.Models;

namespace data_sync.API.Services;

/// <summary>
/// Service zur Verwaltung der Datei-Metadaten in SQLite je Benutzer.
/// </summary>
public class UpdateMetadataService
{
    private readonly SqliteService _sqliteService;

    public UpdateMetadataService(SqliteService sqliteService)
    {
        _sqliteService = sqliteService;
    }

    /// <summary>
    /// Aktualisiert oder erstellt Dateimetadaten für den angegebenen Benutzer via SQLite UPSERT.
    /// </summary>
    public async Task UpdateMetadataAsync(int iBuffyUserId, SyncFile metaData)
    {
        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            throw new InvalidOperationException("SQLite-Verbindung konnte nicht hergestellt werden.");
        }

        await using var dbCommand = connection.CreateCommand();
        dbCommand.CommandText = @"
            INSERT INTO SyncFiles (user_id, file_name, file_path, file_size, hash_value, last_modified, file_state)
            VALUES (@userId, @fileName, @filePath, @fileSize, @hashValue, CURRENT_TIMESTAMP, @fileState)
            ON CONFLICT(user_id, file_path) DO UPDATE SET
                file_name = excluded.file_name,
                file_size = excluded.file_size,
                hash_value = excluded.hash_value,
                last_modified = CURRENT_TIMESTAMP,
                file_state = excluded.file_state;
        ";

        dbCommand.Parameters.AddWithValue("@userId", iBuffyUserId);
        dbCommand.Parameters.AddWithValue("@fileName", metaData.FileName);
        dbCommand.Parameters.AddWithValue("@filePath", metaData.FilePath);
        dbCommand.Parameters.AddWithValue("@fileSize", metaData.FileSize);
        dbCommand.Parameters.AddWithValue("@hashValue", metaData.HashValue);
        dbCommand.Parameters.AddWithValue("@fileState", metaData.FileState.ToString());

        await dbCommand.ExecuteNonQueryAsync();
    }

    /// <summary>
    /// Ruft alle Metadaten eines Benutzers ab.
    /// </summary>
    public async Task<List<ConfirmDownloadResponseDto>> GetUserMetadataListAsync(int iBuffyUserId)
    {
        var resultList = new List<ConfirmDownloadResponseDto>();
        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null) return resultList;

        await using var dbCommand = connection.CreateCommand();
        dbCommand.CommandText = @"
            SELECT file_name, file_path, file_size, last_modified, hash_value, file_state
            FROM SyncFiles
            WHERE user_id = @userId;";
        dbCommand.Parameters.AddWithValue("@userId", iBuffyUserId);

        await using var reader = await dbCommand.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            var item = new ConfirmDownloadResponseDto
            {
                FileName = reader.GetString(0),
                FilePath = reader.GetString(1),
                FileSize = reader.GetInt64(2),
                LastModified = reader.GetDateTime(3),
                Hashvalue = reader.GetString(4),
                FileState = Enum.Parse<FileChangeState>(reader.GetString(5), ignoreCase: true)
            };
            resultList.Add(item);
        }

        return resultList;
    }
}