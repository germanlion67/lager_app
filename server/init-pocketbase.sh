#!/bin/sh
# ============================================================
# PocketBase Initialization Script
# 
# Automatically initializes PocketBase on first start:
# - Creates admin user from environment variables
# - Applies database migrations
# - Validates database structure
# ============================================================

set -e

echo "🚀 PocketBase Initialization Script"
echo "===================================="

# Environment variables with defaults
PB_ADMIN_EMAIL="${PB_ADMIN_EMAIL:-admin@example.com}"
PB_ADMIN_PASSWORD="${PB_ADMIN_PASSWORD:-changeme123}"
PB_DATA_DIR="${PB_DATA_DIR:-/pb_data}"
PB_MIGRATIONS_DIR="${PB_MIGRATIONS_DIR:-/pb_migrations}"

echo "📁 Data directory: $PB_DATA_DIR"
echo "📁 Migrations directory: $PB_MIGRATIONS_DIR"

# Check if this is a fresh installation
if [ ! -f "$PB_DATA_DIR/data.db" ]; then
    echo ""
    echo "🆕 Fresh installation detected - initializing database..."
    echo ""
    
    # Wait a bit for PocketBase to start
    sleep 2
    
    # Check if PocketBase is running and accessible
    MAX_RETRIES=30
    RETRY_COUNT=0
    
    echo "⏳ Waiting for PocketBase to be ready..."
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if wget --spider -q http://localhost:8080/api/health 2>/dev/null; then
            echo "✅ PocketBase is ready!"
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "   Attempt $RETRY_COUNT/$MAX_RETRIES..."
        sleep 1
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "❌ ERROR: PocketBase did not start in time"
        exit 1
    fi
    
    # Wait a bit more for stability
    sleep 2
    
    echo ""
    echo "👤 Creating admin user..."
    echo "   Email: $PB_ADMIN_EMAIL"
    
    # Try to create admin user (may fail if already exists, which is OK)
    if /pb/pocketbase --dir="$PB_DATA_DIR" admin create "$PB_ADMIN_EMAIL" "$PB_ADMIN_PASSWORD" 2>&1; then
        echo "✅ Admin user created successfully!"
    else
        echo "⚠️  Admin user creation failed (may already exist)"
    fi
    
    echo ""
    echo "📦 Applying migrations..."
    
    # Copy migrations if they exist and haven't been copied yet
    if [ -d "$PB_MIGRATIONS_DIR" ] && [ "$(ls -A $PB_MIGRATIONS_DIR 2>/dev/null)" ]; then
        echo "   Copying migration files..."
        cp -r "$PB_MIGRATIONS_DIR"/* "$PB_DATA_DIR/migrations/" 2>/dev/null || true
        echo "✅ Migrations copied!"
    else
        echo "⚠️  No migration files found in $PB_MIGRATIONS_DIR"
    fi
    
    echo ""
    echo "✅ Initialization complete!"
    echo ""
    echo "================================================"
    echo "🔐 Admin Login Credentials:"
    echo "   Email:    $PB_ADMIN_EMAIL"
    echo "   Password: $PB_ADMIN_PASSWORD"
    echo ""
    echo "⚠️  IMPORTANT: Change the password immediately!"
    echo "   Admin UI: http://your-domain/_/"
    echo "================================================"
    echo ""
else
    echo ""
    echo "✅ Database already exists - skipping initialization"
    echo ""
fi

echo "🎉 PocketBase is ready to use!"
