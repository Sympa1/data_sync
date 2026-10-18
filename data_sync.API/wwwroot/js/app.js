/**
 * data_sync Web Dashboard - Client-Logik (Vanilla ES6 JavaScript)
 */

let currentTab = 'dashboard';
let isRegisterMode = false;

// Initialisierung beim Laden der Seite
document.addEventListener('DOMContentLoaded', () => {
    checkAuthSession();
});

// ==========================================
// 1. Authentifizierung & Session-Handling
// ==========================================

function getAuthToken() {
    return localStorage.getItem('data_sync_token');
}

function setAuthSession(token, username, isAdmin, userId) {
    localStorage.setItem('data_sync_token', token);
    localStorage.setItem('data_sync_username', username);
    localStorage.setItem('data_sync_is_admin', isAdmin ? 'true' : 'false');
    localStorage.setItem('data_sync_user_id', userId.toString());
}

function clearAuthSession() {
    localStorage.removeItem('data_sync_token');
    localStorage.removeItem('data_sync_username');
    localStorage.removeItem('data_sync_is_admin');
    localStorage.removeItem('data_sync_user_id');
}

async function checkAuthSession() {
    const sBuffyToken = getAuthToken();
    if (!sBuffyToken) {
        showLoginModal();
        return;
    }

    try {
        const response = await fetch('/api/auth/me', {
            headers: { 'Authorization': `Bearer ${sBuffyToken}` }
        });

        if (response.ok) {
            const user = await response.json();
            setAuthSession(sBuffyToken, user.Username, user.IsAdmin, user.UserId);
            showAppLayout(user.Username, user.IsAdmin);
            loadDashboardStats();
        } else {
            clearAuthSession();
            showLoginModal();
        }
    } catch (err) {
        console.error('Session-Prüfung fehlgeschlagen:', err);
        showLoginModal();
    }
}

function showLoginModal() {
    document.getElementById('login-modal').style.display = 'flex';
    document.getElementById('app-container').style.display = 'none';
}

function showAppLayout(username, isAdmin) {
    document.getElementById('login-modal').style.display = 'none';
    document.getElementById('app-container').style.display = 'flex';

    document.getElementById('current-user-name').textContent = username;
    document.getElementById('current-user-role').textContent = isAdmin ? 'Administrator' : 'Benutzer';
    document.getElementById('current-user-avatar').textContent = username.charAt(0).toUpperCase();

    switchTab('dashboard');
}

function toggleAuthMode() {
    isRegisterMode = !isRegisterMode;
    const title = document.querySelector('.modal-header h2');
    const subtitle = document.getElementById('auth-subtitle');
    const submitBtn = document.getElementById('auth-submit-btn');
    const toggleText = document.getElementById('auth-toggle-text');
    const toggleBtn = document.querySelector('.auth-toggle .btn-link');

    if (isRegisterMode) {
        title.textContent = 'Administrator registrieren';
        subtitle.textContent = 'Erstellen Sie das erste Administratorkonto auf diesem Server.';
        submitBtn.textContent = 'Registrieren & Starten';
        toggleText.textContent = 'Bereits registriert?';
        toggleBtn.textContent = 'Hier anmelden';
    } else {
        title.textContent = 'data_sync Dashboard';
        subtitle.textContent = 'Bitte melden Sie sich mit Ihren Zugangsdaten an.';
        submitBtn.textContent = 'Anmelden';
        toggleText.textContent = 'Noch kein Konto?';
        toggleBtn.textContent = 'Hier registrieren';
    }

    document.getElementById('auth-error').style.display = 'none';
}

async function handleAuth(event) {
    event.preventDefault();
    const sBuffyUsername = document.getElementById('auth-username').value.trim();
    const sBuffyPassword = document.getElementById('auth-password').value;
    const errBox = document.getElementById('auth-error');

    errBox.style.display = 'none';
    const sBuffyEndpoint = isRegisterMode ? '/api/auth/register' : '/api/auth/login';

    try {
        const response = await fetch(sBuffyEndpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ Username: sBuffyUsername, Password: sBuffyPassword })
        });

        const data = await response.json();

        if (response.ok) {
            setAuthSession(data.Token, data.Username, data.IsAdmin, data.UserId);
            showAppLayout(data.Username, data.IsAdmin);
            loadDashboardStats();
            showToast(`Willkommen, ${data.Username}!`);
        } else {
            errBox.textContent = data.message || 'Authentifizierung fehlgeschlagen.';
            errBox.style.display = 'block';
        }
    } catch (err) {
        errBox.textContent = 'Netzwerkfehler: Server nicht erreichbar.';
        errBox.style.display = 'block';
    }
}

async function logout() {
    const sBuffyToken = getAuthToken();
    if (sBuffyToken) {
        try {
            await fetch('/api/auth/logout', {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${sBuffyToken}` }
            });
        } catch (e) {}
    }

    clearAuthSession();
    showLoginModal();
    showToast('Erfolgreich abgemeldet.');
}

// ==========================================
// 2. Tab-Navigation & Routing
// ==========================================

function switchTab(tabName) {
    currentTab = tabName;

    document.querySelectorAll('.nav-item').forEach(btn => btn.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(tab => tab.classList.remove('active'));

    const tabBtnMap = {
        'dashboard': 0,
        'users': 1,
        'files': 2,
        'logs': 3
    };

    const navBtns = document.querySelectorAll('.sidebar-nav .nav-item');
    if (navBtns[tabBtnMap[tabName]]) {
        navBtns[tabBtnMap[tabName]].classList.add('active');
    }

    const tabEl = document.getElementById(`tab-${tabName}`);
    if (tabEl) {
        tabEl.classList.add('active');
    }

    const titles = {
        'dashboard': 'Dashboard-Übersicht',
        'users': 'Benutzerverwaltung',
        'files': 'Dateien im Vault-Speicher',
        'logs': 'System- und Fehlerprotokolle'
    };
    document.getElementById('page-title').textContent = titles[tabName] || 'Dashboard';

    refreshCurrentTab();
}

function refreshCurrentTab() {
    if (currentTab === 'dashboard') loadDashboardStats();
    else if (currentTab === 'users') loadUsersList();
    else if (currentTab === 'files') loadFilesList();
    else if (currentTab === 'logs') loadLogsList();
}

// ==========================================
// 3. API-Aufrufe mit Autorisierung
// ==========================================

async function fetchAuthorized(url, options = {}) {
    const sBuffyToken = getAuthToken();
    if (!sBuffyToken) {
        showLoginModal();
        throw new Error('Nicht authentifiziert.');
    }

    options.headers = options.headers || {};
    options.headers['Authorization'] = `Bearer ${sBuffyToken}`;

    const response = await fetch(url, options);

    if (response.status === 401) {
        clearAuthSession();
        showLoginModal();
        showToast('Sitzung abgelaufen. Bitte erneut anmelden.', true);
        throw new Error('Unauthorized');
    }

    if (response.status === 403) {
        showToast('Zugriff verweigert: Administratorrechte erforderlich.', true);
        throw new Error('Forbidden');
    }

    return response;
}

// ==========================================
// 4. Tab 1: Dashboard Statistiken
// ==========================================

async function loadDashboardStats() {
    try {
        const response = await fetchAuthorized('/api/admin/stats');
        if (!response.ok) return;

        const data = await response.json();

        document.getElementById('stat-users').textContent = data.TotalUsers;
        document.getElementById('stat-files').textContent = data.TotalFiles;
        document.getElementById('stat-storage').textContent = formatBytes(data.TotalStorageBytes);
        document.getElementById('stat-dbsize').textContent = formatBytes(data.DatabaseSizeBytes);
        document.getElementById('server-time').textContent = `Server: ${data.ServerTime}`;
    } catch (err) {
        console.error('Fehler beim Laden der Statistiken:', err);
    }
}

// ==========================================
// 5. Tab 2: Benutzerverwaltung
// ==========================================

async function loadUsersList() {
    const tbody = document.getElementById('users-table-body');
    tbody.innerHTML = '<tr><td colspan="8" class="text-center">Lade Benutzer...</td></tr>';

    try {
        const response = await fetchAuthorized('/api/admin/users');
        if (!response.ok) return;

        const users = await response.json();
        const currentUserId = parseInt(localStorage.getItem('data_sync_user_id') || '0', 10);

        if (users.length === 0) {
            tbody.innerHTML = '<tr><td colspan="8" class="text-center">Keine Benutzer vorhanden.</td></tr>';
            return;
        }

        let sBuffyHtml = '';
        const userSelect = document.getElementById('filter-user');
        userSelect.innerHTML = '<option value="">Alle Benutzer</option>';

        users.forEach(u => {
            // Dropdown für Datei-Filter befüllen
            userSelect.innerHTML += `<option value="${u.UserId}">${escapeHtml(u.Username)} (ID ${u.UserId})</option>`;

            const roleBadge = u.IsAdmin 
                ? '<span class="badge badge-admin">Admin</span>' 
                : '<span class="badge badge-user">User</span>';

            const lastLogin = u.LastLogin ? formatDate(u.LastLogin) : '<span style="color:var(--text-muted)">Nie</span>';

            const deleteBtn = (u.UserId === currentUserId)
                ? '<span style="color:var(--text-muted); font-size:0.8rem">Aktives Konto</span>'
                : `<button class="btn btn-danger btn-sm" onclick="deleteUser(${u.UserId}, '${escapeHtml(u.Username)}')">🗑️ Löschen</button>`;

            sBuffyHtml += `
                <tr>
                    <td><strong>#${u.UserId}</strong></td>
                    <td>${escapeHtml(u.Username)}</td>
                    <td>${roleBadge}</td>
                    <td>${formatDate(u.CreatedAt)}</td>
                    <td>${lastLogin}</td>
                    <td>${u.FileCount}</td>
                    <td>${formatBytes(u.StorageBytes)}</td>
                    <td>${deleteBtn}</td>
                </tr>
            `;
        });

        tbody.innerHTML = sBuffyHtml;
    } catch (err) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center" style="color:var(--danger)">Fehler beim Laden der Benutzer.</td></tr>';
    }
}

function openCreateUserModal() {
    document.getElementById('new-username').value = '';
    document.getElementById('new-password').value = '';
    document.getElementById('new-is-admin').checked = false;
    document.getElementById('create-user-error').style.display = 'none';
    document.getElementById('create-user-modal').style.display = 'flex';
}

function closeCreateUserModal() {
    document.getElementById('create-user-modal').style.display = 'none';
}

async function handleCreateUser(event) {
    event.preventDefault();
    const username = document.getElementById('new-username').value.trim();
    const password = document.getElementById('new-password').value;
    const isAdmin = document.getElementById('new-is-admin').checked;
    const errBox = document.getElementById('create-user-error');

    errBox.style.display = 'none';

    try {
        const response = await fetchAuthorized('/api/admin/users', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ Username: username, Password: password, IsAdmin: isAdmin })
        });

        const data = await response.json();

        if (response.ok) {
            closeCreateUserModal();
            showToast(`Benutzer '${username}' erfolgreich erstellt!`);
            loadUsersList();
            loadDashboardStats();
        } else {
            errBox.textContent = data.message || 'Erstellung fehlgeschlagen.';
            errBox.style.display = 'block';
        }
    } catch (err) {
        errBox.textContent = 'Netzwerkfehler.';
        errBox.style.display = 'block';
    }
}

async function deleteUser(userId, username) {
    if (!confirm(`Möchten Sie den Benutzer '${username}' und alle seine synchronisierten Dateien unwiderruflich löschen?`)) {
        return;
    }

    try {
        const response = await fetchAuthorized(`/api/admin/users/${userId}`, {
            method: 'DELETE'
        });

        const data = await response.json();

        if (response.ok) {
            showToast(`Benutzer '${username}' gelöscht.`);
            loadUsersList();
            loadDashboardStats();
        } else {
            showToast(data.message || 'Löschen fehlgeschlagen.', true);
        }
    } catch (err) {
        showToast('Fehler bei der Kommunikation mit dem Server.', true);
    }
}

// ==========================================
// 6. Tab 3: Datei-Explorer
// ==========================================

async function loadFilesList() {
    const tbody = document.getElementById('files-table-body');
    tbody.innerHTML = '<tr><td colspan="7" class="text-center">Lade Dateien...</td></tr>';

    const userIdFilter = document.getElementById('filter-user').value;
    const sBuffyUrl = userIdFilter ? `/api/admin/files?userId=${userIdFilter}` : '/api/admin/files';

    try {
        const response = await fetchAuthorized(sBuffyUrl);
        if (!response.ok) return;

        const files = await response.json();

        if (files.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" class="text-center">Keine Dateien im Vault gespeichert.</td></tr>';
            return;
        }

        let sBuffyHtml = '';
        files.forEach(f => {
            const hashPreview = f.HashValue ? `${f.HashValue.substring(0, 10)}...` : '-';
            sBuffyHtml += `
                <tr>
                    <td><span class="badge badge-user">${escapeHtml(f.Username)}</span></td>
                    <td><strong>${escapeHtml(f.FileName)}</strong></td>
                    <td style="color:var(--text-secondary); font-family:monospace">${escapeHtml(f.FilePath)}</td>
                    <td>${formatBytes(f.FileSize)}</td>
                    <td><span class="badge-state">${f.FileState}</span></td>
                    <td>${formatDate(f.LastModified)}</td>
                    <td style="font-family:monospace; color:var(--text-muted)" title="${f.HashValue}">${hashPreview}</td>
                </tr>
            `;
        });

        tbody.innerHTML = sBuffyHtml;
    } catch (err) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center" style="color:var(--danger)">Fehler beim Laden der Dateien.</td></tr>';
    }
}

// ==========================================
// 7. Tab 4: System-Protokolle
// ==========================================

async function loadLogsList() {
    const tbody = document.getElementById('logs-table-body');
    tbody.innerHTML = '<tr><td colspan="3" class="text-center">Lade Protokolle...</td></tr>';

    try {
        const response = await fetchAuthorized('/api/admin/logs');
        if (!response.ok) return;

        const logs = await response.json();

        if (logs.length === 0) {
            tbody.innerHTML = '<tr><td colspan="3" class="text-center">Keine Fehlereinträge vorhanden. Alles läuft sauber!</td></tr>';
            return;
        }

        let sBuffyHtml = '';
        logs.forEach(l => {
            const userBadge = l.Username 
                ? `<span class="badge badge-user">${escapeHtml(l.Username)}</span>` 
                : '<span style="color:var(--text-muted)">System</span>';

            sBuffyHtml += `
                <tr>
                    <td style="white-space:nowrap">${formatDate(l.Timestamp)}</td>
                    <td>${userBadge}</td>
                    <td style="font-family:monospace; font-size:0.85rem; color:#fca5a5">${escapeHtml(l.Description)}</td>
                </tr>
            `;
        });

        tbody.innerHTML = sBuffyHtml;
    } catch (err) {
        tbody.innerHTML = '<tr><td colspan="3" class="text-center" style="color:var(--danger)">Fehler beim Laden der Protokolle.</td></tr>';
    }
}

// ==========================================
// 8. Hilfsfunktionen (Formatierung & Toast)
// ==========================================

function formatBytes(bytes) {
    if (!bytes || bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatDate(dateStr) {
    if (!dateStr) return '-';
    const d = new Date(dateStr);
    return d.toLocaleString('de-DE', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    });
}

function escapeHtml(text) {
    if (!text) return '';
    return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function showToast(message, isError = false) {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.style.borderColor = isError ? 'var(--danger)' : 'var(--success)';
    toast.style.display = 'block';

    setTimeout(() => {
        toast.style.display = 'none';
    }, 3500);
}
