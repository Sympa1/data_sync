-- SQLite PRAGMAs (für jede Verbindung empfohlen)
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;

-- 1. Benutzerverwaltung
CREATE TABLE IF NOT EXISTS Users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL COLLATE NOCASE UNIQUE,
    password_hash TEXT NOT NULL,
    password_salt TEXT NOT NULL,
    is_admin INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME
);

-- 2. Bearer-Tokens mit SHA-256 Hash
CREATE TABLE IF NOT EXISTS UserTokens (
    token_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    revoked INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_usertokens_hash ON UserTokens(token_hash);

-- 3. Synchronisations-Dateien je Benutzer
CREATE TABLE IF NOT EXISTS SyncFiles (
    sync_file_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    hash_value TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    file_state TEXT NOT NULL CHECK(file_state IN ('New', 'Modified', 'Unchanged', 'Deleted', 'Conflict')),
    UNIQUE(user_id, file_path)
);
CREATE INDEX IF NOT EXISTS idx_syncfiles_user_path ON SyncFiles(user_id, file_path);
CREATE INDEX IF NOT EXISTS idx_syncfiles_user_hash ON SyncFiles(user_id, hash_value);

-- 4. Letzter Sync-Zustand je Datei und Benutzer
CREATE TABLE IF NOT EXISTS LastSyncState (
    user_id INTEGER NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    hash_value TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    last_synced_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, file_path)
);

-- 5. Audit- und Sync-Events
CREATE TABLE IF NOT EXISTS SyncEvents (
    sync_event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,
    sync_file_id INTEGER NOT NULL REFERENCES SyncFiles(sync_file_id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK(event_type IN ('new', 'modified', 'deleted', 'error')),
    event_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_details TEXT
);

-- 6. Fehlerprotokoll
CREATE TABLE IF NOT EXISTS FehlerProtokoll (
    fehler_protokoll_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER REFERENCES Users(user_id) ON DELETE SET NULL,
    fehler_beschreibung TEXT NOT NULL,
    fehler_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
