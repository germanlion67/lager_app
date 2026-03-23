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

### 📦 Backup erstellen

PocketBase speichert alle Daten in `server/pb_data` (SQLite-DB, Konfiguration) und `server/pb_public` (hochgeladene Bilder/Dateien). Ein vollständiges Backup umfasst beide Verzeichnisse.

#### Methode 1: PocketBase Backup-Befehl (Empfohlen)

```bash
# Automatisches Backup mit Zeitstempel
docker compose -f docker-compose.prod.yml exec pocketbase \
  /pb/pocketbase backup /pb_backups

# Backup-Datei wird erstellt: server/pb_backups/pb_backup_[timestamp].zip
```

**Vorteile:**
- ✅ Konsistentes Backup (PocketBase kümmert sich um DB-Locking)
- ✅ ZIP-Format mit Zeitstempel
- ✅ Kann während Betrieb ausgeführt werden (keine Downtime)

**Backup-Dateien verwalten:**
```bash
# Backups auflisten
ls -lh server/pb_backups/

# Beispiel-Output:
# -rw-r--r-- 1 user user 2.3M Mar 23 10:15 pb_backup_2026_03_23_101530.zip
# -rw-r--r-- 1 user user 2.1M Mar 22 08:30 pb_backup_2026_03_22_083045.zip

# Alte Backups löschen (älter als 7 Tage)
find server/pb_backups/ -name "*.zip" -mtime +7 -delete
```

#### Methode 2: Manuelles Tar-Archiv

```bash
# Services kurz stoppen (garantiert Konsistenz)
docker compose -f docker-compose.prod.yml stop pocketbase

# Vollständiges Backup erstellen
tar -czf backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  server/pb_data \
  server/pb_public \
  server/pb_backups

# Services wieder starten
docker compose -f docker-compose.prod.yml start pocketbase

# Backup-Größe prüfen
ls -lh backup-*.tar.gz
```

**Vorteile:**
- ✅ Einfaches Archiv-Format
- ✅ Beinhaltet auch alte PocketBase-Backups
- ✅ Kann auf externen Storage kopiert werden

**Beispiel-Output:**
```
backup-20260323-101530.tar.gz  (2.8M)
├── server/pb_data/
│   ├── data.db                  (2.3M) - Hauptdatenbank
│   ├── data.db-shm              (32K)  - Shared Memory
│   ├── data.db-wal              (456K) - Write-Ahead Log
│   └── logs.db                  (128K) - Logs
├── server/pb_public/            (1.2M) - Hochgeladene Dateien
└── server/pb_backups/           (2.1M) - Alte Backups
```

#### Methode 3: Automatisches Cron-Backup

```bash
# Crontab öffnen
crontab -e

# Täglich um 3:00 Uhr Backup erstellen (Methode 1)
0 3 * * * cd /pfad/zu/lager_app && docker compose -f docker-compose.prod.yml exec -T pocketbase /pb/pocketbase backup /pb_backups

# Oder wöchentlich am Sonntag um 2:00 Uhr (Methode 2)
0 2 * * 0 cd /pfad/zu/lager_app && docker compose -f docker-compose.prod.yml stop pocketbase && tar -czf /backups/lager-$(date +\%Y\%m\%d).tar.gz server/pb_data server/pb_public && docker compose -f docker-compose.prod.yml start pocketbase

# Alte Backups automatisch löschen (älter als 30 Tage)
0 4 * * * find /backups/ -name "lager-*.tar.gz" -mtime +30 -delete
```

**Hinweis:** Bei Methode 1 mit Cron muss `-T` (disable pseudo-TTY) verwendet werden.

#### Backup extern speichern

```bash
# Auf externen Server kopieren (rsync)
rsync -avz server/pb_backups/ user@backup-server:/backups/lager_app/

# Zu Cloud-Storage hochladen (rclone - falls konfiguriert)
rclone copy server/pb_backups/ remote:lager-backups/

# Lokal auf USB-Stick kopieren
cp backup-*.tar.gz /mnt/usb-backup/
```

### 🔄 Backup wiederherstellen

#### Methode 1: PocketBase-Backup wiederherstellen

```bash
# 1. Services stoppen
docker compose -f docker-compose.prod.yml down

# 2. Backup-ZIP entpacken
unzip server/pb_backups/pb_backup_2026_03_23_101530.zip -d server/pb_data_restore/

# 3. Alte Daten sichern (optional, zur Sicherheit)
mv server/pb_data server/pb_data_old
mv server/pb_public server/pb_public_old

# 4. Wiederhergestellte Daten verschieben
mv server/pb_data_restore/pb_data server/pb_data
mv server/pb_data_restore/pb_public server/pb_public

# 5. Berechtigungen korrigieren (falls nötig)
sudo chown -R $(id -u):$(id -g) server/pb_data server/pb_public

# 6. Services neu starten
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# 7. Logs prüfen
docker compose -f docker-compose.prod.yml logs -f pocketbase
```

**Erwartete Log-Meldung:**
```
pocketbase  | Server started at http://0.0.0.0:8080
pocketbase  | ├─ REST API: http://0.0.0.0:8080/api/
pocketbase  | └─ Admin UI: http://0.0.0.0:8080/_/
```

#### Methode 2: Tar-Archiv wiederherstellen

```bash
# 1. Services stoppen
docker compose -f docker-compose.prod.yml down

# 2. Alte Daten sichern (zur Sicherheit)
mv server/pb_data server/pb_data_old_$(date +%Y%m%d)
mv server/pb_public server/pb_public_old_$(date +%Y%m%d)

# 3. Backup entpacken
tar -xzf backup-20260323-101530.tar.gz

# 4. Datenstruktur prüfen
ls -la server/pb_data/
ls -la server/pb_public/

# 5. Services neu starten
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# 6. Funktionstest
curl http://localhost:8080/api/health
# Erwartete Antwort: {"code":200,"message":"API is healthy","data":{}}
```

#### Restore-Test durchführen

**Wichtig:** Teste regelmäßig, ob deine Backups funktionieren!

```bash
# Test-Umgebung erstellen
cp -r server/pb_data server/pb_data_test
cp -r server/pb_public server/pb_public_test

# Test-Compose-Datei erstellen (andere Ports)
cat << 'EOF' > docker-compose.test.yml
version: '3.8'
services:
  pocketbase-test:
    image: ghcr.io/muchobien/pocketbase:latest
    volumes:
      - ./server/pb_data_test:/pb_data
      - ./server/pb_public_test:/pb_public
    ports:
      - "8081:8080"
    environment:
      - PB_ADMIN_EMAIL=test@example.com
      - PB_ADMIN_PASSWORD=test12345678
EOF

# Test-Container starten
docker compose -f docker-compose.test.yml up -d

# Web-UI öffnen
xdg-open http://localhost:8081/_/

# Prüfen: 
# ✅ Login funktioniert
# ✅ Artikel sind sichtbar
# ✅ Bilder werden angezeigt

# Test-Container wieder löschen
docker compose -f docker-compose.test.yml down -v
rm -rf server/pb_data_test server/pb_public_test docker-compose.test.yml
```

### 🚨 Notfall-Wiederherstellung

Wenn Services nicht mehr starten oder Daten korrupt sind:

```bash
# 1. Alle Container stoppen und entfernen
docker compose -f docker-compose.prod.yml down -v

# 2. Korrupte Daten komplett löschen
sudo rm -rf server/pb_data server/pb_public

# 3. Backup wiederherstellen (Methode 1 oder 2)
tar -xzf backup-20260323-101530.tar.gz

# 4. Falls Backup auch korrupt: Frische PocketBase-Instanz
mkdir -p server/pb_data server/pb_public
sudo chown -R $(id -u):$(id -g) server/pb_data server/pb_public

# 5. Services neu starten (automatische Initialisierung)
docker compose -f docker-compose.prod.yml --env-file .env.production up -d

# 6. Neuen Admin erstellen (wird automatisch durch init-pocketbase.sh erstellt)
# Email/Passwort aus .env.production lesen

# 7. Daten manuell neu anlegen oder altes Backup importieren
```

**Wichtig:** 
- Behalte mindestens 3 Generationen von Backups (z.B. täglich, wöchentlich, monatlich)
- Teste Restores regelmäßig (mindestens monatlich)
- Speichere Backups extern (nicht nur auf dem gleichen Server)

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
