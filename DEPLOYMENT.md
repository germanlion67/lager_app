# 🚀 Produktions-Deployment Guide

Diese Anleitung beschreibt das Aufsetzen der **Lager_app** in einer gehärteten Produktionsumgebung mit SSL/HTTPS, Reverse Proxy und automatisierten Backups.

---

## 🏗️ Architektur (Produktion)

In der Produktion sind alle Dienste voneinander isoliert. Der Zugriff erfolgt ausschließlich über einen Reverse Proxy. Backups werden automatisiert durch einen dedizierten Container erstellt.

```text
Internet
  │
  └──→ Nginx Proxy Manager (Port 80/443)  ← SSL, Header, Routing
         │
         ├──→ lager_frontend (Port 8081)  ← Caddy (statische Assets)
         │
         └──→ pocketbase (Port 8080)      ← API & Admin UI
                │
                ├──→ pb_data/             ← Datenbank & Uploads (Bind-Mount)
                │
                └──→ pb_backups/          ← Backup-Archiv (Bind-Mount)
                       ▲
                       │
                     backup (Cron)        ← Automatisierte Backups
                       • SQLite WAL-Checkpoint
                       • tar.gz mit Rotation
                       • E-Mail-Benachrichtigung
                       • Status-JSON für App-Anzeige
```

---

## 📦 Vorbereitung

### 1. Repository klonen

```bash
git clone https://github.com/germanlion67/lager_app.git
cd lager_app
```

### 2. Umgebungsvariablen anlegen

Kopiere die Vorlage für die Produktion und passe die Werte an.

```bash
cp .env.production.example .env.production
nano .env.production
```

**Wichtige Werte in `.env.production`:**

- `POCKETBASE_URL`: *(optional)* Deine öffentliche API-URL, z. B. `https://api.deine-domain.de`  
  Wird als Build-Default in das Web-Frontend eingebaut. Wenn nicht gesetzt, wird die URL zur Laufzeit über `window.ENV_CONFIG` oder den Setup-Screen konfiguriert.
- `PB_ADMIN_EMAIL`: Deine Admin-Email für PocketBase
- `PB_ADMIN_PASSWORD`: Ein starkes Passwort für den automatischen Setup-Prozess

> ℹ️ **Hinweis ab v0.7.0:** `POCKETBASE_URL` ist nicht mehr zwingend erforderlich.  
> Die App startet auch ohne vorkonfigurierte URL und zeigt einen Einrichtungsbildschirm an.  
> Für die Web-Version wird die URL typischerweise über die Runtime-Config (`docker-entrypoint.sh` → `window.ENV_CONFIG`) gesetzt.

---

## 🚀 Deployment starten

Wir nutzen die produktionsspezifische Compose-Datei, die keine Ports direkt nach außen öffnet (außer NPM).

```bash
docker compose \
  -f docker-compose.prod.yml \
  --env-file .env.production \
  up -d --build
```

### Automatische Initialisierung

Beim ersten Start führt PocketBase automatisch folgende Schritte aus:

1. ✅ **Admin-Account** wird mit den ENV-Daten erstellt.
2. ✅ **Collections** (`artikel`, `users`) werden angelegt.
3. ✅ **API Rules** werden auf „Authentifizierung erforderlich“ gesetzt.
4. ✅ **Indizes** für Performance-Optimierung werden erstellt.

---

## 🛡️ Nginx Proxy Manager Setup

Öffne die Admin-UI deines Proxy Managers  
(Standard: `http://dein-server-ip:81`).

### 1. Flutter Web Frontend

| Feld | Wert |
|---|---|
| Domain Names | `lager.deine-domain.de` |
| Scheme | `http` |
| Forward Hostname | `lager_frontend` |
| Forward Port | `8081` |
| **SSL** | Request a new Let's Encrypt Certificate ✅ |
| **Force SSL** | ✅ |

### 2. PocketBase API

| Feld | Wert |
|---|---|
| Domain Names | `api.deine-domain.de` |
| Scheme | `http` |
| Forward Hostname | `pocketbase` |
| Forward Port | `8080` |
| **SSL** | Request a new Let's Encrypt Certificate ✅ |
| **Force SSL** | ✅ |

---

## 🔧 Server-URL-Konfiguration (ab v0.7.0)

### Web-Version

Die Web-Version erhält die PocketBase-URL über drei mögliche Wege, in dieser Priorität:

1. **Runtime-Config (empfohlen)**  
   Die URL wird beim Container-Start aus der Umgebungsvariable `POCKETBASE_URL` in `window.ENV_CONFIG` injiziert (`docker-entrypoint.sh`).  
   **Vorteil:** Kein Neubau nötig bei URL-Änderung.

2. **Build-Default**  
   Wenn `POCKETBASE_URL` beim Docker-Build als Build-Argument gesetzt wird, wird die URL in den Dart-Code eingebaut.  
   **Nachteil:** Erfordert einen Neubau bei Änderung.

3. **Setup-Screen**  
   Wenn weder Runtime-Config noch Build-Default vorhanden sind, zeigt die Web-App beim ersten Aufruf einen Einrichtungsbildschirm an.  
   Die URL wird im `localStorage` des Browsers gespeichert.

### Mobile-/Desktop-Version

Mobile- und Desktop-Builds erhalten die URL über:

1. **Gespeicherte URL**  
   Beim ersten Start über den Setup-Screen eingegebene URL (`SharedPreferences`)

2. **Build-Default (optional)**  
   Per `--dart-define=POCKETBASE_URL=...` beim Build gesetzt  
   Nützlich für vorkonfigurierte Demo- oder Kunden-Builds

3. **Setup-Screen**  
   Wenn keine URL vorhanden ist, wird beim ersten Start ein Einrichtungsbildschirm angezeigt

### URL ändern

| Plattform | Vorgehen |
|---|---|
| **Web (Docker)** | Umgebungsvariable `POCKETBASE_URL` ändern, Container neu starten |
| **Web (Browser)** | Einstellungen → PocketBase Server → URL ändern |
| **Mobile/Desktop** | Einstellungen → PocketBase Server → URL ändern |

> ⚠️ **Wichtig:** Bei einer URL-Änderung über die Einstellungen wird ein Verbindungstest durchgeführt.  
> Die neue URL wird nur übernommen, wenn der Server erreichbar ist.

---

## 🛡️ Sicherheit (Hardening)

Das System nutzt mehrere Sicherheitsschichten:

- **Netzwerk-Isolierung:** Frontend und PocketBase nutzen `expose`, sind also nicht direkt über die Server-IP erreichbar
- **Security Header:** Caddy (Frontend) erzwingt CSP (Content Security Policy) und HSTS
- **CORS:** PocketBase erlaubt in Produktion nur Zugriffe von deiner konfigurierten Domain
- **Reproducible Builds:** Alle Docker-Images basieren auf fixierten Versionen (`Alpine 3.19.1`, Debian Bookworm), um Build-Drift zu verhindern

---

## 💾 Backup & Wiederherstellung

### Automatisiertes Backup (empfohlen)

Ab v0.7.1 enthält das Produktions-Setup einen dedizierten Backup-Container, der automatisch tägliche Backups erstellt.

#### Funktionsweise

Der Backup-Container (`lager_backup`) läuft als eigenständiger Service in `docker-compose.prod.yml` und:

- führt einen SQLite WAL-Checkpoint durch *(konsistente Datenbank-Kopie)*
- erstellt ein komprimiertes `tar.gz`-Archiv von `pb_data`
- prüft die Integrität des Archivs
- rotiert alte Backups *(Standard: 7 Tage)*
- schreibt eine Status-JSON (`last_backup.json`) für die App-Anzeige
- sendet optional eine E-Mail-Benachrichtigung bei Erfolg oder Fehler

#### Konfiguration

Alle Backup-Einstellungen werden über `.env.production` gesteuert:

```bash
# Backup aktivieren/deaktivieren
BACKUP_ENABLED=true

# Cron-Schedule (Standard: täglich um 3:00 Uhr)
BACKUP_CRON=0 3 * * *

# Anzahl Tage, die Backups aufbewahrt werden
BACKUP_KEEP_DAYS=7

# Zeitzone
TZ=Europe/Berlin

# Benachrichtigung: none | email | webhook
BACKUP_NOTIFY=none

# E-Mail (nur wenn BACKUP_NOTIFY=email)
BACKUP_SMTP_HOST=smtp.example.com
BACKUP_SMTP_PORT=587
BACKUP_SMTP_USER=backup@example.com
BACKUP_SMTP_PASS=geheim
BACKUP_SMTP_FROM=backup@example.com
BACKUP_SMTP_TO=admin@example.com
```

#### Manuelles Backup auslösen

```bash
docker exec lager_backup /backup/backup.sh
```

#### Backup-Status prüfen

```bash
# Status-JSON anzeigen
cat server/pb_backups/last_backup.json

# Backup-Log anzeigen
cat server/pb_backups/backup.log

# Container-Logs
docker logs lager_backup
```

#### Verfügbare Backups auflisten

```bash
./scripts/restore.sh
```

### Wiederherstellung

Die Wiederherstellung erfolgt über das `restore.sh`-Script auf dem Host:

```bash
# Verfügbare Backups anzeigen
./scripts/restore.sh

# Backup wiederherstellen
./scripts/restore.sh lager_backup_20260327_030000.tar.gz
```

#### Was passiert beim Restore?

1. PocketBase- und Backup-Container werden gestoppt
2. Eine Sicherheitskopie der aktuellen Daten wird erstellt
3. Das Backup wird entpackt und die Daten wiederhergestellt
4. Container werden neu gestartet
5. Ein Healthcheck bestätigt, dass PocketBase wieder läuft

> ⚠️ **Achtung:** Die aktuelle Datenbank wird beim Restore überschrieben!  
> Falls Probleme auftreten, kann die automatisch erstellte Sicherheitskopie (`pre_restore_*.tar.gz`) wiederhergestellt werden.

### Backup-Methode B: PocketBase UI (alternativ)

Logge dich in die Admin-UI ein:

`Settings` → `Backups` → `Create new backup`

### Backup-Methode C: Manuelles Volume-Backup

```bash
# SQLite WAL-Checkpoint (wichtig für konsistentes Backup!)
docker exec pocketbase sh -c 'sqlite3 /pb_data/data.db "PRAGMA wal_checkpoint(TRUNCATE);"'

# Archiv erstellen
tar czf pb_backup_$(date +%Y%m%d).tar.gz -C server pb_data
```

---

## 🔄 Updates einspielen

Um auf eine neue Version der App zu aktualisieren:

```bash
git pull origin main
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build
```

> ℹ️ **Ab v0.7.0:** Ein Neubau ist bei URL-Änderungen nicht mehr zwingend nötig  
> (**Web:** Runtime-Config, **Mobile/Desktop:** Einstellungen).

---

[Zurück zur README](README.md) | [Zu den Installationsdetails](INSTALL.md)