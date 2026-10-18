using System.Security.Cryptography;
using System.Text;
using data_sync.API.DTOs;
using Microsoft.Data.Sqlite;

namespace data_sync.API.Services;

/// <summary>
/// Implementiert Benutzerverwaltung und schlanke Bearer-Token-Authentifizierung über SQLite.
/// Verwendet PBKDF2-SHA256 für Passwörter und SHA-256 für Token-Hashes (reine .NET BCL).
/// </summary>
public class AuthService : IAuthService
{
    private readonly SqliteService _sqliteService;
    private const int Pbkdf2Iterations = 100000;
    private const int SaltByteSize = 16;
    private const int HashByteSize = 32;
    private const int TokenValidityDays = 30;

    public AuthService(SqliteService sqliteService)
    {
        _sqliteService = sqliteService;
    }

    /// <summary>
    /// Erzeugt ein Salt und berechnet den PBKDF2-Hash für ein Klartext-Passwort.
    /// </summary>
    private static (string sBuffySalt, string sBuffyHash) HashPassword(string sBuffyPlainPassword)
    {
        byte[] saltBytes = RandomNumberGenerator.GetBytes(SaltByteSize);
        byte[] hashBytes = Rfc2898DeriveBytes.Pbkdf2(
            sBuffyPlainPassword,
            saltBytes,
            Pbkdf2Iterations,
            HashAlgorithmName.SHA256,
            HashByteSize);

        string sBuffySalt = Convert.ToBase64String(saltBytes);
        string sBuffyHash = Convert.ToBase64String(hashBytes);
        return (sBuffySalt, sBuffyHash);
    }

    /// <summary>
    /// Verifiziert ein eingegebenes Passwort gegen Salt und Hash mit konstantem Zeitvergleich.
    /// </summary>
    private static bool VerifyPassword(string sBuffyPlainPassword, string sBuffySalt, string sBuffyExpectedHash)
    {
        byte[] saltBytes = Convert.FromBase64String(sBuffySalt);
        byte[] expectedHashBytes = Convert.FromBase64String(sBuffyExpectedHash);

        byte[] actualHashBytes = Rfc2898DeriveBytes.Pbkdf2(
            sBuffyPlainPassword,
            saltBytes,
            Pbkdf2Iterations,
            HashAlgorithmName.SHA256,
            HashByteSize);

        return CryptographicOperations.FixedTimeEquals(actualHashBytes, expectedHashBytes);
    }

    /// <summary>
    /// Berechnet den SHA-256 Hash eines Roh-Tokens zur sicheren Speicherung in der Datenbank.
    /// </summary>
    private static string HashToken(string sBuffyRawToken)
    {
        byte[] tokenBytes = Encoding.UTF8.GetBytes(sBuffyRawToken);
        byte[] hashBytes = SHA256.HashData(tokenBytes);
        return Convert.ToHexStringLower(hashBytes);
    }

    /// <summary>
    /// Generiert ein neues kryptografisch sicheres Bearer-Token und speichert dessen Hash in SQLite.
    /// </summary>
    private async Task<AuthResponseDto> CreateSessionTokenAsync(SqliteConnection connection, int iBuffyUserId, string sBuffyUsername, bool bIsAdmin)
    {
        byte[] tokenRandomBytes = RandomNumberGenerator.GetBytes(32);
        string sBuffyRawToken = Convert.ToHexStringLower(tokenRandomBytes);
        string sBuffyTokenHash = HashToken(sBuffyRawToken);
        DateTime expiresAt = DateTime.UtcNow.AddDays(TokenValidityDays);

        await using var cmd = connection.CreateCommand();
        cmd.CommandText = @"
            INSERT INTO UserTokens (user_id, token_hash, created_at, expires_at, revoked)
            VALUES (@userId, @tokenHash, CURRENT_TIMESTAMP, @expiresAt, 0);";

        cmd.Parameters.AddWithValue("@userId", iBuffyUserId);
        cmd.Parameters.AddWithValue("@tokenHash", sBuffyTokenHash);
        cmd.Parameters.AddWithValue("@expiresAt", expiresAt.ToString("yyyy-MM-dd HH:mm:ss"));

        await cmd.ExecuteNonQueryAsync();

        return new AuthResponseDto
        {
            Token = sBuffyRawToken,
            ExpiresAt = expiresAt,
            UserId = iBuffyUserId,
            Username = sBuffyUsername,
            IsAdmin = bIsAdmin
        };
    }

    /// <summary>
    /// Registriert einen neuen Benutzer. Der erste Benutzer im System wird automatisch zum Administrator.
    /// </summary>
    public async Task<(bool Success, string? ErrorMessage, AuthResponseDto? Response)> RegisterAsync(string username, string password)
    {
        string sBuffyTrimmedUser = username.Trim();
        if (sBuffyTrimmedUser.Length < 3)
        {
            return (false, "Der Benutzername muss mindestens 3 Zeichen lang sein.", null);
        }

        if (string.IsNullOrWhiteSpace(password) || password.Length < 6)
        {
            return (false, "Das Passwort muss mindestens 6 Zeichen lang sein.", null);
        }

        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            return (false, "Datenbankverbindung nicht verfügbar.", null);
        }

        // Prüfen, ob bereits Benutzer existieren (erster Benutzer = Admin)
        await using var countCmd = connection.CreateCommand();
        countCmd.CommandText = "SELECT COUNT(*) FROM Users;";
        long lUserCount = (long)(await countCmd.ExecuteScalarAsync() ?? 0L);
        int iBuffyIsAdmin = lUserCount == 0 ? 1 : 0;

        // Prüfen, ob Benutzername bereits vergeben ist
        await using var checkCmd = connection.CreateCommand();
        checkCmd.CommandText = "SELECT COUNT(*) FROM Users WHERE username = @username COLLATE NOCASE;";
        checkCmd.Parameters.AddWithValue("@username", sBuffyTrimmedUser);
        long lExists = (long)(await checkCmd.ExecuteScalarAsync() ?? 0L);
        if (lExists > 0)
        {
            return (false, "Dieser Benutzername ist bereits vergeben.", null);
        }

        var (sBuffySalt, sBuffyHash) = HashPassword(password);

        // Benutzer einfügen
        await using var insertCmd = connection.CreateCommand();
        insertCmd.CommandText = @"
            INSERT INTO Users (username, password_hash, password_salt, is_admin, created_at)
            VALUES (@username, @passwordHash, @passwordSalt, @isAdmin, CURRENT_TIMESTAMP);
            SELECT last_insert_rowid();";

        insertCmd.Parameters.AddWithValue("@username", sBuffyTrimmedUser);
        insertCmd.Parameters.AddWithValue("@passwordHash", sBuffyHash);
        insertCmd.Parameters.AddWithValue("@passwordSalt", sBuffySalt);
        insertCmd.Parameters.AddWithValue("@isAdmin", iBuffyIsAdmin);

        var insertResult = await insertCmd.ExecuteScalarAsync();
        int iBuffyNewUserId = Convert.ToInt32(insertResult);

        // Session-Token erzeugen
        var authResponse = await CreateSessionTokenAsync(connection, iBuffyNewUserId, sBuffyTrimmedUser, iBuffyIsAdmin == 1);
        return (true, null, authResponse);
    }

    /// <summary>
    /// Authentifiziert Benutzerdaten und stellt bei Erfolg ein neues Token aus.
    /// </summary>
    public async Task<(bool Success, string? ErrorMessage, AuthResponseDto? Response)> LoginAsync(string username, string password)
    {
        string sBuffyTrimmedUser = username.Trim();

        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            return (false, "Datenbankverbindung nicht verfügbar.", null);
        }

        await using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT user_id, password_hash, password_salt, is_admin FROM Users WHERE username = @username COLLATE NOCASE;";
        cmd.Parameters.AddWithValue("@username", sBuffyTrimmedUser);

        int iBuffyUserId = 0;
        string? sBuffyStoredHash = null;
        string? sBuffyStoredSalt = null;
        bool bIsAdmin = false;

        await using (var reader = await cmd.ExecuteReaderAsync())
        {
            if (await reader.ReadAsync())
            {
                iBuffyUserId = reader.GetInt32(0);
                sBuffyStoredHash = reader.GetString(1);
                sBuffyStoredSalt = reader.GetString(2);
                bIsAdmin = reader.GetInt32(3) == 1;
            }
        }

        if (sBuffyStoredHash == null || sBuffyStoredSalt == null)
        {
            return (false, "Ungültiger Benutzername oder Passwort.", null);
        }

        if (!VerifyPassword(password, sBuffyStoredSalt, sBuffyStoredHash))
        {
            return (false, "Ungültiger Benutzername oder Passwort.", null);
        }

        // Letztes Login aktualisieren
        await using var updateLoginCmd = connection.CreateCommand();
        updateLoginCmd.CommandText = "UPDATE Users SET last_login = CURRENT_TIMESTAMP WHERE user_id = @userId;";
        updateLoginCmd.Parameters.AddWithValue("@userId", iBuffyUserId);
        await updateLoginCmd.ExecuteNonQueryAsync();

        var authResponse = await CreateSessionTokenAsync(connection, iBuffyUserId, sBuffyTrimmedUser, bIsAdmin);
        return (true, null, authResponse);
    }

    /// <summary>
    /// Ruft das Profil eines Benutzers anhand der ID ab.
    /// </summary>
    public async Task<UserProfileDto?> GetUserProfileAsync(int userId)
    {
        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null) return null;

        await using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT user_id, username, is_admin, created_at FROM Users WHERE user_id = @userId;";
        cmd.Parameters.AddWithValue("@userId", userId);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return new UserProfileDto
            {
                UserId = reader.GetInt32(0),
                Username = reader.GetString(1),
                IsAdmin = reader.GetInt32(2) == 1,
                CreatedAt = reader.GetDateTime(3)
            };
        }

        return null;
    }

    /// <summary>
    /// Validiert ein übermitteltes Bearer-Token gegen die SQLite-Datenbank.
    /// </summary>
    public async Task<(bool Valid, int UserId, string Username, bool IsAdmin)> ValidateTokenAsync(string token)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            return (false, 0, string.Empty, false);
        }

        string sBuffyTokenHash = HashToken(token.Trim());

        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null)
        {
            return (false, 0, string.Empty, false);
        }

        await using var cmd = connection.CreateCommand();
        cmd.CommandText = @"
            SELECT u.user_id, u.username, u.is_admin, t.expires_at, t.revoked
            FROM UserTokens t
            JOIN Users u ON t.user_id = u.user_id
            WHERE t.token_hash = @tokenHash;";
        cmd.Parameters.AddWithValue("@tokenHash", sBuffyTokenHash);

        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            int iBuffyUserId = reader.GetInt32(0);
            string sBuffyUsername = reader.GetString(1);
            bool bIsAdmin = reader.GetInt32(2) == 1;
            DateTime expiresAt = reader.GetDateTime(3);
            int iBuffyRevoked = reader.GetInt32(4);

            if (iBuffyRevoked == 0 && expiresAt > DateTime.UtcNow)
            {
                return (true, iBuffyUserId, sBuffyUsername, bIsAdmin);
            }
        }

        return (false, 0, string.Empty, false);
    }

    /// <summary>
    /// Widerruft das angegebene Bearer-Token (Logout).
    /// </summary>
    public async Task<bool> RevokeTokenAsync(string token)
    {
        if (string.IsNullOrWhiteSpace(token)) return false;

        string sBuffyTokenHash = HashToken(token.Trim());

        await using var connection = await _sqliteService.OpenConnectionAsync();
        if (connection == null) return false;

        await using var cmd = connection.CreateCommand();
        cmd.CommandText = "UPDATE UserTokens SET revoked = 1 WHERE token_hash = @tokenHash;";
        cmd.Parameters.AddWithValue("@tokenHash", sBuffyTokenHash);

        int iBuffyRowsAffected = await cmd.ExecuteNonQueryAsync();
        return iBuffyRowsAffected > 0;
    }
}
