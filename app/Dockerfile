# ============================================================
# Stage 1: Flutter Web Build
# ============================================================
FROM debian:bookworm-slim AS build-env

# Abhängigkeiten installieren
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip libglu1-mesa python3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Flutter klonen (stable channel)
RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Flutter konfigurieren
RUN git config --global --add safe.directory /usr/local/flutter \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web

WORKDIR /app

# Layer-Caching: Erst Dependencies, dann Code
COPY pubspec.* ./
RUN flutter pub get

# Restlichen Code kopieren
COPY . .

# Build-Argument für PocketBase URL
# Default: Relativer Pfad → nginx Reverse Proxy leitet an PocketBase weiter
ARG PB_URL=/api

# Flutter Web Release Build
RUN flutter build web --release \
    --dart-define=PB_URL=${PB_URL} \
    --dart-define=FLUTTER_WEB_AUTO_DETECT=true

# ============================================================
# Stage 2: Serve mit nginx
# ============================================================
FROM nginx:alpine

# Sicherheit: nginx als non-root (optional, aber empfohlen)
RUN chown -R nginx:nginx /usr/share/nginx/html \
    && chown -R nginx:nginx /var/cache/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && touch /var/run/nginx.pid \
    && chown -R nginx:nginx /var/run/nginx.pid

# Flutter Web Build kopieren
COPY --from=build-env /app/build/web /usr/share/nginx/html

# nginx Konfiguration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Health-Check für Docker Compose
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget --spider -q http://localhost:80/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
