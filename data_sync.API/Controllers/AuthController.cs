using System.Security.Claims;
using data_sync.API.DTOs;
using data_sync.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace data_sync.API.Controllers;

/// <summary>
/// REST-Controller für Authentifizierung, Registrierung und Benutzersitzungen.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;

    public AuthController(IAuthService authService)
    {
        _authService = authService;
    }

    /// <summary>
    /// Registriert einen neuen Benutzer und liefert bei Erfolg direkt ein Bearer-Token zurück.
    /// </summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequestDto request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new { message = "Benutzername und Passwort sind erforderlich." });
        }

        var (success, errorMessage, response) = await _authService.RegisterAsync(request.Username, request.Password);
        if (!success)
        {
            return BadRequest(new { message = errorMessage });
        }

        return Ok(response);
    }

    /// <summary>
    /// Authentifiziert einen Benutzer anhand von Benutzername und Passwort.
    /// </summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequestDto request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new { message = "Benutzername und Passwort sind erforderlich." });
        }

        var (success, errorMessage, response) = await _authService.LoginAsync(request.Username, request.Password);
        if (!success)
        {
            return Unauthorized(new { message = errorMessage });
        }

        return Ok(response);
    }

    /// <summary>
    /// Liefert die Profildaten des aktuell authentifizierten Benutzers.
    /// </summary>
    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> GetCurrentUser()
    {
        var sBuffyUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrEmpty(sBuffyUserId) || !int.TryParse(sBuffyUserId, out int iBuffyUserId))
        {
            return Unauthorized(new { message = "Nicht authentifiziert." });
        }

        var userProfile = await _authService.GetUserProfileAsync(iBuffyUserId);
        if (userProfile == null)
        {
            return NotFound(new { message = "Benutzerprofil nicht gefunden." });
        }

        return Ok(userProfile);
    }

    /// <summary>
    /// Widerruft das aktuell genutzte Bearer-Token (Logout).
    /// </summary>
    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        if (!Request.Headers.TryGetValue("Authorization", out var authHeaderValues))
        {
            return Ok(new { message = "Erfolgreich abgemeldet." });
        }

        string sBuffyAuth = authHeaderValues.ToString();
        if (sBuffyAuth.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            string sBuffyToken = sBuffyAuth["Bearer ".Length..].Trim();
            await _authService.RevokeTokenAsync(sBuffyToken);
        }

        return Ok(new { message = "Erfolgreich abgemeldet." });
    }
}
