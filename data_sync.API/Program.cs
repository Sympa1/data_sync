using System.Net;
using data_sync.API.Authentication;
using data_sync.API.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.HttpOverrides;

static void ConfigureEndpoint(Microsoft.AspNetCore.Server.Kestrel.Core.KestrelServerOptions options, string url, bool useHttps)
{
    var endpointUri = new Uri(url);
    var port = endpointUri.Port;

    void ConfigureListenOptions(Microsoft.AspNetCore.Server.Kestrel.Core.ListenOptions listenOptions)
    {
        if (useHttps)
        {
            listenOptions.UseHttps();
        }
    }

    if (endpointUri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase))
    {
        options.ListenLocalhost(port, ConfigureListenOptions);
        return;
    }

    if (endpointUri.Host is "0.0.0.0" or "::" or "+")
    {
        options.ListenAnyIP(port, ConfigureListenOptions);
        return;
    }

    if (IPAddress.TryParse(endpointUri.Host, out var ipAddress))
    {
        options.Listen(ipAddress, port, ConfigureListenOptions);
        return;
    }

    options.ListenAnyIP(port, ConfigureListenOptions);
}

// .env beim Start laden via EnvLoadeService
EnvLoadeService.LoadDotEnv();

var builder = WebApplication.CreateBuilder(args);
bool enableHttpsEndpoint = builder.Configuration.GetValue("EnableHttpsEndpoint", builder.Environment.IsDevelopment());
bool enableHttpsRedirection = builder.Configuration.GetValue("EnableHttpsRedirection", enableHttpsEndpoint);

builder.WebHost.ConfigureKestrel(options =>
{
    // Deaktiviert die minimale Datenrate für große Datei-Uploads
    options.Limits.MinRequestBodyDataRate = null;

    var httpUrl = builder.Configuration["ServerEndpoints:Http:Url"] ?? "http://0.0.0.0:5000";
    ConfigureEndpoint(options, httpUrl, useHttps: false);

    if (enableHttpsEndpoint)
    {
        var httpsUrl = builder.Configuration["ServerEndpoints:Https:Url"];
        if (!string.IsNullOrWhiteSpace(httpsUrl))
        {
            ConfigureEndpoint(options, httpsUrl, useHttps: true);
        }
    }
});

// JSON-Deserialisierung mit PascalCase konfigurieren
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = null;
    });

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    // Forwarded Headers von Caddy / Reverse-Proxy akzeptieren
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

// SQLite- und Geschäftslogik-Services registrieren (Scoped)
builder.Services.AddScoped<SqliteService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<GetFilesToSyncService>();
builder.Services.AddScoped<UpdateMetadataService>();
builder.Services.AddScoped<SyncStateService>();

// Schlanke Bearer-Token-Authentifizierung über SQLite konfigurieren (ohne externe JWT-Bibliothek)
builder.Services.AddAuthentication("BearerToken")
    .AddScheme<AuthenticationSchemeOptions, TokenAuthenticationHandler>("BearerToken", null);

builder.Services.AddAuthorization();

var app = builder.Build();

// SQLite-Startup-Checks und automatische Schema-Initialisierung durchführen
FileLogService log = new FileLogService("sqlite_startup.log");
try
{
    await using var scope = app.Services.CreateAsyncScope();
    var sqliteService = scope.ServiceProvider.GetRequiredService<SqliteService>();

    await using var dbStartup = new DbStartupCheckService(sqliteService);
    await dbStartup.CheckDatabaseConnectionAsync();
    await dbStartup.CheckDatabaseTablesAsync();
}
catch (Exception ex)
{
    log.WriteToLog($"SQLite-Startup-Fehler: {ex}", "DBStartup");
    Console.WriteLine($"SQLite-Startup-Fehler: {ex.Message}");
}

// Reverse-Proxy Header verarbeiten
app.UseForwardedHeaders();

if (enableHttpsRedirection)
{
    app.UseHttpsRedirection();
}

// Authentifizierung VOR Autorisierung ausführen
app.UseAuthentication();
app.UseAuthorization();

// Wenn Argument --test übergeben wurde, führe die Test-Suite aus und beende
if (args.Contains("--test"))
{
    int testExitCode = await data_sync.API.Tests.ApiTestSuite.RunAllTestsAsync(app.Services);
    Environment.Exit(testExitCode);
}

app.Run();
