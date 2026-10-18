using Microsoft.Data.Sqlite;

namespace data_sync.API.Services;

/// <summary>
/// Service für die Verwaltung der lokalen SQLite-Datenbankverbindung.
/// Stellt ADO.NET SqliteConnections bereit, erzwingt Foreign Keys und den WAL-Modus
/// für hohe Nebenläufigkeit ohne externen Datenbankserver.
/// </summary>
public class SqliteService : IDisposable, IAsyncDisposable
{
    private readonly string _connectionString;
    private SqliteConnection? _connection;

    /// <summary>
    /// Initialisiert die SQLite-Konfiguration aus der Umgebung oder nutzt den Standardpfad.
    /// Erstellt das Zielverzeichnis bei Bedarf automatisch.
    /// </summary>
    public SqliteService()
    {
        // Pfad zur SQLite-Datenbank ermitteln (Standard: data/data_sync.db)
        var sBuffyDbPath = Environment.GetEnvironmentVariable("DB_PATH");
        if (string.IsNullOrWhiteSpace(sBuffyDbPath))
        {
            sBuffyDbPath = Path.Combine(AppContext.BaseDirectory, "data", "data_sync.db");
        }

        // Sicherstellen, dass das Verzeichnis für die SQLite-Datei existiert
        var sBuffyDirectory = Path.GetDirectoryName(Path.GetFullPath(sBuffyDbPath));
        if (!string.IsNullOrEmpty(sBuffyDirectory) && !Directory.Exists(sBuffyDirectory))
        {
            Directory.CreateDirectory(sBuffyDirectory);
        }

        // Connection String mit SQLite konfigurieren (Shared Cache & WAL für gleichzeitige Zugriffe)
        var connectionStringBuilder = new SqliteConnectionStringBuilder
        {
            DataSource = sBuffyDbPath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Shared
        };

        _connectionString = connectionStringBuilder.ConnectionString;
    }

    /// <summary>
    /// Öffnet asynchron eine SQLite-Verbindung und aktiviert PRAGMAs für Datenintegrität und Performance.
    /// </summary>
    public async Task<SqliteConnection?> OpenConnectionAsync()
    {
        try
        {
            _connection = new SqliteConnection(_connectionString);
            await _connection.OpenAsync();

            // WAL-Modus und Foreign Keys für SQLite zwingend aktivieren
            await using var pragmaCommand = _connection.CreateCommand();
            pragmaCommand.CommandText = @"
                PRAGMA foreign_keys = ON;
                PRAGMA journal_mode = WAL;
                PRAGMA busy_timeout = 5000;";
            await pragmaCommand.ExecuteNonQueryAsync();

            return _connection;
        }
        catch (Exception ex)
        {
            var logService = new FileLogService("sqlite_error.log");
            logService.WriteToLog($"SQLite-Verbindungsfehler: {ex}", "SqliteConnectionError");
            return null;
        }
    }

    /// <summary>
    /// Schließt die aktuelle SQLite-Verbindung, falls geöffnet.
    /// </summary>
    public async Task CloseConnectionAsync()
    {
        if (_connection != null && _connection.State == System.Data.ConnectionState.Open)
        {
            await _connection.CloseAsync();
        }
    }

    /// <summary>
    /// Synchrones Schließen und Freigeben der Ressourcen.
    /// </summary>
    public void Dispose()
    {
        if (_connection != null)
        {
            if (_connection.State == System.Data.ConnectionState.Open)
            {
                _connection.Close();
            }
            _connection.Dispose();
        }
        GC.SuppressFinalize(this);
    }

    /// <summary>
    /// Gibt Ressourcen der Verbindung ordnungsgemäß asynchron frei.
    /// </summary>
    public async ValueTask DisposeAsync()
    {
        if (_connection != null)
        {
            if (_connection.State == System.Data.ConnectionState.Open)
            {
                await _connection.CloseAsync();
            }
            await _connection.DisposeAsync();
        }
        GC.SuppressFinalize(this);
    }
}
