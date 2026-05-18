#!/bin/sh
set -e

echo "Generating runtime configuration..."

# Default to localhost if not set
POCKETBASE_URL="${POCKETBASE_URL:-http://localhost:8080}"

echo "POCKETBASE_URL: $POCKETBASE_URL"

# Generate config.js from template
cat > /srv/config.js << JSEOF
// Runtime configuration for Flutter web app
// Generated at container startup from environment variables
window.ENV_CONFIG = {
  POCKETBASE_URL: '$POCKETBASE_URL'
};
JSEOF

# Generate Caddyfile dynamically so CSP enthält die korrekte POCKETBASE_URL
cat > /etc/caddy/Caddyfile << CADDYEOF
:8081 {
    root * /srv
    encode gzip
    file_server

    # SPA-Routing: alle unbekannten Pfade → index.html
    try_files {path} /index.html

    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https: $POCKETBASE_URL; font-src 'self' data:; connect-src 'self' https: ws: wss: $POCKETBASE_URL; frame-ancestors 'self';"
        -Server
    }
}
CADDYEOF

echo "Configuration generated successfully"

# Start Caddy
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
