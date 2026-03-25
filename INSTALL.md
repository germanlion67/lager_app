# 🛠️ Installationsanleitung

Diese Anleitung führt dich durch die Einrichtung der **Lager_app** für die lokale Entwicklung und verschiedene Zielplattformen.

---

## 📋 Voraussetzungen

### Docker (Web-Deployment)
*   [Docker](https://docs.docker.com/get-docker/) >= 29.0
*   [Docker Compose](https://docs.docker.com/compose/) >= 2.40

### Lokale Entwicklung (Flutter)
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.41.4
*   [Dart SDK](https://dart.dev/get-dart) >= 3.11.1
*   [PocketBase](https://pocketbase.io/docs/) >= 0.36.6
*   **Android Studio** oder **VS Code** mit Flutter-Plugin
*   **Linux Tools** (für Desktop-Builds): `libgtk-3-dev`, `libglu1-mesa-dev`, `pkg-config`, `cmake`

---

## 🐋 Docker (Web) — Dev/Test

Der Docker-Build nutzt das Repository-Root als Kontext, um auf geteilte Pakete zuzugreifen.

```bash
# 1. Repository klonen
git clone https://github.com/germanlion67/lager_app.git
cd lager_app

# 2. Umgebungsvariablen vorbereiten
cp .env.example .env
# Optional: .env anpassen (Standard: Ports 8081/8080)

# 3. Container starten
docker compose up -d --build

# 4. zeigt Logs an
docker compose logs -f pocketbase

# 5. Container neu erstellen ohne Cache
docker compose build --no-cache pocketbase

# Web-App: http://localhost:8081
# PocketBase Admin: http://localhost:8080/_/ (admin@example.com / changeme123)
```

> 💡 **Hinweis**: PocketBase initialisiert sich beim ersten Start automatisch (Collections, Admin-User, Rules). Ändere das Admin-Passwort sofort!

---

## 💻 Lokale Entwicklung (Flutter)

Wenn du direkt am Dart-Code arbeitest, kannst du die App nativ starten.

### 1. Backend starten
```bash
cd server
./pocketbase serve --http=0.0.0.0:8080
```

### 2. Frontend starten (App-Verzeichnis)
```bash
cd app
flutter pub get

# Web (Chrome)
flutter run -d chrome --dart-define=POCKETBASE_URL=http://localhost:8080

# Linux Desktop
flutter run -d linux --dart-define=POCKETBASE_URL=http://localhost:8080

# Windows Desktop
flutter run -d windows --dart-define=POCKETBASE_URL=http://localhost:8080

# Mobile (Android) — Ersetze <IP> durch die IP deines Rechners
flutter run --dart-define=POCKETBASE_URL=http://<IP>:8080
```

---

## 📱 Mobile (Android) Build

Um eine installierbare APK zu erstellen:

```bash
cd app
flutter build apk --release \
    --dart-define=POCKETBASE_URL=http://<dein-server-ip>:8080
```
Die Datei liegt dann unter: `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🛡️ Produktion

Für das produktive Deployment mit SSL, Nginx Proxy Manager und gehärteten Einstellungen folge bitte der separaten Anleitung:

👉 **[DEPLOYMENT.md](DEPLOYMENT.md)**

---

## 🔍 Stolperstellen & Tipps

### PocketBase nicht erreichbar?
*   Prüfe in der App unter **Einstellungen**, ob die `POCKETBASE_URL` korrekt ist.
*   Stelle sicher, dass keine Firewall Port 8080 (Backend) oder 8081 (Frontend) blockiert.

### Docker-Build schlägt fehl?
*   Achte darauf, dass du den Build vom **Wurzelverzeichnis** (`lager_app/`) startest, nicht aus dem `app/`-Ordner heraus.
*   Befehl: `docker build -f app/Dockerfile .`

---

[Zurück zur README](README.md)