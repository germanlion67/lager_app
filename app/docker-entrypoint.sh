#!/bin/sh
set -e

echo "Generating runtime configuration..."

# Default to localhost if not set
POCKETBASE_URL="${POCKETBASE_URL:-http://localhost:8080}"

echo "POCKETBASE_URL: $POCKETBASE_URL"

# Generate config.js from template
# config.js wird bei jedem Container-Start neu generiert → nie cachen
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

    # Security Headers
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: blob: https: $POCKETBASE_URL; font-src 'self' data: https://fonts.gstatic.com; connect-src 'self' https: ws: wss: $POCKETBASE_URL; frame-ancestors 'self';"
        Permissions-Policy "geolocation=(), microphone=(), camera=(self)"
        X-Permitted-Cross-Domain-Policies "none"
        Cross-Origin-Opener-Policy "same-origin"
        Cross-Origin-Embedder-Policy "require-corp"
        -Server
    }

    # Cache-Control: index.html nie cachen (Flutter Entry Point)
    header /index.html Cache-Control "no-cache, no-store, must-revalidate"
    header /index.html Pragma "no-cache"
    header /index.html Expires "0"

    # Cache-Control: config.js nie cachen (dynamisch generiert, enthält POCKETBASE_URL)
    header /config.js Cache-Control "no-cache, no-store, must-revalidate"
    header /config.js Pragma "no-cache"
    header /config.js Expires "0"

    # Cache-Control: manifest.json kurz cachen (ändert sich selten)
    header /manifest.json Cache-Control "public, max-age=86400"

    # Cache-Control: statische Assets lange cachen
    # Flutter verwendet Content-Hashes im Dateinamen → immutable sicher
    @static {
        path *.js *.css *.png *.jpg *.jpeg *.gif *.ico *.svg *.woff *.woff2 *.ttf *.eot *.wasm
        not path /config.js
    }
    header @static Cache-Control "public, max-age=31536000, immutable"

    # SPA-Routing: unbekannte Pfade → /index.html
    try_files {path} /index.html

    file_server
}
CADDYEOF

echo "Configuration generated successfully"

# Start Caddy
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile