# ============================================================
# Stage 1: Flutter Web Build
# ============================================================
FROM debian:bookworm-slim AS build-env

# Fix: Versions-Pin für reproduzierbare Builds —
# flutter stable kann sich zwischen Builds ändern
ARG FLUTTER_VERSION=3.32.0

# Abhängigkeiten installieren
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    python3 \
    ca-certificates \
    # Fix: wget für HEALTHCHECK in Stage 2 nicht nötig hier,
    # aber dnsutils hilft beim Debugging — bleibt weg (minimal image)
    && rm -rf /var/lib/apt/lists/*

# Flutter klonen (gepinnte Version statt rolling "stable")
RUN git clone https://github.com/flutter/flutter.git \
    --branch ${FLUTTER_VERSION} \
    --depth 1 \
    /usr/local/flutter

ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Flutter konfigurieren
RUN git config --global --add safe.directory /usr/local/flutter \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web

WORKDIR /app

# Layer-Caching: Erst Dependencies, dann Code
COPY pubspec.yaml pubspec.lock ./
# Fix: pubspec.lock explizit benennen statt pubspec.* —
# Glob könnte unbeabsichtigt andere Dateien (z.B. pubspec.yaml.bak) einschließen

RUN flutter pub get

# Fix: .dockerignore sicherstellen dass build/, .dart_tool/, .git/
# nicht kopiert werden — hier nur Hinweis, keine Dockerfile-Änderung nötig
COPY . .

# Build-Argument für PocketBase URL
# Default: Relativer Pfad → nginx Reverse Proxy leitet an PocketBase weiter
ARG PB_URL=/api

# Flutter Web Release Build
# Fix: --pwa-strategy=none nur wenn kein Service Worker gewünscht —
# Standard behält PWA-Support, daher kein Flag gesetzt
RUN flutter build web --release \
    --dart-define=PB_URL=${PB_URL} \
    --dart-define=FLUTTER_WEB_AUTO_DETECT=true \
    # Fix: --source-maps entfernt in Release —
    # Source Maps im Produktions-Image sind ein Sicherheitsrisiko
    && find build/web -name "*.map" -delete

# ============================================================
# Stage 2: Serve mit nginx
# ============================================================
FROM nginx:1.27-alpine

# Fix: gepinnte nginx-Version statt rolling :alpine —
# :alpine kann sich zwischen Builds ändern

# Fix: wget explizit installieren — nginx:alpine enthält es nicht immer,
# aber der HEALTHCHECK braucht es
RUN apk add --no-cache wget

# Sicherheit: nginx als non-root
RUN chown -R nginx:nginx /usr/share/nginx/html \
    && chown -R nginx:nginx /var/cache/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && touch /var/run/nginx.pid \
    && chown -R nginx:nginx /var/run/nginx.pid

# Fix: /var/run/nginx.pid Verzeichnis-Ownership sicherstellen —
# auf manchen Alpine-Versionen ist /var/run ein Symlink auf /run
RUN mkdir -p /run && chown -R nginx:nginx /run

# Flutter Web Build kopieren
COPY --from=build-env --chown=nginx:nginx \
    /app/build/web /usr/share/nginx/html

# Fix: --chown direkt im COPY — kein separater chown-Layer nötig

# nginx Konfiguration
COPY --chown=nginx:nginx nginx.conf /etc/nginx/conf.d/default.conf

# Fix: USER nginx — nginx läuft als non-root
# (setzt voraus, dass nginx.conf keinen Port < 1024 verwendet,
#  oder dass nginx master als root startet und worker als nginx)
# Hinweis: nginx master-Prozess muss als root starten für Port 80,
# worker-Prozesse laufen dann als nginx — USER nginx hier weglassen
# da CMD nginx -g "daemon off;" den master als root benötigt.

# Health-Check für Docker Compose
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --spider -q http://localhost:80/ || exit 1
# Fix: --start-period=5s hinzugefügt —
# gibt nginx Zeit zum Starten bevor Health-Checks beginnen

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]