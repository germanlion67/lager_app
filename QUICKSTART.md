# 🚀 Quick Start Guide

Schnelleinstieg für die Lager App mit automatischer PocketBase-Initialisierung.

## 📦 Dev/Test Setup (5 Minuten)

```bash
# 1. Repository klonen
git clone https://github.com/germanlion67/lager_app.git
cd lager_app

# 2. Umgebungsvariablen setzen
cp .env.example .env

# 3. Services starten (mit automatischer Initialisierung)
docker compose up -d --build

# 4. Warten bis Services bereit sind (ca. 2-3 Minuten beim ersten Start)
docker compose logs -f
```

**Fertig! Die App läuft:**
- 🌐 Web-App: http://localhost:8081
- 🔧 PocketBase Admin: http://localhost:8080/_/
- 🔐 Login: `admin@example.com` / `changeme123`

**⚠️ WICHTIG:** Ändern Sie das Passwort nach dem ersten Login!

---

## 🏭 Production Setup (10 Minuten)

### Voraussetzungen
- Domain mit DNS-Konfiguration
- Server mit Docker & Docker Compose
- Ports 80 und 443 offen

### Installation

```bash
# 1. Repository klonen
git clone https://github.com/germanlion67/lager_app.git
cd lager_app

# 2. Produktions-Konfiguration erstellen
cp .env.production.example .env.production

# 3. Konfiguration anpassen
nano .env.production
```

**Wichtige Einstellungen in `.env.production`:**

```dotenv
# Öffentliche API-Domain
POCKETBASE_URL=https://api.your-domain.com

# Admin-Zugangsdaten (werden automatisch erstellt)
PB_ADMIN_EMAIL=admin@your-domain.com
PB_ADMIN_PASSWORD=IhrSicheresPasswort123!
```

```bash
# 4. Services starten
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build

# 5. Logs überwachen
docker compose -f docker-compose.prod.yml logs -f
```

### Nginx Proxy Manager konfigurieren

**Nach ca. 2-3 Minuten:**

1. Öffne: `http://your-server-ip:81`
2. Login: `admin@example.com` / `changeme`
3. **Passwort sofort ändern!**

**Proxy Host für Web-App:**
```
Domain: your-domain.com
Forward to: lager_frontend:8081
SSL: Let's Encrypt ✓
```

**Proxy Host für API:**
```
Domain: api.your-domain.com
Forward to: pocketbase:8080
SSL: Let's Encrypt ✓
```

**Fertig!** Die App ist unter `https://your-domain.com` erreichbar.

---

## 🧪 Deployment testen

Vor dem produktiven Einsatz:

```bash
# Teste Konfiguration
./test-deployment.sh

# Wenn alle Tests grün sind:
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build
```

---

## 🔧 Troubleshooting

### PocketBase startet nicht

```bash
# Prüfe Logs
docker compose logs pocketbase

# Prüfe ob Volume-Berechtigungen korrekt sind
ls -la server/pb_data

# Neustart erzwingen
docker compose down -v
docker compose up -d --build
```

### Flutter Web zeigt Fehler

```bash
# Prüfe ob POCKETBASE_URL korrekt gesetzt ist
docker compose exec app env | grep POCKETBASE_URL

# WICHTIG: Bei URL-Änderung muss neu gebaut werden
docker compose up -d --build app
```

### Migrations werden nicht angewendet

```bash
# Prüfe ob Migrations gemountet sind
docker compose exec pocketbase ls -la /pb_migrations

# Manuell Migrations anwenden
docker compose exec pocketbase /pb/pocketbase migrate --dir=/pb_data
```

### Services starten nicht

```bash
# Prüfe Service-Status
docker compose ps

# Prüfe Resource-Auslastung
docker stats

# Prüfe verfügbaren Speicher
df -h
```

---

## 📚 Weitere Informationen

- **Vollständige Dokumentation:** [docs/PRODUCTION_DEPLOYMENT.md](docs/PRODUCTION_DEPLOYMENT.md)
- **Technische Details:** [docs/TECHNISCHE_ANALYSE_2026-03.md](docs/TECHNISCHE_ANALYSE_2026-03.md)
- **Main README:** [README.md](README.md)

---

## 🔐 Sicherheits-Checkliste

Nach dem ersten Start:

- [ ] PocketBase Admin-Passwort geändert
- [ ] Nginx Proxy Manager Admin-Passwort geändert
- [ ] SSL-Zertifikate aktiv
- [ ] Firewall konfiguriert (nur 80, 443 offen)
- [ ] `.env.production` nicht in Git
- [ ] Backup-Strategie definiert
- [ ] Admin-Port 81 nur lokal erreichbar

---

## 💬 Support

Bei Problemen:
1. Prüfe Logs: `docker compose logs -f`
2. Lese: [docs/PRODUCTION_DEPLOYMENT.md](docs/PRODUCTION_DEPLOYMENT.md)
3. GitHub Issues: https://github.com/germanlion67/lager_app/issues

---

**Version:** 1.0.0 (März 2026)
