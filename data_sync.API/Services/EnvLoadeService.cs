using DotNetEnv; // --> NuGet-Paket DotNetEnv

namespace data_sync.API.Services;

public class EnvLoadeService
{
    public static void LoadDotEnv()
    {
        // Aktuelles Arbeitsverzeichnis
        string currentDir = Environment.CurrentDirectory;

        // Projektstammverzeichnis suchen (ein oder zwei Ebenen nach oben)
        string projectDir = Path.GetFullPath(Path.Combine(currentDir, "..", "..", ".."));

        string envPath = Path.Combine(projectDir, ".env");

        if (File.Exists(envPath))
        {
            Env.Load(envPath);
            Console.WriteLine($".env geladen aus: {envPath}");
        }
        else
        {
            Console.WriteLine(".env-Datei nicht gefunden im Projektstammverzeichnis!");
        }
    }
}