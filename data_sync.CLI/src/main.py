import argparse
import os

from core.commands import (
    InitCommand,
    ScanCommand,
    ManifestCommand,
    DownloadCommand,
    UploadCommand,
    DeleteCommand,
    AuthCommand
)


def main():
    """Haupteinstiegspunkt für das data_sync Python CLI-Tool."""

    parser = argparse.ArgumentParser(
        description="data_sync CLI Tool - Cross-Platform Dateisynchronisation",
        add_help=True
    )

    # Mutually exclusive Gruppe für Hauptaktionen
    group = parser.add_mutually_exclusive_group(required=True)

    group.add_argument(
        '--sync', '-s',
        action='store_true',
        help='Startet die vollständige Datensynchronisation (Scan -> Manifest -> Download -> Upload -> Delete).'
    )

    group.add_argument(
        '--manifest', '-m',
        action='store_true',
        help='Startet den Manifest-Abgleich gegen die Web-API.'
    )

    group.add_argument(
        '--download', '-d',
        action='store_true',
        help='Startet den Download-Prozess nach Manifestübermittlung.'
    )

    group.add_argument(
        '--upload', '-u',
        action='store_true',
        help='Startet den Upload-Prozess nach Manifestübermittlung.'
    )

    group.add_argument(
        '--delete', '-x',
        action='store_true',
        help='Startet den Löschungsprozess nach Manifestübermittlung.'
    )

    group.add_argument(
        '--init', '-i',
        action='store_true',
        help='Initialisiert die lokale SQLite-Datenbank (cli_db.db).'
    )

    group.add_argument(
        '--scan', '-c',
        action='store_true',
        help='Scannt das lokale Verzeichnis und aktualisiert die lokale Datenbank.'
    )

    group.add_argument(
        '--login', '-l',
        action='store_true',
        help='Meldet den Benutzer an der REST-API an und sichert das Bearer-Token.'
    )

    group.add_argument(
        '--register', '-r',
        action='store_true',
        help='Registriert ein neues Benutzerkonto an der REST-API.'
    )

    group.add_argument(
        '--whoami', '-w',
        action='store_true',
        help='Zeigt den aktuellen Login-Status und das Server-Benutzerprofil an.'
    )

    group.add_argument(
        '--logout',
        action='store_true',
        help='Meldet den Benutzer ab und widerruft das Bearer-Token.'
    )

    # Zusätzliche optionale Parameter für Automatisierung/Skripte
    parser.add_argument(
        '--username',
        type=str,
        default=None,
        help='Optional: Benutzername für Login oder Registrierung.'
    )

    parser.add_argument(
        '--password',
        type=str,
        default=None,
        help='Optional: Passwort für Login oder Registrierung.'
    )

    args = parser.parse_args()

    # Authentifizierungs-Commands
    if args.login:
        auth_cmd = AuthCommand()
        auth_cmd.login(username=args.username, password=args.password)

    elif args.register:
        auth_cmd = AuthCommand()
        auth_cmd.register(username=args.username, password=args.password)

    elif args.whoami:
        auth_cmd = AuthCommand()
        auth_cmd.whoami()

    elif args.logout:
        auth_cmd = AuthCommand()
        auth_cmd.logout()

    # Lokale Initialisierung & Scan
    elif args.init:
        init_command = InitCommand()
        init_command.execute()

    elif args.scan:
        scan_command = ScanCommand()
        scan_command.execute()

    # Synchronisations-Befehle
    elif args.manifest:
        manifest_command = ManifestCommand()
        manifest_command.execute()

    elif args.download:
        manifest_command = ManifestCommand()
        files_to_sync = manifest_command.execute()
        if files_to_sync:
            download_command = DownloadCommand()
            download_command.execute(files_to_sync)

    elif args.upload:
        manifest_command = ManifestCommand()
        files_to_sync = manifest_command.execute()
        if files_to_sync:
            upload_command = UploadCommand()
            upload_command.execute(files_to_sync)

    elif args.delete:
        manifest_command = ManifestCommand()
        files_to_sync = manifest_command.execute()
        if files_to_sync:
            delete_command = DeleteCommand()
            delete_command.execute(files_to_sync)

    elif args.sync:
        scan_command = ScanCommand()
        scan_command.execute()

        manifest_command = ManifestCommand()
        files_to_sync = manifest_command.execute()

        if files_to_sync is None:
            print("\n⚠️ Manifest-Verarbeitung fehlgeschlagen. Synchronisation abgebrochen.")
            print("Bitte prüfe die Verbindung zum Server und deinen Anmeldestatus ('--whoami').")
            return

        download_command = DownloadCommand()
        download_command.execute(files_to_sync)

        upload_command = UploadCommand()
        upload_command.execute(files_to_sync)

        delete_command = DeleteCommand()
        delete_command.execute(files_to_sync)


if __name__ == '__main__':
    try:
        main()
    finally:
        print("\n data_sync CLI Ausführung beendet.")