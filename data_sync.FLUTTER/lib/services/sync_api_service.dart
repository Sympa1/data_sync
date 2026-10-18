import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as path;

import '../models/sync_models.dart';

/// Kapselt alle HTTP-Aufrufe an die data_sync REST-API (Sync, Authentifizierung und Administration).
class SyncApiService {
  SyncApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Liefert die normalisierte Basis-URL für Log-Ausgaben.
  String describeBaseUrl(String apiBaseUrl) => _normalizeBaseUrl(apiBaseUrl);

  // ==========================================
  // 1. Authentifizierungs-Endpunkte
  // ==========================================

  /// Meldet den Benutzer über /api/auth/login an und liefert Token und Benutzerdaten zurück.
  Future<Map<String, dynamic>> login({
    required String apiBaseUrl,
    required String username,
    required String password,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final uri = _buildRootUri(apiBaseUrl, '/api/auth/login');
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.post(
        uri,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({'Username': username, 'Password': password}),
      ),
    );

    _ensureSuccess(response, 'Anmeldung');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Registriert ein neues Benutzerkonto über /api/auth/register.
  Future<Map<String, dynamic>> register({
    required String apiBaseUrl,
    required String username,
    required String password,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final uri = _buildRootUri(apiBaseUrl, '/api/auth/register');
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.post(
        uri,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode({'Username': username, 'Password': password}),
      ),
    );

    _ensureSuccess(response, 'Registrierung');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Prüft das aktive Benutzerprofil über /api/auth/me.
  Future<Map<String, dynamic>> getMe({
    required String apiBaseUrl,
    required String authToken,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final uri = _buildRootUri(apiBaseUrl, '/api/auth/me');
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.get(
        uri,
        headers: _buildHeaders(authToken: authToken),
      ),
    );

    _ensureSuccess(response, 'Profilabfrage');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ==========================================
  // 2. Administrations-Endpunkte
  // ==========================================

  /// Ruft System-Statistiken über /api/admin/stats ab.
  Future<Map<String, dynamic>> fetchAdminStats({
    required String apiBaseUrl,
    required String authToken,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final uri = _buildRootUri(apiBaseUrl, '/api/admin/stats');
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.get(
        uri,
        headers: _buildHeaders(authToken: authToken),
      ),
    );

    _ensureSuccess(response, 'Admin-Statistiken');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Ruft die Benutzerliste über /api/admin/users ab.
  Future<List<Map<String, dynamic>>> fetchAdminUsers({
    required String apiBaseUrl,
    required String authToken,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final uri = _buildRootUri(apiBaseUrl, '/api/admin/users');
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.get(
        uri,
        headers: _buildHeaders(authToken: authToken),
      ),
    );

    _ensureSuccess(response, 'Benutzerliste');
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Erstellt einen neuen Benutzer über /api/admin/users.
  Future<void> createAdminUser({
    required String apiBaseUrl,
    required String authToken,
    required String username,
    required String password,
    required bool isAdmin,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final uri = _buildRootUri(apiBaseUrl, '/api/admin/users');
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.post(
        uri,
        headers: _buildHeaders(authToken: authToken, contentType: 'application/json'),
        body: jsonEncode({
          'Username': username,
          'Password': password,
          'IsAdmin': isAdmin,
        }),
      ),
    );

    _ensureSuccess(response, 'Benutzer anlegen');
  }

  /// Löscht einen Benutzer über /api/admin/users/{userId}.
  Future<void> deleteAdminUser({
    required String apiBaseUrl,
    required String authToken,
    required int userId,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final uri = _buildRootUri(apiBaseUrl, '/api/admin/users/$userId');
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.delete(
        uri,
        headers: _buildHeaders(authToken: authToken),
      ),
    );

    _ensureSuccess(response, 'Benutzer löschen');
  }

  /// Ruft System- und Fehlerprotokolle über /api/admin/logs ab.
  Future<List<Map<String, dynamic>>> fetchAdminLogs({
    required String apiBaseUrl,
    required String authToken,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final uri = _buildRootUri(apiBaseUrl, '/api/admin/logs');
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.get(
        uri,
        headers: _buildHeaders(authToken: authToken),
      ),
    );

    _ensureSuccess(response, 'Systemprotokolle');
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  // ==========================================
  // 3. Datei-Synchronisations-Endpunkte
  // ==========================================

  /// Sendet das lokale Manifest an die API (POST /api/sync/manifest).
  Future<List<SyncManifestResponse>> sendManifest({
    required String apiBaseUrl,
    required List<SyncFileDescriptor> manifest,
    String? authToken,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.post(
        _buildUri(apiBaseUrl, 'manifest'),
        headers: _buildHeaders(
          authToken: authToken,
          contentType: 'application/json',
        ),
        body: jsonEncode(manifest.map((entry) => entry.toJson()).toList()),
      ),
    );

    _ensureSuccess(response, 'Manifest');

    final payload = jsonDecode(response.body);

    if (payload is! List) {
      throw Exception('Die Manifest-Antwort hat ein unerwartetes Format.');
    }

    return payload
        .whereType<Map<String, dynamic>>()
        .map(SyncManifestResponse.fromJson)
        .toList();
  }

  /// Lädt eine einzelne Datei auf den Server hoch (POST /api/sync/upload).
  Future<void> uploadFile({
    required String apiBaseUrl,
    required String syncRootPath,
    required SyncFileDescriptor file,
    String? authToken,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final absolutePath = path.join(syncRootPath, file.relativePath);
    final localFile = File(absolutePath);

    if (!await localFile.exists()) {
      throw Exception('Die Upload-Datei wurde lokal nicht gefunden.');
    }

    final basePath = path.posix.dirname(file.relativePath.replaceAll('\\', '/'));
    final uploadUri = _buildUri(
      apiBaseUrl,
      'upload',
      queryParameters: basePath == '.'
          ? null
          : <String, String>{'basePath': basePath},
    );

    final request = http.MultipartRequest('POST', uploadUri)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          absolutePath,
          filename: file.fileName,
        ),
      );

    if (authToken != null && authToken.trim().isNotEmpty) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $authToken';
    }

    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) async {
        final streamedResponse = await client.send(request);
        return http.Response.fromStream(streamedResponse);
      },
    );

    _ensureSuccess(response, 'Upload');
  }

  /// Lädt eine Datei vom Server herunter (GET /api/sync/download).
  Future<void> downloadFile({
    required String apiBaseUrl,
    required String syncRootPath,
    required SyncManifestResponse file,
    String? authToken,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.get(
        _buildUri(
          apiBaseUrl,
          'download',
          queryParameters: {'filePath': file.relativePath},
        ),
        headers: _buildHeaders(authToken: authToken),
      ),
    );

    _ensureSuccess(response, 'Download');

    final absolutePath = path.join(syncRootPath, file.relativePath);
    final localFile = File(absolutePath);

    try {
      await localFile.parent.create(recursive: true);
      await localFile.writeAsBytes(response.bodyBytes, flush: true);
      await localFile.setLastModified(file.lastModified.toLocal());
    } on FileSystemException catch (error) {
      throw Exception(
        _buildLocalWriteErrorMessage(
          syncRootPath: syncRootPath,
          absolutePath: absolutePath,
          details: error.message,
        ),
      );
    }
  }

  /// Meldet eine lokale Löschung an den Server (DELETE /api/sync/delete).
  Future<void> deleteRemoteFile({
    required String apiBaseUrl,
    required String relativePath,
    String? authToken,
    bool allowInsecureTlsForLocalhost = false,
  }) async {
    final response = await _executeRequest(
      apiBaseUrl,
      allowInsecureTlsForLocalhost,
      (client) => client.delete(
        _buildUri(
          apiBaseUrl,
          'delete',
          queryParameters: {'filePath': relativePath},
        ),
        headers: _buildHeaders(authToken: authToken),
      ),
    );

    _ensureSuccess(response, 'Delete');
  }

  // ==========================================
  // 4. Hilfsmethoden für URL- & Request-Bau
  // ==========================================

  Map<String, String> _buildHeaders({String? authToken, String? contentType}) {
    final headers = <String, String>{};
    if (contentType != null) {
      headers[HttpHeaders.contentTypeHeader] = contentType;
    }
    if (authToken != null && authToken.trim().isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $authToken';
    }
    return headers;
  }

  /// Baut eine URI relativ zu /api/sync.
  Uri _buildUri(
    String apiBaseUrl,
    String endpoint, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedBaseUrl = _normalizeBaseUrl(apiBaseUrl);
    final baseUri = Uri.parse(normalizedBaseUrl);
    final normalizedEndpoint = endpoint.replaceFirst(RegExp(r'^/+'), '');
    final combinedPath = [
      ...baseUri.path.split('/').where((part) => part.isNotEmpty),
      normalizedEndpoint,
    ].join('/');

    return baseUri.replace(
      path: '/$combinedPath',
      queryParameters: queryParameters?.isEmpty ?? true ? null : queryParameters,
    );
  }

  /// Baut eine absolute URI relativ zum Server-Root (z.B. für /api/auth/* oder /api/admin/*).
  Uri _buildRootUri(
    String apiBaseUrl,
    String rootPath, {
    Map<String, String>? queryParameters,
  }) {
    final baseUri = Uri.parse(_normalizeBaseUrl(apiBaseUrl));
    final normalizedPath = rootPath.startsWith('/') ? rootPath : '/$rootPath';

    return Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: normalizedPath,
      queryParameters: queryParameters?.isEmpty ?? true ? null : queryParameters,
    );
  }

  /// Ergänzt fehlende API-Segmente an der Basis-URL.
  String _normalizeBaseUrl(String apiBaseUrl) {
    final trimmed = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

    if (trimmed.endsWith('/api/sync')) {
      return trimmed;
    }

    if (trimmed.endsWith('/api')) {
      return '$trimmed/sync';
    }

    return '$trimmed/api/sync';
  }

  /// Führt einen HTTP-Aufruf mit optionaler TLS-Ausnahme für lokale Ziele aus.
  Future<T> _executeRequest<T>(
    String apiBaseUrl,
    bool allowInsecureTlsForLocalhost,
    Future<T> Function(http.Client client) action,
  ) async {
    final targetUri = Uri.parse(_normalizeBaseUrl(apiBaseUrl));
    final client = _createClientForUri(
      targetUri,
      allowInsecureTlsForLocalhost: allowInsecureTlsForLocalhost,
    );

    try {
      return await action(client);
    } on SocketException catch (error) {
      throw Exception('Server unter ${targetUri.host} nicht erreichbar: ${error.message}');
    } catch (error) {
      final message = error.toString();
      if (_looksLikeCertificateError(message)) {
        throw Exception(_buildCertificateErrorMessage(targetUri, message));
      }
      rethrow;
    } finally {
      if (!identical(client, _httpClient)) {
        client.close();
      }
    }
  }

  /// Erstellt bei Bedarf einen Client mit lokaler Zertifikatsausnahme.
  http.Client _createClientForUri(
    Uri uri, {
    required bool allowInsecureTlsForLocalhost,
  }) {
    if (!allowInsecureTlsForLocalhost || !_isSupportedInsecureHttpsUri(uri)) {
      return _httpClient;
    }

    final httpClient = HttpClient()
      ..badCertificateCallback = (certificate, host, port) {
        return _isSupportedInsecureHost(host);
      };

    return IOClient(httpClient);
  }

  /// Erlaubt die TLS-Ausnahme nur für lokale HTTPS-Adressen.
  bool _isSupportedInsecureHttpsUri(Uri uri) {
    return uri.scheme == 'https' && _isSupportedInsecureHost(uri.host);
  }

  /// Begrenzt Zertifikatsausnahmen auf Loopback- und private LAN-Adressen.
  bool _isSupportedInsecureHost(String host) {
    final normalizedHost = host.trim().toLowerCase();
    if (normalizedHost == 'localhost') {
      return true;
    }

    final parsedAddress = InternetAddress.tryParse(normalizedHost);
    if (parsedAddress == null) {
      return false;
    }

    if (parsedAddress.isLoopback) {
      return true;
    }

    if (parsedAddress.type == InternetAddressType.IPv4) {
      return _isPrivateIpv4Address(parsedAddress.address);
    }

    return _isPrivateIpv6Address(parsedAddress.address);
  }

  /// Erkennt RFC1918- und Link-Local-Adressen im lokalen Netz.
  bool _isPrivateIpv4Address(String address) {
    final octets = address.split('.').map(int.tryParse).toList();
    if (octets.length != 4 || octets.any((octet) => octet == null)) {
      return false;
    }

    final first = octets[0]!;
    final second = octets[1]!;

    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        (first == 169 && second == 254);
  }

  /// Erkennt lokale IPv6-Bereiche für Entwicklung im Heim- oder Firmennetz.
  bool _isPrivateIpv6Address(String address) {
    final normalizedAddress = address.toLowerCase();

    return normalizedAddress.startsWith('fc') ||
        normalizedAddress.startsWith('fd') ||
        normalizedAddress.startsWith('fe80:');
  }

  bool _looksLikeCertificateError(String message) {
    final normalizedMessage = message.toLowerCase();

    return normalizedMessage.contains('handshake exception') ||
        normalizedMessage.contains('certificate verify failed') ||
        normalizedMessage.contains('local issuer certificate');
  }

  String _buildCertificateErrorMessage(Uri uri, String details) {
    if (_isSupportedInsecureHttpsUri(uri)) {
      return 'Das HTTPS-Zertifikat für ${uri.host} wird nicht vertraut. Details: $details';
    }

    return 'TLS-Verbindung zur API fehlgeschlagen. Details: $details';
  }

  String _buildLocalWriteErrorMessage({
    required String syncRootPath,
    required String absolutePath,
    required String details,
  }) {
    if (Platform.isAndroid) {
      return 'Android darf nicht in jeden Ordner unter /storage/emulated/0 schreiben. Details: $details';
    }

    return 'Datei konnte lokal nicht gespeichert werden. Details: $details';
  }

  void _ensureSuccess(http.Response response, String operationLabel) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final responseBody = response.body.trim();
    final details = responseBody.isEmpty ? 'Keine weiteren Details.' : responseBody;

    throw Exception(
      '$operationLabel fehlgeschlagen (${response.statusCode}): $details',
    );
  }
}
