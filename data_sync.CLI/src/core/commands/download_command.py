import urllib3

from pathlib import Path
from .base_command import BaseCommand
from ..handlers.config_handler import ConfigHandler
from ..handlers.sqlite_handler import SqliteHandler
from .. import ApiClient
from ..sync_state_manager import SyncStateManager


class DownloadCommand(BaseCommand):
    """
    Command-Klasse zum Herunterladen von Dateien vom Remote-Server.
    Erbt von BaseCommand und implementiert die execute-Methode.
    """

    # Deaktivieren der InsecureRequestWarning, wenn SSL-Verifikation deaktiviert ist
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    def execute(self, files_to_sync):
        """
        Führt den Download der Dateien durch, die synchronisiert werden müssen.
        :param files_to_sync:
        :return:
        """
        print("\nDownload process started")

        # Aufruf der API um die Dateien herunterzuladen
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

        file_download_success = []
        file_download_failed = []

        for file in files_to_sync:
            # Prüfen, ob die Datei heruntergeladen werden muss
            if file.get("toDownload") is True:
                print(f"Download File: {file.get("fileName")} - File Status: {file.get("changeState")} - File Größe: {file.get("size")} Bytes")

                # Wenn ja Download starten
                try:
                    # API gibt Bytes direkt zurück (kein JSON!)
                    file_content = api_client.download_file(endpoint="download", params={"filePath": file.get("relativePath")})
                    
                    relative_path = file.get("relativePath")
                    full_path = Path(sync_path) / relative_path.lstrip("/\\")  # Entferne führende / oder \ im Pfad

                    # parents = Erstelle alle Notwendigen übergeordneten Verzeichnisse
                    # exist_ok = ignoriere es wenn das Verzeichnis bereits existiert
                    full_path.parent.mkdir(parents=True, exist_ok=True)

                    # Datei speichern
                    full_path.write_bytes(file_content)
                    
                    # LastSyncState aktualisieren nach erfolgreichem Download
                    sync_state_manager = SyncStateManager()
                    sync_state_manager.update_sync_state(
                        file_path=file.get("relativePath"),
                        hash_value=file.get("sha256"),
                        file_size=file.get("size")
                    )
                    
                    file_download_success.append(file)




                except Exception as e:
                    error_message = f"Error downloading file {file.get("fileName")}: {str(e)}"
                    print(error_message)
                    self.handle_error(error_message)
                    file_download_failed.append(file)


            else:
                continue

        print(f"Successful downloads: {len(file_download_success)}")
        print(f"Failed downloads: {len(file_download_failed)}")

        self.file_scanner(file_download_success)

        print("Download process completed")

    def file_scanner(self, file_list):
        scanned_files = []

        for file in file_list:
            file_path = file.get("relativePath").lstrip("/\\")  # Entferne führende / oder \ im Pfad

            db_handler = SqliteHandler()

            query_select = ("SELECT file_state "
                            "FROM SyncFiles "
                            "WHERE file_path = ?")
            result_select = db_handler.execute_query(query_select, (file_path,))

            if len(result_select) > 0:
                if result_select[0][0] != 'modified':
                    query_update_new = ("UPDATE SyncFiles "
                                        "SET file_state = 'new' "
                                        "WHERE file_path = ?")
                    db_handler.execute_query(query_update_new, (file_path,))
                else:
                    query_update_modified = ("UPDATE SyncFiles "
                                             "SET file_state = 'modified' "
                                             "WHERE file_path = ?")
                    db_handler.execute_query(query_update_modified, (file_path,))
            else:
                query_insert = ("INSERT INTO SyncFiles "
                                "(file_name, file_path, file_size, hash_value, file_state) "
                                "VALUES (?, ?, ?, ?, ?)")

                db_handler.execute_query(query_insert, (file.get("fileName"),
                                                        file.get("relativePath"),  # ✅ Korrigiert!
                                                        file.get("size"),
                                                        file.get("sha256"),
                                                        "new"))