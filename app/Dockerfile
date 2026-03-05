# Stage 1: Build Flutter Web
FROM debian:bookworm-slim AS build-env

# Abhängigkeiten installieren
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa python3 \
    && rm -rf /var/lib/apt/lists/*

# Flutter klonen (korrekter Pfad)
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Erlaube Flutter als Root auszuführen (für Docker notwendig)
ENV CHROME_EXECUTABLE=/usr/bin/chromium
RUN git config --global --add safe.directory /usr/local/flutter


WORKDIR /app
# Alle Flutter-Dateien kopieren (aus dem /app Verzeichnis)
COPY . .

# Build-Argument für die PocketBase URL (Default: Localhost)
ARG PB_URL=http://127.0.0.1:8090


# Hilft bei der Fehlersuche im Build-Log, zeigt die Flutter-Umgebung und -Konfiguration an
RUN flutter doctor

# Flutter konfigurieren und bauen
RUN flutter config --enable-web
RUN flutter pub get

RUN flutter build web --release --dart-define=PB_URL=${PB_URL}

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
