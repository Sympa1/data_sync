import 'package:flutter/material.dart';
import '../models/settings.dart';
import '../services/settings_service.dart';
import '../services/sync_api_service.dart';

/// Administrations-Seite für Administratoren in der Flutter-App.
/// Ermöglicht die Einsicht von System-Statistiken, das Verwalten von Benutzern
/// und die Einsicht von System- und Fehlerprotokollen.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.settings});

  final Settings settings;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final SyncApiService _apiService = SyncApiService();


  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _logs = [];

  int _selectedTab = 0; // 0: Übersicht & Benutzer, 1: System-Logs

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  /// Lädt alle administrativen Daten vom Server
  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final sBuffyApiUrl = widget.settings.apiUrl;
    final sBuffyAuthToken = widget.settings.authToken;

    if (sBuffyApiUrl == null || sBuffyAuthToken == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'API-URL oder Authentifizierungs-Token fehlt.';
      });
      return;
    }

    try {
      final stats = await _apiService.fetchAdminStats(
        apiBaseUrl: sBuffyApiUrl,
        authToken: sBuffyAuthToken,
        allowInsecureTlsForLocalhost: widget.settings.allowInsecureTlsForLocalhost,
      );

      final users = await _apiService.fetchAdminUsers(
        apiBaseUrl: sBuffyApiUrl,
        authToken: sBuffyAuthToken,
        allowInsecureTlsForLocalhost: widget.settings.allowInsecureTlsForLocalhost,
      );

      final logs = await _apiService.fetchAdminLogs(
        apiBaseUrl: sBuffyApiUrl,
        authToken: sBuffyAuthToken,
        allowInsecureTlsForLocalhost: widget.settings.allowInsecureTlsForLocalhost,
      );

      if (!mounted) return;

      setState(() {
        _stats = stats;
        _users = users;
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Fehler beim Laden der Admin-Daten: $e';
      });
    }
  }

  /// Dialog zum Anlegen eines neuen Benutzers
  Future<void> _showCreateUserDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAdmin = false;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Neuen Benutzer anlegen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Benutzername',
                  hintText: 'z.B. max',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Passwort',
                  hintText: 'Mindestens 6 Zeichen',
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Administrator-Rechte erteilen'),
                value: isAdmin,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setDialogState(() {
                    isAdmin = val ?? false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Erstellen'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      final sBuffyUsername = usernameController.text.trim();
      final sBuffyPassword = passwordController.text;

      if (sBuffyUsername.isEmpty || sBuffyPassword.length < 6) {
        _showSnackBar('Ungültige Eingabe: Passwort muss mindestens 6 Zeichen lang sein.', isError: true);
        return;
      }

      try {
        await _apiService.createAdminUser(
          apiBaseUrl: widget.settings.apiUrl!,
          authToken: widget.settings.authToken!,
          username: sBuffyUsername,
          password: sBuffyPassword,
          isAdmin: isAdmin,
          allowInsecureTlsForLocalhost: widget.settings.allowInsecureTlsForLocalhost,
        );

        _showSnackBar('Benutzer "$sBuffyUsername" erfolgreich erstellt!');
        _loadAdminData();
      } catch (e) {
        _showSnackBar('Fehler beim Erstellen des Benutzers: $e', isError: true);
      }
    }
  }

  /// Bestätigungsdialog zum Löschen eines Benutzers
  Future<void> _confirmDeleteUser(int userId, String username) async {
    if (userId == widget.settings.userId) {
      _showSnackBar('Sie können Ihr eigenes Administratorkonto nicht löschen.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Benutzer "$username" löschen?'),
        content: Text(
          'Möchten Sie das Benutzerkonto von "$username" und alle '
          'dessen synchronisierte Dateien wirklich unwiderruflich löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteAdminUser(
          apiBaseUrl: widget.settings.apiUrl!,
          authToken: widget.settings.authToken!,
          userId: userId,
          allowInsecureTlsForLocalhost: widget.settings.allowInsecureTlsForLocalhost,
        );

        _showSnackBar('Benutzer "$username" wurde gelöscht.');
        _loadAdminData();
      } catch (e) {
        _showSnackBar('Fehler beim Löschen: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
      ),
    );
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null) return '0 B';
    int b = (bytes is int) ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int iBuffy = 0;
    double d = b.toDouble();
    while (d >= 1024 && iBuffy < suffixes.length - 1) {
      d /= 1024;
      iBuffy++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[iBuffy]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server-Administration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdminData,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Benutzer & Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'System-Logs',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAdminData,
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  ),
                )
              : _selectedTab == 0
                  ? _buildOverviewTab()
                  : _buildLogsTab(),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // 1. Statistik-Karten
        if (_stats != null) ...[
          const Text(
            'System-Kennzahlen (SQLite)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Benutzer', '${_stats!['TotalUsers'] ?? _stats!['totalUsers'] ?? 0}', Icons.people, Colors.blue),
              _buildStatCard('Dateien', '${_stats!['TotalFiles'] ?? _stats!['totalFiles'] ?? 0}', Icons.insert_drive_file, Colors.purple),
              _buildStatCard('Speicher', _formatBytes(_stats!['TotalStorageBytes'] ?? _stats!['totalStorageBytes']), Icons.storage, Colors.teal),
              _buildStatCard('DB-Größe', _formatBytes(_stats!['DatabaseSizeBytes'] ?? _stats!['databaseSizeBytes']), Icons.data_usage, Colors.amber),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // 2. Benutzerverwaltung
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Benutzerkonten',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Neu'),
              onPressed: _showCreateUserDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_users.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Keine Benutzer gefunden.'),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _users.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _users[index];
                final userId = user['UserId'] ?? user['userId'] ?? 0;
                final username = user['Username'] ?? user['username'] ?? 'Unbekannt';
                final isAdmin = user['IsAdmin'] ?? user['isAdmin'] ?? false;
                final fileCount = user['FileCount'] ?? user['fileCount'] ?? 0;
                final storageBytes = user['StorageBytes'] ?? user['storageBytes'] ?? 0;
                final isCurrent = userId == widget.settings.userId;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAdmin ? Colors.purple.shade700 : Colors.blue.shade700,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      if (isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade900,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Admin', style: TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                      if (isCurrent)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text('(Sie)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                    ],
                  ),
                  subtitle: Text('$fileCount Dateien • ${_formatBytes(storageBytes)}'),
                  trailing: isCurrent
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDeleteUser(userId, username),
                          tooltip: 'Benutzer löschen',
                        ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLogsTab() {
    if (_logs.isEmpty) {
      return const Center(child: Text('Keine Protokolleinträge vorhanden.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _logs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final log = _logs[index];
        final desc = log['Description'] ?? log['description'] ?? '';
        final time = log['Timestamp'] ?? log['timestamp'] ?? '';
        final username = log['Username'] ?? log['username'] ?? 'System';

        return ListTile(
          leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          title: Text(desc, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
          subtitle: Text('$username • $time', style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                Icon(icon, size: 20, color: color),
              ],
            ),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
