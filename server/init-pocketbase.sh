#!/bin/sh
set -e

echo "PocketBase Initialization Script"
echo "===================================="

PB_ADMIN_EMAIL="${PB_ADMIN_EMAIL:-admin@example.com}"
PB_ADMIN_PASSWORD="${PB_ADMIN_PASSWORD:-changeme123}"
PB_DATA_DIR="${PB_DATA_DIR:-/pb_data}"
PB_MIGRATIONS_DIR="${PB_MIGRATIONS_DIR:-/pb_migrations}"
PB_FORCE_SUPERUSER_UPSERT="${PB_FORCE_SUPERUSER_UPSERT:-0}"
SUPERUSER_MARKER_FILE="${PB_DATA_DIR}/.superuser_initialized"

echo "Data directory: $PB_DATA_DIR"
echo "Migrations directory: $PB_MIGRATIONS_DIR"
echo "Force superuser upsert: $PB_FORCE_SUPERUSER_UPSERT"
echo "Marker file: $SUPERUSER_MARKER_FILE"

# Wait for PocketBase API to be ready
MAX_RETRIES="${PB_READY_MAX_RETRIES:-30}"
RETRY_COUNT=0

echo "Waiting for PocketBase to be ready..."
while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
  if wget --spider -q http://localhost:8080/api/health 2>/dev/null; then
    echo "PocketBase is ready."
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "  Attempt $RETRY_COUNT/$MAX_RETRIES..."
  sleep 1
done

if [ "$RETRY_COUNT" -eq "$MAX_RETRIES" ]; then
  echo "ERROR: PocketBase did not start in time"
  exit 1
fi

# Ensure superuser on first start, optionally on later starts
if [ ! -f "$SUPERUSER_MARKER_FILE" ]; then
  echo ""
  echo "First start (no marker) -> ensuring superuser via upsert..."
  /pb/pocketbase superuser upsert "$PB_ADMIN_EMAIL" "$PB_ADMIN_PASSWORD" --dir="$PB_DATA_DIR"
  touch "$SUPERUSER_MARKER_FILE"
  echo "Marker written."
else
  echo ""
  echo "Marker exists -> not first start."
  if [ "$PB_FORCE_SUPERUSER_UPSERT" = "1" ] || [ "$PB_FORCE_SUPERUSER_UPSERT" = "true" ]; then
    echo "PB_FORCE_SUPERUSER_UPSERT enabled -> upserting superuser..."
    /pb/pocketbase superuser upsert "$PB_ADMIN_EMAIL" "$PB_ADMIN_PASSWORD" --dir="$PB_DATA_DIR"
  else
    echo "Skipping superuser upsert (set PB_FORCE_SUPERUSER_UPSERT=1 to force)."
  fi
fi

# Copy migrations best-effort
mkdir -p "$PB_DATA_DIR/migrations" || true
if [ -d "$PB_MIGRATIONS_DIR" ] && [ "$(ls -A "$PB_MIGRATIONS_DIR" 2>/dev/null)" ]; then
  echo ""
  echo "Copying migration files into $PB_DATA_DIR/migrations/ ..."
  cp -r "$PB_MIGRATIONS_DIR"/* "$PB_DATA_DIR/migrations/" 2>/dev/null || true
  echo "Migrations copied."
else
  echo "No migration files found in $PB_MIGRATIONS_DIR"
fi

echo ""
echo "Initialization complete."