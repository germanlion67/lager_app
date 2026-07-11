# 🏷️ Image-Tagging-Strategie — Lager_app  

**Letzte Aktualisierung:** 2026-05-21  
**Geprüft gegen:** ci.yml, docker-images.yml, release.yml, docker-compose.prod.yml  

---

## Übersicht  

Docker-Images wird über ein GitHub Actions Workflows gebaut und in der  
GitHub Container Registry (GHCR) veröffentlicht. Der Workflow ist **nicht automatisch  
verknüpft** — der Docker-Build muss nach einem Release manuell ausgelöst werden.  

> ⚠️ **Wichtig:** Flutter verwendet `version: 0.9.9+76` in `pubspec.yaml`.  
> Das `+76` (Build-Nummer) ist **kein gültiges Docker-Tag-Zeichen** (`+` ist verboten).  
> Docker-Tags verwenden daher nur `0.9.9` — ohne `v`-Präfix, ohne Build-Nummer.  

---

## 📦 Verfügbare Images  

| Image | Registry-Pfad |  
|---|---|  
| Flutter Web (Caddy) | `ghcr.io/germanlion67/lager_app_web:<tag>` |  
| PocketBase Backend | `ghcr.io/germanlion67/lager_app_pocketbase:<tag>` |  

---

## 🎯 Tagging-Schema  

### Wie Tags entstehen  

Tags werden durch `docker/metadata-action` im Workflow `docker-images.yml` generiert.  
Das Ergebnis hängt davon ab, **wie und von wo** der Workflow ausgelöst wird:  

#### Auslösung via `workflow_dispatch` auf einem Branch  
Branch: harding/v0.9.9  
→ Tag: harding-v0.9.9 (Slashes → Bindestriche)  

Branch: main  
→ Tag: main  
→ Tag: latest (nur auf Default-Branch)  

#### Auslösung nach Git-Tag (z.B. nach release.yml)  
Git-Tag: v0.9.9  
→ Tag: 0.9.9 (semver, ohne "v")  
→ Tag: 0.9 (major.minor)  
→ Tag: 0 (major)  
→ Tag: latest (nur wenn Default-Branch)  

### Vollständige Tag-Tabelle  

| Tag-Format | Beispiel | Wann erzeugt | Verwendung |  
|---|---|---|---|  
| `<major>.<minor>.<patch>` | `0.9.9` | Git-Tag vorhanden + docker-images.yml ausgeführt | **Empfohlen für Produktion** |  
| `<major>.<minor>` | `0.9` | Git-Tag vorhanden | Rolling Patch-Updates |  
| `<major>` | `0` | Git-Tag vorhanden | Rolling Minor/Patch-Updates |  
| `latest` | `latest` | Nur auf Default-Branch (main) | Nur für Dev/Test |  
| `<branch-name>` | `harding-v0.9.9` | workflow_dispatch auf Branch | Branch-Testing |  

> ℹ️ **Kein SHA-Tag:** Die aktuelle Konfiguration erzeugt keinen `<branch>-<sha>`-Tag.  
> Nur der Branch-Name wird als Tag verwendet.  

---

## 🔄 Workflow-Übersicht  

````
┌─────────────────────────────────────────────────────────────┐
│ ci.yml │
│ Trigger: push/PR auf main │
│ ├── test (analyze + flutter test) │
│ └── build-web-verify (WASM-Build + Artefakt-Prüfung) │
│ ⚠️ Kein Docker-Build, kein Image-Push │
└─────────────────────────────────────────────────────────────┘
````

````
┌─────────────────────────────────────────────────────────────┐
│ release.yml │
│ Trigger: workflow_dispatch (Version eingeben) │
│ ├── create-tag → Git-Tag v0.9.9 erstellen │
│ ├── test │
│ ├── build-android │
│ ├── build-windows │
│ ├── build-linux │
│ └── create-release → GitHub Release + Release Notes │
│ ⚠️ Kein Docker-Build, kein Image-Push │
└─────────────────────────────────────────────────────────────┘
````

````
┌─────────────────────────────────────────────────────────────┐
│ docker-images.yml │
│ Trigger: workflow_dispatch (manuell, separat!) │
│ ├── build-and-push-web → ghcr.io lager_app_web │
│ └── build-and-push-pocketbase → ghcr.io lager_app_pb │
│ ✅ Einziger Workflow der Images nach ghcr.io pusht │
└─────────────────────────────────────────────────────────────┘
````

````
┌─────────────────────────────────────────────────────────────┐
│ flutter-maintenance.yml │
│ Trigger: Montags 04:00 UTC + workflow_dispatch │
│ ├── verify (analyze, test, APK debug, Linux debug) │
│ └── windows-build │
│ ℹ️ Kein Deployment, nur Qualitätssicherung │
└─────────────────────────────────────────────────────────────┘
````

---

## ✅ Korrekter Release-Ablauf

```bash
# Schritt 1: Branch in main mergen (PR erstellen und mergen)
# → ci.yml läuft automatisch (test + build-web-verify)

# Schritt 2: release.yml manuell auslösen
# GitHub → Actions → "Release - Build and Deploy" → Run workflow
# Version eingeben: 0.9.9+76
# → Git-Tag v0.9.9 wird erstellt
# → GitHub Release mit APK/Windows/Linux wird erstellt
# → KEIN Docker-Image wird gebaut

# Schritt 3: docker-images.yml manuell auslösen
# GitHub → Actions → "Build and Push Docker Images" → Run workflow
# Auf main ausführen (damit "latest" gesetzt wird)
# → ghcr.io/germanlion67/lager_app_web:0.9.9
# → ghcr.io/germanlion67/lager_app_web:0.9
# → ghcr.io/germanlion67/lager_app_web:0
# → ghcr.io/germanlion67/lager_app_web:latest

# Schritt 4: Image verifizieren
docker pull ghcr.io/germanlion67/lager_app_web:0.9.9

# Schritt 5: Portainer Stack aktualisieren
# VERSION=0.9.9 in .env.production setzen → Pull and redeploy
```

---

## 🚀 Deployment mit docker-compose.prod.yml

### Voraussetzung: .env.production

```yaml
# .env.production
DOCKER_REGISTRY: ghcr.io
DOCKER_USERNAME: germanlion67
VERSION: 0.9.9

POCKETBASE_URL=https://api.deine-domain.de
PB_ADMIN_EMAIL=admin@deine-domain.de
PB_ADMIN_PASSWORD=sicheres-passwort-hier
CORS_ALLOWED_ORIGINS=https://app.deine-domain.de

BACKUP_ENABLED=true
BACKUP_CRON=0 3 * * *
BACKUP_KEEP_DAYS=7
BACKUP_NOTIFY=none
TZ=Europe/Berlin
```


### Stack starten

```bash
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

--- 

### Netzwerk-Architektur

```
Internet
    │
    ▼
Nginx Proxy Manager  :80 / :443   ← Einziger öffentlicher Eingang
    │                  :81 → 127.0.0.1 (Admin UI, nur lokal)
    ├──→ lager_frontend  :8081    (expose, nicht direkt erreichbar)
    │
    └──→ pocketbase      :8080    (expose, nicht direkt erreichbar)
              │
              └──→ lager_backup              (kein Port, nur intern)
```

### URL ändern ohne Rebuild

```bash
# 1. .env.production bearbeiten
nano .env.production   # POCKETBASE_URL anpassen

# 2. Nur App-Container neu starten (kein Image-Rebuild nötig)
docker compose -f docker-compose.prod.yml --env-file .env.production restart app
```

### Update auf neue Version
```bash
# 1. VERSION in .env.production setzen
sed -i 's/VERSION=0.9.9/VERSION=0.9.10/' .env.production

# 2. Image pullen
docker compose -f docker-compose.prod.yml --env-file .env.production pull app

# 3. Container neu starten
docker compose -f docker-compose.prod.yml --env-file .env.production up -d app

# 4. Verifizieren
docker compose -f docker-compose.prod.yml ps
curl https://deine-domain.de/

# 5. Bei Problemen: Rollback
sed -i 's/VERSION=0.9.10/VERSION=0.9.9/' .env.production
docker compose -f docker-compose.prod.yml --env-file .env.production up -d app
```

## 📦 GHCR — Authentifizierung und Image-Verwaltung
```bash
# Login (nur nötig wenn Image privat)
echo $GITHUB_TOKEN | docker login ghcr.io -u germanlion67 --password-stdin

# Verfügbare Tags auflisten
curl -H "Authorization: Bearer$GITHUB_TOKEN" \
  "https://ghcr.io/v2/germanlion67/lager_app_web/tags/list" | jq

# Laufende Version prüfen
docker inspect lager_frontend | jq '.[0].Config.Labels'
docker ps --format "table {{.Names}}\t{{.Image}}"
```

---

## 🔍 Troubleshooting

### Image nicht gefunden
```bash
# 1. Prüfen ob Image existiert
docker pull ghcr.io/germanlion67/lager_app_web:0.9.9

# 2. Wenn nicht gefunden: docker-images.yml wurde nicht ausgeführt
#    → GitHub Actions → "Build and Push Docker Images" → Run workflow

# 3. Wenn Authentifizierungsfehler: Image ist privat
#    → GitHub → Packages → lager_app_web → Visibility → Public
#    ODER: Registry-Credentials in Portainer hinterlegen
```

### Falscher Tag im Stack

```bash
# ❌ Funktioniert nicht (+ ist kein gültiges Docker-Tag-Zeichen)
image: ghcr.io/germanlion67/lager_app_web:v0.9.9+76

# ✅ Korrekt
image: ghcr.io/germanlion67/lager_app_web:0.9.9

# ✅ Oder über .env.production
image: ${DOCKER_REGISTRY}/${DOCKER_USERNAME}/lager_app_web:${VERSION}
# mit VERSION=0.9.9
```

### CI läuft nicht auf Feature-Branch`

`ci.yml` ist auf `main` und PRs gegen `main beschränkt:

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```
Auf `harding/v0.9.9` läuft CI nicht automatisch — erst nach dem Merge in `main`.

---

## ✅ Release-Checkliste

### Vorbereitung
  [ ] Version in pubspec.yaml gesetzt (z.B. 0.9.9+76)
  [ ] CHANGELOG.md aktualisiert
  [ ] Branch in main gemergt (PR)
  [ ] ci.yml auf main grün ✅

### Release erstellen
  [ ] release.yml ausgelöst (Version: 0.9.9+76)
      → Git-Tag v0.9.9 erstellt
      → GitHub Release mit APK/Windows/Linux vorhanden

### Docker-Images bauen
  [ ] docker-images.yml auf main ausgelöst
      → lager_app_web:0.9.9 in GHCR vorhanden
      → lager_app_pocketbase:0.9.9 in GHCR vorhanden
  [ ] docker pull ghcr.io/germanlion67/lager_app_web:0.9.9 ✅

### Deployment
  [ ] VERSION=0.9.9 in .env.production gesetzt
  [ ] Portainer Stack: Pull and redeploy
  [ ] Healthchecks grün (nginx-proxy-manager, pocketbase, app)
  [ ] https://deine-domain.de/ erreichbar ✅
  [ ] Lighthouse-Score geprüft (Referenz: LIGHTHOUSE.md)

---

## 🛠️ Offene Punkte (TODOs)

### TODO-1: docker-images.yml automatisch nach release.yml auslösen

Problem: Docker-Images müssen nach jedem Release manuell gebaut werden.
Wird vergessen → Portainer findet Image nicht.

Lösung: `release.yml` um `build-web-docker` Job erweitern:

```yaml
# In release.yml ergänzen:
build-web-docker:
  needs: [create-tag, test]
  uses: ./.github/workflows/docker-images.yml
  # ODER: Job direkt inline ergänzen (siehe docker-images.yml)
  permissions:
    packages: write
```

### TODO-2: Backup-Service auf vorgebautes Image umstellen

Problem: `docker-compose.prod.yml` baut den Backup-Service lokal:

```yaml
backup:
  build:
    context: ./server/backup
    dockerfile: Dockerfile
```
Das widerspricht dem Prinzip "keine lokalen Build-Tools auf dem Produktionsserver"
und verlängert den Stack-Start.

Lösung: Backup-Image in `docker-images.yml` bauen und pushen:

```yaml
# In docker-images.yml ergänzen:
build-and-push-backup:
  # analog zu build-and-push-pocketbase
  # image: ghcr.io/germanlion67/lager_app_backup:<tag>
```

### TODO-3: ci.yml auf Feature-Branches erweitern (optional)

Problem: CI läuft nicht auf `harding/*`-Branches — Fehler werden erst nach
dem Merge in `main` sichtbar.

Lösung:
```yaml
on:
  push:
    branches: [main, 'harding/**', 'feature/**']
  pull_request:
    branches: [main]
```

### TODO-4: `v`-Präfix im Git-Tag mit Docker-Tag harmonisieren

Problem: Git-Tag ist `v0.9.9`, Docker-Tag ist `0.9.9` (ohne `v`).
Release Notes schreiben `v0.9.9+76` — keines davon existiert als Docker-Tag.

Lösung A: `metadata-action` mit v-Präfix konfigurieren:
```yaml
tags: |
  type=semver,pattern=v{{version}}   # → v0.9.9
```
Lösung B: Dokumentation und Release Notes konsequent auf `0.9.9` (ohne v)
vereinheitlichen.

---

## 📚 Weiterführende Dokumentation


1. [CHANGELOG.md](../CHANGELOG.md)
2. [LIGHTHOUSE-Bericht](LIGHTHOUSE.md)
3. [H-004/H-005 Maßnahmen](OPTIMIZATIONS.md)
4. [Erstinstallation](../INSTALL.md)
5. [GitHub Releases](https://github.com/germanlion67/lager_app/releases)
6. [Alle Images](https://github.com/germanlion67?tab=packages)
7. [Support](https://github.com/germanlion67/lager_app/issues)
