using System.Security.Claims;
using data_sync.API.DTOs;
using data_sync.API.Models;
using data_sync.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace data_sync.API.Controllers;

/// <summary>
/// REST-Controller für die Datei-Synchronisation.
/// Durch [Authorize] geschützt – jeder Benutzer erhält ein isoliertes Verzeichnis unter uploads/{userId}/.
/// Beinhaltet vollständigen Schutz gegen Path Traversal und Directory Traversal Angriffe.
/// </summary>
[Authorize]
[ApiController]
[Route("api/[controller]")]
public class SyncController : ControllerBase
{
    private readonly GetFilesToSyncService _filesToSyncService;
    private readonly UpdateMetadataService _updateMetadataService;
    private readonly SyncStateService _syncStateService;
    private readonly IWebHostEnvironment _environment;

    public SyncController(
        GetFilesToSyncService filesToSyncService,
        UpdateMetadataService updateMetadataService,
        SyncStateService syncStateService,
        IWebHostEnvironment environment)
    {
        _filesToSyncService = filesToSyncService;
        _updateMetadataService = updateMetadataService;
        _syncStateService = syncStateService;
        _environment = environment;
    }

    /// <summary>
    /// Liest die ID des authentifizierten Benutzers aus dem Token aus.
    /// </summary>
    private int GetCurrentUserId()
    {
        var sBuffyClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(sBuffyClaim) || !int.TryParse(sBuffyClaim, out int iBuffyUserId))
        {
            throw new UnauthorizedAccessException("Ungültiger Benutzerkontext im Token.");
        }
        return iBuffyUserId;
    }

    /// <summary>
    /// Ermittelt den sicheren absoluten Pfad im isolierten Benutzerverzeichnis.
    /// Verhindert Directory/Path Traversal (z.B. '../', '..\\') durch strikte Begrenzungsprüfung.
    /// </summary>
    private string GetSecureUserFilePath(int iBuffyUserId, string sBuffyRelativePath)
    {
        if (string.IsNullOrWhiteSpace(sBuffyRelativePath))
        {
            throw new ArgumentException("Dateipfad darf nicht leer sein.", nameof(sBuffyRelativePath));
        }

        // Pfad normalisieren: Backslashes zu Forward-Slashes, führende Slashes entfernen
        string sBuffyClean = sBuffyRelativePath.Replace('\\', '/').TrimStart('/');

        // Benutzer-Wurzelverzeichnis: uploads/{userId}
        string sBuffyUserDir = Path.GetFullPath(Path.Combine(_environment.ContentRootPath, "uploads", iBuffyUserId.ToString()));

        // Absoluter Zielpfad
        string sBuffyFullPath = Path.GetFullPath(Path.Combine(sBuffyUserDir, sBuffyClean));

        // Sicherheitsprüfung: Zielpfad muss zwingend innerhalb des Benutzerverzeichnisses liegen
        string sBuffyBoundary = sBuffyUserDir.EndsWith(Path.DirectorySeparatorChar)
            ? sBuffyUserDir
            : sBuffyUserDir + Path.DirectorySeparatorChar;

        if (!sBuffyFullPath.StartsWith(sBuffyBoundary, StringComparison.Ordinal))
        {
            throw new UnauthorizedAccessException("Path-Traversal-Angriff erkannt: Zugriff außerhalb des Benutzerverzeichnisses verweigert.");
        }

        return sBuffyFullPath;
    }

    /// <summary>
    /// Gleicht das vom Client gesendete Manifest ab und gibt die Synchronisationsaktionen zurück.
    /// </summary>
    [HttpPost("manifest")]
    public async Task<IActionResult> PostManifestByClient([FromBody] List<ManifestEntryDto> manifests)
    {
        if (manifests == null)
        {
            return BadRequest(new { message = "Manifest fehlt oder ist ungültig." });
        }

        int iBuffyUserId = GetCurrentUserId();
        var filesToSync = await _filesToSyncService.GetFilesToSync(iBuffyUserId, manifests);

        return Ok(filesToSync);
    }

    /// <summary>
    /// Lädt eine Datei in das isolierte Benutzerverzeichnis hoch.
    /// </summary>
    [HttpPost("upload")]
    public async Task<IActionResult> UploadFile(IFormFile file, [FromQuery] string basePath = "")
    {
        if (file == null)
        {
            return BadRequest(new { message = "Keine Datei hochgeladen." });
        }

        if (string.IsNullOrWhiteSpace(file.FileName))
        {
            return BadRequest(new { message = "Dateiname fehlt." });
        }

        int iBuffyUserId = GetCurrentUserId();
        string sBuffySafeFileName = Path.GetFileName(file.FileName);
        string sBuffyRelativeDir = string.IsNullOrWhiteSpace(basePath) ? "" : basePath.TrimStart('/', '\\');
        string sBuffyRelativeFile = string.IsNullOrEmpty(sBuffyRelativeDir)
            ? sBuffySafeFileName
            : Path.Combine(sBuffyRelativeDir, sBuffySafeFileName).Replace('\\', '/');

        string sBuffyFullPath;
        try
        {
            sBuffyFullPath = GetSecureUserFilePath(iBuffyUserId, sBuffyRelativeFile);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }

        // Sicherstellen, dass Zielordner existiert
        var sBuffyTargetDir = Path.GetDirectoryName(sBuffyFullPath);
        if (!string.IsNullOrEmpty(sBuffyTargetDir) && !Directory.Exists(sBuffyTargetDir))
        {
            Directory.CreateDirectory(sBuffyTargetDir);
        }

        // Datei auf Server schreiben
        await using (var stream = System.IO.File.Create(sBuffyFullPath))
        {
            await file.CopyToAsync(stream);
        }

        // Metadaten berechnen
        string sBuffyHash = UtilsService.CalculateFileHash(sBuffyFullPath);
        var fileInfo = new FileInfo(sBuffyFullPath);

        var metaData = new SyncFile
        {
            FileName = sBuffySafeFileName,
            FilePath = sBuffyRelativeFile,
            FileSize = fileInfo.Length,
            HashValue = sBuffyHash,
            FileState = FileState.Modified
        };

        // Metadaten und LastSyncState in SQLite für diesen Benutzer aktualisieren
        await _updateMetadataService.UpdateMetadataAsync(iBuffyUserId, metaData);
        await _syncStateService.UpdateSyncStateAsync(iBuffyUserId, sBuffyRelativeFile, sBuffyHash, fileInfo.Length);

        return Ok(new
        {
            status = "success",
            fileName = sBuffySafeFileName,
            filePath = sBuffyRelativeFile,
            hash = sBuffyHash
        });
    }

    /// <summary>
    /// Lädt eine Datei aus dem isolierten Benutzerverzeichnis herunter.
    /// </summary>
    [HttpGet("download")]
    public async Task<IActionResult> DownloadFile([FromQuery] string filePath)
    {
        if (string.IsNullOrWhiteSpace(filePath))
        {
            return BadRequest(new { message = "Dateipfad ist erforderlich." });
        }

        int iBuffyUserId = GetCurrentUserId();
        string sBuffyFullPath;
        try
        {
            sBuffyFullPath = GetSecureUserFilePath(iBuffyUserId, filePath);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }

        if (!System.IO.File.Exists(sBuffyFullPath))
        {
            return NotFound(new { message = "Datei auf dem Server nicht gefunden." });
        }

        var memory = new MemoryStream();
        await using (var stream = new FileStream(sBuffyFullPath, FileMode.Open, FileAccess.Read))
        {
            await stream.CopyToAsync(memory);
        }
        memory.Position = 0;

        string sBuffyRelative = filePath.TrimStart('/', '\\').Replace('\\', '/');
        string sBuffyHash = UtilsService.CalculateFileHash(sBuffyFullPath);
        var fileInfo = new FileInfo(sBuffyFullPath);

        await _syncStateService.UpdateSyncStateAsync(iBuffyUserId, sBuffyRelative, sBuffyHash, fileInfo.Length);

        return File(memory, "application/octet-stream", Path.GetFileName(sBuffyFullPath));
    }

    /// <summary>
    /// Löscht eine Datei aus dem Speicher und markiert sie in der SQLite-Datenbank als gelöscht.
    /// </summary>
    [HttpDelete("delete")]
    public async Task<IActionResult> DeleteFile([FromQuery] string filePath)
    {
        if (string.IsNullOrWhiteSpace(filePath))
        {
            return BadRequest(new { message = "Dateipfad ist erforderlich." });
        }

        int iBuffyUserId = GetCurrentUserId();
        string sBuffyFullPath;
        try
        {
            sBuffyFullPath = GetSecureUserFilePath(iBuffyUserId, filePath);
        }
        catch (Exception ex)
        {
            return BadRequest(new { message = ex.Message });
        }

        string sBuffyRelative = filePath.TrimStart('/', '\\').Replace('\\', '/');

        if (!System.IO.File.Exists(sBuffyFullPath))
        {
            return NotFound(new { message = "Datei nicht gefunden." });
        }

        try
        {
            System.IO.File.Delete(sBuffyFullPath);

            // LastSyncState bereinigen
            await _syncStateService.DeleteSyncStateAsync(iBuffyUserId, sBuffyRelative);

            // Datei-Status auf 'Deleted' setzen, damit andere Clients die Löschung synchronisieren
            var deletedFile = new SyncFile
            {
                FileName = Path.GetFileName(sBuffyRelative),
                FilePath = sBuffyRelative,
                FileSize = 0,
                HashValue = string.Empty,
                FileState = FileState.Deleted
            };
            await _updateMetadataService.UpdateMetadataAsync(iBuffyUserId, deletedFile);

            return Ok(new { status = "success", message = "Datei erfolgreich gelöscht." });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = $"Fehler beim Löschen der Datei: {ex.Message}" });
        }
    }
}
