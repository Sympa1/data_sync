using System;
using System.IO;

namespace data_sync.API.Services;

/// <summary>
/// Diese Klasse dient zum Schreiben von Logfiles.
/// </summary>
public class FileLogService
{
    private string _LogFilePath;
    
    /// <summary>
    /// Die Konstruktor-Methode nimmt den Namen des Logfiles als Parameter entgehen.
    /// </summary>
    /// <param name="logFileName"></param>
    public FileLogService(string logFileName = "error.log")
    {
        // Platziert das Logfile im Stammverzeichnis des Projekts ../bin/Debug/netX.X/
        //this._LogFilePath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, logFileName);
        
        // Aktuelles Arbeitsverzeichnis --> ../bin/Debug/netX.X/
        string currentDir = Environment.CurrentDirectory;

        // Projektstammverzeichnis suchen (ein oder zwei Ebenen nach oben)
        this._LogFilePath = Path.GetFullPath(Path.Combine(currentDir, "..", "..", "..",logFileName));
    }

    /// <summary>
    /// Diese Methode schreibt eine Fehlermeldung in das Logfile.
    /// </summary>
    /// <param name="message"></param>
    /// <param name="headline"></param>
    public void WriteToLog( string message, string headline = "Error")
    {
        DateTime timestamp = DateTime.Now;
        using (var writer = new StreamWriter(_LogFilePath, append: true))
        {
            writer.WriteLine($"===== {headline} =====");
            writer.WriteLine($"Timestamp:\n{timestamp}");
            writer.WriteLine($"Message:\n{message}");
            writer.WriteLine("======================\n");
        }
    }
}