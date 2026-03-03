# Stage 1: Build Flutter Web
FROM debian:bookworm-slim AS build-env

RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /app
# Alle Flutter-Dateien kopieren (aus dem /app Verzeichnis)
COPY . .
RUN flutter config --enable-web
RUN flutter pub get
RUN flutter build web --release --no-wasm-dry-run

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
