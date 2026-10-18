from pathlib import Path
from .base_command import BaseCommand
from ..handlers.config_handler import ConfigHandler
from ..handlers.sqlite_handler import SqliteHandler
from .. import ApiClient
from ..sync_state_manager import SyncStateManager


class DeleteCommand(BaseCommand):
    """
    Command zum Synchronisieren von Löschungen zwischen Client und Server.
    Behandelt sowohl lokale Löschungen (an Server senden) als auch
    Server-Löschungen (lokal ausführen).
    """

    def execute(self, files_to_sync):
        """
        Führt die Synchronisation von Löschungen durch.
        :param files_to_sync: Liste der zu synchronisierenden Dateien vom Server
        :return: None
        """
        print("\nDelete synchronization started")

        # 1. Server-initiierte Löschungen lokal ausführen
        self._process_remote_deletions(files_to_sync)

        # 2. Lokal gelöschte Dateien an Server melden
        self._process_local_deletions()

        print("Delete synchronization completed")

    def _process_remote_deletions(self, files_to_sync):
        """
        Verarbeitet alle Dateien, die vom Server als gelöscht markiert wurden.
        :param files_to_sync: Liste der Dateien vom Manifest-Response
        """
        config_handler = ConfigHandler()
        sync_path = config_handler.get_config("sync_path")
        db_handler = SqliteHandler()
        sync_state_manager = SyncStateManager()

        deletion_count = 0

        for file in files_to_sync:
            if file.get("toDelete") is True:
                try:
                    self.delete_local_file(
                        file_info=file,
                        sync_path=sync_path,
                        db_handler=db_handler,
                        sync_state_manager=sync_state_manager
                    )
                    deletion_count += 1

                except Exception as e:
                    error_message = f"Error deleting local file {file.get('fileName')}: {str(e)}"
                    print(error_message)
                    self.handle_error(error_message)

        print(f"Local deletions processed: {deletion_count}")

    def _process_local_deletions(self):
        """
        Findet lokal gelöschte Dateien und sendet DELETE-Requests an den Server.
        """
        config_handler = ConfigHandler()
        api_base_url = config_handler.get_config("api_base_url")
        sBuffyToken = config_handler.get_config("auth_token")
        verify_ssl = config_handler.get_config("verify_ssl")
        
        if verify_ssl is None:
            verify_ssl = True

        api_client = ApiClient(api_base_url, verify_ssl=verify_ssl, auth_token=sBuffyToken)
        db_handler = SqliteHandler()
        sync_state_manager = SyncStateManager()

        # Finde alle lokal gelöschten Dateien
        query = "SELECT file_path FROM SyncFiles WHERE file_state = 'deleted'"
        deleted_files = db_handler.execute_query(query)

        deletion_count = 0

        for row in deleted_files:
            file_path = row[0]

            # Prüfe: War diese Datei beim letzten Sync vorhanden?
            last_sync_state = sync_state_manager.get_sync_state(file_path)

            if last_sync_state:
                # Datei war beim letzten Sync vorhanden → wurde seit dem gelöscht
                try:
                    self.delete_file_on_server(
                        file_path=file_path,
                        api_client=api_client,
                        sync_state_manager=sync_state_manager
                    )
                    deletion_count += 1

                except Exception as e:
                    error_message = f"Error deleting file on server {file_path}: {str(e)}"
                    print(error_message)
                    self.handle_error(error_message)

        print(f"Server deletions processed: {deletion_count}")

    def delete_local_file(self, file_info: dict, sync_path: str, db_handler, sync_state_manager):
        """
        Löscht eine Datei lokal, die auf dem Server gelöscht wurde.
        :param file_info: Dictionary mit Datei-Informationen
        :param sync_path: Basis-Pfad des Sync-Ordners
        :param db_handler: SQLite Handler Instanz
        :param sync_state_manager: SyncStateManager Instanz
        """
        relative_path = file_info.get("relativePath")
        file_name = file_info.get("fileName")

        print(f"Server requests deletion: {file_name}")

        # Vollständigen Pfad erstellen
        full_path = Path(sync_path) / relative_path.lstrip("/\\")

        # Datei lokal löschen falls sie existiert
        if full_path.exists():
            full_path.unlink()
            print(f"Deleted locally: {relative_path}")
        else:
            print(f"ℹFile already deleted: {relative_path}")

        # Datenbank aktualisieren
        query = "UPDATE SyncFiles SET file_state = 'deleted' WHERE file_path = ?"
        db_handler.execute_query(query, (relative_path,))

        # LastSyncState löschen (Datei ist beidseitig gelöscht)
        sync_state_manager.delete_sync_state(relative_path)

    def delete_file_on_server(self, file_path: str, api_client, sync_state_manager):
        """
        Sendet einen DELETE-Request an den Server für eine lokal gelöschte Datei.
        :param file_path: Relativer Pfad der Datei
        :param api_client: ApiClient Instanz
        :param sync_state_manager: SyncStateManager Instanz
        """
        print(f"Sending DELETE to server: {file_path}")

        # DELETE-Request an Server senden
        response = api_client.delete_file(
            endpoint="delete",
            params={"filePath": file_path}
        )

        if response.get("status") == "success":
            print(f"Server deletion successful: {file_path}")

            # LastSyncState löschen (Datei ist beidseitig gelöscht)
            sync_state_manager.delete_sync_state(file_path)
        else:
            raise RuntimeError(f"Server deletion failed: {response.get('message', 'Unknown error')}")
