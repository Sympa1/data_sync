using System.Security.Claims;
using System.Text.Encodings.Web;
using data_sync.API.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace data_sync.API.Authentication;

/// <summary>
/// Eigener ASP.NET Core Authentication Handler für Bearer-Tokens.
/// Liest das Token aus dem Authorization-Header und validiert es über den IAuthService in SQLite.
/// </summary>
public class TokenAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    private readonly IAuthService _authService;

    public TokenAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder,
        IAuthService authService)
        : base(options, logger, encoder)
    {
        _authService = authService;
    }

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        // Authorization-Header auslesen
        if (!Request.Headers.TryGetValue("Authorization", out var authHeaderValues))
        {
            return AuthenticateResult.NoResult();
        }

        string sBuffyAuthHeader = authHeaderValues.ToString();
        if (string.IsNullOrWhiteSpace(sBuffyAuthHeader) || !sBuffyAuthHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            return AuthenticateResult.NoResult();
        }

        // Bearer-Präfix abschneiden
        string sBuffyToken = sBuffyAuthHeader["Bearer ".Length..].Trim();
        if (string.IsNullOrWhiteSpace(sBuffyToken))
        {
            return AuthenticateResult.Fail("Ungültiges Token-Format.");
        }

        var (isValid, iBuffyUserId, sBuffyUsername, bIsAdmin) = await _authService.ValidateTokenAsync(sBuffyToken);
        if (!isValid)
        {
            return AuthenticateResult.Fail("Token ist ungültig oder abgelaufen.");
        }

        // Benutzeridentität für ASP.NET Core ClaimsPrincipal aufbauen
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, iBuffyUserId.ToString()),
            new Claim(ClaimTypes.Name, sBuffyUsername),
            new Claim(ClaimTypes.Role, bIsAdmin ? "Admin" : "User")
        };

        var identity = new ClaimsIdentity(claims, Scheme.Name);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, Scheme.Name);

        return AuthenticateResult.Success(ticket);
    }
}
