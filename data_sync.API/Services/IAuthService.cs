using data_sync.API.DTOs;

namespace data_sync.API.Services;

/// <summary>
/// Schnittstelle für Benutzerregistrierung, Authentifizierung und Tokenverwaltung.
/// </summary>
public interface IAuthService
{
    /// <summary>
    /// Registriert einen neuen Benutzer mit PBKDF2-gehashtem Passwort.
    /// </summary>
    Task<(bool Success, string? ErrorMessage, AuthResponseDto? Response)> RegisterAsync(string username, string password);

    /// <summary>
    /// Authentifiziert einen Benutzer und generiert ein kryptografisches Bearer-Token.
    /// </summary>
    Task<(bool Success, string? ErrorMessage, AuthResponseDto? Response)> LoginAsync(string username, string password);

    /// <summary>
    /// Ruft das Benutzerprofil anhand der User-ID ab.
    /// </summary>
    Task<UserProfileDto?> GetUserProfileAsync(int userId);

    /// <summary>
    /// Validiert ein Bearer-Token gegen die SQLite-Datenbank.
    /// </summary>
    Task<(bool Valid, int UserId, string Username, bool IsAdmin)> ValidateTokenAsync(string token);

    /// <summary>
    /// Widerruft ein aktives Bearer-Token (Logout).
    /// </summary>
    Task<bool> RevokeTokenAsync(string token);
}
