import os
import tempfile
import unittest
from unittest.mock import MagicMock, patch

from core.api_client import ApiClient
from core.handlers.config_handler import ConfigHandler


class TestApiClient(unittest.TestCase):
    """
    Unit-Tests für ApiClient zur Verifikation von URL-Auflösung,
    Bearer-Token-Verwaltung und Header-Konfiguration.
    """

    def test_url_resolution(self):
        """Verifiziert die korrekte URL-Auflösung für Auth- und Sync-Routen."""
        # Test 1: Basis-URL ohne Pfad
        client1 = ApiClient("http://localhost:5000")
        self.assertEqual(client1._resolve_url("login"), "http://localhost:5000/api/auth/login")
        self.assertEqual(client1._resolve_url("manifest"), "http://localhost:5000/api/sync/manifest")
        self.assertEqual(client1._resolve_url("upload"), "http://localhost:5000/api/sync/upload")

        # Test 2: Abwärtskompatibilität wenn api_base_url auf /api/sync endet
        client2 = ApiClient("http://192.168.178.10:5000/api/sync")
        self.assertEqual(client2._resolve_url("manifest"), "http://192.168.178.10:5000/api/sync/manifest")
        self.assertEqual(client2._resolve_url("login"), "http://192.168.178.10:5000/api/auth/login")
        self.assertEqual(client2._resolve_url("me"), "http://192.168.178.10:5000/api/auth/me")

    def test_bearer_token_headers(self):
        """Prüft, ob gesetzte Bearer-Tokens im Authorization-Header übergeben werden."""
        sBuffyToken = "my_secret_token_12345"
        client = ApiClient("http://localhost:5000", auth_token=sBuffyToken)

        self.assertIn("Authorization", client.headers)
        self.assertEqual(client.headers["Authorization"], f"Bearer {sBuffyToken}")

        # Token entfernen / abmelden
        client.set_auth_token(None)
        self.assertNotIn("Authorization", client.headers)

    @patch("core.api_client.requests.post")
    def test_login_success(self, mock_post):
        """Simuliert erfolgreiches Login und Token-Speicherung im Client."""
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "token": "test_token_abc",
            "userId": 42,
            "username": "tester",
            "isAdmin": False
        }
        mock_post.return_value = mock_resp

        client = ApiClient("http://localhost:5000")
        result = client.login("tester", "SecretPassword!")

        self.assertEqual(result["userId"], 42)
        self.assertEqual(client.auth_token, "test_token_abc")
        self.assertEqual(client.headers["Authorization"], "Bearer test_token_abc")


class TestConfigHandler(unittest.TestCase):
    """
    Unit-Tests für ConfigHandler mit temporärer JSON-Konfigurationsdatei.
    """

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.config_path = os.path.join(self.temp_dir.name, "test_config.json")

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_config_read_write(self):
        """Prüft das Schreiben und Auslesen von Konfigurationswerten."""
        handler = ConfigHandler(filename=self.config_path)
        handler.set_config("api_base_url", "http://127.0.0.1:5000")
        handler.set_config("auth_token", "saved_token_xyz")

        # Neu laden aus Datei
        handler_reload = ConfigHandler(filename=self.config_path)
        sBuffyUrl = handler_reload.get_config("api_base_url")
        sBuffyToken = handler_reload.get_config("auth_token")

        self.assertEqual(sBuffyUrl, "http://127.0.0.1:5000")
        self.assertEqual(sBuffyToken, "saved_token_xyz")


if __name__ == "__main__":
    unittest.main()
