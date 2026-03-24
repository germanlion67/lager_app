# 📋 Manuelle Optimierungen & Klärungsfragen

Diese Datei dokumentiert Optimierungen aus der PRIORITAETEN_CHECKLISTE.md, die **manuelle Handlungen** oder **Klärungen** erfordern und daher nicht automatisch umgesetzt wurden.

**Letzte Aktualisierung:** 2026-03-24 (H-001 Linux: Implementiert, iOS/macOS: Zurückgestellt)

---

## 🟠 HOCH (Wichtig für vollständige Produktionsreife)

### H-001: Platform-Builds in CI/CD

**Status Linux:** ✅ Implementiert (2026-03-24) – Linux-Build ist in `.github/workflows/release.yml` aktiv.  
**Status iOS/macOS:** 🔴 Zurückgestellt – Benötigt Apple Developer Account

**Linux-Build (ERLEDIGT):**
- Build-Job: `build-linux` in `release.yml`
- Dependencies: clang, cmake, ninja-build, pkg-config, libgtk-3-dev, libglu1-mesa-dev, liblzma-dev, libsecret-1-dev
- Ausgabe: `linux-release-{version}.tar.gz` als GitHub Release Artifact

**iOS/macOS – Zurückgestellt, offene Klärungen:**
1. **Apple Developer Account:** Ist ein aktiver Apple Developer Account verfügbar?
   - Account-ID und Team-ID für iOS/macOS Signing
   - Zugriff auf App Store Connect für Veröffentlichung

2. **Signing Certificates & Provisioning Profiles:**
   - Sollen diese als GitHub Secrets hinterlegt werden?
   - Welche Signing-Methode: Development, Ad-Hoc, oder App Store Distribution?

**Nächste Schritte für iOS (wenn bereit):**
1. Apple Developer Account einrichten
2. Signing Certificates generieren und in GitHub Secrets speichern
3. Workflow `.github/workflows/release.yml` um iOS/macOS Jobs erweitern
4. Artifacts für iOS/macOS hochladen

**Geschätzte Komplexität iOS:** 🔴 Hoch (3-5 Stunden + jährliche Wartung)

---

### H-005: Prod-Stack nutzt vorgebautes Frontend-Image

**Status:** ⏳ Ausstehend - Benötigt GitHub Container Registry Images

**Erforderliche Klärungen:**
1. **Image Registry:**
   - GitHub Container Registry (ghcr.io) verwenden? (empfohlen)
   - Oder Docker Hub?

2. **Tagging-Strategie:**
   - SemVer Tags (`v1.0.0`, `v1.1.0`) für Releases?
   - `latest` für neueste stabile Version?
   - `develop` für Entwicklungsversion?

3. **Automatisierung:**
   - Soll `.github/workflows/docker-build-push.yml` automatisch bei Git Tags bauen?
   - Sollen Pre-Release Versionen anders getaggt werden?

**Implementierung:**
```yaml
# In docker-compose.prod.yml und docker-stack.yml:
services:
  app:
    # VORHER (lokaler Build):
    # build:
    #   context: ./app
    #   dockerfile: Dockerfile
    
    # NACHHER (vorgebautes Image):
    image: ghcr.io/germanlion67/lager_app:latest
    # Oder mit spezifischer Version:
    # image: ghcr.io/germanlion67/lager_app:v1.0.0
```

**Nächste Schritte:**
1. GitHub Container Registry aktivieren (falls noch nicht geschehen)
2. `.github/workflows/docker-build-push.yml` prüfen und ggf. erweitern
3. `docker-compose.prod.yml` auf `image:` umstellen (kein `build:`)
4. `docker-stack.yml` entsprechend anpassen
5. Dokumentation aktualisieren (PRODUCTION_DEPLOYMENT.md)

**Geschätzte Komplexität:** 🟡 Mittel (1-2 Stunden)

---

## 🟡 MITTEL (Verbesserungen für Wartbarkeit)

### M-001: Testabdeckung erhöhen

**Status:** ⏳ Ausstehend - Umfangreiche Arbeit

**Aktueller Stand:** ~6,5% Testabdeckung

**Erforderliche Klärungen:**
1. **Priorität der Test-Bereiche:**
   - Welche Services/Screens sind am kritischsten?
   - Backend-Sync (PocketBase) oder UI-Komponenten zuerst?

2. **Test-Strategie:**
   - Unit-Tests (Services, Models)
   - Widget-Tests (UI-Komponenten)
   - Integration-Tests (End-to-End Flows)

3. **Ziel-Abdeckung:**
   - Minimal: 40% (wie in PRIORITAETEN_CHECKLISTE.md)
   - Ideal: 60-80%

**Zu testende Komponenten (Priorität):**
1. **Hoch:**
   - `artikel_db_service.dart` - CRUD Operationen
   - `pocketbase_sync_service.dart` - Sync-Logik
   - `app_config.dart` - Konfiguration

2. **Mittel:**
   - `artikel_list_screen.dart` - Widget-Tests
   - `artikel_erfassen_screen.dart` - Widget-Tests
   - `backup_service.dart` - Backup/Restore

3. **Integration:**
   - Offline → Online Sync Flow
   - Artikel Erfassen → Speichern → Sync
   - PDF Export → Backup → Restore

**Nächste Schritte:**
1. Test-Vorlage erstellen (Beispiel für jeden Test-Typ)
2. Mock-Daten für PocketBase vorbereiten
3. Systematisch Tests für priorisierte Komponenten schreiben
4. CI/CD: Coverage-Report generieren und als Artifact speichern

**Geschätzte Komplexität:** 🔴 Sehr Hoch (10-20 Stunden)

---

### M-002: Debug-Prints entfernen

**Status:** 🔄 Teilweise - Linter aktiv, manuelle Cleanup ausstehend

**Aktueller Stand:** 
- ✅ Linter-Rule `avoid_print: true` in `analysis_options.yaml` aktiviert
- ⏳ 46 `debugPrint` Statements gefunden (werden vom Linter markiert)

**Erforderliche Klärungen:**
1. **Logging-Strategie:**
   - Alle `debugPrint` entfernen?
   - Oder durch `AppLogService.logger.d()` ersetzen?
   - Welche Log-Level für welche Bereiche?

2. **Betroffene Dateien (Priorität):**
   - `artikel_erfassen_screen.dart`
   - `artikel_erfassen_io.dart`
   - Weitere Services und Screens

**Empfohlene Vorgehensweise:**
```dart
// VORHER:
debugPrint('[ArtikelService] Artikel gespeichert: ${artikel.id}');

// NACHHER:
AppLogService.logger.d('Artikel gespeichert: ${artikel.id}');
```

**Nächste Schritte:**
1. Entscheiden: Löschen oder durch Logger ersetzen?
2. Bei Ersetzen: `AppLogService` in betroffenen Dateien importieren
3. Such-Ersetzen mit grep/sed oder IDE Find&Replace
4. Linter erneut laufen lassen um Vollständigkeit zu prüfen

**Geschätzte Komplexität:** 🟡 Mittel (2-3 Stunden, mechanisch)

---

### M-005: Deployment Targets aktualisieren

**Status:** ⏳ Ausstehend - Benötigt Gerätetests

**Erforderliche Klärungen:**
1. **iOS Minimum Version:**
   - Aktuell: `13.0`
   - Vorschlag: `14.0` oder `15.0`
   - Begründung: iOS 13 wird von Apple nicht mehr supported (seit iOS 17)

2. **macOS Minimum Version:**
   - Aktuell: `10.15` (Catalina)
   - Vorschlag: `11.0` (Big Sur) oder `12.0` (Monterey)
   - Begründung: Ältere Versionen haben weniger Nutzer

3. **Kompatibilität mit Dependencies:**
   - Müssen alle Flutter Packages mit neuen Targets kompatibel sein
   - Breaking Changes in nativen APIs?

4. **Test-Geräte:**
   - Welche physischen Geräte/Simulatoren sind verfügbar?
   - iOS 14/15 Simulatoren testen
   - macOS 11/12 VMs oder Geräte

**Zu aktualisierende Dateien:**
- `ios/Podfile` - `platform :ios, '14.0'`
- `ios/Runner.xcodeproj/project.pbxproj` - `IPHONEOS_DEPLOYMENT_TARGET`
- `macos/Podfile` - `platform :osx, '11.0'`
- `macos/Runner.xcodeproj/project.pbxproj` - `MACOSX_DEPLOYMENT_TARGET`

**Nächste Schritte:**
1. Marktanalyse: Welche iOS/macOS Versionen werden noch genutzt?
2. Dependencies auf Kompatibilität prüfen
3. Target-Versionen in Xcode-Projekten aktualisieren
4. Auf Zielgeräten/Simulatoren testen
5. Dokumentation aktualisieren

**Geschätzte Komplexität:** 🟡 Mittel (3-4 Stunden mit Testing)

---

### M-006: Docker Stack Deploy "Happy Path" dokumentieren & testen

**Status:** ⏳ Ausstehend - Dokumentation erweitern

**Erforderliche Klärungen:**
1. **Zielgruppe:**
   - Technisch versierte Endnutzer?
   - Oder absolute Anfänger (minimal Docker-Kenntnisse)?

2. **Dokumentationstiefe:**
   - Nur Kommandos?
   - Oder Schritt-für-Schritt mit Screenshots?
   - Troubleshooting-Sektion erweitern?

3. **Test-Umgebung:**
   - Frischer Ubuntu Server (Digital Ocean, AWS, Hetzner)?
   - Oder lokale VM (VirtualBox, VMware)?

**Zu dokumentieren:**
```bash
# Minimal-Schritte für Endnutzer-Installation:

# 1. Repository klonen
git clone https://github.com/germanlion67/lager_app.git
cd lager_app

# 2. Environment-Variablen setzen
cp .env.production.example .env.production
nano .env.production  # POCKETBASE_URL, Credentials setzen

# 3. Docker Swarm initialisieren (falls noch nicht geschehen)
docker swarm init

# 4. Secrets erstellen
echo "IhrSicheresPasswort" | docker secret create pb_admin_password -

# 5. Stack deployen
docker stack deploy -c docker-stack.yml lager

# 6. Status prüfen
docker stack services lager
docker stack ps lager

# 7. Logs anzeigen
docker service logs lager_pocketbase
docker service logs lager_app
```

**Nächste Schritte:**
1. Frischen Test-Server aufsetzen (Ubuntu 22.04 LTS)
2. Obige Schritte durchführen und dokumentieren
3. Alle Fehler/Fallstricke notieren
4. `docs/DOCKER_STACK_GUIDE.md` erstellen
5. README.md mit Link ergänzen

**Geschätzte Komplexität:** 🟡 Mittel (2-3 Stunden)

---

### M-007: PocketBase Indizes/Constraints prüfen

**Status:** ⏳ Ausstehend - Datenbank-Analyse

**Erforderliche Klärungen:**
1. **Performance-Anforderungen:**
   - Wie viele Artikel werden erwartet? (100, 1.000, 10.000+?)
   - Welche Queries sind am häufigsten?

2. **Eindeutigkeits-Constraints:**
   - Soll `artikel.nummer` eindeutig sein (UNIQUE)?
   - Soll Kombination `ort + fach + artikel.nummer` eindeutig sein?

3. **Performance-Indizes:**
   - Schnelle Suche nach `ort`, `fach`, `kategorie`?
   - Volltext-Suche auf `bezeichnung`, `beschreibung`?

**Zu prüfende Felder (Collection: artikel):**
- `nummer` - Index für schnelle Suche? UNIQUE Constraint?
- `ort` - Index für Filter
- `fach` - Index für Filter
- `kategorie` - Index für Filter
- `bezeichnung` - Volltext-Index für Suche?
- `beschreibung` - Volltext-Index für Suche?

**PocketBase Migration-Beispiel:**
```javascript
// server/pb_migrations/XXXXXX_add_indices.js
migrate((db) => {
  // Index auf 'nummer' für schnelle Suche
  db.collection('artikel').createIndex('idx_artikel_nummer', 'nummer');
  
  // Unique Constraint auf 'nummer' (optional)
  // db.collection('artikel').addUniqueConstraint(['nummer']);
  
  // Composite Index für ort+fach Filterung
  db.collection('artikel').createIndex('idx_artikel_ort_fach', ['ort', 'fach']);
  
  // Volltext-Index für Suche (falls PocketBase unterstützt)
  // ...
}, (db) => {
  // Rollback
  db.collection('artikel').dropIndex('idx_artikel_nummer');
  db.collection('artikel').dropIndex('idx_artikel_ort_fach');
});
```

**Nächste Schritte:**
1. Query-Patterns analysieren (welche Queries werden am häufigsten ausgeführt?)
2. Entscheiden: Welche Indizes/Constraints sind sinnvoll?
3. Migration erstellen und testen
4. Performance vorher/nachher messen (bei größerer Datenmenge)

**Geschätzte Komplexität:** 🟡 Mittel (2-4 Stunden)

---

### M-009: Scan-Funktion allgemein prüfen

**Status:** ⏳ Ausstehend - Feature-Analyse

**Erforderliche Klärungen:**
1. **Aktueller Stand:**
   - Existiert bereits eine Scan-Funktion im Code?
   - Wenn ja: Welche Plattformen werden unterstützt?
   - Welche Scanner-Library wird verwendet?

2. **Plattformabdeckung:**
   - Web: Webcam-basiertes Scannen?
   - Mobile (Android/iOS): Native Kamera?
   - Desktop (Windows/Linux/macOS): USB-Scanner? Webcam?

3. **Fallback-Strategie:**
   - Manuelle Eingabe wenn Scan fehlschlägt?
   - Wie wird Benutzer informiert?

**Zu prüfende Bereiche:**
- Code-Suche: `grep -r "scan" app/lib/`
- Dependencies: `mobile_scanner`, `qr_code_scanner`, o.ä.?
- UX-Flow: Scan-Button → Kamera → Ergebnis → Fehlerfall

**Nächste Schritte:**
1. Code-Analyse: Scan-Funktionalität lokalisieren
2. Auf allen Plattformen testen (Web, Android, Windows, Linux)
3. Fehlerfälle durchspielen (Abbruch, keine Berechtigung, kein Gerät)
4. UX-Verbesserungen dokumentieren
5. Falls nicht vorhanden: Scan-Feature-Spezifikation erstellen

**Geschätzte Komplexität:** 🟡 Mittel bis 🔴 Hoch (abhängig vom aktuellen Stand)

---

### M-010: QR-Scanning plattformübergreifend

**Status:** ⏳ Ausstehend - Feature-Erweiterung

**Erforderliche Klärungen:**
1. **Use Cases:**
   - Welche Entitäten sollen QR-Codes haben?
     - Artikel (eindeutige ID oder Nummer)?
     - Lagerorte (Regal/Fach)?
     - Dokumente?

2. **QR-Code-Generierung:**
   - Sollen QR-Codes in der App generiert werden?
   - Oder extern (z.B. Etikettendrucker)?

3. **Architektur:**
   - Gemeinsame Schnittstelle für alle Plattformen?
   - Platform-spezifische Implementierung (conditional imports)?

**Empfohlene Libraries:**
- Scan: `mobile_scanner` (Web, Android, iOS, Desktop)
- Generierung: `qr_flutter` (alle Plattformen)

**Beispiel-Architektur:**
```
lib/
  services/
    qr_service.dart          # Interface
    qr_service_mobile.dart   # Android/iOS Implementation
    qr_service_web.dart      # Web Implementation
    qr_service_desktop.dart  # Windows/Linux/macOS Implementation
```

**Nächste Schritte:**
1. Use Cases definieren
2. Library evaluieren (`mobile_scanner` vs. Alternativen)
3. Architektur-Design (Interface + Platform-Implementierungen)
4. Proof-of-Concept auf einer Plattform
5. Rollout auf alle Plattformen
6. Tests auf allen Plattformen

**Geschätzte Komplexität:** 🔴 Hoch (8-12 Stunden)

---

### M-011: Artikelbilder optimieren

**Status:** ⏳ Ausstehend - Performance-Optimierung

**Erforderliche Klärungen:**
1. **Aktueller Stand:**
   - Werden Bilder bereits in Listen/Details angezeigt?
   - Welche Bildgrößen werden gespeichert?

2. **Thumbnail-Strategie:**
   - Server-seitig (PocketBase Auto-Resize)?
   - Client-seitig (Flutter Image-Resize)?

3. **Performance-Ziele:**
   - Maximale Dateigröße für Uploads?
   - Maximale Bildgröße für Thumbnails?
   - Lazy Loading in Listen?

**PocketBase-Features:**
- Automatische Thumbnail-Generierung: `?thumb=100x100`
- Beispiel: `http://pb/api/files/artikel/{id}/{filename}?thumb=200x200`

**Zu optimieren:**
1. **Listen-Ansicht:** Kleine Thumbnails (100x100 oder 200x200)
2. **Detail-Ansicht:** Größere Vorschau (400x400 oder 600x600)
3. **Upload:** Bild-Kompression vor Upload (auf Mobile)
4. **Caching:** Flutter Image-Cache nutzen

**Nächste Schritte:**
1. Aktuelles Bildhandling analysieren
2. PocketBase Thumbnail-Feature evaluieren
3. Client-seitige Optimierung (Image-Widget mit Caching)
4. Performance-Tests (große Artikelliste mit Bildern)

**Geschätzte Komplexität:** 🟡 Mittel (4-6 Stunden)

---

### M-012: Dokumentenanhänge pro Artikel

**Status:** ⏳ Ausstehend - Feature-Erweiterung

**Erforderliche Klärungen:**
1. **Use Cases:**
   - Welche Dokumenttypen? (PDF, Excel, Word, Bilder, etc.)
   - Wie viele Anhänge pro Artikel? (Limit?)

2. **PocketBase Schema:**
   - `artikel` Collection erweitern mit `files` Feld (Multiple)?
   - Oder separate `attachments` Collection mit Relation?

3. **UX-Flow:**
   - Upload: Drag&Drop? File-Picker?
   - Liste: Dateiname, Größe, Typ, Thumbnail?
   - Download: Direkter Download oder Vorschau?
   - Löschen: Einzeln oder mehrere gleichzeitig?

4. **Dateigrößen-Limits:**
   - Maximum pro Datei? (z.B. 10MB)
   - Maximum gesamt pro Artikel? (z.B. 50MB)

**Schema-Optionen:**

**Option A: Erweiterung der Artikel Collection**
```javascript
// Einfacher, aber weniger flexibel
artikel: {
  // ... bestehende Felder
  dokumente: { type: 'file', multiple: true, max: 10 }
}
```

**Option B: Separate Attachments Collection**
```javascript
// Flexibler, mehr Metadaten möglich
attachments: {
  artikel: { type: 'relation', collection: 'artikel' },
  datei: { type: 'file' },
  bezeichnung: { type: 'text' },
  beschreibung: { type: 'text', optional: true },
  created: { type: 'date' }
}
```

**Nächste Schritte:**
1. Use Cases mit Endnutzern klären
2. Schema-Design entscheiden (Option A vs. B)
3. PocketBase Migration erstellen
4. UI/UX Design (Upload, Liste, Download)
5. Implementierung (Flutter)
6. Tests auf allen Plattformen

**Geschätzte Komplexität:** 🔴 Sehr Hoch (12-16 Stunden)

---

### M-013: Backup & Restore vollständig

**Status:** ⏳ Ausstehend - Erweiterung & Testing

**Aktueller Stand:**
- Grundlegendes Backup vorhanden (via PocketBase Admin UI)
- Dokumentation in README vorhanden

**Erforderliche Klärungen:**
1. **Backup-Umfang:**
   - ✅ Datenbank (`pb_data`)
   - ❓ Uploads (Artikelbilder, Dokumente in `pb_public`)?
   - ❓ Konfiguration (`.env`, Docker-Volumes)?

2. **Backup-Automatisierung:**
   - Manuell (wie aktuell)?
   - Oder automatisch (cron, Docker Health-Check)?
   - Wie oft? (täglich, wöchentlich?)
   - Wohin? (lokales Volume, S3, externe Festplatte?)

3. **Restore-Prozess:**
   - Wird aktuell nur Backup dokumentiert, aber nicht Restore?
   - Full Restore auf frischem System testen!

**Backup-Script-Beispiel:**
```bash
#!/bin/bash
# backup-pocketbase.sh

BACKUP_DIR="/pb_backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.zip"

# Stoppe PocketBase (oder nutze PocketBase Backup API)
docker compose stop pocketbase

# Erstelle Backup
cd server/
zip -r "$BACKUP_FILE" pb_data/ pb_public/

# Starte PocketBase
docker compose start pocketbase

echo "Backup erstellt: $BACKUP_FILE"
```

**Restore-Prozess:**
```bash
#!/bin/bash
# restore-pocketbase.sh

BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: ./restore-pocketbase.sh <backup.zip>"
  exit 1
fi

# Stoppe Services
docker compose down

# Sichere aktuellen Stand (falls Restore fehlschlägt)
mv server/pb_data server/pb_data.backup

# Restore
unzip "$BACKUP_FILE" -d server/

# Starte Services
docker compose up -d

echo "Restore abgeschlossen. Prüfe Logs mit: docker compose logs -f"
```

**Nächste Schritte:**
1. Backup-Umfang definieren (DB + Uploads?)
2. Automatisierungs-Script erstellen (optional)
3. Restore-Prozess dokumentieren und testen
4. **Restore-Test auf frischem System durchführen!**
5. Dokumentation erweitern (`docs/BACKUP_RESTORE.md`)

**Geschätzte Komplexität:** 🟡 Mittel (3-5 Stunden)

---

## 🟢 NIEDRIG (Nice-to-Have)

### N-001: Mocking-Libraries bereinigen

**Status:** ⏳ Ausstehend - Aufräumen

Beide Libraries sind in `pubspec.yaml`:
- `mockito: ^5.4.4`
- `mocktail: ^1.0.4`

**Klärung:**
- Werden beide aktuell genutzt?
- Wenn nein: Welche behalten? (Empfehlung: `mocktail` - einfacher)

**Nächste Schritte:**
1. Tests auf eine Library migrieren
2. Ungenutzte Library aus `pubspec.yaml` entfernen

**Geschätzte Komplexität:** 🟢 Niedrig (30 Min)

---

### N-002: dependency_overrides dokumentieren

**Status:** ⏳ Ausstehend - Dokumentation

In `pubspec.yaml`:
```yaml
dependency_overrides:
  intl: ^0.20.0
```

**Klärung:**
- Warum ist Override nötig?
- Gibt es ein GitHub-Issue?

**Nächste Schritte:**
1. Override-Grund recherchieren
2. Kommentar in `pubspec.yaml` hinzufügen
3. Bei `flutter pub upgrade` prüfen ob noch nötig

**Geschätzte Komplexität:** 🟢 Niedrig (15 Min)

---

### N-003: GitHub Secrets dokumentieren

**Status:** ⏳ Ausstehend - Dokumentation

**Zu dokumentieren:**
- `GH_PAT` (GitHub Personal Access Token)
  - Scopes: `repo`, `write:packages`
  - Verwendung: Docker Image Push zu ghcr.io

**Nächste Schritte:**
1. README-Sektion "GitHub Actions Setup" erstellen
2. PAT-Erstellung Schritt-für-Schritt dokumentieren
3. Secrets-Verwaltung dokumentieren

**Geschätzte Komplexität:** 🟢 Niedrig (30 Min)

---

### N-004: Roboto-Fontwechsel

**Status:** ⏳ Ausstehend - Design-Entscheidung

**Klärung:**
- Ist Roboto wirklich gewünscht?
- Oder aktuelle Default-Fonts beibehalten?

**Bei Umsetzung:**
1. Roboto Fonts in `assets/fonts/` ablegen
2. `pubspec.yaml` Fonts-Sektion aktualisieren
3. `ThemeData` mit `fontFamily: 'Roboto'` erweitern
4. Web-Build testen (Umlaute, Font-Loading)

**Geschätzte Komplexität:** 🟢 Niedrig (1 Stunde)

---

### N-005: PocketBase Admin Reset/Reinit-Prozedur

**Status:** ⏳ Ausstehend - Dokumentation & Sicherheit

**Klärung:**
- Wann ist Reset/Reinit nötig?
- Welche Daten sollen erhalten bleiben?

**Sicherer Reset-Prozess:**
```bash
# 1. Backup erstellen!
./backup-pocketbase.sh

# 2. Services stoppen
docker compose down

# 3. Daten löschen (GEFAHR!)
rm -rf server/pb_data/*

# 4. Neu starten (Auto-Init erstellt Admin neu)
docker compose up -d
```

**Nächste Schritte:**
1. Dokumentieren: Wann Reset, wann Reinit?
2. Sicherheits-Checkliste (Backup vor Reset!)
3. Script mit Bestätigung (`read -p "Wirklich löschen? [yes/NO]"`)

**Geschätzte Komplexität:** 🟢 Niedrig (1 Stunde)

---

## 📊 Zusammenfassung

### Prioritäten für manuelle Umsetzung

**Kurzfristig (< 1 Woche):**
1. H-005: Prod-Stack mit vorgebauten Images (🟡 Mittel)
2. M-006: Docker Stack Deploy dokumentieren (🟡 Mittel)
3. M-007: PocketBase Indizes prüfen (🟡 Mittel)
4. M-002: Debug-Prints entfernen (🟡 Mittel)

**Mittelfristig (1-2 Wochen):**
5. M-001: Testabdeckung erhöhen (🔴 Sehr Hoch)
6. M-013: Backup & Restore vollständig (🟡 Mittel)
7. M-011: Artikelbilder optimieren (🟡 Mittel)

**Langfristig (> 2 Wochen):**
8. H-001: Platform Builds in CI/CD (🔴 Hoch)
9. M-010: QR-Scanning plattformübergreifend (🔴 Hoch)
10. M-012: Dokumentenanhänge (🔴 Sehr Hoch)

**Optional (Nice-to-Have):**
11. N-001 bis N-005 (🟢 Niedrig)

---

**Hinweis:** Diese Datei wird bei jeder Umsetzung aktualisiert. Status-Updates werden hier dokumentiert.
