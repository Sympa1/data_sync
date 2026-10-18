namespace data_sync.API.Services;

/// <summary>
/// Protokolliert Datenbankfehler in der FehlerProtokoll-Tabelle von SQLite.
/// Nutzt SqliteService per Dependency Injection.
/// </summary>
public class DbErrorLogService
{
    private readonly SqliteService _dbService;

    public DbErrorLogService(SqliteService sqliteService)
    {
        _dbService = sqliteService;
    }

    /// <summary>
    /// Schreibt eine aussagekräftige Fehlermeldung in die FehlerProtokoll-Tabelle.
    /// </summary>
    public async Task LogDbErrorAsync(Exception ex, string contextInfo, int? iBuffyUserId = null)
    {
        await using var connection = await _dbService.OpenConnectionAsync();
        if (connection != null)
        {
            await using var dbCommand = connection.CreateCommand();
            var sBuffyFehlerBeschreibung = $"Fehler im Kontext '{contextInfo}': {ex.Message}\nStackTrace: {ex.StackTrace}";
            dbCommand.CommandText = @"
                INSERT INTO FehlerProtokoll (user_id, fehler_beschreibung, fehler_timestamp)
                VALUES (@userId, @fehlerBeschreibung, CURRENT_TIMESTAMP);";

            dbCommand.Parameters.AddWithValue("@userId", (object?)iBuffyUserId ?? DBNull.Value);
            dbCommand.Parameters.AddWithValue("@fehlerBeschreibung", sBuffyFehlerBeschreibung);

            await dbCommand.ExecuteNonQueryAsync();
        }
    }
}