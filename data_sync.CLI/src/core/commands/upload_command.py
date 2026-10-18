import os
from .base_command import BaseCommand
from ..handlers.config_handler import ConfigHandler
from ..handlers.sqlite_handler import SqliteHandler
from .. import ApiClient
from ..sync_state_manager import SyncStateManager


class UploadCommand(BaseCommand):
    """
    Command zum Hochladen von Dateien auf den Remote-Server.
    """
    def execute(self, files_to_sync):
        """
        Startet den Upload-Prozess für die angegebenen Dateien.
        :param files_to_sync:
        :return:
        """
        print("\nUpload process started")

        # Aufruf der API um die Dateien hochzuladen
        config_handler = ConfigHandler()
        sync_path = config_handler.get_config("sync_path")
        api_base_url = config_handler.get_config("api_base_url")
        sBuffyToken = config_handler.get_config("auth_token")
        verify_ssl = config_handler.get_config("verify_ssl")
        if verify_ssl is None:
            verify_ssl = True  # Default: SSL-Verifikation aktiviert

        if verify_ssl is False:
            print("Warning: SSL verification is disabled.")

        api_client = ApiClient(api_base_url, verify_ssl=verify_ssl, auth_token=sBuffyToken)
        print(f"Using API base URL: {api_base_url}")

        file_upload_success = []
        file_upload_failed = []

        for file in files_to_sync:
            # Prüfen, ob die Datei hochgeladen werden muss
            # Entweder: toUpload = True ODER changeState = "New"
            change_state = file.get("changeState", "").lower()
            should_upload = file.get("toUpload") is True or change_state == "new"
            
            # Überspringe gelöschte Dateien
            if change_state == "deleted":
                continue
            
            if should_upload:
                print(f"Upload File: {file.get('fileName')} - File Status: {file.get('changeState')} - File Größe: {file.get('size')} Bytes")

                # Wenn ja Upload starten
                try:
                    relative_path = file.get("relativePath")
                    full_path = f"{sync_path}/{relative_path.lstrip('/\\')}"  # Entferne führende / oder \ im Pfad

                    # Dateiinhalt lesen
                    with open(full_path, "rb") as f:
                        file_content = f.read()

                    # Extrahiere nur den Verzeichnis-Teil (ohne Dateinamen)
                    relative_dir = os.path.dirname(relative_path)

                    # API-Aufruf zum Hochladen der Datei
                    response = api_client.upload_files(
                        endpoint="upload",
                        files={"file": (file.get("fileName"), file_content)},
                        params={"basePath": relative_dir})

                    if response.get("status") == "success":
                        relative_path = file.get("relativePath")
                        client_hash = file.get("sha256")
                        server_hash = response.get("hash", "")

                        # Prüfe ob Client- und Server-Hash übereinstimmen
                        hash_match = client_hash == server_hash
                        if not hash_match:
                            print(f"  HASH MISMATCH for {file.get('fileName')}!")
                            print(f"    Client: {client_hash}")
                            print(f"    Server: {server_hash}")

                        # LastSyncState mit dem vom Server berechneten Hash aktualisieren,
                        # damit der nächste Manifest-Vergleich übereinstimmt
                        sync_state_manager = SyncStateManager()
                        sync_state_manager.update_sync_state(
                            file_path=relative_path,
                            hash_value=server_hash if server_hash else client_hash,
                            file_size=file.get("size")
                        )

                        # SyncFiles mit dem Server-Hash aktualisieren, damit der
                        # nächste Scan die Datei nicht erneut als geändert erkennt
                        db_handler = SqliteHandler()
                        db_handler.execute_query(
                            "UPDATE SyncFiles SET file_state = 'unchanged', hash_value = ? WHERE file_path = ?",
                            (server_hash if server_hash else client_hash, relative_path,)
                        )

                        status = "✓" if hash_match else "⚠ hash mismatch"
                        print(f"  Upload successful: {file.get('fileName')} [{status}] (Client: {client_hash[:8]}... | Server: {server_hash[:8] if server_hash else 'N/A'}...)")
                        file_upload_success.append(file)
                    else:
                        error_upload = f"Failed to upload file: {file.get('fileName')} - Reason: {response.get('message')}"
                        print(error_upload)
                        self.handle_error(error_upload)
                        file_upload_failed.append(file)

                except Exception as e:
                    error_message = f"Error uploading file: {file.get('fileName')} - Error: {str(e)}"
                    print(error_message)
                    file_upload_failed.append(file)

        print(f"\nSuccessful uploads: {len(file_upload_success)}")
        print(f"Failed uploads: {len(file_upload_failed)}")
        print("Upload process completed")