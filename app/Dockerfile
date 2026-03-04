# Stage 1: Build Flutter Web
FROM debian:bookworm-slim AS build-env

RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /app
# Alle Flutter-Dateien kopieren (aus dem /app Verzeichnis)
COPY . .

# Build-Argument für die PocketBase URL (Default: Localhost)
ARG PB_URL=http://127.0.0.1:8090

# RUN flutter config --enable-web
RUN flutter doctor # Hilft bei der Fehlersuche im Build-Log
RUN flutter pub get
# --no-wasm-dry-run ist oft bei älteren Skripten dabei, für Standard-Web reicht:
RUN flutter build web --release --web-renderer html

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html --dart-define=PB_URL=${PB_URL}
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
