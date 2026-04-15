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
2. ✅ **Collections** (`artikel`, `artikel_dokumente`, `attachments`, `users`) werden angelegt.
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

Die Web-Version erhält die PocketBase-URL über folgende Wege, in dieser Priorität:

| Priorität | Quelle                             | Beschreibung                                                              |
| :-------- | :--------------------------------- | :------------------------------------------------------------------------ |
| 1         | `SharedPreferences` (`localStorage`) | Persistiert vom Setup-Screen oder Einstellungen                           |
| 2         | Runtime-Config (empfohlen)         | URL aus `window.ENV_CONFIG` via `docker-entrypoint.sh` — kein Neubau nötig |
| 3         | Build-Default                      | `--dart-define=POCKETBASE_URL=...` beim Docker-Build — Neubau bei Änderung nötig |
| 4         | Setup-Screen                       | Erststart-Eingabe, wird in `localStorage` gespeichert                     |

### Mobile-/Desktop-Version

Mobile- und Desktop-Builds erhalten die URL über:

| Priorität | Quelle                             | Beschreibung                                  |
| :-------- | :--------------------------------- | :-------------------------------------------- |
| 1         | `SharedPreferences`                | Persistiert vom Setup-Screen oder Einstellungen |
| 2         | `RuntimeEnvConfig`                 | Gibt auf Native immer null zurück (Stub)      |
| 3         | Build-Default                      | Per `--dart-define=POCKETBASE_URL=...` beim Build |
| 4         | `Setup-Screen`                     | Erststart-Eingabe                             |

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
- **App-Lock (ab v0.8.2)**: Auf nativen Plattformen (Android, Desktop) kann die App mit biometrischer Authentifizierung (local_auth: ^3.0.1) gesperrt werden. Bei nicht verfügbarer Biometrie greift der Geräte-PIN als Fallback. Die Sperrzeit ist konfigurierbar (Standard: 5 Minuten Inaktivität). Nur Native — kein kIsWeb-Pfad.

## 🌐 CORS-Konfiguration (H-002)

### Was ist CORS?

CORS (Cross-Origin Resource Sharing) kontrolliert, welche Websites auf die
PocketBase-API zugreifen dürfen. Ohne CORS-Einschränkung könnte jede beliebige
Website API-Requests an deinen Server senden.

### Konfiguration

CORS wird über die Umgebungsvariable `CORS_ALLOWED_ORIGINS` in `.env.production` gesteuert:

```bash
# Einzelne Domain (Standard)
CORS_ALLOWED_ORIGINS=https://lager.germanlion67.de

# Mehrere Domains (komma-getrennt, KEINE Leerzeichen!)
CORS_ALLOWED_ORIGINS=https://lager.germanlion67.de,https://admin.germanlion67.de

# Mit lokaler Entwicklung
CORS_ALLOWED_ORIGINS=https://lager.germanlion67.de,http://localhost:8081
```

### Regeln

| Regel | Beschreibung |
|---|---|
| Kein Trailing-Slash | ✅ `https://example.com` — ❌ `https://example.com/` |
| Kein Wildcard in Prod | ❌ `*` ist nur für Entwicklung erlaubt |
| Kein Leerzeichen | ❌ `https://a.com, https://b.com` |
| Mit Protokoll | ✅ `https://example.com` — ❌ `example.com` |

### Was braucht CORS?

| Client | CORS nötig? | Warum |
|---|---|---|
| Web-Frontend (Browser) | ✅ Ja | Browser erzwingt CORS |
| Android App | ❌ Nein | Kein Origin-Header |
| iOS App | ❌ Nein | Kein Origin-Header |
| Desktop App | ❌ Nein | Kein Origin-Header |
| curl / Postman | ❌ Nein | Kein Browser |

### Domain-Umzug

Bei einem Domain-Umzug:

1. `.env.production` anpassen:
   ```bash
   POCKETBASE_URL=https://api.neue-domain.de
   CORS_ALLOWED_ORIGINS=https://lager.neue-domain.de
   ```
2. Container neu starten:
   ```bash
   docker compose -f docker-compose.prod.yml restart pocketbase app
   ```
3. DNS: Neue A-Records anlegen
4. Nginx Proxy Manager: Neue Proxy Hosts anlegen

> 💡 **Übergangsphase:** Beide Domains gleichzeitig erlauben:
> ```bash
> CORS_ALLOWED_ORIGINS=https://lager.alte-domain.de,https://lager.neue-domain.de
> ```

### Überprüfung

```bash
# Erlaubte Origin testen
curl -I -H "Origin: https://lager.germanlion67.de" \
  https://api.germanlion67.de/api/health
# → Access-Control-Allow-Origin: https://lager.germanlion67.de

# Unerlaubte Origin testen
curl -I -H "Origin: https://boese-seite.de" \
  https://api.germanlion67.de/api/health
# → Kein Access-Control-Allow-Origin Header
```
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

> ℹ️ Hinweis: Ein Neubau ist bei URL-Änderungen nicht zwingend nötig.

> **Web**: Runtime-Config (`POCKETBASE_URL` in `.env.production` ändern, Container neu starten)
> **Mobile/Desktop**: Einstellungen → PocketBase Server → URL ändern

---


## 📎 Attachments-Collection (ab v0.7.2)

Die Collection `attachments` speichert Dateianhänge pro Artikel.

### API-Regeln

| Regel | Wert | Begründung |
|---|---|---|
| listRule | `""` (offen) | Kein Login-Flow implementiert |
| viewRule | `""` (offen) | Analog zu `artikel`-Collection |
| createRule | `""` (offen) | Analog zu `artikel`-Collection |
| updateRule | `""` (offen) | Analog zu `artikel`-Collection |
| deleteRule | `""` (offen) | Analog zu `artikel`-Collection |


### Schema-Felder

| Feld | Typ | Required | Beschreibung |
|---|---|---|---|
| `artikel_uuid` | text | ✅ | UUID des zugehörigen Artikels (36 Zeichen, UUID-Pattern) |
| `datei` | file | ✅ | Dateianhang (max 10 MB, erlaubte MIME-Types) |
| `bezeichnung` | text | ✅ | Vom Nutzer vergebener Name (max 200 Zeichen) |
| `beschreibung` | text | ❌ | Optionale Beschreibung |
| `mime_type` | text | ❌ | MIME-Typ der Datei |
| `datei_groesse` | number | ❌ | Dateigröße in Bytes |
| `sort_order` | number | ❌ | Sortierreihenfolge |
| `uuid` | text | ✅ | Client-seitige UUID (36 Zeichen) |
| `etag` | text | ❌ | Sync-ETag |
| `device_id` | text | ❌ | Geräte-ID |
| `deleted` | bool | ❌ | Soft-Delete Flag |
| `updated_at` | number | ❌ | Sync-Timestamp |

### Erlaubte MIME-Types

`image/png`, `image/jpeg`, `image/webp`, `application/pdf`,
`application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`,
`application/vnd.ms-excel`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`,
`text/plain`, `text/csv`

### Limits

- Max **20 Anhänge** pro Artikel
- Max **10 MB** pro Datei

---
## 🐳 Portainer Stack Deployment

> 📖 **Detaillierte Betriebshinweise** (Erststart, Cold-Start-Verifikation, Fehlerbehebung) findest du in
> [`docs/PORTAINER_PROD.md`](docs/PORTAINER_PROD.md).

### Voraussetzungen

- Portainer installiert und erreichbar
- Nginx Proxy Manager installiert und erreichbar
- DNS-Einträge für beide Subdomains gesetzt:
  - `lager.germanlion67.de` → Server-IP
  - `api.germanlion67.de` → Server-IP

### Stack YAML

In Portainer unter **Stacks → Add stack** folgendes YAML einfügen:

````yaml
# ============================================================
# Lager App - Portainer Stack (Produktion)
#
# Architektur:
#   Internet → Nginx Proxy Manager (:80/:443)
#                ├── lager.domain.de    → lager_frontend:8081
#                └── api.domain.de      → pocketbase:8080
#
# Erforderliche Environment Variables:
#   PB_ADMIN_EMAIL          Admin E-Mail für PocketBase
#   PB_ADMIN_PASSWORD       Admin Passwort (sicher wählen!)
#   POCKETBASE_URL          Öffentliche API-URL (z.B. https://api.deine-domain.de)
#   CORS_ALLOWED_ORIGINS    Frontend-Domain (z.B. https://lager.deine-domain.de)
# ============================================================

services:

  # ============================================================
  # Nginx Proxy Manager
  # Einziger Service mit öffentlichen Ports
  # Admin UI: http://SERVER-IP:81 (nur lokal/VPN!)
  # ============================================================
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx_proxy_manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "127.0.0.1:81:81"
    volumes:
      - npm_data:/data
      - npm_letsencrypt:/etc/letsencrypt
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:81/api/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    depends_on:
      pocketbase:
        condition: service_healthy
      app:
        condition: service_healthy
    networks:
      - lager_network

  # ============================================================
  # PocketBase Backend
  # Nur intern erreichbar (expose, keine ports)
  # CORS wird über CORS_ALLOWED_ORIGINS gesteuert (H-002)
  # ============================================================
  pocketbase:
    image: ghcr.io/germanlion67/lager_app_pocketbase:latest
    container_name: lager_pocketbase
    restart: unless-stopped
    expose:
      - "8080"
    environment:
      - PB_ADMIN_EMAIL=${PB_ADMIN_EMAIL:-admin@example.com}
      - PB_ADMIN_PASSWORD=${PB_ADMIN_PASSWORD}
      - PB_DATA_DIR=/pb_data
      - PB_MIGRATIONS_DIR=/pb_migrations
      - PB_DEV_MODE=0
      - CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS:?CORS_ALLOWED_ORIGINS muss gesetzt sein!}
    volumes:
      - pb_data:/pb_data
      - pb_public:/pb_public
      - pb_backups:/pb_backups
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/api/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
    networks:
      - lager_network

  # ============================================================
  # Flutter Web Frontend
  # Nur intern erreichbar (expose, keine ports)
  # POCKETBASE_URL muss die öffentliche API-URL sein!
  # ============================================================
  app:
    image: ghcr.io/germanlion67/lager_app_web:latest
    container_name: lager_frontend
    restart: unless-stopped
    expose:
      - "8081"
    environment:
      - POCKETBASE_URL=${POCKETBASE_URL:?POCKETBASE_URL muss gesetzt sein!}
    depends_on:
      pocketbase:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8081/"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    networks:
      - lager_network

  # ============================================================
  # Backup Service
  # Automatisierte tägliche Backups mit Rotation
  # ============================================================
  backup:
    image: ghcr.io/germanlion67/lager_app_backup:latest
    container_name: lager_backup
    restart: unless-stopped
    environment:
      - BACKUP_ENABLED=${BACKUP_ENABLED:-true}
      - BACKUP_CRON=${BACKUP_CRON:-0 3 * * *}
      - BACKUP_KEEP_DAYS=${BACKUP_KEEP_DAYS:-7}
      - BACKUP_NOTIFY=${BACKUP_NOTIFY:-none}
      - TZ=${TZ:-Europe/Berlin}
    volumes:
      - pb_data:/pb_data:ro
      - pb_backups:/pb_backups
    depends_on:
      pocketbase:
        condition: service_healthy
    networks:
      - lager_network

volumes:
  npm_data:
  npm_letsencrypt:
  pb_data:
  pb_public:
  pb_backups:

networks:
  lager_network:
    driver: bridge
````

### Environment Variables in Portainer

Beim Stack-Deployment in Portainer unter **Environment variables** setzen:

| Variable | Wert | Pflicht |
|---|---|---|
| `PB_ADMIN_EMAIL` | `admin@germanlion67.de` | ✅ |
| `PB_ADMIN_PASSWORD` | `SicheresPasswort123!` | ✅ |
| `POCKETBASE_URL` | `https://api.germanlion67.de` | ✅ |
| `CORS_ALLOWED_ORIGINS` | `https://lager.germanlion67.de` | ✅ |
| `BACKUP_ENABLED` | `true` | Optional |
| `BACKUP_CRON` | `0 3 * * *` | Optional |
| `BACKUP_KEEP_DAYS` | `7` | Optional |
| `TZ` | `Europe/Berlin` | Optional |

### Nginx Proxy Manager einrichten

Nach dem ersten Start NPM Admin UI öffnen (`http://SERVER-IP:81`):

1. **Erstlogin:** `admin@example.com` / `changeme`
2. **Proxy Host 1:** `lager.germanlion67.de` → `lager_frontend:8081` → SSL ✅
3. **Proxy Host 2:** `api.germanlion67.de` → `lager_pocketbase:8080` → SSL ✅

> ⚠️ **Wichtig:** Bei den Proxy Hosts als Hostname den **Container-Namen** verwenden
> (z.B. `lager_pocketbase`), nicht `localhost`!

--- 

[Zurück zur README](README.md) | [Zu den Installationsdetails](INSTALL.md)