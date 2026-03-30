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

# Test-User Konfiguration (optional)
PB_TEST_USER_EMAIL="${PB_TEST_USER_EMAIL:-}"
PB_TEST_USER_PASSWORD="${PB_TEST_USER_PASSWORD:-}"
PB_TEST_USER_ENABLED="${PB_TEST_USER_ENABLED:-0}"
TESTUSER_MARKER_FILE="${PB_DATA_DIR}/.testuser_initialized"

echo "Data directory: $PB_DATA_DIR"
echo "Migrations directory: $PB_MIGRATIONS_DIR"
echo "Force superuser upsert: $PB_FORCE_SUPERUSER_UPSERT"
echo "Marker file: $SUPERUSER_MARKER_FILE"
if [ "$PB_TEST_USER_ENABLED" = "1" ] || [ "$PB_TEST_USER_ENABLED" = "true" ]; then
  echo "Test-User: $PB_TEST_USER_EMAIL (enabled)"
else
  echo "Test-User: disabled"
fi

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

# ============================================================
# Test-User erstellen (optional, nur Entwicklung!)
# Wird über die PocketBase API erstellt (nicht superuser CLI)
# PocketBase v0.23+: Superuser-Auth über _superusers Collection
# ============================================================
if [ "$PB_TEST_USER_ENABLED" = "1" ] || [ "$PB_TEST_USER_ENABLED" = "true" ]; then
  if [ -z "$PB_TEST_USER_EMAIL" ] || [ -z "$PB_TEST_USER_PASSWORD" ]; then
    echo ""
    echo "⚠️  WARNING: PB_TEST_USER_ENABLED=1 but email or password is empty. Skipping."
  elif [ ! -f "$TESTUSER_MARKER_FILE" ]; then
    echo ""
    echo "Creating test user: $PB_TEST_USER_EMAIL ..."

    # Auth-Token vom Superuser holen (PocketBase v0.23+)
    echo "  Authenticating as superuser..."
    AUTH_RESPONSE=$(wget --content-on-error -qO- --post-data "{\"identity\":\"$PB_ADMIN_EMAIL\",\"password\":\"$PB_ADMIN_PASSWORD\"}" \
      --header="Content-Type: application/json" \
      "http://localhost:8080/api/collections/_superusers/auth-with-password" 2>/dev/null || echo "")

    if [ -z "$AUTH_RESPONSE" ]; then
      echo "  ⚠️  Could not authenticate as superuser."
      echo "  Skipping test user creation."
    else
      ADMIN_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4)

      if [ -z "$ADMIN_TOKEN" ]; then
        echo "  ⚠️  Could not extract admin token. Response:"
        echo "  $AUTH_RESPONSE"
        echo "  Skipping test user creation."
      else
        echo "  ✅ Admin authenticated successfully."

        # User über die users Collection erstellen
        CREATE_RESPONSE=$(wget --content-on-error -qO- --post-data "{\"email\":\"$PB_TEST_USER_EMAIL\",\"password\":\"$PB_TEST_USER_PASSWORD\",\"passwordConfirm\":\"$PB_TEST_USER_PASSWORD\"}" \
          --header="Content-Type: application/json" \
          --header="Authorization: Bearer $ADMIN_TOKEN" \
          "http://localhost:8080/api/collections/users/records" 2>/dev/null || echo "")

        if echo "$CREATE_RESPONSE" | grep -q '"id"'; then
          echo "  ✅ Test user created successfully: $PB_TEST_USER_EMAIL"
          touch "$TESTUSER_MARKER_FILE"
          echo "  Marker written."
        elif echo "$CREATE_RESPONSE" | grep -qi 'not_unique\|already exists\|UNIQUE constraint'; then
          echo "  ℹ️  Test user already exists. Skipping."
          touch "$TESTUSER_MARKER_FILE"
          echo "  Marker written."
        else
          echo "  ⚠️  Could not create test user. Response:"
          echo "  $CREATE_RESPONSE"
          echo "  This is non-fatal. The app will still work."
        fi
      fi
    fi
  else
    echo ""
    echo "Test-User marker exists -> skipping creation."
  fi
else
  echo ""
  echo "Test-User creation disabled (set PB_TEST_USER_ENABLED=1 to enable)."
fi

# Copy migrations best-effort
mkdir -p "$PB_DATA_DIR/migrations" || true
if [ -d "$PB_MIGRATIONS_DIR" ] && [ "$(ls -A "$PB_MIGRATIONS_DIR" 2>/dev/null)" ]; then
  echo ""
  echo "Copying migration files into $PB_DATA_DIR/migrations/ ..."

  # Vorher: welche Dateien existieren bereits?
  EXISTING_MIGRATIONS=$(ls "$PB_DATA_DIR/migrations/" 2>/dev/null || echo "")

  cp -r "$PB_MIGRATIONS_DIR"/* "$PB_DATA_DIR/migrations/" 2>/dev/null || true

  # Nachher: neue Dateien erkennen und loggen
  echo "Migration files status:"
  for f in "$PB_MIGRATIONS_DIR"/*; do
    filename=$(basename "$f")
    if echo "$EXISTING_MIGRATIONS" | grep -qF "$filename"; then
      echo "  [SKIP]  $filename (already existed)"
    else
      echo "  [NEW]   $filename (freshly copied -> will be applied by PocketBase)"
    fi
  done

  echo "Migrations copied."
else
  echo "No migration files found in $PB_MIGRATIONS_DIR"
fi

echo ""
echo "Initialization complete."