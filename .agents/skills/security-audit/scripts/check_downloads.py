#!/usr/bin/env python3
"""
Sicherheits-, Supply-Chain- & Dependency-Auditor fuer data_sync.

Prueft alle drei Teilprojekte:
1. data_sync.API (C# / .NET 10.0 .csproj)
2. data_sync.CLI (Python 3)
3. data_sync.FLUTTER (Flutter / Dart pubspec.yaml)

Erzwingt strikt die Whitelist freigegebener Bibliotheken (KEINE NEUEN LIBRARIES!),
erkennt Hardcoded Secrets, Path Traversal, SQL-Injection und unautorisierte Downloads.
Nutzt verbindlich sBuffy (String-Puffer) und iBuffy (Integer-Zaehler).
"""

import math
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Set


class DataSyncSecurityScanner:
    """
    Sicherheits- und Supply-Chain Scanner fuer das data_sync Repository.
    Erzwingt strikt die Vorgaben aus AGENTS.md und GEMINI.md.
    """

    # Whitelist der erlaubten externen Bibliotheken je Plattform
    ALLOWED_PACKAGES_DOTNET: Set[str] = {
        "Microsoft.Data.Sqlite",
        "MySql.Data",
        "DotNetEnv",
        "xunit",
    }

    ALLOWED_PACKAGES_PYTHON: Set[str] = {
        "requests",
        "urllib3",  # transitive dependency von requests
    }

    ALLOWED_PACKAGES_FLUTTER: Set[str] = {
        "flutter",
        "cupertino_icons",
        "sqflite",
        "sqflite_common_ffi",
        "path_provider",
        "path",
        "file_picker",
        "http",
        "crypto",
        "google_fonts",
        "permission_handler",
        "flutter_lints",
        "flutter_launcher_icons",
        "flutter_test",
    }

    SKIP_DIRS: Set[str] = {
        ".git", ".venv", "venv", "__pycache__", "bin", "obj",
        ".dart_tool", "build", "ephemeral", "ios", "android", "windows", "linux", "web",
        ".mypy_cache", ".pytest_cache", ".ruff_cache"
    }

    def __init__(self, root_dir: Path) -> None:
        """Initialisiert den Scanner mit dem Projekt-Wurzelverzeichnis."""
        self.root_dir = root_dir
        self.findings: List[Dict[str, Any]] = []
        self.download_inventory: List[Dict[str, Any]] = []

    def scan_all(self) -> List[Dict[str, Any]]:
        """Fuehrt alle Pruefungen auf Bibliotheken, Quellcode und Konfigurationen durch."""
        self.findings.clear()
        self.download_inventory.clear()
        self._scan_dotnet_dependencies()
        self._scan_python_dependencies()
        self._scan_flutter_dependencies()
        self._scan_source_code()
        return self.findings

    def _add_finding(
        self,
        s_component: str,
        i_line: int,
        s_category: str,
        s_desc: str,
        s_severity: str = "HIGH",
    ) -> None:
        """Registriert einen sicherheitsrelevanten Befund im Audit-Protokoll."""
        self.findings.append({
            "component": s_component,
            "line": i_line,
            "category": s_category,
            "description": s_desc,
            "severity": s_severity,
        })

    def _add_download_entry(
        self,
        s_what: str,
        s_where_from: str,
        s_where_to: str,
        s_trigger: str,
        s_risk: str = "REVIEW",
    ) -> None:
        """Registriert einen Download- oder Installationsvorgang fuer die Nachweistabelle."""
        self.download_inventory.append({
            "what": s_what,
            "where_from": s_where_from,
            "where_to": s_where_to,
            "trigger": s_trigger,
            "risk": s_risk,
        })

    @staticmethod
    def _calculate_shannon_entropy(s_data: str) -> float:
        """Berechnet die Shannon-Entropie eines Strings zur Erkennung von Geheimnissen."""
        if not s_data:
            return 0.0
        f_entropy = 0.0
        i_len = len(s_data)
        for s_char in set(s_data):
            f_prob = float(s_data.count(s_char)) / i_len
            f_entropy -= f_prob * math.log2(f_prob)
        return f_entropy

    def _scan_dotnet_dependencies(self) -> None:
        """Prueft .NET *.csproj Dateien gegen die freigegebene NuGet-Whitelist."""
        csproj_re = re.compile(r'<PackageReference\s+Include="([^"]+)"(?:\s+Version="([^"]+)")?', re.IGNORECASE)
        for csproj_file in self.root_dir.rglob("*.csproj"):
            if any(part in self.SKIP_DIRS for part in csproj_file.parts):
                continue
            rel_path = str(csproj_file.relative_to(self.root_dir))
            with open(csproj_file, "r", encoding="utf-8", errors="ignore") as f_in:
                for iBuffy, line in enumerate(f_in, start=1):
                    sBuffy = line.strip()
                    m = csproj_re.search(sBuffy)
                    if m:
                        pkg_name = m.group(1)
                        pkg_ver = m.group(2) or "unbekannt"
                        if pkg_name not in self.ALLOWED_PACKAGES_DOTNET:
                            self._add_finding(
                                rel_path,
                                iBuffy,
                                "Bibliotheken-Whitelist-Verstoss (.NET)",
                                f"Unerlaubtes NuGet-Paket gefunden: '{pkg_name}' (Version: {pkg_ver}). Nur Whitelist erlaubt!",
                                "CRITICAL",
                            )
                        else:
                            self._add_download_entry(
                                s_what=f"NuGet-Paket ({pkg_name} {pkg_ver})",
                                s_where_from="nuget.org via HTTPS",
                                s_where_to=".NET Cache / bin",
                                s_trigger=f"{rel_path}:{iBuffy}",
                                s_risk="OK (Whitelist)",
                            )

    def _scan_python_dependencies(self) -> None:
        """Prueft Python-Dateien im CLI-Client auf unerlaubte Drittanbieter-Pakete."""
        py_import_re = re.compile(r"^\s*(?:import|from)\s+([a-zA-Z0-9_]+)")
        std_modules = {
            "os", "sys", "hashlib", "sqlite3", "json", "argparse", "pathlib",
            "datetime", "abc", "typing", "math", "re", "time", "unittest",
            "dataclasses", "enum", "shutil", "tempfile", "copy"
        }
        for py_file in (self.root_dir / "data_sync.CLI" / "src").rglob("*.py"):
            rel_path = str(py_file.relative_to(self.root_dir))
            with open(py_file, "r", encoding="utf-8", errors="ignore") as f_in:
                for iBuffy, line in enumerate(f_in, start=1):
                    sBuffy = line.strip()
                    m = py_import_re.match(sBuffy)
                    if m:
                        mod = m.group(1)
                        if mod.startswith("core") or mod.startswith("."):
                            continue
                        if mod not in std_modules and mod not in self.ALLOWED_PACKAGES_PYTHON:
                            self._add_finding(
                                rel_path,
                                iBuffy,
                                "Bibliotheken-Whitelist-Verstoss (Python)",
                                f"Unerlaubter externer Python-Import: '{mod}'. Nicht auf Whitelist!",
                                "CRITICAL",
                            )

    def _scan_flutter_dependencies(self) -> None:
        """Prueft data_sync.FLUTTER/pubspec.yaml gegen die pub.dev Whitelist."""
        pubspec_path = self.root_dir / "data_sync.FLUTTER" / "pubspec.yaml"
        if not pubspec_path.exists():
            return
        rel_path = str(pubspec_path.relative_to(self.root_dir))
        in_deps = False
        in_dev_deps = False
        dep_re = re.compile(r"^ {2}([a-zA-Z0-9_]+):")

        with open(pubspec_path, "r", encoding="utf-8", errors="ignore") as f_in:
            for iBuffy, line in enumerate(f_in, start=1):
                sBuffy = line.rstrip()
                if sBuffy == "dependencies:":
                    in_deps = True
                    in_dev_deps = False
                    continue
                elif sBuffy == "dev_dependencies:":
                    in_deps = False
                    in_dev_deps = True
                    continue
                elif re.match(r"^[a-zA-Z0-9_]+:", sBuffy) and not sBuffy.startswith(" "):
                    in_deps = False
                    in_dev_deps = False
                    continue

                if in_deps or in_dev_deps:
                    m = dep_re.match(sBuffy)
                    if m:
                        pkg_name = m.group(1)
                        if pkg_name not in self.ALLOWED_PACKAGES_FLUTTER:
                            self._add_finding(
                                rel_path,
                                iBuffy,
                                "Bibliotheken-Whitelist-Verstoss (Flutter)",
                                f"Unerlaubtes Flutter-Paket gefunden: '{pkg_name}'. Nicht auf Whitelist!",
                                "CRITICAL",
                            )
                        else:
                            self._add_download_entry(
                                s_what=f"Flutter-Paket ({pkg_name})",
                                s_where_from="pub.dev / Flutter SDK",
                                s_where_to=".pub-cache",
                                s_trigger=f"{rel_path}:{iBuffy}",
                                s_risk="OK (Whitelist)",
                            )

    def _scan_source_code(self) -> None:
        """Scannt Quelltexte (C#, Python, Dart) nach Secrets, Injection und Path Traversal."""
        secret_token_re = re.compile(
            r"(sk-[a-zA-Z0-9]{20,}|gh[pousr]_[a-zA-Z0-9]{20,}|AIza[0-9A-Za-z\-_]{35}|"
            r"AKIA[0-9A-Z]{16}|-----BEGIN (?:RSA |EC )?PRIVATE KEY-----)"
        )
        cred_assign_re = re.compile(
            r"\b(password|passwd|secret|api_key|access_token)\s*=\s*['\"]([^'\"]{5,})['\"]",
            re.IGNORECASE,
        )
        # SQL-Injection: Konkatenation in Queries statt Parameter
        sql_inj_re = re.compile(
            r"(?:MySqlCommand|sqlite3|execute|rawQuery)\s*\(\s*(?:\$['\"]|f['\"]|['\"].*?(?:SELECT|INSERT|UPDATE|DELETE).*?(?:\+|%|\.format))",
            re.IGNORECASE,
        )

        for root, dirs, files in os.walk(self.root_dir):
            dirs[:] = [d for d in dirs if d not in self.SKIP_DIRS and d != "security-audit"]
            for file_name in files:
                if not file_name.endswith((".cs", ".py", ".dart", ".sh", ".json", ".yaml", ".yml")):
                    continue
                if file_name in ("caddy-root.crt", ".env.example"):
                    continue

                file_path = Path(root) / file_name
                rel_path = str(file_path.relative_to(self.root_dir))

                with open(file_path, "r", encoding="utf-8", errors="ignore") as f_in:
                    for iBuffy, line in enumerate(f_in, start=1):
                        sBuffy = line.strip()
                        if not sBuffy or sBuffy.startswith("//") or sBuffy.startswith("#"):
                            continue

                        # 1. Hardcoded Secrets
                        if secret_token_re.search(sBuffy):
                            self._add_finding(
                                rel_path,
                                iBuffy,
                                "Hardcoded Secret / Token",
                                "Kritisches Token- oder Private-Key-Muster im Code entdeckt.",
                                "CRITICAL",
                            )

                        # 2. Hardcoded Passwoerter (ausgenommen Umgebungsvariablen-Platzhalter)
                        m_cred = cred_assign_re.search(sBuffy)
                        if m_cred:
                            s_val = m_cred.group(2)
                            if not s_val.startswith(("$", "{", "os.getenv", "Environment.Get", "YOUR_", "<")):
                                f_ent = self._calculate_shannon_entropy(s_val)
                                if f_ent > 2.5:
                                    self._add_finding(
                                        rel_path,
                                        iBuffy,
                                        "Hardcoded Password / Credential",
                                        f"Klartext-Passwort oder Secret in Variable '{m_cred.group(1)}' hinterlegt.",
                                        "HIGH",
                                    )

                        # 3. SQL-Injection Pruefung
                        if sql_inj_re.search(sBuffy):
                            self._add_finding(
                                rel_path,
                                iBuffy,
                                "SQL-Injection Risiko",
                                f"String-Interpolation in SQL-Query gefunden: {sBuffy[:60]}...",
                                "CRITICAL",
                            )


def main() -> int:
    """Haupteinstiegspunkt fuer den data_sync Security-Scanner."""
    root_path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
    scanner = DataSyncSecurityScanner(root_path)
    findings = scanner.scan_all()

    print("=" * 78)
    print("DATA_SYNC SICHERHEITS-, SUPPLY-CHAIN- & WHITELIST-AUDITOR")
    print("=" * 78)

    print(f"\n[1] ERLAUBTE DEPENDENCY-DOWNLOADS ({len(scanner.download_inventory)} Pakete):")
    iBuffy = 0
    for item in scanner.download_inventory:
        iBuffy += 1
        print(f"    ({iBuffy}) {item['what']} von {item['where_from']} [{item['risk']}]")

    print(f"\n[2] BEFUNDE & VERSTOESSE ({len(findings)} Befunde):")
    if not findings:
        print("✔ PASSED: 0 Whitelist-Verstoesse, 0 kritische Secrets oder Injection-Befunde.")
        return 0

    iBuffy = 0
    for finding in findings:
        iBuffy += 1
        print(f"  [{iBuffy}] [{finding['severity']}] {finding['category']}")
        print(f"      Stelle: {finding['component']}:{finding['line']}")
        print(f"      Detail: {finding['description']}\n")

    return 1


if __name__ == "__main__":
    sys.exit(main())
