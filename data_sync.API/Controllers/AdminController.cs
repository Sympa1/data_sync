using System.Security.Claims;
using data_sync.API.DTOs;
using data_sync.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace data_sync.API.Controllers;

/// <summary>
/// REST-Controller für administrative Aufgaben und das Web-Dashboard.
/// Zugriff ist auf Benutzer mit der Rolle 'Admin' beschränkt.
/// </summary>
[Authorize(Roles = "Admin")]
[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly SqliteService _sqliteService;
    private readonly IAuthService _authService;
    private readonly IWebHostEnvironment _environment;

    public AdminController(
        SqliteService sqliteService,
        IAuthService authService,
        IWebHostEnvironment environment)
    {
        _sqliteService = sqliteService;
        _authService = authService;
        _environment = environment;
    }

    /// <summary>
    /// Ruft zusammenfassende Statistiken des Systems ab (Benutzer, Dateien, Speicherplatz, DB-Größe).
    /// </summary>
    [HttpGet("stats")]
    public async Task<IActionResult> GetStats()
    {
        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            return StatusCode(500, new { message = "Datenbankverbindung nicht verfügbar." });
        }

        int iBuffyTotalUsers = 0;
        int iBuffyTotalFiles = 0;
        long lTotalStorageBytes = 0;

        // 1. Benutzeranzahl
        await using (var cmd = connection.CreateCommand())
        {
            cmd.CommandText = "SELECT COUNT(*) FROM Users;";
            iBuffyTotalUsers = Convert.ToInt32(await cmd.ExecuteScalarAsync() ?? 0);
        }

        // 2. Aktive Dateien und Speicherbedarf
        await using (var cmd = connection.CreateCommand())
        {
            cmd.CommandText = @"
                SELECT COUNT(*), COALESCE(SUM(file_size), 0) 
                FROM SyncFiles 
                WHERE file_state != 'Deleted';";
            await using var reader = await cmd.ExecuteReaderAsync();
            if (await reader.ReadAsync())
            {
                iBuffyTotalFiles = reader.GetInt32(0);
                lTotalStorageBytes = reader.GetInt64(1);
            }
        }

        // 3. SQLite Datenbank-Dateigröße ermitteln
        long lDbSizeBytes = 0;
        var sBuffyDbPath = Environment.GetEnvironmentVariable("DB_PATH");
        if (string.IsNullOrWhiteSpace(sBuffyDbPath))
        {
            sBuffyDbPath = Path.Combine(AppContext.BaseDirectory, "data", "data_sync.db");
        }
        if (System.IO.File.Exists(sBuffyDbPath))
        {
            lDbSizeBytes = new FileInfo(sBuffyDbPath).Length;
        }

        var stats = new AdminStatsDto
        {
            TotalUsers = iBuffyTotalUsers,
            TotalFiles = iBuffyTotalFiles,
            TotalStorageBytes = lTotalStorageBytes,
            DatabaseSizeBytes = lDbSizeBytes,
            ServerTime = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
        };

        return Ok(stats);
    }

    /// <summary>
    /// Listet alle Benutzer mit Speicherverbrauch und Datei-Anzahl auf.
    /// </summary>
    [HttpGet("users")]
    public async Task<IActionResult> GetUsers()
    {
        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            return StatusCode(500, new { message = "Datenbankverbindung nicht verfügbar." });
        }

        var userList = new List<AdminUserItemDto>();

        await using var cmd = connection.CreateCommand();
        cmd.CommandText = @"
            SELECT 
                u.user_id,
                u.username,
                u.is_admin,
                u.created_at,
                u.last_login,
                COUNT(CASE WHEN f.file_state != 'Deleted' THEN 1 END) as file_count,
                COALESCE(SUM(CASE WHEN f.file_state != 'Deleted' THEN f.file_size ELSE 0 END), 0) as storage_bytes
            FROM Users u
            LEFT JOIN SyncFiles f ON u.user_id = f.user_id
            GROUP BY u.user_id
            ORDER BY u.user_id ASC;";

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            int iBuffyUid = reader.GetInt32(0);
            string sBuffyUname = reader.GetString(1);
            bool bIsAdmin = reader.GetInt32(2) == 1;
            DateTime createdAt = reader.GetDateTime(3);
            DateTime? lastLogin = reader.IsDBNull(4) ? null : reader.GetDateTime(4);
            int iBuffyFiles = reader.GetInt32(5);
            long lStorage = reader.GetInt64(6);

            userList.Add(new AdminUserItemDto
            {
                UserId = iBuffyUid,
                Username = sBuffyUname,
                IsAdmin = bIsAdmin,
                CreatedAt = createdAt,
                LastLogin = lastLogin,
                FileCount = iBuffyFiles,
                StorageBytes = lStorage
            });
        }

        return Ok(userList);
    }

    /// <summary>
    /// Erstellt einen neuen Benutzer durch den Administrator.
    /// </summary>
    [HttpPost("users")]
    public async Task<IActionResult> CreateUser([FromBody] AdminCreateUserDto request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new { message = "Benutzername und Passwort sind erforderlich." });
        }

        var (success, errorMessage, response) = await _authService.RegisterAsync(request.Username, request.Password);
        if (!success || response == null)
        {
            return BadRequest(new { message = errorMessage });
        }

        // Falls explizit als Admin markiert werden soll (und nicht der allererste Benutzer war)
        if (request.IsAdmin && !response.IsAdmin)
        {
            await using var connection = await _sqliteService.OpenConnectionAsync();
            if (connection != null)
            {
                await using var cmd = connection.CreateCommand();
                cmd.CommandText = "UPDATE Users SET is_admin = 1 WHERE user_id = @userId;";
                cmd.Parameters.AddWithValue("@userId", response.UserId);
                await cmd.ExecuteNonQueryAsync();
            }
        }

        return Ok(new { message = $"Benutzer '{request.Username}' erfolgreich angelegt.", userId = response.UserId });
    }

    /// <summary>
    /// Löscht einen Benutzer mitsamt seinen synchronisierten Dateien und Datenbankeinträgen.
    /// Der angemeldete Administrator kann sich nicht selbst löschen.
    /// </summary>
    [HttpDelete("users/{userId}")]
    public async Task<IActionResult> DeleteUser(int userId)
    {
        var sBuffyCurrentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (int.TryParse(sBuffyCurrentUserId, out int iBuffyCurrentUid) && iBuffyCurrentUid == userId)
        {
            return BadRequest(new { message = "Sie können Ihr eigenes Administratorkonto nicht löschen." });
        }

        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            return StatusCode(500, new { message = "Datenbankverbindung nicht verfügbar." });
        }

        // Benutzer aus SQLite löschen (ON DELETE CASCADE löscht UserTokens, SyncFiles, LastSyncState etc.)
        await using (var cmd = connection.CreateCommand())
        {
            cmd.CommandText = "DELETE FROM Users WHERE user_id = @userId;";
            cmd.Parameters.AddWithValue("@userId", userId);
            int iBuffyDeleted = await cmd.ExecuteNonQueryAsync();

            if (iBuffyDeleted == 0)
            {
                return NotFound(new { message = "Benutzer wurde nicht gefunden." });
            }
        }

        // Verzeichnis des Benutzers auf der Festplatte löschen
        string sBuffyUserDir = Path.GetFullPath(Path.Combine(_environment.ContentRootPath, "uploads", userId.ToString()));
        if (Directory.Exists(sBuffyUserDir))
        {
            try
            {
                Directory.Delete(sBuffyUserDir, recursive: true);
            }
            catch (Exception ex)
            {
                // Fehler protokollieren, aber Vorgang fortsetzen
                Console.WriteLine($"Konnte Benutzerverzeichnis nicht vollständig löschen: {ex.Message}");
            }
        }

        return Ok(new { message = $"Benutzer ID {userId} und alle zugehörigen Daten wurden gelöscht." });
    }

    /// <summary>
    /// Listet synchronisierte Dateien über alle Benutzer oder gefiltert nach Benutzer auf.
    /// </summary>
    [HttpGet("files")]
    public async Task<IActionResult> GetFiles([FromQuery] int? userId = null)
    {
        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            return StatusCode(500, new { message = "Datenbankverbindung nicht verfügbar." });
        }

        var fileList = new List<AdminFileItemDto>();

        await using var cmd = connection.CreateCommand();
        string sBuffySql = @"
            SELECT f.sync_file_id, f.user_id, u.username, f.file_name, f.file_path, f.file_size, f.hash_value, f.last_modified, f.file_state
            FROM SyncFiles f
            JOIN Users u ON f.user_id = u.user_id ";

        if (userId.HasValue)
        {
            sBuffySql += "WHERE f.user_id = @userId ";
            cmd.Parameters.AddWithValue("@userId", userId.Value);
        }

        sBuffySql += "ORDER BY f.last_modified DESC LIMIT 100;";
        cmd.CommandText = sBuffySql;

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            fileList.Add(new AdminFileItemDto
            {
                SyncFileId = reader.GetInt32(0),
                UserId = reader.GetInt32(1),
                Username = reader.GetString(2),
                FileName = reader.GetString(3),
                FilePath = reader.GetString(4),
                FileSize = reader.GetInt64(5),
                HashValue = reader.GetString(6),
                LastModified = reader.GetDateTime(7),
                FileState = reader.GetString(8)
            });
        }

        return Ok(fileList);
    }

    /// <summary>
    /// Ruft die jüngsten System- und Fehlerprotokolle ab.
    /// </summary>
    [HttpGet("logs")]
    public async Task<IActionResult> GetLogs()
    {
        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            return StatusCode(500, new { message = "Datenbankverbindung nicht verfügbar." });
        }

        var logs = new List<AdminLogItemDto>();

        await using var cmd = connection.CreateCommand();
        cmd.CommandText = @"
            SELECT p.fehler_protokoll_id, p.user_id, u.username, p.fehler_beschreibung, p.fehler_timestamp
            FROM FehlerProtokoll p
            LEFT JOIN Users u ON p.user_id = u.user_id
            ORDER BY p.fehler_protokoll_id DESC
            LIMIT 50;";

        await using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            logs.Add(new AdminLogItemDto
            {
                Id = reader.GetInt32(0),
                UserId = reader.IsDBNull(1) ? null : reader.GetInt32(1),
                Username = reader.IsDBNull(2) ? null : reader.GetString(2),
                Description = reader.GetString(3),
                Timestamp = reader.GetDateTime(4)
            });
        }

        return Ok(logs);
    }
}
