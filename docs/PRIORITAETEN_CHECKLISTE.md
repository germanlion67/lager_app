# ✅ Prioritäten-Checkliste - Lager_app

Basierend auf der technischen Analyse vom 2026-03-21

---

## 🔴 KRITISCH (Vor Produktionseinsatz zwingend erforderlich)

### K-001: App Bundle Identifiers aktualisieren
- [ ] `android/app/build.gradle.kts` → applicationId ändern
- [ ] `android/build.gradle.kts` → namespace ändern  
- [ ] `ios/Runner.xcodeproj/project.pbxproj` → PRODUCT_BUNDLE_IDENTIFIER ändern
- [ ] `macos/Runner.xcodeproj/project.pbxproj` → PRODUCT_BUNDLE_IDENTIFIER ändern
- [ ] **Entscheidung:** Welcher Bundle Identifier? (z.B. `com.germanlion67.lagerverwaltung`)

**Blockiert:** Google Play Store, Apple App Store Veröffentlichung

---

### K-002: PocketBase API Rules (Sicherheit!)
- [ ] `server/pb_migrations/1772784781_created_artikel.js` aktualisieren
- [ ] `server/pb_migrations/pb_schema.json` aktualisieren
- [ ] Entscheidung treffen:
  - [ ] Option A: Authentifizierung erforderlich (`"@request.auth.id != '"`)
  - [ ] Option B: Öffentlich lesbar, Auth zum Schreiben
  - [ ] Option C: Komplett öffentlich (nur für Demo!)
- [ ] Migration testen mit frischer PocketBase-Instanz

**Risiko:** Aktuell kann jeder alle Daten sehen, erstellen, ändern, löschen!

---

### K-003: PocketBase Auto-Initialisierung
- [ ] Init-Script erstellen (`server/init-pocketbase.sh`)
- [ ] Superuser-Erstellung via ENV-Variablen
- [ ] Migration automatisch anwenden
- [ ] Docker-Compose Integration (init-container oder entrypoint)
- [ ] Dokumentation in README aktualisieren
- [ ] Testen: Frisches `docker compose up` muss sofort funktionieren

**Blockiert:** Ein-Klick-Deployment, Produktionsautomatisierung

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

### M-004: Produktions-Compose verschieben
- [ ] `app/docker-compose.prod.yaml` → `/docker-compose.prod.yml` verschieben
- [ ] Build-Context-Pfade anpassen (`context: ./app`)
- [ ] Volume-Pfade anpassen
- [ ] README aktualisieren
- [ ] Testen: Produktions-Compose muss funktionieren

**Ziel:** Konsistente Projektstruktur

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
