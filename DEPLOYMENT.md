# 🚀 Deployment Guide

## Voraussetzungen

- ✅ Docker installiert
- ✅ Portainer installiert (optional, aber empfohlen)
- ✅ Reverse Proxy konfiguriert (falls öffentlich erreichbar)

---

## 📦 Images

Die Docker Images werden automatisch gebaut und zu GitHub Container Registry (GHCR) gepusht:

- **PocketBase:** `ghcr.io/germanlion67/lager_app_pocketbase:latest`
- **Frontend:** `ghcr.io/germanlion67/lager_app_web:latest`

---

## 🎨 Deployment via Portainer (empfohlen)

### 1. Portainer öffnen

```
http://DEINE-SERVER-IP:9000
```

### 2. Stack erstellen

1. **Sidebar:** Stacks → "Add stack"
2. **Name:** `lager_app`
3. **Build method:** "Repository"
4. **Repository URL:** `https://github.com/germanlion67/lager_app`
5. **Repository reference:** `refs/heads/main`
6. **Compose path:** `portainer-stack.yml`

**ODER:**

1. **Build method:** "Web editor"
2. **Paste:** Inhalt von `portainer-stack.yml`

### 3. Environment Variables

| Variable | Beispiel | Beschreibung |
|----------|----------|--------------|
| `PB_ADMIN_EMAIL` | `admin@example.com` | PocketBase Admin Email |
| `PB_ADMIN_PASSWORD` | `SuperSecret123!` | PocketBase Admin Passwort |
| `PB_PORT` | `8080` | PocketBase Port (Standard: 8080) |
| `WEB_PORT` | `8081` | Frontend Port (Standard: 8081) |
| `POCKETBASE_URL` | `http://pocketbase:8080` | PocketBase URL für Frontend |
| `CORS_ALLOWED_ORIGINS` | `https://example.com` | Erlaubte CORS Origins |

### 4. Deploy

Klicke auf **"Deploy the stack"**

### 5. Stack verwalten (Portainer)

```bash
# Stack Status prüfen
# → Portainer UI: Stacks → lager_app → Container list

# Stack aktualisieren (neue Images pullen)
# → Portainer UI: Stacks → lager_app → "Pull and redeploy"

# Stack stoppen
# → Portainer UI: Stacks → lager_app → "Stop this stack"

# Stack starten
# → Portainer UI: Stacks → lager_app → "Start this stack"

# Stack löschen
# → Portainer UI: Stacks → lager_app → "Delete this stack"

# Logs anzeigen
# → Portainer UI: Containers → lager_pocketbase/lager_app → "Logs"
```

---

## 🐳 Deployment via Docker Compose (CLI)

### 1. Repository klonen

```bash
git clone https://github.com/germanlion67/lager_app.git
cd lager_app
```

### 2. Environment Variables erstellen

```bash
cat > .env << 'EOF'
PB_ADMIN_EMAIL=admin@example.com
PB_ADMIN_PASSWORD=SuperSecret123!
PB_PORT=8080
WEB_PORT=8081
POCKETBASE_URL=http://pocketbase:8080
CORS_ALLOWED_ORIGINS=*
EOF
```

> **Wichtig:** Passe die Werte in `.env` an deine Bedürfnisse an!

### 3. Stack starten

```bash
# Stack im Hintergrund starten
docker compose -f portainer-stack.yml up -d

# Stack im Vordergrund starten (mit Logs)
docker compose -f portainer-stack.yml up
```

### 4. Status prüfen

```bash
# Container Status anzeigen
docker compose -f portainer-stack.yml ps

# Detaillierte Informationen
docker compose -f portainer-stack.yml ps -a

# Logs aller Services anzeigen
docker compose -f portainer-stack.yml logs

# Logs eines bestimmten Services
docker compose -f portainer-stack.yml logs pocketbase
docker compose -f portainer-stack.yml logs app

# Logs live verfolgen (alle Services)
docker compose -f portainer-stack.yml logs -f

# Logs live verfolgen (ein Service)
docker compose -f portainer-stack.yml logs -f pocketbase

# Nur die letzten 50 Zeilen
docker compose -f portainer-stack.yml logs --tail=50

# Container Ressourcen-Nutzung
docker stats
```

### 5. Stack verwalten

```bash
# Stack stoppen (Container bleiben erhalten)
docker compose -f portainer-stack.yml stop

# Stack wieder starten
docker compose -f portainer-stack.yml start

# Stack neu starten
docker compose -f portainer-stack.yml restart

# Einzelnen Service neu starten
docker compose -f portainer-stack.yml restart pocketbase

# Stack herunterfahren (Container werden gelöscht, Volumes bleiben)
docker compose -f portainer-stack.yml down

# Stack herunterfahren + Volumes löschen (VORSICHT: Datenverlust!)
docker compose -f portainer-stack.yml down -v

# Stack herunterfahren + Images löschen
docker compose -f portainer-stack.yml down --rmi all
```

### 6. Updates durchführen

```bash
# Neue Images pullen
docker compose -f portainer-stack.yml pull

# Stack mit neuen Images neu starten
docker compose -f portainer-stack.yml up -d

# Oder in einem Befehl:
docker compose -f portainer-stack.yml pull && docker compose -f portainer-stack.yml up -d

# Alte/ungenutzte Images aufräumen
docker image prune -a -f
```

### 7. Einzelne Container verwalten

```bash
# In Container einsteigen (Shell)
docker compose -f portainer-stack.yml exec pocketbase sh
docker compose -f portainer-stack.yml exec app sh

# Befehl in Container ausführen
docker compose -f portainer-stack.yml exec pocketbase ls -la /pb_data

# Container inspizieren
docker compose -f portainer-stack.yml exec pocketbase env
```

### 8. Volumes verwalten

```bash
# Volumes anzeigen
docker volume ls

# Volume inspizieren
docker volume inspect lager_app_pb_data

# Volume Backup erstellen
docker run --rm -v lager_app_pb_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/pb_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .

# Volume wiederherstellen
docker run --rm -v lager_app_pb_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/pb_data_backup_YYYYMMDD_HHMMSS.tar.gz -C /data
```

### 9. Netzwerk prüfen

```bash
# Netzwerke anzeigen
docker network ls

# Netzwerk inspizieren
docker network inspect lager_app_lager_network

# Welche Container sind im Netzwerk?
docker network inspect lager_app_lager_network --format='{{range .Containers}}{{.Name}} {{end}}'
```

### 10. Troubleshooting

```bash
# Alle Container-Prozesse anzeigen
docker compose -f portainer-stack.yml top

# Container-Events live verfolgen
docker compose -f portainer-stack.yml events

# Konfiguration validieren
docker compose -f portainer-stack.yml config

# Konfiguration mit aufgelösten Variablen anzeigen
docker compose -f portainer-stack.yml config --resolve-image-digests

# Port-Mappings anzeigen
docker compose -f portainer-stack.yml port pocketbase 8080
docker compose -f portainer-stack.yml port app 8081
```

---

## 🔄 Kompletter Update-Workflow

**Szenario:** Neue Version deployen

```bash
# 1. Auf Entwicklungsrechner: Neue Images bauen
cd ~/lager_app
docker build -t ghcr.io/germanlion67/lager_app_pocketbase:latest ./server
docker build -t ghcr.io/germanlion67/lager_app_web:latest ./app

# 2. Images zu GHCR pushen
docker push ghcr.io/germanlion67/lager_app_pocketbase:latest
docker push ghcr.io/germanlion67/lager_app_web:latest

# 3. Auf Server: Neue Images pullen und deployen
ssh user@server
cd ~/lager_app
docker compose -f portainer-stack.yml pull
docker compose -f portainer-stack.yml up -d

# 4. Status prüfen
docker compose -f portainer-stack.yml ps
docker compose -f portainer-stack.yml logs -f --tail=50
```

---

## 🌐 Reverse Proxy Konfiguration

### Nginx (Beispiel)

```nginx
# Frontend
server {
    listen 80;
    server_name example.com;
    
    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# PocketBase API
server {
    listen 80;
    server_name api.example.com;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket Support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Traefik (Beispiel)

Füge diese Labels zu `portainer-stack.yml` hinzu:

```yaml
services:
  app:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.lager-app.rule=Host(`example.com`)"
      - "traefik.http.routers.lager-app.entrypoints=websecure"
      - "traefik.http.routers.lager-app.tls.certresolver=letsencrypt"
      - "traefik.http.services.lager-app.loadbalancer.server.port=8081"
  
  pocketbase:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.lager-api.rule=Host(`api.example.com`)"
      - "traefik.http.routers.lager-api.entrypoints=websecure"
      - "traefik.http.routers.lager-api.tls.certresolver=letsencrypt"
      - "traefik.http.services.lager-api.loadbalancer.server.port=8080"
```

---

## 🔧 Troubleshooting

### Container startet nicht

```bash
# Detaillierte Logs anzeigen
docker compose -f portainer-stack.yml logs pocketbase
docker compose -f portainer-stack.yml logs app

# Container-Konfiguration prüfen
docker compose -f portainer-stack.yml config

# Container neu erstellen
docker compose -f portainer-stack.yml up -d --force-recreate

# Einzelnen Container neu erstellen
docker compose -f portainer-stack.yml up -d --force-recreate pocketbase
```

### Images nicht gefunden

```bash
# Manuell bei GHCR anmelden
echo "DEIN_GITHUB_TOKEN" | docker login ghcr.io -u germanlion67 --password-stdin

# Images manuell pullen
docker pull ghcr.io/germanlion67/lager_app_pocketbase:latest
docker pull ghcr.io/germanlion67/lager_app_web:latest

# Image-Cache löschen und neu pullen
docker compose -f portainer-stack.yml pull --no-cache
```

### PocketBase Admin nicht erreichbar

```bash
# 1. Container läuft?
docker compose -f portainer-stack.yml ps

# 2. Logs prüfen
docker compose -f portainer-stack.yml logs pocketbase

# 3. Port-Mapping prüfen
docker compose -f portainer-stack.yml port pocketbase 8080

# 4. Healthcheck Status
docker inspect lager_pocketbase --format='{{.State.Health.Status}}'

# 5. Manuell testen
curl http://localhost:8080/api/health
```

### Volumes/Daten gehen verloren

```bash
# Volumes vor dem Löschen sichern!
docker run --rm -v lager_app_pb_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/pb_data_backup.tar.gz -C /data .

# Volumes anzeigen (sollten nach 'down' noch existieren)
docker volume ls | grep lager_app

# Stack OHNE Volume-Löschung herunterfahren
docker compose -f portainer-stack.yml down
# NICHT: docker compose -f portainer-stack.yml down -v
```

### Performance-Probleme

```bash
# Ressourcen-Nutzung prüfen
docker stats

# Container-Logs Größe prüfen
docker compose -f portainer-stack.yml exec pocketbase du -sh /var/log

# Alte Logs rotieren
docker compose -f portainer-stack.yml logs --since 24h > logs_backup.txt
docker compose -f portainer-stack.yml restart

# Ungenutzte Images/Container aufräumen
docker system prune -a -f
```

---

## 📊 Monitoring

### Via Portainer

- **Container Status:** Stacks → lager_app
- **Logs:** Containers → lager_pocketbase/lager_app → Logs
- **Stats:** Containers → lager_pocketbase/lager_app → Stats
- **Console:** Containers → lager_pocketbase/lager_app → Console

### Via CLI

```bash
# Echtzeit-Monitoring
watch -n 2 'docker compose -f portainer-stack.yml ps'

# Ressourcen-Nutzung
docker stats --no-stream

# Disk-Usage
docker system df

# Detaillierte Disk-Usage
docker system df -v
```

---

## 🎯 Quick Reference

### Häufigste Befehle

```bash
# Stack starten
docker compose -f portainer-stack.yml up -d

# Status prüfen
docker compose -f portainer-stack.yml ps

# Logs anzeigen
docker compose -f portainer-stack.yml logs -f

# Update durchführen
docker compose -f portainer-stack.yml pull && docker compose -f portainer-stack.yml up -d

# Stack stoppen
docker compose -f portainer-stack.yml down

# Backup erstellen
docker run --rm -v lager_app_pb_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/backup_$(date +%Y%m%d).tar.gz -C /data .
```
