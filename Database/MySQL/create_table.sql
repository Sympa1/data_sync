--=============================================
--|                                           |
--| Enthält alle Tabellen der MySQL Datenbank |
--|                                           |
--=============================================

CREATE TABLE file (
    file_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    -- Für später user_id INTEGER REFERENCES user(user_id),
    path TEXT NOT NULL, -- Pfad vom Sync-Root-Verzeichnis
    size INTEGER NOT NULL, -- Dateigroeße in Bytes
    modification_time DATETIME DEFAULT NULL, -- Timestamp wann die Datei geändert wurde
    created_at DATETIME NOT NULL, -- Timestamp wann die Datei erstellt wurde
    hash TEXT NOT NULL, -- Hash der Datei
    state ENUM('synced', 'modified', 'conflict', 'deleted'), -- Zustand der Datei
    updated_at DATETIME -- Wann wurde die Datei das letzte mal geupdatet
);

CREATE TABLE sync_events(
    log_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    file_id INTEGER REFERENCES file(file_id),
    -- Für später device_id INTEGER REFERENCES device(device_id),
    action ENUM('download', 'upload', 'conflict', 'delete', 'error'), -- Was wurde beim synchronisieren gemacht
    timestamp TEXT,
    details TEXT -- Sonstige Infos
);