import 'dart:async';

import 'package:data_sync_flutter/models/settings.dart';
import 'package:data_sync_flutter/services/settings_service.dart';
import 'package:data_sync_flutter/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sync-Seite mit Download-, Upload- und Sync-Aktionen
class SyncPage extends StatefulWidget {
  const SyncPage({super.key, this.isVisible = true, this.loadSettings});

  final bool isVisible;
  final Future<Settings> Function()? loadSettings;

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final SyncService _syncService = SyncService();
  final SettingsService _settingsService = SettingsService();

  Settings? _currentSettings;
  List<String> _logs = const [
    '[INFO] App gestartet und bereit.',
    '[WAIT] Warte auf API-URL und Sync-Verzeichnis.',
    '[NEXT] Danach kannst du einen ersten Testlauf starten.',
  ];
  bool _isRunning = false;
  String _statusLabel = 'Noch nicht eingerichtet';
  IconData _statusIcon = Icons.hourglass_bottom_rounded;
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatus());
  }

  @override
  void didUpdateWidget(covariant SyncPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Laedt den Status neu, sobald die Seite nach Einstellungs-Aenderungen
    // wieder sichtbar wird.
    if (widget.isVisible && !oldWidget.isVisible) {
      unawaited(_loadStatus());
    }
  }

  /// Lädt den aktuellen Einrichtungsstand für den Kopfbereich.
  Future<void> _loadStatus() async {
    final settings =
        await (widget.loadSettings?.call() ??
            _settingsService.getAllSettings());

    if (!mounted) {
      return;
    }

    final isConfigured =
        (settings.apiUrl?.trim().isNotEmpty ?? false) &&
        (settings.syncPath?.trim().isNotEmpty ?? false);

    setState(() {
      _currentSettings = settings;
      _isConfigured = isConfigured;
      _statusLabel = isConfigured
          ? (settings.isAuthenticated
              ? 'Bereit (${settings.username})'
              : 'Login erforderlich')
          : 'Noch nicht eingerichtet';
      _statusIcon = isConfigured
          ? (settings.isAuthenticated
              ? Icons.check_circle_outline
              : Icons.lock_outline)
          : Icons.hourglass_bottom_rounded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Verhindert, dass der letzte Inhalt von der Navigation überdeckt wird.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isConfigured) ...[
            // Trennt den Kopfbereich visuell vom restlichen Inhalt.
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primaryContainer, colorScheme.surface],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Verwendet eine eigene Fläche für das Status-Icon.
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.surface.withValues(
                          alpha: 0.7,
                        ),
                        foregroundColor: colorScheme.primary,
                        child: const Icon(Icons.cloud_sync_outlined),
                      ),
                      const Spacer(),
                      // Zeigt den aktuellen Einrichtungsstand direkt im Kopfbereich an.
                      _StatusPill(
                        label: _isRunning ? 'Sync laeuft' : _statusLabel,
                        icon: _isRunning ? Icons.sync : _statusIcon,
                        backgroundColor: colorScheme.surface,
                        foregroundColor: colorScheme.onSurface,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Bereit fuer den ersten Abgleich',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lege zuerst API-URL und Sync-Verzeichnis fest. Danach startest du Download, Upload oder einen kompletten Sync direkt von hier.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _InfoChip(
                        icon: Icons.link_rounded,
                        label: 'API verbinden',
                      ),
                      _InfoChip(
                        icon: Icons.folder_open_rounded,
                        label: 'Ordner waehlen',
                      ),
                      _InfoChip(
                        icon: Icons.terminal_rounded,
                        label: 'Log im Blick behalten',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Reserviert einen eigenen Bereich für Status- und Log-Ausgaben.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.terminal_outlined,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Aktivitaetsprotokoll',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _logs
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _LogLine.fromEntry(entry),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_currentSettings != null &&
              !_currentSettings!.isAuthenticated &&
              _isConfigured) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nicht angemeldet: Bitte melde dich in den Einstellungen an, um zu synchronisieren.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Gruppiert die verfügbaren Sync-Aktionen.
          Text(
            'Aktionen',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.sync_rounded,
            title: 'Kompletten Sync starten',
            subtitle:
                'Fuehrt Manifest, Download, Upload und Loeschungen nacheinander aus.',
            isPrimary: true,
            enabled: !_isRunning,
            showProgress: _isRunning,
            onTap: () => _runAction(
              actionLabel: 'Sync',
              action: () => _syncService.runFullSync(onLog: _appendLog),
            ),
          ),
          const SizedBox(height: 12),
          // Download und Upload bleiben als gleichrangige Aktionen zusammen.
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.download_rounded,
                  title: 'Download',
                  subtitle: 'Hole Daten vom Server.',
                  enabled: !_isRunning,
                  onTap: () => _runAction(
                    actionLabel: 'Download',
                    action: () => _syncService.runDownload(onLog: _appendLog),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.upload_rounded,
                  title: 'Upload',
                  subtitle: 'Sende lokale Daten hoch.',
                  enabled: !_isRunning,
                  onTap: () => _runAction(
                    actionLabel: 'Upload',
                    action: () => _syncService.runUpload(onLog: _appendLog),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Führt eine Sync-Aktion aus und protokolliert den Ablauf.
  Future<void> _runAction({
    required String actionLabel,
    required Future<void> Function() action,
  }) async {
    if (_isRunning) {
      return;
    }

    setState(() {
      _isRunning = true;
      _logs = ['[START] $actionLabel wird vorbereitet ...'];
    });

    try {
      await action();
      _appendLog('[DONE] $actionLabel erfolgreich abgeschlossen.');
      await _loadStatus();
    } catch (error) {
      _appendLog('[ERROR] $error');
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$actionLabel fehlgeschlagen: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  /// Ergänzt eine neue Log-Zeile im sichtbaren Protokoll.
  void _appendLog(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _logs = [..._logs, message];
    });
  }
}

/// Kleine Status-Markierung fuer den Kopfbereich.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    // Großer Radius erzeugt die typische Badge-Form.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kompakte Hinweis-Chips fuer den Hero-Bereich.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Die Chips dienen als kompakte Hinweise im Kopfbereich.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurface),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine formatierte Log-Zeile mit Monospace-Schrift.
class _LogLine extends StatelessWidget {
  const _LogLine({
    required this.label,
    required this.message,
    required this.color,
  });

  /// Erstellt eine Log-Zeile aus einem einzelnen String-Eintrag.
  factory _LogLine.fromEntry(String entry) {
    final pattern = RegExp(r'^\[(.+?)\]\s*(.*)$');
    final match = pattern.firstMatch(entry);

    if (match == null) {
      return _LogLine(
        label: '[INFO]',
        message: entry,
        color: Colors.lightBlueAccent,
      );
    }

    final label = '[${match.group(1)!}]';
    final message = match.group(2) ?? '';

    return _LogLine(
      label: label,
      message: message,
      color: _colorForLabel(label),
    );
  }

  final String label;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Hebt Präfix und Nachricht innerhalb einer Log-Zeile getrennt hervor.
    final textStyle = GoogleFonts.jetBrainsMono(
      fontSize: 13,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.45,
    );

    return RichText(
      text: TextSpan(
        style: textStyle,
        children: [
          TextSpan(
            text: '$label ',
            style: textStyle.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: message),
        ],
      ),
    );
  }

  /// Ordnet einem Log-Präfix eine feste Akzentfarbe zu.
  static Color _colorForLabel(String label) {
    switch (label) {
      case '[ERROR]':
        return Colors.redAccent;
      case '[DONE]':
        return Colors.lightGreenAccent;
      case '[START]':
        return Colors.lightBlueAccent;
      case '[WAIT]':
        return Colors.amberAccent;
      default:
        return Colors.lightBlueAccent;
    }
  }
}

/// Visuell hervorgehobene Aktionskarte fuer die Startseite.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
    this.enabled = true,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool enabled;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Primäre und sekundäre Aktionen verwenden unterschiedliche Flächenfarben.
    final backgroundColor = isPrimary
        ? colorScheme.primary
        : colorScheme.surface;
    final foregroundColor = isPrimary
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    // Material + InkWell aktiviert den Ripple-Effekt für die gesamte Karte.
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trennt das Aktionssymbol von Titel und Beschreibung.
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? colorScheme.onPrimary.withValues(alpha: 0.14)
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isPrimary
                      ? colorScheme.onPrimary
                      : colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isPrimary
                      ? colorScheme.onPrimary.withValues(alpha: 0.82)
                      : colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (showProgress) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: foregroundColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
