import json

from .base_command import BaseCommand
from ..handlers.config_handler import ConfigHandler
from ..handlers.sqlite_handler import SqliteHandler
from ..api_client import ApiClient
from ..models import SyncFileModel


class ManifestCommand(BaseCommand):
    """
    Klasse für den Manifest-Befehl.
    Diese Klasse erstellt ein Manifest der lokalen Dateien und sendet es an die API.
    """
    def execute(self):
        """
        Führt den Manifest-Befehl aus.
        :return:
        """
        if not self.validate_config():
            config_error = "Configuration validation failed. Aborting manifest processing."
            print(config_error)
            self.handle_error(config_error)
            return

        try:
            print("\nStarting manifest processing...")

            # Datenbankverbindung herstellen
            db_handler = SqliteHandler()

            if not db_handler:
                raise ConnectionError("Failed to connect to the database.")

            print("Database connection established successfully.")

            # API URL aus der Konfiguration laden
            config_handler = ConfigHandler()
            api_base_url = config_handler.get_config("api_base_url")

            if not api_base_url:
                raise ValueError("API base URL is not configured.")

            print(f"Using API base URL: {api_base_url}")

            # Bearer-Token und SSL-Verifikation aus Konfiguration laden
            sBuffyToken = config_handler.get_config("auth_token")
            if not sBuffyToken:
                print("⚠️  Warnung: Nicht angemeldet! Bitte führe zuerst 'python3 main.py --login' aus.")

            verify_ssl = config_handler.get_config("verify_ssl")
            if verify_ssl is None:
                verify_ssl = True  # Default: SSL-Verifikation aktiviert

            if verify_ssl is False:
                print("Warning: SSL verification is disabled.")

            # API Client mit Token und SSL-Einstellung initialisieren
            api_client = ApiClient(api_base_url, verify_ssl=verify_ssl, auth_token=sBuffyToken)

            if not api_client:
                raise ValueError("Failed to initialize API client.")

            print("Connected to API client successfully.")

            # Manifest erstellen und senden
            print("\nClient manifest:")
            manifest = self.create_manifest(db_handler)
            
            if len(manifest) == 0:
                print("⚠️  No files in local database - this is a new client or empty sync directory")
                print("Sending empty manifest to request all files from server...")
            else:
                for file in manifest:
                    print(f"File Pfad: {file.get("relativePath")} - File Status: {file.get("changeState")} - File Größe: {file.get("size")} Bytes")

            files_to_sync_json = self.send_manifest(api_client, manifest)

            print("\n" + "=" * 80)
            print("Server response - Files to sync:")
            for file in files_to_sync_json:
                print(f"File Pfad: {file.get("relativePath")} - File Status: {file.get("changeState")} - File Größe: {file.get("size")} Bytes")

            print("\n" + "=" * 80)
            print("Manifest processing completed successfully.")

            return files_to_sync_json

        except Exception as e:
            error_message = f"Error during manifest processing: {e}"
            print(error_message)
            self.handle_error(error_message)

    def create_manifest(self, db_handler):
        """
        Erstellt das Manifest aus der lokalen Datenbank.
        :param db_handler: Instanz des Datenbank-Handlers.
        :return: JSON-String des Manifests.
        """
        manifest = []

        query = ("SELECT file_name, "
                    " file_path, "
                    "file_size, "
                    "hash_value, "
                    "created_at, "
                    "last_modified, "
                    "file_state "
                 "FROM SyncFiles "
                 "WHERE file_state != 'conflict'")

        query_result = db_handler.execute_query(query)

        for row in query_result:
            sync_file = SyncFileModel(
                file_name=row[0],
                file_path=row[1],
                file_size=row[2],
                hash_value=row[3],
                created_at=row[4],
                last_modified=row[5],
                file_state=row[6]
            )
            manifest.append(sync_file.to_dict())

        return manifest

    def send_manifest(self, api_client, manifest):
        """
        Sendet das Manifest an die API und erhält die Antwort.
        :param api_client:
        :param manifest:
        :return:
        """
        response = []

        try:
            response = api_client.post(
                endpoint="manifest", json=manifest)

        except Exception as e:
            raise RuntimeError(f"Failed to send manifest to API: {e}")

        return response