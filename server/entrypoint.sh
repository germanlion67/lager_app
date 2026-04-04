#!/bin/sh
set -e

# ============================================================
# PocketBase Entrypoint with CORS Configuration (H-002)
#
# - Kopiert Migrationen vor dem Start nach ${PB_DATA_DIR}/migrations (via init-pocketbase.sh)
# - Startet PocketBase mit --migrationsDir=${PB_DATA_DIR}/migrations, damit automigrate die richtige Quelle nutzt.
# ============================================================

CORS="${CORS_ALLOWED_ORIGINS:-*}"
PB_DIR="${PB_DATA_DIR:-/pb_data}"
PB_MIG_DIR="${PB_DIR}/migrations"

echo "============================================"
echo "PocketBase Entrypoint"
echo "============================================"
echo "CORS_ALLOWED_ORIGINS: $CORS"
echo "Data directory:       ${PB_DIR}"
echo "Migrations dir:       ${PB_MIG_DIR}"
echo "============================================"

if [ "$CORS" = "*" ]; then
  echo ""
  echo "⚠️  WARNING: CORS is set to wildcard (*)"
  echo "   This is fine for development but INSECURE for production!"
  echo "   Set CORS_ALLOWED_ORIGINS in .env.production to your domain(s)."
  echo ""
fi

# 1) Init-Script VOR PocketBase Start (damit Migrationen rechtzeitig da sind)
#    Hinweis: init-pocketbase.sh wartet auf die API. Deshalb darf es NICHT mehr warten,
#    bevor PocketBase läuft. Unser init-pocketbase.sh kopiert Migrationen früh, aber
#    der Rest (superuser/testuser) braucht die API.
#
#    Daher splitten wir den Ablauf:
#    - early migrations copy passiert hier direkt (kleiner Block),
#    - danach PocketBase starten,
#    - danach init-pocketbase.sh laufen lassen (wie bisher).

# Early migrations copy (minimal, robust)
mkdir -p "${PB_MIG_DIR}" || true
if [ -d "${PB_MIGRATIONS_DIR:-/pb_migrations}" ] && [ "$(ls -A "${PB_MIGRATIONS_DIR:-/pb_migrations}" 2>/dev/null)" ]; then
  cp -r "${PB_MIGRATIONS_DIR:-/pb_migrations}"/* "${PB_MIG_DIR}/" 2>/dev/null || true
fi

# 2) PocketBase starten (im Hintergrund), damit init-pocketbase.sh die API nutzen kann
if [ "$CORS" = "*" ]; then
  echo "Starting PocketBase (CORS: wildcard/default)..."
  /pb/pocketbase serve \
    --http=0.0.0.0:8080 \
    --dir="${PB_DIR}" \
    --migrationsDir="${PB_MIG_DIR}" &
else
  echo "Starting PocketBase (CORS: restricted)..."
  /pb/pocketbase serve \
    --http=0.0.0.0:8080 \
    --dir="${PB_DIR}" \
    --migrationsDir="${PB_MIG_DIR}" \
    --origins="$CORS" &
fi

PB_PID=$!

# 3) Init-Script (superuser/testuser) nachdem PB läuft
sleep 3
/pb/init-pocketbase.sh

# 4) Container läuft solange PB läuft
wait $PB_PID