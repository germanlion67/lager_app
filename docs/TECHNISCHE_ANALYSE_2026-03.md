# 🔍 Technische Stabilisierungs- und Qualitätsanalyse
**Lager_app Repository** • Stand: März 2026

---

## 📊 Executive Summary

**Gesamtbewertung: 🟡 Produktionsreif mit wichtigen Einschränkungen**

- **Codequalität**: ✅ Gut (18.313 LOC, saubere Architektur)
- **Testabdeckung**: ⚠️ Niedrig (1.193 LOC Tests = ~6.5%)
- **Sicherheit**: ⚠️ Teilweise problematisch (siehe Details)
- **Build-Stabilität**: ⚠️ Plattform-abhängig
- **Produktionsreife**: ⚠️ Nicht empfohlen (lt. README)

### Kritische Befunde (müssen vor Produktionseinsatz behoben werden)
1. ❌ **KRITISCH**: Default App-Identifiers (`com.example.ev`) auf allen Plattformen
2. ❌ **KRITISCH**: PocketBase Collection muss manuell erstellt werden
3. ❌ **KRITISCH**: Offene API Rules (`listRule: ""`) - keine Authentifizierung
4. ⚠️ **HOCH**: Fehlende iOS/macOS/Linux Builds im Release-Workflow
5. ⚠️ **HOCH**: CORS nicht konfiguriert (potentielles Problem für Web)
6. ⚠️ **HOCH**: Produktiv-Datenbank-Initialisierung nicht automatisiert

---

## 1️⃣ KRITISCHE PROBLEME (Priorität: KRITISCH)

### 🔴 K-001: Default App Bundle Identifiers nicht aktualisiert
**Dateien betroffen:**
- `app/android/app/build.gradle.kts` (Line 18)
- `app/android/build.gradle.kts` (Line 18)
- `app/ios/Runner.xcodeproj/project.pbxproj` (mehrfach)
- `app/macos/Runner.xcodeproj/project.pbxproj` (mehrfach)

**Problem:**
Alle Plattformen verwenden den Flutter-Default-Identifier `com.example.ev` statt eines eindeutigen Produktions-Identifiers.

```kotlin
// AKTUELL (FALSCH):
applicationId = "com.example.ev"

// SOLLTE SEIN:
applicationId = "com.germanlion67.lagerverwaltung"
// oder: "de.germanlion.elektronik.verwaltung"
```

**Auswirkung:**
- ❌ **Kann nicht in Google Play Store veröffentlicht werden**
- ❌ **Kann nicht in Apple App Store veröffentlicht werden**
- ❌ **Kollisionen bei parallelen Installationen**
- ❌ **Push-Notifications funktionieren nicht**
- ❌ **Unprofessioneller Eindruck**

**Priorität:** 🔴 **KRITISCH** - Blockiert Store-Veröffentlichung

**Empfehlung:**
```bash
# Suchen und ersetzen in allen Platform-Dateien:
com.example.ev → com.germanlion67.lagerverwaltung

# Betroffene Dateien:
- android/app/build.gradle.kts
- android/build.gradle.kts  
- ios/Runner.xcodeproj/project.pbxproj
- macos/Runner.xcodeproj/project.pbxproj
```

---

### 🔴 K-002: PocketBase Collection `artikel` - Offene API Rules (Security)
**Datei:** `server/pb_migrations/pb_schema.json`

**Problem:**
Die Collection `artikel` hat leere API Rules:
```json
{
  "listRule": "",
  "viewRule": "",
  "createRule": "",
  "updateRule": "",
  "deleteRule": ""
}
```

**Bedeutung der leeren Rules:**
- `""` (leerer String) = **Öffentlich zugänglich ohne Auth**
- `null` = Gesperrt
- `"@request.auth.id != ''"` = Nur authentifizierte Nutzer

**Auswirkung:**
- ⚠️ **Jeder kann alle Artikel lesen** (DSGVO-Problem!)
- ⚠️ **Jeder kann Artikel erstellen, ändern, löschen** (Vandalismus möglich)
- ⚠️ **Keine Zugriffskontrolle** (Multi-User-Betrieb unsicher)
- ⚠️ **Produktionseinsatz hochriskant**

**Priorität:** 🔴 **KRITISCH (SICHERHEIT)**

**Empfehlung:**
```json
{
  "listRule": "@request.auth.id != ''",
  "viewRule": "@request.auth.id != ''",
  "createRule": "@request.auth.id != ''",
  "updateRule": "@request.auth.id != ''",
  "deleteRule": "@request.auth.id != ''"
}
```

**Alternativ** (falls öffentliche API gewünscht):
- Nur Lesen erlauben: `"listRule": "", "viewRule": ""`
- Schreiben nur für Auth: `"createRule": "@request.auth.id != ''"`

**Wichtig:** Änderungen auch in `1772784781_created_artikel.js` Migration vornehmen!

---

### 🔴 K-003: Manuelle PocketBase-Initialisierung erforderlich
**Dokumentiert in:** `README.md` (Lines 308-325)

**Problem:**
Nach erstem Docker-Start muss Admin manuell:
1. PocketBase Admin-UI öffnen (`http://localhost:8080/_/`)
2. Admin-Account anlegen
3. Collection `artikel` **manuell** erstellen (Migration nicht auto-gemountet)

**Auswirkung:**
- ❌ **Produktivinstallation nicht automatisiert**
- ❌ **Fehleranfällig** (falsches Schema möglich)
- ❌ **Schlechte User Experience**
- ❌ **Blockiert "Ein-Klick-Deployment"**

**Priorität:** 🔴 **KRITISCH (DEPLOYMENT)**

**Empfehlung:**
1. **Init-Container** oder **Startup-Script** erstellen:
   ```bash
   #!/bin/bash
   # server/init-pocketbase.sh
   
   # Warte auf PocketBase
   while ! curl -s http://localhost:8080/api/health > /dev/null; do
     sleep 1
   done
   
   # Erstelle Superuser (nur wenn noch keiner existiert)
   if [ ! -f /pb_data/data.db ]; then
     pb migrate
   fi
   ```

2. **Superuser via ENV:** PocketBase CLI unterstützt:
   ```bash
   pocketbase admin create admin@example.com password123
   ```
   
3. **Auto-Migration aktivieren:**
   - Migrations-Ordner als Volume mounten
   - Oder: Migration direkt in `/pb_data` kopieren

**Siehe auch:** Punkt 4 der Anforderungen (PocketBase-Erstinitialisierung)

---

### 🔴 K-004: POCKETBASE_URL muss zur Build-Zeit gesetzt werden
**Dateien:**
- `app/Dockerfile` (Lines 36-43)
- `docker-compose.yml` (Lines 56-60)
- `app/lib/config/app_config.dart` (Lines 38-46)

**Problem:**
Die PocketBase-URL wird zur **Build-Zeit** in die Flutter Web App eingebrannt:

```dockerfile
ARG POCKETBASE_URL=http://localhost:8080
RUN flutter build web --release \
    --dart-define=POCKETBASE_URL=${POCKETBASE_URL}
```

**Auswirkung:**
- ❌ **URL-Änderung erfordert kompletten Rebuild** (nicht nur Restart)
- ❌ **`docker compose restart app`** reicht **nicht** aus
- ❌ **Ein Image pro URL** (keine generische Prod-Image möglich)
- ⚠️ **Verwirrend für Nutzer** (README warnt, aber leicht übersehen)

**Aktueller Workaround (dokumentiert im README):**
```bash
docker compose up -d --build app  # --build ist Pflicht!
```

**Priorität:** 🔴 **KRITISCH (DEPLOYMENT)**

**Langfristige Lösung:**
1. **Runtime-Konfiguration** via `window.ENV` oder `config.json`:
   ```javascript
   // web/index.html
   <script>
     window.ENV = {
       POCKETBASE_URL: '{{POCKETBASE_URL}}'  // Wird von Caddy/nginx ersetzt
     };
   </script>
   ```

2. **Oder:** Entrypoint-Script das zur Startzeit `/srv/config.js` generiert

**Kurzfristige Verbesserung:**
- ⚠️ Klarere Warnung im `docker-compose.yml`
- ✅ Healthcheck der `app` auf korrekte URL prüfen lassen

---

## 2️⃣ HOHE PRIORITÄT

### 🟠 H-001: Fehlende iOS/macOS/Linux Builds im Release-Workflow
**Datei:** `.github/workflows/release.yml`

**Problem:**
Der Release-Workflow baut nur:
- ✅ Android APK + App Bundle
- ✅ Windows (ZIP)

Aber **nicht**:
- ❌ iOS (obwohl Projekt konfiguriert)
- ❌ macOS (obwohl Projekt konfiguriert)
- ❌ Linux (obwohl im flutter-maintenance getestet)

**Auswirkung:**
- ⚠️ Apple-User haben keine offiziellen Releases
- ⚠️ Linux-User bekommen keine Binaries
- ⚠️ Inkonsistente Plattform-Unterstützung

**Priorität:** 🟠 **HOCH**

**Empfehlung:**
```yaml
# Zu release.yml hinzufügen:

build-ios:
  name: Build iOS
  runs-on: macos-latest
  needs: [create-tag, test]
  steps:
    - name: Build iOS
      run: flutter build ios --release --no-codesign
    # Hinweis: Store-Deployment erfordert Signing (Apple Developer Account)

build-macos:
  name: Build macOS
  runs-on: macos-latest
  needs: [create-tag, test]
  steps:
    - name: Build macOS
      run: flutter build macos --release

build-linux:
  name: Build Linux
  runs-on: ubuntu-latest
  needs: [create-tag, test]
  steps:
    - name: Build Linux
      run: flutter build linux --release
    - name: Create Archive
      run: tar -czvf linux-release.tar.gz -C build/linux/x64/release/bundle .
```

---

### 🟠 H-002: CORS nicht konfiguriert (Web-Deployment-Risiko)
**Betroffen:** PocketBase API

**Problem:**
Keine CORS-Konfiguration gefunden in:
- ❌ PocketBase Startup-Flags
- ❌ Nginx Proxy Manager Setup
- ❌ Caddy-Konfiguration

**Aktuell funktioniert es nur, weil:**
- Dev/Test: Browser und PocketBase laufen beide auf `localhost` (gleiche Origin)
- Prod: **Ungetestet** - könnte brechen wenn Flutter Web und PocketBase auf verschiedenen Subdomains laufen

**Potenzielles Szenario:**
```
Frontend: https://app.example.com   (Caddy)
Backend:  https://api.example.com   (PocketBase)
          ↑ CORS-Fehler, da verschiedene Origins!
```

**Priorität:** 🟠 **HOCH**

**Empfehlung:**
1. **PocketBase CORS aktivieren:**
   ```yaml
   # docker-compose.yml / docker-compose.prod.yaml
   pocketbase:
     environment:
       - POCKETBASE_CORS_ALLOWED_ORIGINS=https://app.example.com
   ```

2. **Oder in Nginx Proxy Manager:**
   ```nginx
   add_header 'Access-Control-Allow-Origin' 'https://app.example.com';
   add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS';
   add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization';
   ```

3. **Best Practice:** Wildcard nur für Dev/Test:
   ```bash
   # Dev:  CORS_ALLOWED_ORIGINS=*
   # Prod: CORS_ALLOWED_ORIGINS=https://app.deine-domain.de
   ```

---

### 🟠 H-003: Web Manifest hat Generic Metadata
**Datei:** `app/web/manifest.json`

**Probleme:**
```json
{
  "name": "ev",                              // ❌ Zu kurz, unverständlich
  "short_name": "ev",                        // ❌ Zu kurz
  "description": "A new Flutter project.",   // ❌ Flutter-Default
  "background_color": "#0175C2",             // ❌ Falsch (sollte #1976d2 sein)
  "theme_color": "#0175C2",                  // ❌ Falsch
  "orientation": "portrait-primary"          // ❌ Falsch für Admin-App
}
```

**Auswirkung:**
- ⚠️ Unprofessionelle PWA-Installation
- ⚠️ Falsche App-Farben im Browser
- ⚠️ Rotation auf Desktop blockiert

**Priorität:** 🟠 **HOCH**

**Fix:**
```json
{
  "name": "Elektronik Lagerverwaltung",
  "short_name": "Lager",
  "description": "Lagerverwaltung für Elektronikbauteile und Bastelzubehör",
  "background_color": "#1976d2",
  "theme_color": "#1976d2",
  "orientation": "any"
}
```

---

### 🟠 H-004: Placeholder-URLs in Produktion möglich
**Datei:** `app/lib/config/app_config.dart` (Lines 39, 45)

**Problem:**
```dart
kDebugMode
  ? 'http://localhost:8080'
  : 'https://your-production-server.com';  // ❌ Placeholder!

// Mobile:
'http://192.168.178.XX:8090'  // ❌ Placeholder mit XX!
```

**Auswirkung:**
- ⚠️ Release-Build mit Placeholder = App funktioniert nicht
- ⚠️ Warnung im Code vorhanden, aber leicht übersehen
- ⚠️ Build schlägt nicht fehl (Silent Failure)

**Aktueller Schutz:**
```dart
static bool get hasPlaceholderUrl =>
    pocketBaseUrl.contains('192.168.178.XX') ||
    pocketBaseUrl.contains('your-production-server.com');
```
Runtime-Warnung wird geloggt.

**Priorität:** 🟠 **HOCH**

**Empfehlung:**
1. **Compile-Time-Check** hinzufügen:
   ```dart
   static void _validateConfig() {
     if (kReleaseMode && hasPlaceholderUrl) {
       throw StateError(
         'PRODUKTIONSFEHLER: Placeholder-URL in Release-Build! '
         'Bitte --dart-define=POCKETBASE_URL=... setzen.'
       );
     }
   }
   ```

2. **Oder:** Umgebungsvariable **zwingend** machen:
   ```dart
   static const String _pocketBaseUrlOverride = String.fromEnvironment(
     'POCKETBASE_URL',
     defaultValue: 'FEHLT',  // ← statt leerer String
   );
   ```

---

## 3️⃣ MITTLERE PRIORITÄT

### 🟡 M-001: Niedrige Testabdeckung
**Statistik:**
- **Produktionscode:** 18.313 Zeilen Dart
- **Tests:** 1.193 Zeilen
- **Abdeckung:** ~6,5%

**Vorhandene Tests:**
```
app/test/
├── dokumente_utils_test.dart       (1 Datei)
├── models/                         (2 Tests)
├── services/                       (3 Tests)
├── widgets/                        (2 Tests)
└── performance/                    (2 Tests)
```

**Fehlende Testabdeckung:**
- ❌ Keine Tests für `screens/` (größter Code-Anteil!)
- ❌ Keine Integration-Tests
- ❌ Keine E2E-Tests
- ⚠️ Services nur teilweise getestet

**Priorität:** 🟡 **MITTEL** (aber wichtig für Produktionsreife)

**Empfehlung:**
1. **Mindest-Abdeckung für kritische Pfade:**
   - `artikel_db_service.dart` → CRUD-Operations
   - `pocketbase_sync_service.dart` → Sync-Logik
   - `export_service.dart` → PDF/CSV-Export

2. **Widget-Tests** für:
   - `artikel_list_screen.dart`
   - `artikel_detail_screen.dart`
   - `settings_screen.dart`

3. **Integration-Tests** für:
   - Offline → Online Sync
   - Bildupload + Thumbnail-Generation

**Ziel:** Mindestens 40-50% Testabdeckung vor Produktionseinsatz

---

### 🟡 M-002: Debug-Print-Statements im Produktionscode
**Gefunden:** 11 `debugPrint` Statements in Production-Code

**Dateien:**
- `app/lib/screens/artikel_erfassen_screen.dart` (7x)
- `app/lib/screens/artikel_erfassen_io.dart` (4x)

**Problem:**
```dart
debugPrint('[DEBUG] artikelId: $artikelId');
debugPrint('[DEBUG] _bildBytes null: ${_bildBytes == null}');
// ... etc
```

**Auswirkung:**
- ⚠️ Performance-Overhead (minimal, aber unnötig)
- ⚠️ Potentielle Datenlecks in Logs
- ⚠️ Unprofessionell

**Priorität:** 🟡 **MITTEL**

**Empfehlung:**
1. **Sofort:** Kommentieren oder löschen (nicht für Prod relevant)
2. **Langfristig:** Logger verwenden:
   ```dart
   final _log = AppLogService.logger;
   _log.d('artikelId: $artikelId');  // Wird nur in Debug-Mode geloggt
   ```

---

### 🟡 M-003: Inkonsistente Flutter-Version in CI
**Dateien:**
- `.github/workflows/release.yml` → `flutter-version: '3.35.6'`
- `.github/workflows/flutter-maintenance.yml` → `flutter-version: '3.41.4'`
- `app/Dockerfile` → `ARG FLUTTER_VERSION=3.41.4`

**Problem:**
- Release-Builds nutzen **3.35.6** (veraltet)
- Docker + Maintenance nutzen **3.41.4** (aktuell)

**Auswirkung:**
- ⚠️ Release-Builds könnten andere Bugs haben als Docker
- ⚠️ Inkonsistente Build-Umgebungen
- ⚠️ Verwirr für Entwickler

**Priorität:** 🟡 **MITTEL**

**Fix:**
```yaml
# release.yml (Line 54, 85, 122):
flutter-version: '3.41.4'  # ← Update
```

---

### 🟡 M-004: Produktions-Compose-Datei am falschen Ort
**Datei:** `app/docker-compose.prod.yaml`

**Problem:**
- Dev-Compose: `/docker-compose.yml` (Root)
- Prod-Compose: `/app/docker-compose.prod.yaml` (im app-Ordner!)

**Inkonsistenz:**
```bash
# Dev/Test:
cd /
docker compose up

# Produktion:
cd /app  # ← Warum hier?
docker compose -f docker-compose.prod.yaml up
```

**Auswirkung:**
- ⚠️ Verwirrend für Nutzer
- ⚠️ Relative Pfade müssen angepasst werden
- ⚠️ Inkonsistente Projektstruktur

**Priorität:** 🟡 **MITTEL**

**Empfehlung:**
Verschiebe `app/docker-compose.prod.yaml` → Root:
```bash
mv app/docker-compose.prod.yaml docker-compose.prod.yml
```

Und passe Pfade an:
```yaml
services:
  app:
    build:
      context: ./app  # ← war nur "."
```

---

### 🟡 M-005: iOS/macOS Deployment Targets veraltet
**Dateien:**
- `app/ios/Runner.xcodeproj/project.pbxproj` → `IPHONEOS_DEPLOYMENT_TARGET = 13.0`
- `app/macos/Runner.xcodeproj/project.pbxproj` → `MACOSX_DEPLOYMENT_TARGET = 10.15`

**Problem:**
- iOS 13.0 ist von 2019 (aktuell iOS 17+)
- macOS 10.15 (Catalina) ist von 2019 (aktuell macOS 14+)

**Auswirkung:**
- ⚠️ Blockiert neuere APIs
- ⚠️ Limitiert potentielle Nutzer (aber sehr alte Geräte)
- ℹ️ Aktuell kein direktes Problem

**Priorität:** 🟡 **MITTEL**

**Empfehlung:**
```
iOS:   13.0 → 14.0 oder 15.0
macOS: 10.15 → 11.0 (Big Sur) oder 12.0
```

---

## 4️⃣ NIEDRIGE PRIORITÄT

### 🟢 N-001: Doppelte Mocking-Libraries
**Datei:** `app/pubspec.yaml` (Lines 144-152)

**Problem:**
```yaml
dev_dependencies:
  mockito: ^5.4.2
  mocktail: ^1.0.4
```

**Beide Libraries erfüllen denselben Zweck.** Kommentar im Code warnt bereits.

**Priorität:** 🟢 **NIEDRIG**

**Empfehlung:**
- Wenn `@GenerateMocks` im Code genutzt wird → `mockito` behalten
- Sonst → `mocktail` nutzen (modernere API, kein build_runner nötig)

---

### 🟢 N-002: dependency_overrides ohne Kommentar
**Datei:** `app/pubspec.yaml` (Lines 194-198)

**Problem:**
```yaml
dependency_overrides:
  connectivity_plus_platform_interface: ^2.0.0
```

**Kommentar erklärt Grund, aber Version ist nicht gepinnt.**

**Priorität:** 🟢 **NIEDRIG**

**Empfehlung:**
```yaml
dependency_overrides:
  # Benötigt bis connectivity_plus ^6.2.0 erscheint
  # Siehe: https://github.com/fluttercommunity/plus_plugins/issues/XYZ
  connectivity_plus_platform_interface: 2.0.0  # ← Exakte Version pinnen
```

---

### 🟢 N-003: Fehlende GitHub Secrets Dokumentation
**Workflows verwenden:**
- `${{ secrets.GH_PAT }}`
- `${{ secrets.GITHUB_TOKEN }}`

**Aber:** README dokumentiert nicht, wie man `GH_PAT` einrichtet.

**Priorität:** 🟢 **NIEDRIG**

**Empfehlung:**
Zu README hinzufügen:
```markdown
## GitHub Actions Setup

### Erforderliche Secrets

- `GH_PAT`: Personal Access Token mit `repo` scope
  - Erstellen: GitHub Settings → Developer settings → Personal access tokens
  - Verwendung: Tag-Erstellung im Release-Workflow
```

---

## 5️⃣ PLATTFORM-SPEZIFISCHE ANALYSE

### 🌐 **Web (Flutter Web + Docker)**

**Status:** ✅ **Produktionsbereit (mit Einschränkungen)**

**Build-Konfiguration:**
- ✅ Dockerfile vorhanden und getestet
- ✅ Multi-Stage-Build (Flutter + Caddy)
- ✅ Caching optimiert
- ✅ SPA-Routing konfiguriert
- ⚠️ Build-Zeit-URL-Problem (siehe K-004)

**Laufzeit:**
- ✅ Caddy als Static File Server
- ✅ Healthcheck konfiguriert
- ✅ Gzip-Kompression aktiv
- ✅ Cache-Headers für Assets
- ⚠️ CORS nicht explizit konfiguriert (siehe H-002)

**Platform-Guards:**
- ✅ Alle `dart:io` Pakete hinter `kIsWeb` Guards
- ✅ Conditional Imports funktionieren
- ✅ Web-spezifische Services vorhanden

**Bekannte Einschränkungen:**
- ❌ QR-Scanner nicht verfügbar (mobile_scanner Web-Support experimentell)
- ❌ Lokale Datenbank nicht verfügbar (nutzt direkt PocketBase)
- ✅ PDF-Export funktioniert (via `printing` Package)

**Empfehlungen:**
1. CORS konfigurieren (H-002)
2. Web Manifest aktualisieren (H-003)
3. Runtime-URL-Konfiguration implementieren (K-004)

---

### 📱 **Android**

**Status:** ✅ **Produktionsbereit**

**Build-Konfiguration:**
- ✅ Gradle Kotlin DSL
- ✅ CI/CD vorhanden (APK + App Bundle)
- ✅ Splash Screen konfiguriert
- ✅ Icons generiert
- ❌ **Bundle ID = `com.example.ev`** (siehe K-001)

**Laufzeit:**
- ✅ SQLite lokal + PocketBase Sync
- ✅ Bildupload funktioniert
- ✅ QR-Scanner verfügbar
- ✅ Offline-First Architektur

**Permissions:**
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```
✅ Alle Permissions sinnvoll und dokumentiert

**Deployment-Target:**
- `minSdkVersion 21` (Android 5.0 Lollipop) ✅ Angemessen
- `targetSdkVersion 34` (Android 14) ✅ Aktuell

**Empfehlungen:**
1. **KRITISCH:** Bundle ID aktualisieren
2. ProGuard Rules prüfen (falls Obfuscation gewünscht)
3. Release-Signing konfigurieren (für Store-Upload)

---

### 🪟 **Windows Desktop**

**Status:** ✅ **Produktionsbereit**

**Build-Konfiguration:**
- ✅ CMakeLists.txt vorhanden
- ✅ CI/CD vorhanden (ZIP-Archiv)
- ✅ Runner konfiguriert
- ❌ **Bundle ID = `com.example.ev`** (siehe K-001)

**Laufzeit:**
- ✅ SQLite lokal (sqflite_common_ffi)
- ✅ PocketBase Sync
- ⚠️ QR-Scanner eingeschränkt (mobile_scanner Desktop-Support experimentell)

**Deployment:**
- ✅ Standalone-Executable
- ⚠️ Keine Installer (.exe, .msi) generiert
- ⚠️ Keine Code-Signing (SmartScreen-Warnung möglich)

**Empfehlungen:**
1. **Bundle ID aktualisieren**
2. MSIX-Installer generieren:
   ```yaml
   flutter pub run msix:create
   ```
3. Code-Signing für Produktion (verhindert SmartScreen)

---

### 🐧 **Linux Desktop**

**Status:** ⚠️ **Build funktioniert, aber keine CI/CD**

**Build-Konfiguration:**
- ✅ CMakeLists.txt vorhanden
- ✅ Flutter Maintenance Workflow testet Linux
- ❌ **Kein Release-Build im Workflow** (siehe H-001)

**Laufzeit:**
- ✅ SQLite lokal
- ✅ PocketBase Sync
- ⚠️ Connectivity-Service hat WSL2-Workaround (siehe Code)

**Besonderheiten:**
```dart
// lib/services/connectivity_service.dart
if (!kIsWeb && Platform.isLinux) {
  // WSL2 + NetworkManager Fallback zu TCP-Check
  return _tcpCheck();
}
```

**Empfehlungen:**
1. Linux-Build zu Release-Workflow hinzufügen
2. AppImage oder .deb generieren:
   ```bash
   flutter build linux --release
   # Dann: appimagetool oder dpkg-deb
   ```
3. WSL2-Einschränkung in README dokumentieren

---

### 🍎 **iOS**

**Status:** ❌ **Konfiguriert, aber nicht gebaut**

**Build-Konfiguration:**
- ✅ Xcode-Projekt vorhanden
- ✅ Runner konfiguriert
- ✅ Splash Screen + Icons
- ❌ **Kein CI/CD** (siehe H-001)
- ❌ **Bundle ID = `com.example.ev`** (siehe K-001)

**Deployment-Target:**
- `IPHONEOS_DEPLOYMENT_TARGET = 13.0` (iOS 13)
- ⚠️ Veraltet (siehe M-005)

**Signing:**
- ❌ Nicht konfiguriert
- ❌ Provisioning Profile fehlt

**Empfehlungen:**
1. **KRITISCH:** Bundle ID aktualisieren
2. Apple Developer Account einrichten
3. CI/CD mit Fastlane konfigurieren
4. Deployment Target auf iOS 14+ anheben

---

### 🍏 **macOS**

**Status:** ❌ **Konfiguriert, aber nicht gebaut**

**Build-Konfiguration:**
- ✅ Xcode-Projekt vorhanden
- ✅ Runner konfiguriert
- ❌ **Kein CI/CD** (siehe H-001)
- ❌ **Bundle ID = `com.example.ev`** (siehe K-001)

**Deployment-Target:**
- `MACOSX_DEPLOYMENT_TARGET = 10.15` (Catalina)
- ⚠️ Veraltet (siehe M-005)

**Signing:**
- ❌ Nicht konfiguriert
- ❌ App Sandboxing nicht aktiviert (Store-Requirement)

**Empfehlungen:**
1. **KRITISCH:** Bundle ID aktualisieren
2. Deployment Target auf 11.0+ anheben
3. Hardened Runtime + Notarization konfigurieren (für Store)
4. Entitlements konfigurieren (Camera, Network, File Access)

---

## 6️⃣ DOCKER & DEPLOYMENT

### ✅ **Stärken**

1. **Saubere Multi-Stage-Builds:**
   ```dockerfile
   # Stage 1: Flutter Build
   FROM debian:bookworm-slim AS build-env
   
   # Stage 2: Caddy Static Server
   FROM caddy:2-alpine
   ```
   ✅ Schlankes finales Image (~50 MB für Caddy + Flutter Web)

2. **Layer-Caching optimiert:**
   ```dockerfile
   COPY pubspec.yaml pubspec.lock ./
   RUN flutter pub get  # ← Cached wenn Dependencies unverändert
   COPY . .
   ```

3. **Healthchecks konfiguriert:**
   - PocketBase: `/api/health`
   - Frontend: Root-Route
   - Nginx Proxy Manager: Admin API

4. **Trennung Dev/Prod:**
   - `docker-compose.yml` → Dev/Test (Ports gemappt)
   - `docker-compose.prod.yaml` → Prod (nur intern, NPM vorgeschaltet)

### ⚠️ **Schwächen**

1. **Build-Time URL** (siehe K-004)
2. **Fehlende PocketBase-Initialisierung** (siehe K-003)
3. **CORS nicht konfiguriert** (siehe H-002)
4. **Compose-Datei am falschen Ort** (siehe M-004)

### 🔒 **Sicherheit**

**✅ Gut:**
- `.env` und `.env.production` in `.gitignore`
- `server/pb_data/` gitignored
- Keine Secrets im Code
- Nginx Proxy Manager Admin-UI nur auf `127.0.0.1:81`

**⚠️ Problematisch:**
- PocketBase API-Rules offen (siehe K-002)
- Keine Rate-Limiting konfiguriert
- Keine Security-Headers (HSTS, CSP, X-Frame-Options)

**Empfehlung - Security-Headers:**
```caddyfile
# Caddyfile - erweitern:
header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains"
    X-Content-Type-Options "nosniff"
    X-Frame-Options "DENY"
    X-XSS-Protection "1; mode=block"
    Referrer-Policy "no-referrer"
}
```

---

## 7️⃣ ZUSAMMENFASSUNG & ROADMAP

### 📊 Prioritäten-Matrix

| Kategorie | Kritisch | Hoch | Mittel | Niedrig |
|-----------|----------|------|--------|---------|
| **Sicherheit** | K-002 (API Rules) | H-002 (CORS) | M-002 (Debug-Prints) | - |
| **Deployment** | K-001 (Bundle ID)<br>K-003 (PocketBase Init)<br>K-004 (Build-URL) | H-001 (Fehlende Builds)<br>H-003 (Web Manifest)<br>H-004 (Placeholder-URLs) | M-004 (Compose-Ort) | N-003 (Secrets-Doku) |
| **Code-Qualität** | - | - | M-001 (Tests)<br>M-003 (Flutter-Versionen) | N-001 (Doppelte Libs)<br>N-002 (Overrides) |
| **Plattform** | - | H-001 (iOS/macOS/Linux) | M-005 (Deployment Targets) | - |

### 🚀 Empfohlene Roadmap

**Phase 1 - Kritische Fixes (vor jedem Produktionseinsatz):**
1. ✅ Bundle IDs aktualisieren (K-001)
2. ✅ PocketBase API Rules setzen (K-002)
3. ✅ PocketBase Auto-Init implementieren (K-003)
4. ✅ Runtime-URL-Konfiguration (K-004)

**Phase 2 - Deployment-Vorbereitung:**
5. ✅ CORS konfigurieren (H-002)
6. ✅ Web Manifest aktualisieren (H-003)
7. ✅ iOS/macOS/Linux Builds (H-001)
8. ✅ Placeholder-URL Validation (H-004)

**Phase 3 - Code-Qualität:**
9. ✅ Testabdeckung erhöhen (M-001)
10. ✅ Debug-Prints entfernen (M-002)
11. ✅ Flutter-Versionen vereinheitlichen (M-003)

**Phase 4 - Polish:**
12. ✅ Deployment Targets aktualisieren (M-005)
13. ✅ Compose-Datei verschieben (M-004)
14. ✅ Security-Headers hinzufügen
15. ✅ Dokumentation vervollständigen

---

## 8️⃣ ABSCHLIESSENDE BEWERTUNG

### ✅ Was gut funktioniert:
- **Saubere Architektur:** Offline-First, Sync-Logik, Service-Layer
- **Plattform-Trennung:** Conditional Imports, kIsWeb-Guards
- **Docker-Setup:** Multi-Stage-Builds, Healthchecks
- **Code-Stil:** Konsistent, gut dokumentiert

### ⚠️ Was verbessert werden muss:
- **Sicherheit:** API Rules, CORS, Security-Headers
- **Deployment:** Auto-Init, Bundle IDs, CI/CD-Lücken
- **Tests:** Nur 6,5% Abdeckung
- **Dokumentation:** Fehlende Prod-Deployment-Anleitung

### 🎯 Fazit:
**Das Projekt ist technisch solide, aber für Produktionseinsatz müssen die kritischen Punkte (K-001 bis K-004) zwingend behoben werden.**

Nach Umsetzung der Phase-1-Fixes:
- ✅ Web-Deployment produktionsbereit
- ✅ Android-Deployment produktionsbereit
- ⚠️ iOS/macOS benötigen zusätzlich Apple-Signing
- ⚠️ Windows/Linux benötigen zusätzlich Installer-Generierung

---

**Dokument erstellt:** März 2026  
**Letzte Aktualisierung:** 2026-03-21  
**Nächste Review:** Nach Umsetzung Phase 1
