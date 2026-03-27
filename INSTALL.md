# 🛠️ Installationsanleitung

Diese Anleitung führt dich durch die Einrichtung der **Lager_app** für die lokale Entwicklung und verschiedene Zielplattformen.

---

## 📋 Voraussetzungen

### Docker (Web-Deployment)
- Docker >= `29.0`
- Docker Compose >= `2.40`

### Lokale Entwicklung (Flutter)
- Flutter SDK >= `3.41.4`
- Dart SDK >= `3.11.1`
- PocketBase >= `0.36.6`
- Android Studio oder VS Code mit Flutter-Plugin
- Linux-Tools für Desktop-Builds:
  - `libgtk-3-dev`
  - `libglu1-mesa-dev`
  - `pkg-config`
  - `cmake`

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

# 4. Logs anzeigen
docker compose logs -f pocketbase

# 5. Container ohne Cache neu erstellen
docker compose build --no-cache pocketbase

# Web-App: http://localhost:8081
# PocketBase Admin: http://localhost:8080/_/ (admin@example.com / changeme123)
```

> 💡 **Hinweis:** PocketBase initialisiert sich beim ersten Start automatisch  
> (Collections, Admin-User, Rules).  
> Ändere das Admin-Passwort sofort!

---

## 💻 Lokale Entwicklung (Flutter)

Wenn du direkt am Dart-Code arbeitest, kannst du die App nativ starten.

### 1. Backend starten

```bash
cd server
./pocketbase serve --http=0.0.0.0:8080
```

### 2. Frontend starten (App-Verzeichnis)

Ab v0.7.0 ist `--dart-define=POCKETBASE_URL=...` optional.  
Wenn es nicht angegeben wird, zeigt die App beim ersten Start einen Einrichtungsbildschirm an, in dem die Server-URL eingegeben werden kann.

```bash
cd app
flutter pub get

# === Variante A: Ohne --dart-define (Setup-Screen beim ersten Start) ===

# Web (Chrome)
flutter run -d chrome

# Linux Desktop
flutter run -d linux

# Windows Desktop
flutter run -d windows

# Mobile (Android)
flutter run

# === Variante B: Mit --dart-define (URL vorkonfiguriert) ===

# Web (Chrome)
flutter run -d chrome --dart-define=POCKETBASE_URL=http://localhost:8080

# Linux Desktop
flutter run -d linux --dart-define=POCKETBASE_URL=http://localhost:8080

# Windows Desktop
flutter run -d windows --dart-define=POCKETBASE_URL=http://localhost:8080

# Mobile (Android) — Ersetze <IP> durch die IP deines Rechners
flutter run --dart-define=POCKETBASE_URL=http://<IP>:8080
```

> 💡 **Tipp für Android:** `localhost` zeigt auf dem Android-Gerät auf das Gerät selbst, nicht auf deinen Entwicklungsrechner.  
> Verwende stattdessen:
>
> - **Emulator:** `http://10.0.2.2:8080`
> - **Echtes Gerät im LAN:** `http://192.168.x.x:8080`  
>   *(IP deines Rechners)*

> 💡 **Tipp:** Wenn du die URL einmal über den Setup-Screen oder die Einstellungen eingegeben hast, wird sie lokal gespeichert.  
> Beim nächsten Start ist kein `--dart-define` mehr nötig.

---

## 📱 Mobile (Android) Build

Um eine installierbare APK zu erstellen:

```bash
cd app

# Variante A: Ohne vorkonfigurierte URL (Setup-Screen beim ersten Start)
flutter build apk --release

# Variante B: Mit vorkonfigurierter URL (z. B. für Demo oder Kunden-Build)
flutter build apk --release \
  --dart-define=POCKETBASE_URL=https://api.deine-domain.de
```

Die Datei liegt dann unter:

```text
build/app/outputs/flutter-apk/app-release.apk
```

> ℹ️ **Hinweis ab v0.7.0:**  
> Bei Variante A wird beim ersten App-Start ein Einrichtungsbildschirm angezeigt, in dem der Benutzer die Server-URL eingeben kann.  
> Die URL wird lokal auf dem Gerät gespeichert.

---

## 🖥️ Server-URL nach der Installation konfigurieren

### Erststart (Setup-Screen)

Wenn die App ohne vorkonfigurierte URL gebaut wurde, erscheint beim ersten Start ein Einrichtungsbildschirm:

1. Server-URL eingeben  
   z. B. `https://api.deine-domain.de` oder `http://192.168.x.x:8080`
2. Auf **„Verbindung testen“** klicken  
   Die App prüft, ob der Server erreichbar ist.
3. Bei Erfolg auf **„Weiter“** klicken  
   Die URL wird gespeichert und die App startet.

### Später ändern

Die Server-URL kann jederzeit über  
**Einstellungen → PocketBase Server**  
geändert werden.

Ein Verbindungstest wird automatisch durchgeführt, bevor die neue URL übernommen wird.

---

## 🛡️ Produktion

Für das produktive Deployment mit SSL, Nginx Proxy Manager und gehärteten Einstellungen folge bitte der separaten Anleitung:

👉 [DEPLOYMENT.md](DEPLOYMENT.md)

---

## 🔍 Stolperstellen & Tipps

### PocketBase nicht erreichbar?
- Prüfe in der App unter **Einstellungen**, ob die PocketBase-URL korrekt ist.
- Stelle sicher, dass keine Firewall Port `8080` (Backend) oder `8081` (Frontend) blockiert.
- Auf Android: Verwende **nicht** `localhost`, sondern die tatsächliche IP-Adresse deines Rechners oder `10.0.2.2` im Emulator.

### App zeigt Setup-Screen, obwohl URL konfiguriert sein sollte?
- Prüfe, ob `--dart-define=POCKETBASE_URL=...` beim Build korrekt gesetzt wurde.
- Prüfe, ob die URL syntaktisch gültig ist  
  *(muss mit `http://` oder `https://` beginnen)*.
- Bei der Web-Version: Prüfe, ob `POCKETBASE_URL` als Umgebungsvariable im Docker-Container gesetzt ist.

### HTTP-Verbindung wird auf Android blockiert?
- Android blockiert standardmäßig unverschlüsselten HTTP-Traffic (ab API-Level 28).
- Die App hat `android:usesCleartextTraffic="true"` bereits gesetzt, sodass HTTP für LAN-Tests funktioniert.
- Für Produktion wird dennoch **HTTPS** empfohlen.

### Docker-Build schlägt fehl?
- Achte darauf, dass du den Build vom Wurzelverzeichnis `lager_app/` startest, nicht aus dem `app/`-Ordner heraus.

Beispiel:

```bash
docker build -f app/Dockerfile .
```

---

[Zurück zur README](README.md)