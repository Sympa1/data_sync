namespace data_sync.API.DTOs;

/// <summary>
/// Registrierungs-Anfrage eines neuen Benutzers.
/// </summary>
public class RegisterRequestDto
{
    public required string Username { get; set; }
    public required string Password { get; set; }
}

/// <summary>
/// Login-Anfrage mit Benutzername und Passwort.
/// </summary>
public class LoginRequestDto
{
    public required string Username { get; set; }
    public required string Password { get; set; }
}

/// <summary>
/// Erfolgreiche Authentifizierungs-Antwort mit Bearer-Token.
/// </summary>
public class AuthResponseDto
{
    public required string Token { get; set; }
    public DateTime ExpiresAt { get; set; }
    public int UserId { get; set; }
    public required string Username { get; set; }
    public bool IsAdmin { get; set; }
}

/// <summary>
/// Profilinformationen des aktuell angemeldeten Benutzers.
/// </summary>
public class UserProfileDto
{
    public int UserId { get; set; }
    public required string Username { get; set; }
    public bool IsAdmin { get; set; }
    public DateTime CreatedAt { get; set; }
}
