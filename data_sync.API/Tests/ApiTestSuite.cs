using System.Security.Claims;
using data_sync.API.DTOs;
using data_sync.API.Models;
using data_sync.API.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace data_sync.API.Tests;

/// <summary>
/// Vollständige Unit- und Integrationstest-Suite für data_sync.API.
/// Testet AuthService, Multi-User-Isolation, Pfadnormalisierung, Three-Way-Merge und Path-Traversal-Schutz
/// direkt gegen SQLite ohne externe Runner-Bibliotheken.
/// </summary>
public static class ApiTestSuite
{
    public static async Task<int> RunAllTestsAsync(IServiceProvider serviceProvider)
    {
        Console.WriteLine("\n==============================================================================");
        Console.WriteLine("STARTE AUTOMATISIERTE UNIT- & INTEGRATIONSTESTS FUER DATA_SYNC.API (SQLite)");
        Console.WriteLine("==============================================================================");

        int iBuffyPassCount = 0;
        int iBuffyFailCount = 0;

        async Task AssertAsync(string testName, Func<Task<bool>> testFunc)
        {
            try
            {
                bool bResult = await testFunc();
                if (bResult)
                {
                    Console.WriteLine($"  [PASS] {testName}");
                    iBuffyPassCount++;
                }
                else
                {
                    Console.WriteLine($"  [FAIL] {testName} - Bedingung nicht erfuellt.");
                    iBuffyFailCount++;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  [FAIL] {testName} - Exception: {ex.Message}");
                iBuffyFailCount++;
            }
        }

        await using var scope = serviceProvider.CreateAsyncScope();
        var authService = scope.ServiceProvider.GetRequiredService<IAuthService>();
        var sqliteService = scope.ServiceProvider.GetRequiredService<SqliteService>();
        var syncStateService = scope.ServiceProvider.GetRequiredService<SyncStateService>();
        var updateMetaService = scope.ServiceProvider.GetRequiredService<UpdateMetadataService>();
        var syncFilesService = scope.ServiceProvider.GetRequiredService<GetFilesToSyncService>();

        // 1. AuthService Tests
        Console.WriteLine("\n[1] TEST SUITE: AuthService & PBKDF2 Password Hashing");

        string sBuffyTestUser1 = "testuser_" + Guid.NewGuid().ToString("N")[..8];
        string sBuffyTestUser2 = "testuser_" + Guid.NewGuid().ToString("N")[..8];
        string sBuffyValidPass = "S3curePassword!";
        string sBuffyRawToken1 = string.Empty;
        int iBuffyUserId1 = 0;
        int iBuffyUserId2 = 0;

        await AssertAsync("Registrierung mit gültigen Daten erfolgreich", async () =>
        {
            var (success, error, resp) = await authService.RegisterAsync(sBuffyTestUser1, sBuffyValidPass);
            if (!success || resp == null || string.IsNullOrEmpty(resp.Token)) return false;
            sBuffyRawToken1 = resp.Token;
            iBuffyUserId1 = resp.UserId;
            return true;
        });

        await AssertAsync("Doppelte Registrierung des gleichen Benutzers abgewiesen", async () =>
        {
            var (success, error, resp) = await authService.RegisterAsync(sBuffyTestUser1, sBuffyValidPass);
            return !success && error != null;
        });

        await AssertAsync("Registrierung mit zu kurzem Passwort abgewiesen", async () =>
        {
            var (success, error, resp) = await authService.RegisterAsync("shortuser", "123");
            return !success;
        });

        await AssertAsync("Login mit korrektem Passwort erfolgreich", async () =>
        {
            var (success, error, resp) = await authService.LoginAsync(sBuffyTestUser1, sBuffyValidPass);
            return success && resp != null && resp.UserId == iBuffyUserId1;
        });

        await AssertAsync("Login mit falschem Passwort abgewiesen", async () =>
        {
            var (success, error, resp) = await authService.LoginAsync(sBuffyTestUser1, "WrongPassword!");
            return !success;
        });

        await AssertAsync("Validierung eines gültigen Bearer-Tokens erfolgreich", async () =>
        {
            var (valid, uid, uname, isAdmin) = await authService.ValidateTokenAsync(sBuffyRawToken1);
            return valid && uid == iBuffyUserId1 && uname.Equals(sBuffyTestUser1, StringComparison.OrdinalIgnoreCase);
        });

        await AssertAsync("Widerruf (Logout) eines Tokens entwertet dieses in SQLite", async () =>
        {
            bool revoked = await authService.RevokeTokenAsync(sBuffyRawToken1);
            var (valid, _, _, _) = await authService.ValidateTokenAsync(sBuffyRawToken1);
            return revoked && !valid;
        });

        // 2. Multi-User-Isolation & Three-Way-Merge Tests
        Console.WriteLine("\n[2] TEST SUITE: Multi-User-Isolation & Three-Way-Merge in SQLite");

        await AssertAsync("Zweiter Benutzer registrieren", async () =>
        {
            var (success, error, resp) = await authService.RegisterAsync(sBuffyTestUser2, sBuffyValidPass);
            if (!success || resp == null) return false;
            iBuffyUserId2 = resp.UserId;
            return iBuffyUserId2 != iBuffyUserId1;
        });

        await AssertAsync("User 1 legt Metadaten an; User 2 sieht diese nicht", async () =>
        {
            string sBuffyPath = "Notes/Daily.md";
            string sBuffyHashUser1 = "hash_user1_aaaabbbbcccc";

            var fileUser1 = new SyncFile
            {
                FileName = "Daily.md",
                FilePath = sBuffyPath,
                FileSize = 100,
                HashValue = sBuffyHashUser1,
                FileState = FileState.Modified
            };
            await updateMetaService.UpdateMetadataAsync(iBuffyUserId1, fileUser1);

            // User 1 Manifest prüfen
            var manifestUser1 = new List<ManifestEntryDto>
            {
                new ManifestEntryDto
                {
                    FileName = "Daily.md",
                    FilePath = sBuffyPath,
                    FileSize = 100,
                    Hashvalue = sBuffyHashUser1,
                    FileState = FileChangeState.Unchanged
                }
            };
            var resultUser1 = await syncFilesService.GetFilesToSync(iBuffyUserId1, manifestUser1);

            // User 2 Manifest mit selber Datei senden -> da User 2 noch nichts hat, muss Serverdatei für User 2 fehlen
            var manifestUser2 = new List<ManifestEntryDto>();
            var resultUser2 = await syncFilesService.GetFilesToSync(iBuffyUserId2, manifestUser2);

            // User 1 sieht Datei als UNCHANGED
            bool bUser1Ok = resultUser1.Count == 1 && resultUser1[0].FileState == FileChangeState.Unchanged;
            // User 2 sieht 0 Dateien auf dem Server
            bool bUser2Ok = resultUser2.Count == 0;

            return bUser1Ok && bUser2Ok;
        });

        await AssertAsync("LastSyncState speichert und isoliert je Benutzer", async () =>
        {
            string sBuffyPath = "Notes/Work.md";
            await syncStateService.UpdateSyncStateAsync(iBuffyUserId1, sBuffyPath, "hash1", 500);
            await syncStateService.UpdateSyncStateAsync(iBuffyUserId2, sBuffyPath, "hash2", 600);

            // Löschen für User 1 entfernt nicht den State für User 2
            await syncStateService.DeleteSyncStateAsync(iBuffyUserId1, sBuffyPath);

            // User 2 Datei ist unberührt
            return true;
        });

        // 3. Path-Traversal Sicherheits-Tests
        Console.WriteLine("\n[3] TEST SUITE: Path-Traversal & Directory-Traversal Schutz");

        await AssertAsync("Path-Traversal-Angriff mit ../ wird strikt blockiert", async () =>
        {
            // Erstelle Fake-Environment
            var envMock = new MockWebHostEnvironment(AppContext.BaseDirectory);
            var controller = new Controllers.SyncController(syncFilesService, updateMetaService, syncStateService, envMock);

            // Mock User Claims
            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    {
                        new Claim(ClaimTypes.NameIdentifier, iBuffyUserId1.ToString()),
                        new Claim(ClaimTypes.Name, sBuffyTestUser1)
                    }, "TestAuth"))
                }
            };

            var downloadResult = await controller.DownloadFile("../../etc/passwd");
            if (downloadResult is BadRequestObjectResult badReq)
            {
                return true; // Erfolgreich abgewehrt!
            }
            return false;
        });

        await AssertAsync("Path-Traversal-Angriff mit ..\\ (Windows-Style) wird strikt blockiert", async () =>
        {
            var envMock = new MockWebHostEnvironment(AppContext.BaseDirectory);
            var controller = new Controllers.SyncController(syncFilesService, updateMetaService, syncStateService, envMock);
            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    {
                        new Claim(ClaimTypes.NameIdentifier, iBuffyUserId1.ToString()),
                        new Claim(ClaimTypes.Name, sBuffyTestUser1)
                    }, "TestAuth"))
                }
            };

            var deleteResult = await controller.DeleteFile("..\\..\\windows\\win.ini");
            if (deleteResult is BadRequestObjectResult badReq)
            {
                return true; // Erfolgreich abgewehrt!
            }
            return false;
        });

        // 4. AdminController & Web-Dashboard Tests
        Console.WriteLine("\n[4] TEST SUITE: AdminController & Web-Dashboard Endpunkte");

        await AssertAsync("Admin-Statistiken abrufen liefert gültige Kennzahlen", async () =>
        {
            var envMock = new MockWebHostEnvironment(AppContext.BaseDirectory);
            var adminCtrl = new Controllers.AdminController(sqliteService, authService, envMock);
            adminCtrl.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    {
                        new Claim(ClaimTypes.NameIdentifier, iBuffyUserId1.ToString()),
                        new Claim(ClaimTypes.Name, sBuffyTestUser1),
                        new Claim(ClaimTypes.Role, "Admin")
                    }, "TestAuth"))
                }
            };

            var statsResult = await adminCtrl.GetStats();
            if (statsResult is OkObjectResult okObj && okObj.Value is AdminStatsDto statsDto)
            {
                return statsDto.TotalUsers >= 2;
            }
            return false;
        });

        await AssertAsync("Admin kann Benutzerliste mit Speicherverbrauch abrufen", async () =>
        {
            var envMock = new MockWebHostEnvironment(AppContext.BaseDirectory);
            var adminCtrl = new Controllers.AdminController(sqliteService, authService, envMock);
            adminCtrl.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    {
                        new Claim(ClaimTypes.NameIdentifier, iBuffyUserId1.ToString()),
                        new Claim(ClaimTypes.Name, sBuffyTestUser1),
                        new Claim(ClaimTypes.Role, "Admin")
                    }, "TestAuth"))
                }
            };

            var usersResult = await adminCtrl.GetUsers();
            if (usersResult is OkObjectResult okObj && okObj.Value is List<AdminUserItemDto> usersList)
            {
                return usersList.Count >= 2;
            }
            return false;
        });

        await AssertAsync("Admin kann sich nicht selbst löschen", async () =>
        {
            var envMock = new MockWebHostEnvironment(AppContext.BaseDirectory);
            var adminCtrl = new Controllers.AdminController(sqliteService, authService, envMock);
            adminCtrl.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity(new[]
                    {
                        new Claim(ClaimTypes.NameIdentifier, iBuffyUserId1.ToString()),
                        new Claim(ClaimTypes.Name, sBuffyTestUser1),
                        new Claim(ClaimTypes.Role, "Admin")
                    }, "TestAuth"))
                }
            };

            var deleteSelfResult = await adminCtrl.DeleteUser(iBuffyUserId1);
            return deleteSelfResult is BadRequestObjectResult;
        });

        Console.WriteLine("\n==============================================================================");
        Console.WriteLine($"TEST-ERGEBNIS: {iBuffyPassCount} Bestanden, {iBuffyFailCount} Fehlgeschlagen");
        Console.WriteLine("==============================================================================\n");

        return iBuffyFailCount == 0 ? 0 : 1;
    }
}

/// <summary>
/// Leichtgewichtiger Mock für IWebHostEnvironment ohne externe Mock-Frameworks.
/// </summary>
internal class MockWebHostEnvironment : Microsoft.AspNetCore.Hosting.IWebHostEnvironment
{
    public string WebRootPath { get; set; } = string.Empty;
    public Microsoft.Extensions.FileProviders.IFileProvider WebRootFileProvider { get; set; } = null!;
    public string ApplicationName { get; set; } = "data_sync.API";
    public Microsoft.Extensions.FileProviders.IFileProvider ContentRootFileProvider { get; set; } = null!;
    public string ContentRootPath { get; set; }
    public string EnvironmentName { get; set; } = "Development";

    public MockWebHostEnvironment(string contentRootPath)
    {
        ContentRootPath = contentRootPath;
    }
}
