# =============================================================================
# Lager_app — Backup-Container
# =============================================================================
# Leichtgewichtiger Container mit Cron, SQLite3 und Backup-Tools.
# Läuft als Service in docker-compose.prod.yml.
# =============================================================================

FROM alpine:3.20

RUN apk add --no-cache \
    bash \
    sqlite \
    tar \
    gzip \
    curl \
    msmtp \
    jq \
    tzdata

# Zeitzone konfigurierbar (Standard: Europe/Berlin)
ENV TZ=Europe/Berlin

# Arbeitsverzeichnis
WORKDIR /backup

# Scripts kopieren
COPY backup.sh /backup/backup.sh
COPY entrypoint.sh /backup/entrypoint.sh

RUN chmod +x /backup/backup.sh /backup/entrypoint.sh

ENTRYPOINT ["/backup/entrypoint.sh"]