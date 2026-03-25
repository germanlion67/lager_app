# 🚀 Produktions-Deployment Guide

Diese Anleitung beschreibt das Aufsetzen der **Lager_app** in einer gehärteten Produktionsumgebung mit SSL/HTTPS, Reverse Proxy und automatisierten Backups.

---

## 🏗️ Architektur (Produktion)

In der Produktion sind alle Dienste voneinander isoliert. Der Zugriff erfolgt ausschließlich über einen Reverse Proxy.

```
Internet
  │
  └──→ Nginx Proxy Manager (Port 80/443)  ← SSL, Header, Routing
         │
         ├──→ lager_frontend (Port 8081)  ← Caddy (statische Assets)
         │
         └──→ pocketbase (Port 8080)      ← API & Admin UI
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
*   `POCKETBASE_URL`: Deine öffentliche API-URL (z.B. `https://api.deine-domain.de`).
*   `PB_ADMIN_EMAIL`: Deine Admin-Email für PocketBase.
*   `PB_ADMIN_PASSWORD`: Ein starkes Passwort für den automatischen Setup-Prozess.

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
1.  ✅ **Admin-Account** wird mit den ENV-Daten erstellt.
2.  ✅ **Collections** (`artikel`, `users`) werden angelegt.
3.  ✅ **API Rules** werden auf "Authentifizierung erforderlich" gesetzt.
4.  ✅ **Indizes** für Performance-Optimierung werden erstellt.

---

## 🛡️ Nginx Proxy Manager Setup

Öffne die Admin-UI deines Proxy Managers (Standard: `http://dein-server-ip:81`).

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

> ⚠️ **Wichtig**: Wenn du die `POCKETBASE_URL` änderst, musst du das Frontend neu bauen, da die URL zur Build-Zeit in den Dart-Code eingebrannt wird:
> `docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build app`

---

## 🛡️ Sicherheit (Hardening)

Das System nutzt mehrere Sicherheitsschichten:
*   **Netzwerk-Isolierung**: Frontend und PocketBase nutzen `expose`, sind also nicht direkt über die Server-IP erreichbar.
*   **Security Header**: Caddy (Frontend) erzwingt CSP (Content Security Policy) und HSTS.
*   **CORS**: PocketBase erlaubt in Produktion nur Zugriffe von deiner konfigurierten Domain.
*   **Reproducible Builds**: Alle Docker-Images basieren auf fixierten Versionen (Alpine 3.19.1, Debian Bookworm), um Build-Drift zu verhindern.

---

## 💾 Backup & Wiederherstellung

### 1. Methode A: PocketBase UI (Empfohlen)
Logge dich in die Admin-UI ein: `Settings` → `Backups` → `Create new backup`.

### 2. Methode B: Docker Volume Backup (Manuell)
Sichere die Datenbank-Dateien direkt als Archiv:
```bash
docker run --rm \
  -v lager_app_pb_data:/pb_data \
  -v $(pwd):/backup \
  alpine tar czf /backup/pb_backup_$(date +%Y%m%d).tar.gz /pb_data
```

### 3. Automatisiertes Backup (Cron)
Erstelle einen Cronjob, um tägliche Sicherungen durchzuführen:
```bash
0 3 * * * /pfad/zu/deinem/backup_script.sh
```

---

## 🔄 Updates einspielen

Um auf eine neue Version der App zu aktualisieren:

```bash
git pull origin main
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build
```

---

[Zurück zur README](README.md) | [Zu den Installationsdetails](INSTALL.md)