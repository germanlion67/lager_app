# ============================================================
# Stage 1: Flutter Web Build
# ============================================================
FROM debian:bookworm-slim AS build-env

ARG FLUTTER_VERSION=3.41.4

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git \
    --branch ${FLUTTER_VERSION} \
    --depth 1 \
    /usr/local/flutter

ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN git config --global --add safe.directory /usr/local/flutter \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web

WORKDIR /app

# Layer-Caching: Dependencies vor Code
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# PocketBase URL wird zur Build-Zeit eingebrannt.
# Dev/Test:   http://localhost:8080  (PocketBase direkt, kein Proxy)
# Produktion: https://deine-domain.de (Nginx Proxy Manager übernimmt)
# Überschreibbar via docker-compose.yml build args.
ARG POCKETBASE_URL=http://localhost:8080

RUN flutter build web --release \
    --dart-define=POCKETBASE_URL=${POCKETBASE_URL} \
    --dart-define=FLUTTER_WEB_AUTO_DETECT=true \
    --no-source-maps

# ============================================================
# Stage 2: Caddy Static File Server with Runtime Config
# Ersetzt nginx vollständig.
# Caddy übernimmt nur das Ausliefern der Flutter Web Assets
# und das SPA-Routing (alle Routen → /index.html).
# Runtime-Konfiguration wird beim Start aus Umgebungsvariablen generiert.
# ============================================================
FROM caddy:2-alpine

# Flutter Web Build aus Stage 1 kopieren
COPY --from=build-env /app/build/web /srv

# Caddyfile für SPA-Routing
COPY Caddyfile /etc/caddy/Caddyfile

# Entrypoint-Script für Runtime-Config
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://localhost:8081/ || exit 1

# Verwende Entrypoint für Runtime-Config-Generierung
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]