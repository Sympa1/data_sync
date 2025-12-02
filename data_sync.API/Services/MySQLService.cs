using DotNetEnv; // --> NuGet-Paket
using MySql.Data.MySqlClient; // --> NuGet-Paket

namespace data_sync.API.Services;

public class MySQLService : IDisposable
{
    private readonly string _connectionString;
    private MySqlConnection _connection;
    
    public MySQLService()
    {
        var server = Env.GetString("MYSQL_SERVER");
        var port = Env.GetInt("MYSQL_PORT");
        var database = Env.GetString("MYSQL_DATABASE");
        var user = Env.GetString("MYSQL_USER");
        var password = Env.GetString("MYSQL_PASSWORD");

        if (string.IsNullOrEmpty(server) || string.IsNullOrEmpty(database) || string.IsNullOrEmpty(user) ||
            string.IsNullOrEmpty(password))
        {
            FileLogService errorLog = new FileLogService("dbError.log");
            errorLog.WriteToLog("MySQL-Verbindungsdaten fehlen.");
            throw new Exception("MySQL-Verbindungsdaten fehlen."); // Erzeuge eine Exception.
        }
        
        //_connectionString = $"Server={server};Port={port};Database={database};Uid={user};Pwd={password};SslMode=none;";

        var _connectionStringBuilder = new MySqlConnectionStringBuilder
        {
            Server = server,
            Port = Convert.ToUInt32(port),
            Database = database,
            UserID = user,
            Password = password,
            SslMode = MySqlSslMode.Required, // Alternativ None oder Preferred oder Required
            
            // Explizit die zu verwendende TLS-Version angeben.
            // Wir versuchen es zuerst mit der sichersten Variante, die MySQL 5.7 evtl. kann.
            TlsVersion = "Tls13"
        };
        _connectionString = _connectionStringBuilder.ConnectionString;
    }

    public MySqlConnection OpenConnection()
    {
        try
        {
            _connection = new MySqlConnection(_connectionString);
            _connection.Open();
            return _connection;
        }
        catch (Exception e)
        {
            FileLogService errorLog = new FileLogService("dbError.log");
            errorLog.WriteToLog($"{e}");
            return null;
        }
    }
    
    /// <summary>
    /// Prüft ob eine Verbindung Null ist, wenn nicht, ob diese offen ist. Ist dem so, wird sie geschlossen.
    /// </summary>
    public void CloseConnection()
    {
        if (_connection?.State == System.Data.ConnectionState.Open)
            _connection.Close();
    }

    /// <summary>
    /// Gibt die Ressourcen (Connection) frei.
    /// </summary>
    public void Dispose()
    {
        _connection.Dispose();
    }
}