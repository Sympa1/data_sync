import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:data_sync_flutter/models/settings.dart';
import 'package:data_sync_flutter/screens/admin_page.dart';
import 'package:data_sync_flutter/services/settings_service.dart';
import 'package:data_sync_flutter/services/sync_api_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Die Settings-Seite der App
///
/// Diese Seite ermöglicht es dem User, seine Synchronisierungseinstellungen zu konfigurieren:
/// - Sync-Verzeichnis: Der lokale Ordner, der synchronisiert werden soll
/// - API-URL: Die Adresse des Sync-Backend-Servers
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.loadSettings});

  final Future<Settings> Function()? loadSettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SyncApiService _syncApiService = SyncApiService();

  /// Die aktuellen Einstellungen der App
  ///
  /// Statt zwei separate Variablen zu haben (syncPath, apiUrl),
  /// nutzen wir das Settings-Modell. Das ist sauberer und macht es
  /// einfacher, die Settings später an andere Services zu übergeben.
  Settings? settings;
  bool _isLoading = true;

  /// Diese Methode wird aufgerufen, wenn die SettingsPage erstellt wird
  ///
  /// Sie ist Teil des StatefulWidget Lifecycle:
  /// 1. Widget erstellen → initState()
  /// 2. initState() → build()
  /// 3. build() → UI wird angezeigt
  ///
  /// Hier laden wir die Settings aus der Datenbank.
  @override
  void initState() {
    super.initState(); // Wichtig: Immer super.initState() aufrufen!

    // Lade die gespeicherten Einstellungen aus der Datenbank
    _loadSettings();
  }

  /// Lädt die gespeicherten Einstellungen und aktualisiert den Ladezustand.
  Future<void> _loadSettings() async {
    try {
      // Rufe den Service auf, um alle Einstellungen zu laden
      final loadedSettings =
          await (widget.loadSettings?.call() ??
              SettingsService().getAllSettings());

      // Verhindert setState nach dispose.
      if (!mounted) {
        return;
      }

      // Teile Flutter mit, dass sich die Daten geändert haben
      setState(() {
        settings = loadedSettings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Einstellungen konnten nicht geladen werden.',
        isError: true,
      );
    }
  }

  /// Öffnet einen Dialog zur Bearbeitung der API-URL.
  Future<void> _enterApiUrl() async {
    // Vorbelegung mit dem aktuell gespeicherten Wert.
    final controller = TextEditingController(text: settings?.apiUrl ?? '');

    final enteredUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('API-URL eingeben'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText:
                'z.B. http://192.168.0.10:8088 oder https://192.168.0.10:8443',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(), // Abbrechen → null zurückgeben
            child: Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(controller.text.trim()), // Wert zurückgeben
            child: Text('Speichern'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    // Abbruch oder leere Eingabe erzeugen keine Änderung.
    if (enteredUrl == null || enteredUrl.isEmpty) return;

    // Akzeptiert nur vollständige HTTP- oder HTTPS-Adressen.
    if (!_isValidApiUrl(enteredUrl)) {
      _showMessage('Bitte gib eine gueltige API-URL ein.', isError: true);
      return;
    }

    setState(() {
      settings = Settings(
        syncPath: settings?.syncPath,
        apiUrl: enteredUrl,
        allowInsecureTlsForLocalhost:
            settings?.allowInsecureTlsForLocalhost ?? false,
      );
    });

    try {
      await SettingsService().saveSetting('apiUrl', enteredUrl);

      if (!mounted) {
        return;
      }

      _showMessage('API-URL gespeichert.');
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage('API-URL konnte nicht gespeichert werden.', isError: true);
    }
  }

  /// Öffnet den Dialog zur Auswahl des lokalen Sync-Verzeichnisses.
  Future<void> _selectSyncDirectory() async {
    try {
      if (Platform.isAndroid) {
        await _ensureAndroidFileAccess();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(e.toString(), isError: true);
      return;
    }

    final selectedPath = await FilePicker.platform.getDirectoryPath();

    // Abbruch oder dispose erzeugen keine Änderung.
    if (!mounted || selectedPath == null) {
      return;
    }

    setState(() {
      // Übernimmt den neuen Pfad und behält die übrigen Werte bei.
      settings = Settings(
        syncPath: selectedPath,
        apiUrl: settings?.apiUrl,
        allowInsecureTlsForLocalhost:
            settings?.allowInsecureTlsForLocalhost ?? false,
      );
    });

    // Speichere den neuen Pfad in der Datenbank
    try {
      await SettingsService().saveSetting('syncPath', selectedPath);

      if (!mounted) {
        return;
      }

      _showMessage(
        Platform.isAndroid
            ? 'Sync-Verzeichnis gespeichert. Auf Android sollte das ein sichtbarer Ordner wie Documents/data_sync sein.'
            : 'Sync-Verzeichnis gespeichert.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Sync-Verzeichnis konnte nicht gespeichert werden.',
        isError: true,
      );
    }
  }

  /// Fordert auf Android den Vollzugriff auf den gemeinsamen Speicher an.
  Future<void> _ensureAndroidFileAccess() async {
    final currentStatus = await Permission.manageExternalStorage.status;

    if (currentStatus.isGranted) {
      return;
    }

    final requestedStatus = await Permission.manageExternalStorage.request();

    if (requestedStatus.isGranted) {
      return;
    }

    throw Exception(
      'Android braucht "Alle Dateien verwalten", damit ein sichtbarer Ordner '
      'wie Documents/data_sync voll synchronisiert werden kann. Bitte die '
      'Berechtigung erlauben und das Verzeichnis danach erneut auswaehlen.',
    );
  }

  /// Prüft auf eine vollständige HTTP- oder HTTPS-URL.
  bool _isValidApiUrl(String value) {
    final uri = Uri.tryParse(value);

    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// Speichert, ob lokale HTTPS-Zertifikate fuer Entwicklung und LAN akzeptiert werden.
  Future<void> _toggleLocalhostCertificateOverride(bool value) async {
    final currentSettings = settings ?? Settings();

    setState(() {
      settings = Settings(
        syncPath: currentSettings.syncPath,
        apiUrl: currentSettings.apiUrl,
        allowInsecureTlsForLocalhost: value,
      );
    });

    try {
      await SettingsService().saveSetting(
        'allowInsecureTlsForLocalhost',
        value.toString(),
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        value
            ? 'Lokale HTTPS-Zertifikate fuer localhost und LAN-Adressen sind aktiviert.'
            : 'Lokale HTTPS-Zertifikate fuer localhost und LAN-Adressen sind deaktiviert.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        settings = Settings(
          syncPath: currentSettings.syncPath,
          apiUrl: currentSettings.apiUrl,
          allowInsecureTlsForLocalhost:
              currentSettings.allowInsecureTlsForLocalhost,
        );
      });

      _showMessage(
        'Die TLS-Einstellung konnte nicht gespeichert werden.',
        isError: true,
      );
    }
  }

  /// Zeigt eine einheitliche Rückmeldung für Erfolg oder Fehler.
  void _showMessage(String message, {bool isError = false}) {
    final backgroundColor = isError
        ? Theme.of(context).colorScheme.error
        : null;
    final foregroundColor = isError
        ? Theme.of(context).colorScheme.onError
        : null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        action: isError
            ? SnackBarAction(
                label: 'Schliessen',
                textColor: foregroundColor,
                onPressed: () {},
              )
            : null,
      ),
    );
  }

  /// Öffnet den Dialog zur Anmeldung mit Benutzername und Passwort.
  Future<void> _showLoginDialog() async {
    final sBuffyApiUrl = settings?.apiUrl?.trim();
    if (sBuffyApiUrl == null || sBuffyApiUrl.isEmpty) {
      _showMessage('Bitte hinterlege zuerst eine API-URL.', isError: true);
      return;
    }

    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Anmelden'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Benutzername',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    autofocus: true,
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Passwort',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    enabled: !isSubmitting,
                  ),
                  if (isSubmitting) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final sBuffyUsername = usernameController.text.trim();
                          final sBuffyPassword = passwordController.text;

                          if (sBuffyUsername.isEmpty || sBuffyPassword.isEmpty) {
                            _showMessage(
                              'Bitte Benutzername und Passwort eingeben.',
                              isError: true,
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            final loginResult = await _syncApiService.login(
                              apiBaseUrl: sBuffyApiUrl,
                              username: sBuffyUsername,
                              password: sBuffyPassword,
                              allowInsecureTlsForLocalhost:
                                  settings?.allowInsecureTlsForLocalhost ?? false,
                            );

                            final sBuffyToken = loginResult['token'] as String;
                            final userMap =
                                loginResult['user'] as Map<String, dynamic>;
                            final iBuffyUserId = userMap['id'] as int;
                            final sBuffyReturnedUser =
                                userMap['username'] as String;
                            final bool bBuffyIsAdmin =
                                userMap['isAdmin'] == true;

                            await SettingsService().saveAuthSession(
                              token: sBuffyToken,
                              username: sBuffyReturnedUser,
                              userId: iBuffyUserId,
                              isAdmin: bBuffyIsAdmin,
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            await _loadSettings();
                            if (mounted) {
                              _showMessage(
                                'Erfolgreich als $sBuffyReturnedUser angemeldet.',
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              _showMessage(
                                'Anmeldung fehlgeschlagen: $e',
                                isError: true,
                              );
                            }
                          }
                        },
                  child: const Text('Anmelden'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Öffnet den Dialog zur Registrierung eines neuen Benutzerkontos.
  Future<void> _showRegisterDialog() async {
    final sBuffyApiUrl = settings?.apiUrl?.trim();
    if (sBuffyApiUrl == null || sBuffyApiUrl.isEmpty) {
      _showMessage('Bitte hinterlege zuerst eine API-URL.', isError: true);
      return;
    }

    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Konto erstellen'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Benutzername (mind. 3 Zeichen)',
                      prefixIcon: Icon(Icons.person_add_outlined),
                    ),
                    autofocus: true,
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Passwort (mind. 6 Zeichen)',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Passwort wiederholen',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                    obscureText: true,
                    enabled: !isSubmitting,
                  ),
                  if (isSubmitting) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final sBuffyUsername = usernameController.text.trim();
                          final sBuffyPassword = passwordController.text;
                          final sBuffyConfirm =
                              confirmPasswordController.text;

                          if (sBuffyUsername.length < 3) {
                            _showMessage(
                              'Benutzername muss mindestens 3 Zeichen lang sein.',
                              isError: true,
                            );
                            return;
                          }

                          if (sBuffyPassword.length < 6) {
                            _showMessage(
                              'Passwort muss mindestens 6 Zeichen lang sein.',
                              isError: true,
                            );
                            return;
                          }

                          if (sBuffyPassword != sBuffyConfirm) {
                            _showMessage(
                              'Passwörter stimmen nicht überein.',
                              isError: true,
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            final regResult = await _syncApiService.register(
                              apiBaseUrl: sBuffyApiUrl,
                              username: sBuffyUsername,
                              password: sBuffyPassword,
                              allowInsecureTlsForLocalhost:
                                  settings?.allowInsecureTlsForLocalhost ?? false,
                            );

                            final sBuffyToken = regResult['token'] as String;
                            final userMap =
                                regResult['user'] as Map<String, dynamic>;
                            final iBuffyUserId = userMap['id'] as int;
                            final sBuffyReturnedUser =
                                userMap['username'] as String;
                            final bool bBuffyIsAdmin =
                                userMap['isAdmin'] == true;

                            await SettingsService().saveAuthSession(
                              token: sBuffyToken,
                              username: sBuffyReturnedUser,
                              userId: iBuffyUserId,
                              isAdmin: bBuffyIsAdmin,
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            await _loadSettings();
                            if (mounted) {
                              _showMessage(
                                'Konto erstellt und angemeldet als $sBuffyReturnedUser.',
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              _showMessage(
                                'Registrierung fehlgeschlagen: $e',
                                isError: true,
                              );
                            }
                          }
                        },
                  child: const Text('Registrieren'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Meldet das aktuelle Benutzerkonto ab und löscht die Sitzungsdaten.
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text(
          'Möchtest du dich wirklich abmelden? Die lokalen Dateien bleiben erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await SettingsService().clearAuthSession();
      await _loadSettings();
      if (mounted) {
        _showMessage('Erfolgreich abgemeldet.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Abmelden fehlgeschlagen: $e', isError: true);
      }
    }
  }

  /// Öffnet die Administrations-Ansicht für Administratoren.
  void _openAdminPage() {
    if (settings == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AdminPage(settings: settings!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usesAndroidSharedDirectory = Platform.isAndroid;
    // Beide Werte bestimmen den Einrichtungsstand im Kopfbereich.
    final hasApiUrl = settings?.apiUrl?.isNotEmpty ?? false;
    final hasSyncPath = settings?.syncPath?.isNotEmpty ?? false;
    final isConfigured = hasApiUrl && hasSyncPath;
    final completedSteps = (hasApiUrl ? 1 : 0) + (hasSyncPath ? 1 : 0);

    return ListView(
      // Hält Abstand zur unteren Navigation.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        if (!isConfigured) ...[
          // Fasst Einrichtungsstand und kurze Einordnung zusammen.
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: const Icon(Icons.settings_suggest_outlined),
                    ),
                    const Spacer(),
                    _StatusChip(
                      label: '$completedSteps von 2 fertig',
                      isComplete: completedSteps == 2,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Alles Wichtige an einem Ort',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hier richtest du die Verbindung zum Backend und dein lokales Sync-Verzeichnis ein. Sobald beides gesetzt ist, ist die App bereit fuer den ersten echten Lauf.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                _OverviewRow(
                  icon: Icons.language_outlined,
                  title: 'API-URL',
                  isComplete: hasApiUrl,
                ),
                const SizedBox(height: 12),
                _OverviewRow(
                  icon: Icons.folder_outlined,
                  title: 'Sync-Verzeichnis',
                  isComplete: hasSyncPath,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        // Enthält die bearbeitbaren Einstellungen.
        Text(
          'Konfiguration',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _SettingCard(
          icon: Icons.language_outlined,
          title: 'API-URL',
          value: settings?.apiUrl ?? 'Noch keine Adresse hinterlegt',
          description:
              'Die Android-App nutzt diese Adresse spaeter fuer Upload, Download und den Manifest-Abgleich.',
          actionLabel: hasApiUrl ? 'Adresse aendern' : 'Adresse eintragen',
          isComplete: hasApiUrl,
          isLoading: _isLoading,
          onTap: _enterApiUrl,
        ),
        const SizedBox(height: 12),
        _SettingCard(
          icon: Icons.folder_outlined,
          title: 'Sync-Verzeichnis',
          value: settings?.syncPath ?? 'Noch kein Verzeichnis ausgewaehlt',
          description: usesAndroidSharedDirectory
              ? 'Auf Android kannst du mit der zusaetzlichen Berechtigung einen sichtbaren Ordner wie Documents/data_sync verwenden. So bleiben die Dateien ausserhalb der App auffindbar.'
              : 'Dieser Ordner ist die lokale Quelle fuer Dateien, die hoch- oder heruntergeladen werden sollen.',
          actionLabel: usesAndroidSharedDirectory
              ? (hasSyncPath
                    ? 'Sichtbaren Ordner aendern'
                    : 'Sichtbaren Ordner waehlen')
              : (hasSyncPath ? 'Verzeichnis aendern' : 'Verzeichnis waehlen'),
          isComplete: hasSyncPath,
          isLoading: _isLoading,
          onTap: _selectSyncDirectory,
        ),
        const SizedBox(height: 12),
        _ToggleSettingCard(
          icon: Icons.https_outlined,
          title: 'Lokale HTTPS-Zertifikate erlauben',
          description:
              'Erlaubt fuer https://localhost, https://127.0.0.1 und private LAN-Adressen auch selbstsignierte Zertifikate. Wenn du ueber Caddy im Heimnetz arbeitest, gib in der API-URL den richtigen Port deines Reverse Proxys an.',
          value: settings?.allowInsecureTlsForLocalhost ?? false,
          isLoading: _isLoading,
          onChanged: _toggleLocalhostCertificateOverride,
        ),
        const SizedBox(height: 24),
        Text(
          'Benutzer-Konto',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (settings?.isAuthenticated == true) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.account_circle_outlined,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings?.username ?? 'Benutzer',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            _StatusChip(
                              label: (settings?.isAdmin ?? false)
                                  ? 'Administrator'
                                  : 'Standardbenutzer',
                              isComplete: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Benutzer-ID: ${settings?.userId ?? "-"}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Abmelden'),
                  ),
                ],
              ),
            ),
          ),
          if (settings?.isAdmin == true) ...[
            const SizedBox(height: 12),
            _SettingCard(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Server-Administration',
              value: 'Benutzer, Sync-Dateien und System-Logs verwalten',
              description:
                  'Als Administrator kannst du Statistiken einsehen, neue Benutzer anlegen und das System überwachen.',
              actionLabel: 'Administration öffnen',
              isComplete: true,
              isLoading: _isLoading,
              onTap: _openAdminPage,
            ),
          ],
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nicht angemeldet',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            const _StatusChip(
                              label: 'Anmeldung erforderlich',
                              isComplete: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Für die Synchronisation mit dem Server wird ein Benutzer-Token benötigt.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _isLoading ? null : _showLoginDialog,
                          child: const Text('Anmelden'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _showRegisterDialog,
                          child: const Text('Registrieren'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Zeigt den Einrichtungsstatus einer einzelnen Voraussetzung.
class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.icon,
    required this.title,
    required this.isComplete,
  });

  final IconData icon;
  final String title;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        _StatusChip(
          label: isComplete ? 'Fertig' : 'Offen',
          isComplete: isComplete,
        ),
      ],
    );
  }
}

/// Visuell hervorgehobene Karte fuer eine einzelne Einstellung.
class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
    required this.actionLabel,
    required this.isComplete,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String description;
  final String actionLabel;
  final bool isComplete;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        _StatusChip(
                          label: isComplete ? 'Eingerichtet' : 'Noch offen',
                          isComplete: isComplete,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isLoading ? 'Wird geladen ...' : actionLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isLoading
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Schalterkarte fuer boolesche Einstellungen.
class _ToggleSettingCard extends StatelessWidget {
  const _ToggleSettingCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.isLoading,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch(value: value, onChanged: isLoading ? null : onChanged),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value ? 'Aktiviert' : 'Deaktiviert',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kleine Statusanzeige fuer Karten und Uebersichten.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.isComplete});

  final String label;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isComplete
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foregroundColor = isComplete
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
