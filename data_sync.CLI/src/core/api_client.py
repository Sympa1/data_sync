import json
from typing import Any, Dict, Optional, Union
import requests


class ApiClient:
    """
    API-Client zur Kommunikation mit der data_sync REST-API.
    Unterstützt Authentifizierung via Bearer-Token, Dateitransfers (Upload/Download),
    Manifest-Abgleich und Authentifizierungs-Endpunkte (/api/auth/*).
    """

    def __init__(self, base_url: str, verify_ssl: bool = True, auth_token: Optional[str] = None):
        """
        Initialisiert den ApiClient mit Basis-URL, SSL-Flag und optionalem Bearer-Token.
        Normalisiert die Server-URL so, dass sowohl /api/sync als auch die Root-URL unterstützt werden.
        """
        self.base_url = base_url.rstrip("/")
        self.verify_ssl = verify_ssl
        self.auth_token = auth_token

        # Ermittle Server-Root (z.B. http://localhost:5000)
        sBuffyUrl = self.base_url
        if sBuffyUrl.endswith("/api/sync"):
            sBuffyUrl = sBuffyUrl[:-9]
        elif sBuffyUrl.endswith("/api"):
            sBuffyUrl = sBuffyUrl[:-4]
        self.server_root = sBuffyUrl

        # Standard-Header inkl. Bearer-Token konfigurieren
        self.headers: Dict[str, str] = {}
        if self.auth_token:
            self.headers["Authorization"] = f"Bearer {self.auth_token}"

    def set_auth_token(self, token: Optional[str]) -> None:
        """
        Aktualisiert das aktive Bearer-Token im Client.
        """
        self.auth_token = token
        if token:
            self.headers["Authorization"] = f"Bearer {token}"
        elif "Authorization" in self.headers:
            del self.headers["Authorization"]

    def _resolve_url(self, endpoint: str) -> str:
        """
        Löst den vollständigen URL-Pfad für API-Endpunkte auf.
        Unterscheidet fachlich zwischen Auth- und Sync-Routen.
        """
        sBuffyCleanEndpoint = endpoint.strip("/")
        if sBuffyCleanEndpoint.startswith("api/"):
            return f"{self.server_root}/{sBuffyCleanEndpoint}"
        elif sBuffyCleanEndpoint in ("register", "login", "me", "logout"):
            return f"{self.server_root}/api/auth/{sBuffyCleanEndpoint}"
        elif sBuffyCleanEndpoint in ("manifest", "upload", "download", "delete"):
            return f"{self.server_root}/api/sync/{sBuffyCleanEndpoint}"
        return f"{self.base_url}/{sBuffyCleanEndpoint}"

    def register(self, username: str, password: str) -> Dict[str, Any]:
        """
        Registriert einen neuen Benutzer über /api/auth/register.
        """
        sBuffyUrl = self._resolve_url("register")
        response = requests.post(
            sBuffyUrl,
            json={"username": username, "password": password},
            verify=self.verify_ssl,
            timeout=15
        )
        response.raise_for_status()
        return response.json()

    def login(self, username: str, password: str) -> Dict[str, Any]:
        """
        Meldet einen Benutzer über /api/auth/login an und setzt das Token im Client.
        """
        sBuffyUrl = self._resolve_url("login")
        response = requests.post(
            sBuffyUrl,
            json={"username": username, "password": password},
            verify=self.verify_ssl,
            timeout=15
        )
        response.raise_for_status()
        data = response.json()
        sBuffyToken = data.get("token") or data.get("Token")
        if sBuffyToken:
            self.set_auth_token(sBuffyToken)
        return data

    def get_me(self) -> Dict[str, Any]:
        """
        Ruft das eigene Benutzerprofil über /api/auth/me ab.
        """
        sBuffyUrl = self._resolve_url("me")
        response = requests.get(
            sBuffyUrl,
            headers=self.headers,
            verify=self.verify_ssl,
            timeout=15
        )
        response.raise_for_status()
        return response.json()

    def logout(self) -> bool:
        """
        Meldet den Benutzer über /api/auth/logout ab und widerruft das Token auf dem Server.
        """
        sBuffyUrl = self._resolve_url("logout")
        try:
            response = requests.post(
                sBuffyUrl,
                headers=self.headers,
                verify=self.verify_ssl,
                timeout=15
            )
            self.set_auth_token(None)
            return response.status_code == 200
        except Exception:
            self.set_auth_token(None)
            return False

    def get(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> Any:
        """
        Führt einen authentifizierten GET-Request an die API aus.
        """
        sBuffyUrl = self._resolve_url(endpoint)
        response = requests.get(
            sBuffyUrl,
            params=params,
            headers=self.headers,
            verify=self.verify_ssl,
            timeout=30
        )
        response.raise_for_status()
        return response.json()

    def post(self, endpoint: str, json: Any = None, params: Optional[Dict[str, Any]] = None) -> Any:
        """
        Führt einen authentifizierten POST-Request mit JSON-Body aus.
        """
        sBuffyUrl = self._resolve_url(endpoint)
        response = requests.post(
            sBuffyUrl,
            json=json,
            params=params,
            headers=self.headers,
            verify=self.verify_ssl,
            timeout=60
        )
        response.raise_for_status()
        return response.json()

    def put(self, endpoint: str, data: Any = None, params: Optional[Dict[str, Any]] = None) -> Any:
        """
        Führt einen authentifizierten PUT-Request aus.
        """
        sBuffyUrl = self._resolve_url(endpoint)
        response = requests.put(
            sBuffyUrl,
            json=data,
            params=params,
            headers=self.headers,
            verify=self.verify_ssl,
            timeout=30
        )
        response.raise_for_status()
        return response.json()

    def delete(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> Any:
        """
        Führt einen authentifizierten DELETE-Request aus.
        """
        sBuffyUrl = self._resolve_url(endpoint)
        response = requests.delete(
            sBuffyUrl,
            params=params,
            headers=self.headers,
            verify=self.verify_ssl,
            timeout=30
        )
        response.raise_for_status()
        return response.json()

    def upload_files(self, endpoint: str, files: Any, params: Optional[Dict[str, Any]] = None) -> Any:
        """
        Lädt eine Datei multipart/form-data an den Ziel-Endpunkt hoch.
        """
        sBuffyUrl = self._resolve_url(endpoint)
        # Für multipart/form-data setzt requests den Content-Type Boundary selbst,
        # daher nur Authorization-Header übergeben
        headers = dict(self.headers)
        response = requests.post(
            sBuffyUrl,
            files=files,
            params=params,
            headers=headers,
            verify=self.verify_ssl,
            timeout=120
        )
        response.raise_for_status()
        return response.json()

    def download_file(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> bytes:
        """
        Lädt Dateiinhalte als Binärdaten vom Server herunter.
        """
        sBuffyUrl = self._resolve_url(endpoint)
        response = requests.get(
            sBuffyUrl,
            params=params,
            headers=self.headers,
            verify=self.verify_ssl,
            timeout=120
        )
        response.raise_for_status()
        return response.content

    def delete_file(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> Any:
        """
        Löscht eine Datei auf dem Remote-Server.
        """
        if params is None or "filePath" not in params:
            raise ValueError("Parameter 'filePath' ist für delete_file() erforderlich.")

        sBuffyUrl = self._resolve_url(endpoint)
        try:
            response = requests.delete(
                sBuffyUrl,
                params=params,
                headers=self.headers,
                verify=self.verify_ssl,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"DELETE-Request für {params.get('filePath')} fehlgeschlagen: {e}")
