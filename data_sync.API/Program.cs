using data_sync.API.Services;

var builder = WebApplication.CreateBuilder(args);

// .env einmalig beim Start laden
DotNetEnv.Env.Load();

// Add services to the container.
builder.Services.AddControllers();

// Registriere GetFilesToSyncService als Scoped (mit automatischem Dispose)
builder.Services.AddScoped<GetFilesToSyncService>();


var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();