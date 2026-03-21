#!/bin/sh
set -e

echo "Generating runtime configuration..."

# Default to localhost if not set
POCKETBASE_URL="${POCKETBASE_URL:-http://localhost:8080}"

echo "POCKETBASE_URL: $POCKETBASE_URL"

# Generate config.js from template
cat > /srv/config.js << EOF
// Runtime configuration for Flutter web app
// Generated at container startup from environment variables
window.ENV_CONFIG = {
  POCKETBASE_URL: '$POCKETBASE_URL'
};
EOF

echo "Configuration generated successfully"

# Start Caddy
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
