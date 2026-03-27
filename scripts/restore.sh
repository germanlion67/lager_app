#!/usr/bin/env bash
# =============================================================================
# Lager_app — Backup-Wiederherstellung
# =============================================================================
#
# Stellt ein PocketBase-Backup aus einem tar.gz-Archiv wieder her.
#
# Verwendung:
#   ./scripts/restore.sh                               # Zeigt verfügbare Backups
#   ./scripts/restore.sh lager_backup_20260327.tar.gz   # Stellt Backup wieder her
#
# ⚠️ ACHTUNG: Die aktuelle Datenbank wird dabei überschrieben!
#
# Funktioniert sowohl mit docker-compose.yml (Dev) als auch mit
# docker-compose.prod.yml (Produktion).
#
# =============================================================================

set -euo pipefail

# ── Konfiguration ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PB_DATA_DIR="${PROJECT_ROOT}/server/pb_data"
BACKUP_DIR="${BACKUP_DIR:-${PROJECT_ROOT}/server/pb_backups}"

CONTAINER_NAME="pocketbase"
BACKUP_CONTAINER_NAME="lager_backup"

# ── Hilfsfunktionen ──────────────────────────────────────────────────────────

log_info()  { echo "[$(date '+%H:%M:%S')] ℹ️  $*"; }
log_ok()    { echo "[$(date '+%H:%M:%S')] ✅ $*"; }
log_warn()  { echo "[$(date '+%H:%M:%S')] ⚠️  $*"; }
log_error() { echo "[$(date '+%H:%M:%S')] ❌ $*"; }

# ── Verfügbare Backups anzeigen ──────────────────────────────────────────────

list_backups() {
    echo ""
    echo "📦 Verfügbare Backups in: $BACKUP_DIR"
    echo "───────────────────────────────────────────────────────"

    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR"/lager_backup_*.tar.gz 2>/dev/null)" ]]; then
        echo "  Keine Backups gefunden."
        echo ""
        exit 0
    fi

    printf "  %-40s %10s %s\n" "DATEI" "GRÖSSE" "DATUM"
    echo "  ────────────────────────────────────────────────────"

    for f in "$BACKUP_DIR"/lager_backup_*.tar.gz; do
        SIZE=$(du -sh "$f" | cut -f1)
        DATE=$(date -r "$f" '+%Y-%m-%d %H:%M')
        printf "  %-40s %10s %s\n" "$(basename "$f")" "$SIZE" "$DATE"
    done

    # Letzten Backup-Status anzeigen
    if [[ -f "$BACKUP_DIR/last_backup.json" ]]; then
        echo ""
        echo "📋 Letztes Backup:"
        echo "───────────────────────────────────────────────────────"
        jq -r '"  Status:    \(.status)\n  Zeitpunkt: \(.timestamp)\n  Datei:     \(.file)\n  Größe:     \(.size)"' \
            "$BACKUP_DIR/last_backup.json" 2>/dev/null || cat "$BACKUP_DIR/last_backup.json"
    fi

    echo ""
    echo "Verwendung: $0 <DATEINAME>"
    echo ""
}

# ── Ohne Argument: Backups auflisten ─────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    list_backups
    exit 0
fi

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Verwendung: $0 [BACKUP_DATEI]"
    echo ""
    echo "  Ohne Argument:  Zeigt verfügbare Backups"
    echo "  Mit Dateiname:  Stellt das angegebene Backup wieder her"
    echo ""
    exit 0
fi

# ── Backup-Datei prüfen ─────────────────────────────────────────────────────

BACKUP_FILE="$1"

if [[ ! -f "$BACKUP_FILE" ]]; then
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
    log_error "Backup-Datei nicht gefunden: $1"
    echo ""
    list_backups
    exit 1
fi

log_info "Prüfe Archiv-Integrität..."
if ! tar tzf "$BACKUP_FILE" &>/dev/null; then
    log_error "Archiv ist beschädigt: $BACKUP_FILE"
    exit 1
fi
log_ok "Archiv OK"

# ── Sicherheitsabfrage ──────────────────────────────────────────────────────

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  ⚠️  ACHTUNG: DATENBANK WIRD ÜBERSCHRIEBEN!              ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║                                                           ║"
printf "║  Backup:  %-47s ║\n" "$(basename "$BACKUP_FILE")"
printf "║  Ziel:    %-47s ║\n" "$PB_DATA_DIR"
echo "║                                                           ║"
echo "║  Die aktuelle Datenbank wird durch das Backup             ║"
echo "║  ersetzt. Dieser Vorgang kann NICHT rückgängig            ║"
echo "║  gemacht werden!                                          ║"
echo "║                                                           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
read -rp "Fortfahren? (ja/nein): " CONFIRM

if [[ "$CONFIRM" != "ja" ]]; then
    log_info "Abgebrochen."
    exit 0
fi

# ── Schritt 1: Container stoppen ─────────────────────────────────────────────

log_info "Stoppe Container..."

CONTAINERS_STOPPED=()

for name in "$BACKUP_CONTAINER_NAME" "$CONTAINER_NAME"; do
    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        docker stop "$name" >/dev/null 2>&1
        CONTAINERS_STOPPED+=("$name")
        log_ok "  $name gestoppt"
    fi
done

# ── Schritt 2: Sicherheitskopie ─────────────────────────────────────────────

SAFETY_BACKUP="${BACKUP_DIR}/pre_restore_$(date +%Y%m%d_%H%M%S).tar.gz"
log_info "Erstelle Sicherheitskopie..."

tar czf "$SAFETY_BACKUP" -C "$(dirname "$PB_DATA_DIR")" "$(basename "$PB_DATA_DIR")" 2>/dev/null
log_ok "Sicherheitskopie: $(basename "$SAFETY_BACKUP")"

# ── Schritt 3: Wiederherstellen ──────────────────────────────────────────────

log_info "Stelle Backup wieder her..."

rm -rf "$PB_DATA_DIR"
mkdir -p "$PB_DATA_DIR"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"

if [[ -d "$TEMP_DIR/pb_data" ]]; then
    cp -r "$TEMP_DIR/pb_data/"* "$PB_DATA_DIR/"
    log_ok "pb_data wiederhergestellt"
else
    log_error "pb_data nicht im Archiv gefunden!"
    log_info "Stelle Sicherheitskopie wieder her..."
    tar xzf "$SAFETY_BACKUP" -C "$(dirname "$PB_DATA_DIR")"
    exit 1
fi

if [[ -f "$TEMP_DIR/backup_info.txt" ]]; then
    echo ""
    echo "📋 Backup-Informationen:"
    echo "───────────────────────────────────────────────────────"
    cat "$TEMP_DIR/backup_info.txt"
    echo "───────────────────────────────────────────────────────"
fi

# ── Schritt 4: Container neu starten ────────────────────────────────────────

if [[ ${#CONTAINERS_STOPPED[@]} -gt 0 ]]; then
    log_info "Starte Container..."

    # PocketBase zuerst, dann Backup
    for name in "$CONTAINER_NAME" "$BACKUP_CONTAINER_NAME"; do
        if [[ " ${CONTAINERS_STOPPED[*]} " =~ " ${name} " ]]; then
            docker start "$name" >/dev/null 2>&1
            log_ok "  $name gestartet"
        fi
    done

    # Warte auf PocketBase Healthcheck
    log_info "Warte auf PocketBase..."
    for i in {1..30}; do
        if docker exec "$CONTAINER_NAME" wget --spider -q "http://localhost:8080/api/health" 2>/dev/null; then
            log_ok "PocketBase ist bereit!"
            break
        fi
        if [[ $i -eq 30 ]]; then
            log_warn "Healthcheck-Timeout — prüfe: docker logs $CONTAINER_NAME"
        fi
        sleep 1
    done
fi

# ── Zusammenfassung ──────────────────────────────────────────────────────────

echo ""
log_info "═══════════════════════════════════════════════════════"
log_ok "Wiederherstellung abgeschlossen!"
log_info "  Backup:           $(basename "$BACKUP_FILE")"
log_info "  Sicherheitskopie: $(basename "$SAFETY_BACKUP")"
log_info "═══════════════════════════════════════════════════════"
echo ""
log_info "Falls Probleme auftreten:"
log_info "  $0 $(basename "$SAFETY_BACKUP")"