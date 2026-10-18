namespace data_sync.API.Services;

public static class UtilsService
{
    public static string CalculateFileHash(string filePath)
    {
        using (var sha256 = System.Security.Cryptography.SHA256.Create())
        {
            using (var stream = System.IO.File.OpenRead(filePath))
            {
                var hash = sha256.ComputeHash(stream);
                // Lowercase für Kompatibilität mit Python-Client
                return Convert.ToHexString(hash).ToLowerInvariant();
            }
        }
    }
}