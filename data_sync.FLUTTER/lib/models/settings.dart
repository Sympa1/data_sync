/// Speichert alle Sync- und Authentifizierungs-Einstellungen der App.
class Settings {
  final String? syncPath;
  final String? apiUrl;
  final bool allowInsecureTlsForLocalhost;
  final String? authToken;
  final String? username;
  final int? userId;
  final bool isAdmin;

  Settings({
    this.syncPath,
    this.apiUrl,
    this.allowInsecureTlsForLocalhost = false,
    this.authToken,
    this.username,
    this.userId,
    this.isAdmin = false,
  });

  /// Prüft, ob der Benutzer aktuell an der REST-API angemeldet ist.
  bool get isAuthenticated => authToken != null && authToken!.trim().isNotEmpty;

  /// Erstellt eine Kopie mit optional überschriebenen Werten.
  Settings copyWith({
    String? syncPath,
    String? apiUrl,
    bool? allowInsecureTlsForLocalhost,
    String? authToken,
    String? username,
    int? userId,
    bool? isAdmin,
  }) {
    return Settings(
      syncPath: syncPath ?? this.syncPath,
      apiUrl: apiUrl ?? this.apiUrl,
      allowInsecureTlsForLocalhost: allowInsecureTlsForLocalhost ?? this.allowInsecureTlsForLocalhost,
      authToken: authToken ?? this.authToken,
      username: username ?? this.username,
      userId: userId ?? this.userId,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
