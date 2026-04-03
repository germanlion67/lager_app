#!/usr/bin/env bash
# =============================================================================
# Lager_app — Backup-Script (Container-Version)
# =============================================================================
#
# Wird vom Cron im Backup-Container ausgeführt.
# Kann auch manuell aufgerufen werden:
#   docker exec lager_backup /backup/backup.sh
#
# =============================================================================

set -euo pipefail

# ── Umgebungsvariablen laden ─────────────────────────────────────────────────

if [[ -f /backup/.env_backup ]]; then
    set -a
    source /backup/.env_backup
    set +a
fi

# ── Konfiguration ────────────────────────────────────────────────────────────

PB_DATA_DIR="${PB_DATA_DIR:-/pb_data}"
PB_BACKUPS_DIR="${PB_BACKUPS_DIR:-/pb_backups}"
KEEP_DAYS="${BACKUP_KEEP_DAYS:-7}"
NOTIFY="${BACKUP_NOTIFY:-none}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DATE_HUMAN="$(date '+%Y-%m-%d %H:%M:%S')"
BACKUP_FILE="lager_backup_${TIMESTAMP}.tar.gz"

# Status-Tracking
STATUS="success"
ERROR_MSG=""

# ── Hilfsfunktionen ──────────────────────────────────────────────────────────

log_info()  { echo "[$(date '+%H:%M:%S')] ℹ️  $*"; }
log_ok()    { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
log_warn()  { echo "[$(date '+%H:%M:%S')] ⚠️  $*"; }
log_error() { echo "[$(date '+%H:%M:%S')] ❌ $*"; STATUS="error"; ERROR_MSG="$*"; }

# Benachrichtigung senden
send_notification() {
    local status="$1"
    local message="$2"
    local subject=""

    if [[ "$NOTIFY" == "none" ]]; then
        return 0
    fi

    if [[ "$status" == "success" ]]; then
        subject="✅ Lager_app Backup erfolgreich — $(date '+%Y-%m-%d')"
    else
        subject="❌ Lager_app Backup FEHLGESCHLAGEN — $(date '+%Y-%m-%d')"
    fi

    case "$NOTIFY" in
        email)
            send_email "$subject" "$message"
            ;;
        webhook)
            send_webhook "$status" "$subject" "$message"
            ;;
        *)
            log_warn "Unbekannter Benachrichtigungstyp: $NOTIFY"
            ;;
    esac
}

send_email() {
    local subject="$1"
    local body="$2"
    local to="${BACKUP_SMTP_TO:-}"

    if [[ -z "$to" ]]; then
        log_warn "Keine E-Mail-Adresse konfiguriert (BACKUP_SMTP_TO)"
        return 1
    fi

    echo -e "Subject: ${subject}\nFrom: ${BACKUP_SMTP_FROM:-backup@lager-app}\nTo: ${to}\nContent-Type: text/plain; charset=UTF-8\n\n${body}" \
        | msmtp "$to" 2>/dev/null \
        && log_ok "E-Mail gesendet an $to" \
        || log_warn "E-Mail-Versand fehlgeschlagen"
}

send_webhook() {
    local status="$1"
    local subject="$2"
    local body="$3"
    local url="${BACKUP_WEBHOOK_URL:-}"

    if [[ -z "$url" ]]; then
        log_warn "Keine Webhook-URL konfiguriert (BACKUP_WEBHOOK_URL)"
        return 1
    fi

    curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{\"status\":\"${status}\",\"subject\":\"${subject}\",\"message\":\"${body}\"}" \
        >/dev/null 2>&1 \
        && log_ok "Webhook gesendet" \
        || log_warn "Webhook fehlgeschlagen"
}

# Status-JSON schreiben (für App-Anzeige)
write_status() {
    local status="$1"
    local file="$2"
    local size="$3"
    local count="$4"
    local error="${5:-}"

    cat > "$PB_BACKUPS_DIR/last_backup.json" <<EOF
{
    "status": "${status}",
    "timestamp": "${DATE_HUMAN}",
    "timestamp_unix": $(date +%s),
    "file": "${file}",
    "size": "${size}",
    "backup_count": ${count},
    "keep_days": ${KEEP_DAYS},
    "error": "${error}"
}
EOF
    # M-008: Kopie nach pb_public für HTTP-Zugriff durch die App
    if [[ -d "/pb_public" ]]; then
        cp "$PB_BACKUPS_DIR/last_backup.json" "/pb_public/last_backup.json" 2>/dev/null \
            && log_info "Status-JSON nach pb_public kopiert" \
            || log_warn "Konnte Status-JSON nicht nach pb_public kopieren"
    fi

}

# ── Hauptprogramm ────────────────────────────────────────────────────────────

log_info "═══════════════════════════════════════════════════════"
log_info "Lager_app Backup — ${DATE_HUMAN}"
log_info "═══════════════════════════════════════════════════════"

# ── Vorprüfungen ─────────────────────────────────────────────────────────────

if [[ ! -d "$PB_DATA_DIR" ]]; then
    log_error "Datenverzeichnis nicht gefunden: $PB_DATA_DIR"
    write_status "error" "" "0" "0" "Datenverzeichnis nicht gefunden"
    send_notification "error" "Datenverzeichnis nicht gefunden: $PB_DATA_DIR"
    exit 1
fi

if [[ ! -f "$PB_DATA_DIR/data.db" ]]; then
    log_error "Datenbank nicht gefunden: $PB_DATA_DIR/data.db"
    write_status "error" "" "0" "0" "Datenbank nicht gefunden"
    send_notification "error" "Datenbank nicht gefunden: $PB_DATA_DIR/data.db"
    exit 1
fi

mkdir -p "$PB_BACKUPS_DIR"

# Speicherplatz prüfen (mindestens 100 MB)
AVAILABLE_MB=$(df -m "$PB_BACKUPS_DIR" | awk 'NR==2 {print $4}')
if [[ "$AVAILABLE_MB" -lt 100 ]]; then
    log_error "Zu wenig Speicherplatz: ${AVAILABLE_MB} MB frei"
    write_status "error" "" "0" "0" "Zu wenig Speicherplatz: ${AVAILABLE_MB} MB"
    send_notification "error" "Zu wenig Speicherplatz auf dem Backup-Volume: ${AVAILABLE_MB} MB frei (mindestens 100 MB benötigt)"
    exit 1
fi

DB_SIZE=$(du -sh "$PB_DATA_DIR/data.db" 2>/dev/null | cut -f1 || echo "unbekannt")
DATA_SIZE=$(du -sh "$PB_DATA_DIR" 2>/dev/null | cut -f1 || echo "unbekannt")

log_info "Quelle:     $PB_DATA_DIR"
log_info "DB-Größe:   $DB_SIZE"
log_info "Gesamt:     $DATA_SIZE"
log_info "Speicher:   ${AVAILABLE_MB} MB frei"

# ── Schritt 1: SQLite WAL-Checkpoint ─────────────────────────────────────────

log_info "SQLite WAL-Checkpoint..."

sqlite3 "$PB_DATA_DIR/data.db" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null \
    && log_ok "WAL-Checkpoint erfolgreich" \
    || log_warn "WAL-Checkpoint fehlgeschlagen (Backup wird trotzdem erstellt)"

# ── Schritt 2: Backup erstellen ──────────────────────────────────────────────

log_info "Erstelle Backup-Archiv..."

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Datenbank und Storage kopieren
cp -r "$PB_DATA_DIR" "$TEMP_DIR/pb_data"

# Metadaten
cat > "$TEMP_DIR/backup_info.txt" <<EOF
Lager_app Backup
================
Erstellt:     ${DATE_HUMAN}
Hostname:     $(hostname)
Datei:        ${BACKUP_FILE}
DB-Größe:     ${DB_SIZE}
Daten-Größe:  ${DATA_SIZE}
Rotation:     ${KEEP_DAYS} Tage
EOF

# Archiv erstellen
tar czf "$PB_BACKUPS_DIR/$BACKUP_FILE" \
    -C "$TEMP_DIR" \
    pb_data \
    backup_info.txt \
    2>/dev/null

if [[ ! -f "$PB_BACKUPS_DIR/$BACKUP_FILE" ]]; then
    log_error "Backup-Archiv konnte nicht erstellt werden!"
    write_status "error" "" "0" "0" "Archiv-Erstellung fehlgeschlagen"
    send_notification "error" "Backup-Archiv konnte nicht erstellt werden."
    exit 1
fi

BACKUP_SIZE=$(du -sh "$PB_BACKUPS_DIR/$BACKUP_FILE" | cut -f1)
log_ok "Backup erstellt: $BACKUP_FILE ($BACKUP_SIZE)"

# ── Schritt 3: Integrität prüfen ─────────────────────────────────────────────

log_info "Prüfe Integrität..."

if tar tzf "$PB_BACKUPS_DIR/$BACKUP_FILE" &>/dev/null; then
    FILE_COUNT=$(tar tzf "$PB_BACKUPS_DIR/$BACKUP_FILE" | wc -l)
    log_ok "Archiv OK — ${FILE_COUNT} Dateien"
else
    log_error "Archiv ist beschädigt!"
    rm -f "$PB_BACKUPS_DIR/$BACKUP_FILE"
    write_status "error" "$BACKUP_FILE" "0" "0" "Archiv beschädigt"
    send_notification "error" "Backup-Archiv war beschädigt und wurde gelöscht: $BACKUP_FILE"
    exit 1
fi

# ── Schritt 4: Rotation ─────────────────────────────────────────────────────

log_info "Rotiere Backups älter als $KEEP_DAYS Tage..."

DELETED_COUNT=0
while IFS= read -r old_backup; do
    rm -f "$old_backup"
    log_info "  Gelöscht: $(basename "$old_backup")"
    ((DELETED_COUNT++))
done < <(find "$PB_BACKUPS_DIR" -name "lager_backup_*.tar.gz" -mtime +"$KEEP_DAYS" -type f 2>/dev/null)

if [[ "$DELETED_COUNT" -eq 0 ]]; then
    log_info "  Keine alten Backups zu löschen"
else
    log_ok "$DELETED_COUNT alte Backup(s) gelöscht"
fi

# ── Zusammenfassung ──────────────────────────────────────────────────────────

TOTAL_BACKUPS=$(find "$PB_BACKUPS_DIR" -name "lager_backup_*.tar.gz" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$PB_BACKUPS_DIR" 2>/dev/null | cut -f1)

log_info "═══════════════════════════════════════════════════════"
log_ok "Backup abgeschlossen!"
log_info "  Datei:       $BACKUP_FILE"
log_info "  Größe:       $BACKUP_SIZE"
log_info "  Vorhandene:  $TOTAL_BACKUPS Backup(s)"
log_info "  Gesamt:      $TOTAL_SIZE"
log_info "═══════════════════════════════════════════════════════"

# ── Status schreiben & Benachrichtigung ──────────────────────────────────────

write_status "success" "$BACKUP_FILE" "$BACKUP_SIZE" "$TOTAL_BACKUPS"

NOTIFICATION_BODY="Backup erfolgreich erstellt.

Datei:       ${BACKUP_FILE}
Größe:       ${BACKUP_SIZE}
DB-Größe:    ${DB_SIZE}
Vorhandene:  ${TOTAL_BACKUPS} Backup(s)
Gesamt:      ${TOTAL_SIZE}
Rotation:    ${KEEP_DAYS} Tage
Zeitpunkt:   ${DATE_HUMAN}"

send_notification "success" "$NOTIFICATION_BODY"