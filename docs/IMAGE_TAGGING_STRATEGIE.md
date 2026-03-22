# 🏷️ Image-Tagging-Strategie - Lager_app

**Letzte Aktualisierung:** 2026-03-22

## Übersicht

Dieses Dokument beschreibt die Image-Tagging-Strategie für Docker-Images der Lager_app. Die Strategie basiert auf **Semantic Versioning (SemVer)** und ermöglicht vorhersehbare Deployments.

---

## 🎯 Tagging-Schema

### Produktions-Images

Alle Docker-Images werden automatisch über GitHub Actions gebaut und in GitHub Container Registry (GHCR) veröffentlicht:

```
ghcr.io/germanlion67/lager_app_web:<tag>
```

### Verfügbare Tags

| Tag-Format | Beispiel | Beschreibung | Verwendung |
|------------|----------|--------------|------------|
| `v<version>` | `v1.2.0` | Spezifische Release-Version (SemVer) | **Empfohlen für Produktion** |
| `v<major>.<minor>` | `v1.2` | Latest Patch für Minor-Version | Rolling Updates innerhalb Minor-Version |
| `v<major>` | `v1` | Latest Minor/Patch für Major-Version | Rolling Updates innerhalb Major-Version |
| `latest` | `latest` | Neuestes Release | **Nur für Entwicklung/Testing** |
| `main` | `main` | Neuester Build vom main-Branch | **Nur für CI/CD-Testing** |
| `<branch>-<sha>` | `feature-abc123` | Spezifischer Branch-Build | **Nur für Feature-Testing** |

---

## ✅ Best Practices

### Für Produktionsumgebungen

**Empfehlung:** Verwenden Sie **exakte Versions-Tags** (`v1.2.0`)

```yaml
# docker-compose.prod.yml
services:
  app:
    image: ghcr.io/germanlion67/lager_app_web:v1.2.0  # ✅ Empfohlen
```

**Vorteile:**
- ✅ Vorhersehbares Verhalten
- ✅ Reproduzierbare Deployments
- ✅ Kontrollierte Updates
- ✅ Einfaches Rollback

**Warnung vor `latest`:**
```yaml
# ❌ NICHT für Produktion verwenden
services:
  app:
    image: ghcr.io/germanlion67/lager_app_web:latest
```

**Probleme mit `latest`:**
- ❌ Unvorhersehbare Updates beim `docker pull`
- ❌ Schwer zu debuggen (welche Version läuft?)
- ❌ Schwieriges Rollback
- ❌ Unterschiedliche Versionen auf verschiedenen Servern

### Für Entwicklungsumgebungen

Für Dev/Test können Sie flexiblere Tags verwenden:

```yaml
# docker-compose.yml (Development)
services:
  app:
    image: ghcr.io/germanlion67/lager_app_web:latest  # OK für Dev
```

---

## 🔄 Update-Strategien

### Strategie 1: Manuelle Updates (Empfohlen)

**Für:** Produktionsumgebungen, kritische Systeme

```bash
# 1. Neue Version in .env setzen
echo "VERSION=v1.3.0" >> .env

# 2. Image pullen
docker compose pull app

# 3. Services neu starten
docker compose up -d

# 4. Verifizieren
docker compose ps
docker compose logs app
```

### Strategie 2: Rolling Minor Updates

**Für:** Unkritische Umgebungen, automatische Patch-Updates

```yaml
# .env
VERSION=v1.2  # Automatisch neuestes v1.2.x
```

**Wichtig:** Regelmäßig testen und manuell auf neue Minor-Versionen upgraden!

### Strategie 3: Pinned Version mit Update-Reminder

**Für:** Produktionsumgebungen mit geplanten Wartungsfenstern

```yaml
# .env
VERSION=v1.2.0  # Exakte Version
# TODO: Nächstes Update-Fenster: 2026-04-15
# Check: https://github.com/germanlion67/lager_app/releases
```

---

## 📦 Verfügbare Registries

### GitHub Container Registry (GHCR) - Empfohlen

```bash
# Authentifizierung (falls private)
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Image pullen
docker pull ghcr.io/germanlion67/lager_app_web:v1.2.0
```

**Vorteile:**
- ✅ Direkt mit GitHub-Repository verknüpft
- ✅ Kostenlos für öffentliche Repositories
- ✅ Automatische Builds via GitHub Actions
- ✅ Hohe Verfügbarkeit

### Docker Hub - Optional

Falls gewünscht, können Images zusätzlich zu Docker Hub gepusht werden:

```yaml
# docker-compose.prod.yml
services:
  app:
    image: germanlion67/lager_app_web:v1.2.0
```

---

## 🔍 Image-Informationen abrufen

### Version eines laufenden Containers prüfen

```bash
# Inspect Image Labels
docker inspect lager_frontend | jq '.[0].Config.Labels'

# Prüfe Image-Tag
docker ps --format "table {{.Names}}\t{{.Image}}"
```

### Verfügbare Tags auflisten

```bash
# GHCR Tags (erfordert Token mit read:packages)
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://ghcr.io/v2/germanlion67/lager_app_web/tags/list | jq

# GitHub Releases prüfen
gh release list --repo germanlion67/lager_app
```

---

## 🚀 Deployment-Beispiele

### Produktions-Stack mit exakter Version

```yaml
# docker-stack.yml oder docker-compose.prod.yml
version: '3.8'

services:
  app:
    image: ghcr.io/germanlion67/lager_app_web:v1.2.0
    deploy:
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
      rollback_config:
        parallelism: 1
        delay: 5s
```

### .env mit Version-Pinning

```bash
# .env.production
VERSION=v1.2.0
DOCKER_REGISTRY=ghcr.io
DOCKER_USERNAME=germanlion67
```

```yaml
# docker-compose.prod.yml
services:
  app:
    image: ${DOCKER_REGISTRY}/${DOCKER_USERNAME}/lager_app_web:${VERSION}
```

### Update auf neue Version

```bash
# 1. Backup erstellen
./backup.sh

# 2. Version in .env ändern
sed -i 's/VERSION=v1.2.0/VERSION=v1.3.0/' .env

# 3. Image pullen
docker compose pull

# 4. Rolling Update
docker compose up -d

# 5. Verifizieren
docker compose logs -f app
curl https://ihre-domain.de/

# 6. Bei Problemen: Rollback
sed -i 's/VERSION=v1.3.0/VERSION=v1.2.0/' .env
docker compose up -d
```

---

## 🧪 Verifizierung: Frisches Setup ohne Build-Tools

### Test-Szenario

Ziel: Sicherstellen, dass das Produktions-Setup **nur** vorgebaute Images verwendet und **keine** lokalen Build-Tools (Flutter, Node.js) benötigt.

### Verifizierungs-Schritte

```bash
# 1. Frisches System ohne Flutter/Node.js simulieren
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/app \
  -w /app \
  alpine:3.19 sh

# 2. Nur Docker installieren
apk add --no-cache docker-cli docker-compose

# 3. Prüfen: Keine Build-Tools vorhanden
flutter --version  # sollte "command not found" ergeben
node --version     # sollte "command not found" ergeben

# 4. .env konfigurieren
cp .env.production.example .env
# ... .env bearbeiten ...

# 5. Docker Compose verwenden
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d

# 6. Verifizieren
docker compose -f docker-compose.prod.yml ps
```

**Erwartetes Ergebnis:**
- ✅ Alle Images wurden von GHCR gepullt
- ✅ Kein lokaler Build wurde ausgeführt
- ✅ Services starten erfolgreich
- ✅ Healthchecks sind "healthy"

**Bei Fehlern:**
- ❌ Wenn `build:` Einträge in compose-File → entfernen
- ❌ Wenn lokale Dateien gemountet werden → prüfen ob notwendig

---

## 📚 Weiterführende Dokumentation

- **Releases:** [GitHub Releases](https://github.com/germanlion67/lager_app/releases)
- **GHCR Packages:** [GitHub Packages](https://github.com/germanlion67?tab=packages)
- **Deployment:** [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)
- **Changelog:** [CHANGELOG.md](../CHANGELOG.md)

---

## ✅ Checkliste für Releases

Beim Erstellen eines neuen Releases:

- [ ] Version in CHANGELOG.md eintragen
- [ ] Git-Tag erstellen (`git tag v1.2.0`)
- [ ] GitHub Release mit Tag erstellen
- [ ] GitHub Actions baut und pusht Images automatisch
- [ ] Images in GHCR verifizieren
- [ ] Produktions-Deployment testen (siehe oben)
- [ ] Dokumentation aktualisieren falls nötig
- [ ] PRIORITAETEN_CHECKLISTE.md aktualisieren

---

**Fragen?** → [GitHub Issues](https://github.com/germanlion67/lager_app/issues)
