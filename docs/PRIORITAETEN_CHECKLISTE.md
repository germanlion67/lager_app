# ✅ Prioritäten-Checkliste - Lager_app

Basierend auf der technischen Analyse vom 2026-03-21  
**Letzte Aktualisierung:** 2026-03-21 (nach Production Stack Implementation)

---

## 📊 Umsetzungsstatus

**Gesamt-Fortschritt:** 5 von 17 kritischen/hohen Prioritäten abgeschlossen

### ✅ Abgeschlossen (5)
- K-001: App Bundle Identifiers (alle Plattformen)
- K-002: PocketBase API Rules (Sicherheit)
- K-003: PocketBase Auto-Initialisierung
- M-004: Produktions-Compose verschoben
- Zusätzlich: Docker Stack, GitHub Actions, Produktions-Dokumentation

### 🔄 In Arbeit (0)
- Keine

### ⏳ Ausstehend (12)
- K-004: POCKETBASE_URL Build-Time Problem
- H-001 bis H-004: 4 hohe Prioritäten
- M-001 bis M-005: 4 mittlere Prioritäten (1 erledigt)
- N-001 bis N-003: 3 niedrige Prioritäten

---

## 🔴 KRITISCH (Vor Produktionseinsatz zwingend erforderlich)

### K-001: App Bundle Identifiers aktualisieren ✅ ERLEDIGT
- [x] `android/app/build.gradle.kts` → applicationId geändert zu `com.germanlion67.lagerverwaltung`
- [x] `android/app/build.gradle.kts` → namespace geändert zu `com.germanlion67.lagerverwaltung`
- [x] `android/.../MainActivity.kt` → Package verschoben nach `com.germanlion67.lagerverwaltung`
- [x] `ios/Runner.xcodeproj/project.pbxproj` → PRODUCT_BUNDLE_IDENTIFIER geändert
- [x] `macos/Runner.xcodeproj/project.pbxproj` → PRODUCT_BUNDLE_IDENTIFIER (Tests) geändert
- [x] `macos/Runner/Configs/AppInfo.xcconfig` → PRODUCT_BUNDLE_IDENTIFIER geändert
- [x] `linux/CMakeLists.txt` → APPLICATION_ID geändert
- [x] `windows/runner/Runner.rc` → CompanyName und Produktinfo aktualisiert
- [x] **Bundle Identifier festgelegt:** `com.germanlion67.lagerverwaltung`

**Status:** ✅ App Store Veröffentlichung jetzt möglich. Alle Plattformen aktualisiert.

---

### K-002: PocketBase API Rules (Sicherheit!) ✅ ERLEDIGT
- [x] `server/pb_migrations/1772784781_created_artikel.js` aktualisiert
- [x] `server/pb_migrations/pb_schema.json` aktualisiert
- [x] Entscheidung getroffen:
  - [x] Option A: Authentifizierung erforderlich (`"@request.auth.id != '"`) - IMPLEMENTIERT
  - [ ] Option B: Öffentlich lesbar, Auth zum Schreiben
  - [ ] Option C: Komplett öffentlich (nur für Demo!)
- [x] Migration getestet mit frischer PocketBase-Instanz

**Status:** ✅ Alle API Rules erfordern jetzt Authentifizierung. GDPR-konform.

---

### K-003: PocketBase Auto-Initialisierung ✅ ERLEDIGT
- [x] Init-Script erstellt (`server/init-pocketbase.sh`)
- [x] Superuser-Erstellung via ENV-Variablen (PB_ADMIN_EMAIL, PB_ADMIN_PASSWORD)
- [x] Migration automatisch anwenden (Migrations-Kopie beim Start)
- [x] Docker-Compose Integration (custom PocketBase Dockerfile)
- [x] Dokumentation in README und PRODUCTION_DEPLOYMENT.md aktualisiert
- [x] Getestet: Frisches `docker compose up` funktioniert sofort

**Status:** ✅ Ein-Klick-Deployment jetzt möglich. 26 automatische Tests bestanden.

---

### K-004: POCKETBASE_URL Build-Time Problem
**Kurzfristig:**
- [ ] Klarere Warnung in `docker-compose.yml` ergänzen
- [ ] README mit `--build` Pflicht prominenter dokumentieren

**Langfristig (empfohlen):**
- [ ] Runtime-Konfiguration via `window.ENV` implementieren
- [ ] Oder: Caddy-Entrypoint-Script für config.js-Generierung
- [ ] Migration zu Runtime-Config testen
- [ ] Dokumentation aktualisieren

**Blockiert:** Flexible Produktions-Deployments

---

## 🟠 HOCH (Wichtig für vollständige Produktionsreife)

### H-001: Fehlende Platform-Builds in CI/CD
- [ ] iOS-Build-Job zu `.github/workflows/release.yml` hinzufügen
- [ ] macOS-Build-Job hinzufügen
- [ ] Linux-Build-Job hinzufügen
- [ ] Artifact-Upload für alle Plattformen
- [ ] Release-Notes mit Download-Links aktualisieren
- [ ] **Hinweis:** iOS/macOS benötigen Apple Developer Account + Signing

**Betrifft:** Apple-User, Linux-User haben keine offiziellen Builds

---

### H-002: CORS-Konfiguration
- [ ] PocketBase CORS-ENV-Variable setzen
- [ ] Oder: Nginx Proxy Manager CORS-Header konfigurieren
- [ ] Für Dev/Test: `CORS_ALLOWED_ORIGINS=*` (Wildcard OK)
- [ ] Für Produktion: Spezifische Domain angeben
- [ ] Testen mit verschiedenen Subdomains

**Risiko:** Produktions-Deployment mit verschiedenen Domains könnte brechen

---

### H-003: Web Manifest Metadaten
- [ ] `app/web/manifest.json` aktualisieren:
  - [ ] `name` → "Elektronik Lagerverwaltung"
  - [ ] `short_name` → "Lager"
  - [ ] `description` → Sinnvolle Beschreibung
  - [ ] `background_color` → `#1976d2`
  - [ ] `theme_color` → `#1976d2`
  - [ ] `orientation` → `"any"`
- [ ] PWA-Installation testen (Chrome, Edge)

**Betrifft:** Web-App-Darstellung, PWA-Installation

---

### H-004: Placeholder-URL Validation
- [ ] Compile-Time-Check in `app_config.dart` hinzufügen
- [ ] Release-Build soll fehlschlagen bei Placeholder
- [ ] Oder: Zwingenden ENV-Variable-Check
- [ ] CI/CD-Test: Release-Build ohne URL muss fehlschlagen

**Verhindert:** Silent Failures in Produktion

---

## 🟡 MITTEL (Verbesserungen für Wartbarkeit)

### M-001: Testabdeckung erhöhen
- [ ] Ziel: Mindestens 40% Abdeckung
- [ ] Tests für `artikel_db_service.dart` (CRUD)
- [ ] Tests für `pocketbase_sync_service.dart` (Sync-Logik)
- [ ] Widget-Tests für `artikel_list_screen.dart`
- [ ] Integration-Test für Offline→Online Sync
- [ ] CI/CD: Test-Coverage-Report generieren

**Status:** Aktuell nur ~6,5% Testabdeckung

---

### M-002: Debug-Prints entfernen
- [ ] Alle `debugPrint` in `artikel_erfassen_screen.dart` entfernen/auskommentieren
- [ ] Alle `debugPrint` in `artikel_erfassen_io.dart` entfernen/auskommentieren
- [ ] Optional: Durch `AppLogService.logger.d()` ersetzen
- [ ] Linter-Rule hinzufügen: `avoid_print: true`

**11 Debug-Statements gefunden**

---

### M-003: Flutter-Versionen vereinheitlichen
- [ ] `.github/workflows/release.yml` → `3.35.6` → `3.41.4` updaten
- [ ] Sicherstellen: Alle Workflows nutzen dieselbe Version
- [ ] Dokumentation aktualisieren

**Betrifft:** Build-Konsistenz

---

### M-004: Produktions-Compose verschieben ✅ ERLEDIGT
- [x] `app/docker-compose.prod.yaml` → `/docker-compose.prod.yml` verschoben
- [x] Build-Context-Pfade angepasst (`context: ./app`)
- [x] Volume-Pfade angepasst
- [x] README aktualisiert
- [x] Getestet: Produktions-Compose funktioniert aus Root

**Status:** ✅ Konsistente Projektstruktur erreicht.

---

### M-005: Deployment Targets aktualisieren
- [ ] iOS: `13.0` → `14.0` oder `15.0`
- [ ] macOS: `10.15` → `11.0` oder `12.0`
- [ ] Kompatibilität mit Dependencies prüfen
- [ ] Testen auf Zielgeräten/Simulatoren

**Niedrige Dringlichkeit** (funktioniert aktuell)

---

## 🟢 NIEDRIG (Nice-to-Have)

### N-001: Mocking-Libraries bereinigen
- [ ] Entscheidung: `mockito` oder `mocktail`?
- [ ] Ungenutztes Package aus `pubspec.yaml` entfernen
- [ ] Tests auf gewähltes Package migrieren

---

### N-002: dependency_overrides dokumentieren
- [ ] Version auf exakte Version pinnen (nicht `^2.0.0`)
- [ ] Link zu GitHub-Issue hinzufügen
- [ ] Reminder: Bei `flutter pub upgrade` prüfen ob noch nötig

---

### N-003: GitHub Secrets dokumentieren
- [ ] README-Sektion "GitHub Actions Setup" erstellen
- [ ] `GH_PAT` Erstellung dokumentieren
- [ ] Scopes dokumentieren (`repo`)

---

## 📋 Zusätzliche Empfehlungen (nicht in Analyse)

### Dokumentation vervollständigen ✅ ERLEDIGT (Teilweise)
- [x] Produktions-Deployment-Anleitung (PRODUCTION_DEPLOYMENT.md erstellt)
- [x] Plattform-spezifische Build-Anleitungen (im README)
- [ ] Backup/Restore-Prozedur dokumentieren (grundlegend vorhanden, kann erweitert werden)
- [x] Troubleshooting-Sektion erweitert (in PRODUCTION_DEPLOYMENT.md)

**Status:** ✅ Hauptdokumentation vollständig. Backup/Restore kann noch detaillierter werden.

---

### Docker Hub / GitHub Container Registry Integration ✅ ERLEDIGT
- [x] GitHub Actions Workflow erstellt (.github/workflows/docker-build-push.yml)
- [x] Automatischer Build bei Push zu main/master
- [x] Automatischer Build bei Version Tags (v*)
- [x] Flutter Web Image wird gebaut und gepusht
- [x] PocketBase Image wird gebaut und gepusht
- [x] Multi-Platform Caching implementiert
- [x] Automated testing auf Pull Requests

**Status:** ✅ CI/CD Pipeline vollständig implementiert und getestet.

---

### Security-Headers hinzufügen
- [ ] `Caddyfile` erweitern mit:
  - [ ] `Strict-Transport-Security`
  - [ ] `X-Content-Type-Options`
  - [ ] `X-Frame-Options`
  - [ ] `X-XSS-Protection`
  - [ ] `Referrer-Policy`
- [ ] Testen mit securityheaders.com

---

### Dokumentation vervollständigen
- [ ] Produktions-Deployment-Anleitung
- [ ] Plattform-spezifische Build-Anleitungen
- [ ] Backup/Restore-Prozedur dokumentieren
- [ ] Troubleshooting-Sektion erweitern

---

## 🎯 Phasen-Plan (Empfehlung)

**Phase 1: Kritische Fixes (1-2 Wochen)**
- K-001, K-002, K-003, K-004
- Nach Abschluss: **Produktionsfreigabe möglich**

**Phase 2: Deployment-Verbesserungen (1 Woche)**
- H-001, H-002, H-003, H-004

**Phase 3: Code-Qualität (2-3 Wochen)**
- M-001 (Tests), M-002, M-003

**Phase 4: Polish (nach Bedarf)**
- M-004, M-005, alle N-Punkte

---

**Tracking:** Diese Checkliste kann in GitHub Projects oder Issues übertragen werden  
**Update:** Bei Abschluss Status auf `[x]` ändern
