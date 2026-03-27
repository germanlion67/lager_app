#!/usr/bin/env bash
# =============================================================================
# Backup-Container Entrypoint
# =============================================================================
# Konfiguriert Cron und SMTP basierend auf Umgebungsvariablen,
# dann startet den Cron-Daemon im Vordergrund.
# =============================================================================

set -euo pipefail

log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $*"; }
log_ok()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $*"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $*"; }

# ── Konfiguration anzeigen ───────────────────────────────────────────────────

BACKUP_CRON="${BACKUP_CRON:-0 3 * * *}"
BACKUP_KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"
BACKUP_ENABLED="${BACKUP_ENABLED:-true}"
BACKUP_NOTIFY="${BACKUP_NOTIFY:-none}"

log_info "═══════════════════════════════════════════════════════"
log_info "Lager_app Backup-Container"
log_info "═══════════════════════════════════════════════════════"
log_info "Backup aktiv:   $BACKUP_ENABLED"
log_info "Cron-Schedule:  $BACKUP_CRON"
log_info "Rotation:       $BACKUP_KEEP_DAYS Tage"
log_info "Benachrichtigung: $BACKUP_NOTIFY"
log_info "Zeitzone:       $TZ"

# ── SMTP konfigurieren (falls E-Mail-Benachrichtigung aktiv) ─────────────────

if [[ "$BACKUP_NOTIFY" == "email" ]]; then
    SMTP_HOST="${BACKUP_SMTP_HOST:-}"
    SMTP_PORT="${BACKUP_SMTP_PORT:-587}"
    SMTP_USER="${BACKUP_SMTP_USER:-}"
    SMTP_PASS="${BACKUP_SMTP_PASS:-}"
    SMTP_FROM="${BACKUP_SMTP_FROM:-${SMTP_USER}}"
    SMTP_TO="${BACKUP_SMTP_TO:-}"

    if [[ -z "$SMTP_HOST" ]] || [[ -z "$SMTP_USER" ]] || [[ -z "$SMTP_TO" ]]; then
        log_error "E-Mail-Benachrichtigung aktiviert, aber SMTP-Konfiguration unvollständig!"
        log_error "Benötigte Variablen: BACKUP_SMTP_HOST, BACKUP_SMTP_USER, BACKUP_SMTP_TO"
        exit 1
    fi

    # msmtp-Konfiguration erstellen
    cat > /etc/msmtprc <<EOF
defaults
auth           on
tls            on
tls_starttls   on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        backup
host           ${SMTP_HOST}
port           ${SMTP_PORT}
from           ${SMTP_FROM}
user           ${SMTP_USER}
password       ${SMTP_PASS}

account default : backup
EOF

    chmod 600 /etc/msmtprc
    log_ok "SMTP konfiguriert (${SMTP_HOST}:${SMTP_PORT})"
fi

# ── Umgebungsvariablen für Cron exportieren ──────────────────────────────────

# Cron hat keinen Zugriff auf Container-Umgebungsvariablen,
# daher exportieren wir sie in eine Datei.
env | grep -E '^(BACKUP_|SMTP_|TZ=)' > /backup/.env_backup
echo "PB_DATA_DIR=/pb_data" >> /backup/.env_backup
echo "PB_BACKUPS_DIR=/pb_backups" >> /backup/.env_backup

# ── Cron-Job einrichten ──────────────────────────────────────────────────────

if [[ "$BACKUP_ENABLED" == "true" ]]; then
    # Crontab erstellen
    echo "${BACKUP_CRON} /backup/backup.sh >> /pb_backups/backup.log 2>&1" > /etc/crontabs/root
    log_ok "Cron-Job eingerichtet: ${BACKUP_CRON}"

    # Initiales Backup beim ersten Start (falls noch keins existiert)
    if [[ ! -f /pb_backups/last_backup.json ]]; then
        log_info "Kein vorheriges Backup gefunden — erstelle initiales Backup..."
        /backup/backup.sh >> /pb_backups/backup.log 2>&1 || true
    fi

    log_ok "Backup-Container bereit — warte auf nächsten Cron-Lauf"
    log_info "═══════════════════════════════════════════════════════"

    # Cron im Vordergrund starten (hält den Container am Leben)
    exec crond -f -l 2
else
    log_info "Backup ist deaktiviert (BACKUP_ENABLED=false)"
    log_info "Container bleibt aktiv für manuelle Backups:"
    log_info "  docker exec lager_backup /backup/backup.sh"
    log_info "═══════════════════════════════════════════════════════"

    # Container am Leben halten ohne Cron
    exec tail -f /dev/null
fi