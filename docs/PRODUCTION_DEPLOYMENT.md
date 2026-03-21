# 🚀 Production Deployment Guide

Dieses Dokument beschreibt die produktionsreife Installation der Lager App mit automatischer PocketBase-Initialisierung.

## 📋 Voraussetzungen

- Docker & Docker Compose (oder Docker Swarm für Stack-Deployment)
- Domain mit DNS-Konfiguration
- SSL-Zertifikat (wird von Nginx Proxy Manager automatisch mit Let's Encrypt erstellt)
- Mindestens 2GB RAM, 10GB Speicher

## 🎯 Deployment-Methoden

### Methode 1: Docker Compose (Empfohlen für einzelne Server)

#### Schritt 1: Repository klonen

```bash
git clone https://github.com/germanlion67/lager_app.git
cd lager_app
```

#### Schritt 2: Umgebungsvariablen konfigurieren

```bash
# Erstelle Produktions-Konfiguration
cp .env.production.example .env.production

# Bearbeite die Datei und setze:
nano .env.production
```

**Wichtige Konfigurationen:**

```dotenv
# PocketBase Admin (wird beim ersten Start erstellt)
PB_ADMIN_EMAIL=admin@your-domain.com
PB_ADMIN_PASSWORD=IhrSicheresPasswort123!

# Öffentliche API-URL (vom Browser erreichbar!)
POCKETBASE_URL=https://api.your-domain.com
```

#### Schritt 3: Services starten

```bash
# Starte alle Services mit automatischer Initialisierung
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build
```

**Was passiert automatisch:**
- ✅ PocketBase-Datenbank wird erstellt
- ✅ Admin-Benutzer wird angelegt
- ✅ Migrationen werden angewendet
- ✅ Collections werden erstellt
- ✅ Flutter Web wird gebaut und bereitgestellt

#### Schritt 4: Nginx Proxy Manager konfigurieren

1. Öffne Nginx Proxy Manager Admin: `http://your-server-ip:81`
2. Standard-Login: `admin@example.com` / `changeme`
3. **WICHTIG:** Ändere sofort das Passwort!

**Proxy Host für Flutter Web einrichten:**

```
Domain Names: your-domain.com
Scheme: http
Forward Hostname/IP: lager_frontend
Forward Port: 8081
Block Common Exploits: ✓
Websockets Support: ✓

SSL Tab:
- Request new SSL Certificate
- Force SSL: ✓
- HTTP/2 Support: ✓
```

**Proxy Host für PocketBase API einrichten:**

```
Domain Names: api.your-domain.com
Scheme: http
Forward Hostname/IP: pocketbase
Forward Port: 8080
Block Common Exploits: ✓
Websockets Support: ✓

SSL Tab:
- Request new SSL Certificate
- Force SSL: ✓
- HTTP/2 Support: ✓
```

#### Schritt 5: Verifizieren

```bash
# Prüfe Service-Status
docker compose -f docker-compose.prod.yml ps

# Prüfe Logs
docker compose -f docker-compose.prod.yml logs -f

# Teste PocketBase API
curl https://api.your-domain.com/api/health

# Teste Flutter Web
curl https://your-domain.com
```

---

### Methode 2: Docker Stack (Für Docker Swarm / Multi-Node)

#### Schritt 1: Docker Swarm initialisieren

```bash
docker swarm init
```

#### Schritt 2: Umgebungsvariablen setzen

```bash
# Setze Admin-Credentials als Docker Secrets
echo "admin@your-domain.com" | docker secret create pb_admin_email -
echo "IhrSicheresPasswort123!" | docker secret create pb_admin_password -

# Oder als Environment Variables
export PB_ADMIN_EMAIL=admin@your-domain.com
export PB_ADMIN_PASSWORD=IhrSicheresPasswort123!
export VERSION=latest
```

#### Schritt 3: Stack deployen

```bash
docker stack deploy -c docker-stack.yml lager_app
```

#### Schritt 4: Services überwachen

```bash
# Liste Services
docker stack services lager_app

# Prüfe Logs
docker service logs lager_app_pocketbase -f
docker service logs lager_app_app -f

# Skaliere Frontend bei Bedarf
docker service scale lager_app_app=3
```

---

### Methode 3: Pre-Built Docker Images (Docker Hub / GitHub Container Registry)

Wenn Sie die vorgefertigten Images verwenden möchten:

```bash
# Pull Images
docker pull ghcr.io/germanlion67/lager_app_web:latest
docker pull ghcr.io/germanlion67/lager_app_pocketbase:latest

# Starte mit docker-compose.prod.yml (Image-Namen anpassen)
docker compose -f docker-compose.prod.yml up -d
```

---

## 🔧 Konfiguration

### PocketBase Admin-Zugang

Nach dem ersten Start:

1. Öffne: `https://api.your-domain.com/_/`
2. Login mit den konfigurierten Credentials
3. **WICHTIG:** Ändere sofort das Passwort im PocketBase Admin UI!

### API-Sicherheit

Die PocketBase Collection `artikel` ist standardmäßig mit Authentifizierung geschützt:
- Lesezugriff: Nur authentifizierte Benutzer
- Schreibzugriff: Nur authentifizierte Benutzer

**Falls öffentlicher Lesezugriff gewünscht:**
1. Öffne PocketBase Admin UI: `https://api.your-domain.com/_/`
2. Navigiere zu Collections → artikel → API Rules
3. Passe `listRule` und `viewRule` an

### CORS-Konfiguration

Falls mehrere Domains verwendet werden:

```bash
# In .env.production
CORS_ALLOWED_ORIGINS=https://your-domain.com,https://app.your-domain.com
```

---

## 🔄 Updates & Wartung

### Update auf neue Version

```bash
# Pull neueste Changes
git pull origin main

# Rebuild und Neustart
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build

# Oder mit docker stack
docker stack deploy -c docker-stack.yml lager_app
```

### Backup erstellen

```bash
# PocketBase Datenbank sichern
docker compose -f docker-compose.prod.yml exec pocketbase \
  /pb/pocketbase backup /pb_backups

# Oder manuell
tar -czf backup-$(date +%Y%m%d).tar.gz \
  server/pb_data \
  server/pb_public \
  server/pb_backups
```

### Backup wiederherstellen

```bash
# Services stoppen
docker compose -f docker-compose.prod.yml down

# Backup entpacken
tar -xzf backup-20260321.tar.gz

# Services neu starten
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

---

## 📊 Monitoring

### Logs anzeigen

```bash
# Alle Logs
docker compose -f docker-compose.prod.yml logs -f

# Nur PocketBase
docker compose -f docker-compose.prod.yml logs -f pocketbase

# Nur Flutter Web
docker compose -f docker-compose.prod.yml logs -f app

# Nur Nginx Proxy Manager
docker compose -f docker-compose.prod.yml logs -f nginx-proxy-manager
```

### Health Checks

```bash
# PocketBase
curl https://api.your-domain.com/api/health

# Flutter Web
curl https://your-domain.com

# Nginx Proxy Manager
curl http://localhost:81/api/
```

---

## 🐛 Troubleshooting

### Problem: PocketBase startet nicht

```bash
# Prüfe Logs
docker compose -f docker-compose.prod.yml logs pocketbase

# Prüfe Berechtigungen
ls -la server/pb_data

# Lösche Datenbank für Neustart (VORSICHT: Datenverlust!)
rm -rf server/pb_data/*
docker compose -f docker-compose.prod.yml up -d --force-recreate
```

### Problem: Migrations werden nicht angewendet

```bash
# Prüfe ob Migrations-Verzeichnis gemountet ist
docker compose -f docker-compose.prod.yml exec pocketbase ls -la /pb_migrations

# Manuelle Migration
docker compose -f docker-compose.prod.yml exec pocketbase \
  /pb/pocketbase migrate --dir=/pb_data
```

### Problem: Flutter Web zeigt Fehler

```bash
# Prüfe ob POCKETBASE_URL korrekt ist
docker compose -f docker-compose.prod.yml exec app env | grep POCKETBASE_URL

# WICHTIG: URL-Änderung erfordert Rebuild!
docker compose -f docker-compose.prod.yml up -d --build app
```

### Problem: Nginx Proxy Manager nicht erreichbar

```bash
# Prüfe ob Port 81 gebunden ist
netstat -tulpn | grep :81

# Starte Service neu
docker compose -f docker-compose.prod.yml restart nginx-proxy-manager
```

---

## 🔒 Sicherheits-Checkliste

- [ ] PocketBase Admin-Passwort geändert
- [ ] Nginx Proxy Manager Admin-Passwort geändert
- [ ] SSL-Zertifikate aktiv und gültig
- [ ] Firewall konfiguriert (nur Port 80, 443 offen)
- [ ] `.env.production` nicht in Git committet
- [ ] Backups eingerichtet
- [ ] PocketBase API Rules geprüft
- [ ] CORS richtig konfiguriert
- [ ] Admin UI nur über lokales Netzwerk erreichbar

---

## 📚 Weitere Ressourcen

- [README.md](../README.md) - Allgemeine Dokumentation
- [TECHNISCHE_ANALYSE_2026-03.md](TECHNISCHE_ANALYSE_2026-03.md) - Technische Details
- [PRIORITAETEN_CHECKLISTE.md](PRIORITAETEN_CHECKLISTE.md) - Feature-Status

---

## 💬 Support

Bei Problemen:
1. Prüfe die Logs: `docker compose logs -f`
2. Suche in Issues: https://github.com/germanlion67/lager_app/issues
3. Erstelle ein neues Issue mit vollständigen Logs

---

**Stand:** März 2026  
**Version:** 1.0.0
