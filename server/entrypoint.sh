#!/bin/sh
set -e

# ============================================================
# PocketBase Entrypoint with CORS Configuration (H-002)
#
# Liest CORS_ALLOWED_ORIGINS aus der Umgebung und übergibt
# die Origins als --origins Flag an PocketBase.
#
# Beispiele für CORS_ALLOWED_ORIGINS:
#   "*"                                          → Alle Origins (Entwicklung)
#   "https://lager.example.com"                  → Einzelne Domain
#   "https://lager.example.com,https://admin.example.com"  → Mehrere Domains
#   "https://lager.example.com,http://localhost:8081"       → Produktion + lokale Entwicklung
#
# PocketBase v0.36+ akzeptiert --origins als komma-getrennte Liste.
# Mobile Apps (Android/iOS/Desktop) senden keinen Origin-Header,
# CORS betrifft nur Browser-Requests.
# ============================================================

CORS="${CORS_ALLOWED_ORIGINS:-*}"

echo "============================================"
echo "PocketBase Entrypoint"
echo "============================================"
echo "CORS_ALLOWED_ORIGINS: $CORS"
echo "Data directory:       ${PB_DATA_DIR:-/pb_data}"
echo "============================================"

# Validierung: Warnung bei Wildcard in Produktion
if [ "$CORS" = "*" ]; then
  echo ""
  echo "⚠️  WARNING: CORS is set to wildcard (*)"
  echo "   This is fine for development but INSECURE for production!"
  echo "   Set CORS_ALLOWED_ORIGINS in .env.production to your domain(s)."
  echo ""
fi

# PocketBase im Hintergrund starten MIT/OHNE --origins Flag
if [ "$CORS" = "*" ]; then
  # Wildcard: kein --origins Flag → PocketBase Default (alles erlaubt)
  echo "Starting PocketBase (CORS: wildcard/default)..."
  /pb/pocketbase serve \
    --http=0.0.0.0:8080 \
    --dir="${PB_DATA_DIR:-/pb_data}" &
else
  # Spezifische Origins: --origins Flag setzen
  echo "Starting PocketBase (CORS: restricted)..."
  /pb/pocketbase serve \
    --http=0.0.0.0:8080 \
    --dir="${PB_DATA_DIR:-/pb_data}" \
    --origins="$CORS" &
fi

PB_PID=$!

# Warten bis PocketBase bereit ist, dann Init-Script ausführen
sleep 3
/pb/init-pocketbase.sh

# Auf PocketBase-Prozess warten (Container läuft solange PB läuft)
wait $PB_PID