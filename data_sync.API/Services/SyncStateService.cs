namespace data_sync.API.Services;

/// <summary>
/// Verwaltet den letzten bekannten Synchronisationsstand einer Datei je Benutzer in SQLite.
/// </summary>
public class SyncStateService
{
    private readonly SqliteService _sqliteService;

    public SyncStateService(SqliteService sqliteService)
    {
        _sqliteService = sqliteService;
    }

    /// <summary>
    /// Legt den letzten Synchronisationsstand für eine Datei und einen Benutzer an oder aktualisiert ihn via SQLite UPSERT.
    /// </summary>
    public async Task UpdateSyncStateAsync(int iBuffyUserId, string sBuffyFilePath, string sBuffyHash, long fileSize)
    {
        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            throw new InvalidOperationException("SQLite-Verbindung konnte nicht hergestellt werden.");
        }

        await using var dbCommand = connection.CreateCommand();
        dbCommand.CommandText = @"
            INSERT INTO LastSyncState (user_id, file_path, hash_value, file_size, last_synced_at)
            VALUES (@userId, @filePath, @hashValue, @fileSize, CURRENT_TIMESTAMP)
            ON CONFLICT(user_id, file_path) DO UPDATE SET
                hash_value = excluded.hash_value,
                file_size = excluded.file_size,
                last_synced_at = CURRENT_TIMESTAMP;";

        dbCommand.Parameters.AddWithValue("@userId", iBuffyUserId);
        dbCommand.Parameters.AddWithValue("@filePath", sBuffyFilePath);
        dbCommand.Parameters.AddWithValue("@hashValue", sBuffyHash);
        dbCommand.Parameters.AddWithValue("@fileSize", fileSize);

        await dbCommand.ExecuteNonQueryAsync();
    }

    /// <summary>
    /// Entfernt den Synchronisationsstand für eine gelöschte Datei eines Benutzers.
    /// </summary>
    public async Task DeleteSyncStateAsync(int iBuffyUserId, string sBuffyFilePath)
    {
        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            throw new InvalidOperationException("SQLite-Verbindung konnte nicht hergestellt werden.");
        }

        await using var dbCommand = connection.CreateCommand();
        dbCommand.CommandText = "DELETE FROM LastSyncState WHERE user_id = @userId AND file_path = @filePath;";
        dbCommand.Parameters.AddWithValue("@userId", iBuffyUserId);
        dbCommand.Parameters.AddWithValue("@filePath", sBuffyFilePath);

        await dbCommand.ExecuteNonQueryAsync();
    }
}
