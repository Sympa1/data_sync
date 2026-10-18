import getpass
import sys
from typing import Optional
from .base_command import BaseCommand
from ..handlers.config_handler import ConfigHandler
from ..api_client import ApiClient


class AuthCommand(BaseCommand):
    """
    Command für Authentifizierungs-Operationen (Login, Registrierung, Status, Logout).
    Verwaltet das lokale Bearer-Token in der config.json.
    """

    def __init__(self):
        super().__init__()
        self.config_handler = ConfigHandler()

    def _get_api_client(self) -> ApiClient:
        """Erstellt eine konfigurierte ApiClient-Instanz."""
        sBuffyBaseUrl = self.config_handler.get_config("api_base_url") or "http://localhost:5000"
        bVerifySsl = self.config_handler.get_config("verify_ssl")
        if bVerifySsl is None:
            bVerifySsl = True
        sBuffyToken = self.config_handler.get_config("auth_token")
        return ApiClient(sBuffyBaseUrl, verify_ssl=bVerifySsl, auth_token=sBuffyToken)

    def execute(self):
        """Standard-Ausführung: Prüft den Login-Status."""
        self.whoami()

    def login(self, username: Optional[str] = None, password: Optional[str] = None):
        """
        Führt das Login durch und speichert das empfangene Bearer-Token.
        """
        print("\n=== data_sync CLI: Anmeldung ===")
        if not username:
            username = input("Benutzername: ").strip()
        if not password:
            password = getpass.getpass("Passwort: ")

        if not username or not password:
            print("Fehler: Benutzername und Passwort dürfen nicht leer sein.")
            return False

        try:
            api_client = self._get_api_client()
            resp = api_client.login(username, password)

            sBuffyToken = resp.get("token") or resp.get("Token")
            iBuffyUserId = resp.get("userId") or resp.get("UserId")
            sBuffyUname = resp.get("username") or resp.get("Username") or username
            bIsAdmin = resp.get("isAdmin") or resp.get("IsAdmin") or False

            # Konfiguration mit neuem Token und Benutzerdaten aktualisieren
            self.config_handler.set_config("auth_token", sBuffyToken)
            self.config_handler.set_config("user_id", iBuffyUserId)
            self.config_handler.set_config("username", sBuffyUname)

            print(f"\n✓ Erfolgreich angemeldet als '{sBuffyUname}' (User-ID: {iBuffyUserId}, Admin: {bIsAdmin})")
            print("Das Bearer-Token wurde in config.json gesichert.")
            return True

        except Exception as ex:
            sBuffyErr = f"Anmeldung fehlgeschlagen: {ex}"
            print(f"\n✗ {sBuffyErr}")
            self.handle_error(sBuffyErr)
            return False

    def register(self, username: Optional[str] = None, password: Optional[str] = None):
        """
        Registriert einen neuen Benutzer und speichert das resultierende Token.
        """
        print("\n=== data_sync CLI: Registrierung ===")
        if not username:
            username = input("Gewünschter Benutzername: ").strip()
        if not password:
            password = getpass.getpass("Passwort (mind. 6 Zeichen): ")
            password_confirm = getpass.getpass("Passwort wiederholen: ")
            if password != password_confirm:
                print("Fehler: Passwörter stimmen nicht überein.")
                return False

        if not username or not password:
            print("Fehler: Benutzername und Passwort sind erforderlich.")
            return False

        try:
            api_client = self._get_api_client()
            resp = api_client.register(username, password)

            sBuffyToken = resp.get("token") or resp.get("Token")
            iBuffyUserId = resp.get("userId") or resp.get("UserId")
            sBuffyUname = resp.get("username") or resp.get("Username") or username
            bIsAdmin = resp.get("isAdmin") or resp.get("IsAdmin") or False

            self.config_handler.set_config("auth_token", sBuffyToken)
            self.config_handler.set_config("user_id", iBuffyUserId)
            self.config_handler.set_config("username", sBuffyUname)

            print(f"\n✓ Benutzer '{sBuffyUname}' erfolgreich registriert und angemeldet!")
            print(f"User-ID: {iBuffyUserId} (Admin: {bIsAdmin})")
            return True

        except Exception as ex:
            sBuffyErr = f"Registrierung fehlgeschlagen: {ex}"
            print(f"\n✗ {sBuffyErr}")
            self.handle_error(sBuffyErr)
            return False

    def whoami(self):
        """
        Prüft den aktuellen Authentifizierungs-Status gegen den Server.
        """
        sBuffyToken = self.config_handler.get_config("auth_token")
        if not sBuffyToken:
            print("\nNicht angemeldet. Bitte führe 'python3 main.py --login' aus.")
            return False

        try:
            api_client = self._get_api_client()
            profile = api_client.get_me()
            sBuffyUname = profile.get("username") or profile.get("Username")
            iBuffyUid = profile.get("userId") or profile.get("UserId")
            bAdmin = profile.get("isAdmin") or profile.get("IsAdmin")

            print(f"\n✓ Angemeldet als: {sBuffyUname} (User-ID: {iBuffyUid}, Admin: {bAdmin})")
            return True

        except Exception as ex:
            print(f"\n✗ Authentifizierung ungültig oder abgelaufen: {ex}")
            print("Bitte melde dich erneut an mit: python3 main.py --login")
            return False

    def logout(self):
        """
        Meldet den Benutzer ab und entfernt das Token.
        """
        try:
            api_client = self._get_api_client()
            api_client.logout()
        except Exception:
            pass

        self.config_handler.set_config("auth_token", None)
        self.config_handler.set_config("username", None)
        self.config_handler.set_config("user_id", None)
        print("\n✓ Erfolgreich abgemeldet. Lokales Token entfernt.")
        return True
