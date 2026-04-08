# 📜 Projekthistorie & Meilensteine

Dieses Dokument dient als Archiv für alle bisherigen Phasen, Analysen und Zusammenfassungen der **Lager_app**. Es bewahrt das Wissen aus den ursprünglichen Planungs- und Umsetzungsdokumenten.



### v0.7.7+5 — 2026-04-08 - P-002: Suche Debounce + DB-Suche**
- Timer(300ms) verhindert Suche bei jedem Tastendruck
- Mobile: SQL LIKE via `_db.searchArtikel()`
- Web: clientseitiger Filter über geladene PocketBase-Liste
- Skeleton während laufender Suche, Footer bei aktiver Suche versteckt
- Leer-Feld → sofortiger Reset zur paginierten Liste

**Test (O-006): Widget-Tests ArtikelErfassenScreen**
- 11 Tests: Render, Validierung, Abbrechen-Pfade
- `physicalSize 1080x2400` + `scrollUntilVisible()` für ListView-Scroll
- `pumpAndSettle(5s)` für async `_initArtikelnummer()`


### v0.7.7+4 — 2026-04-08 — M-005: Pagination für Artikelliste

**Problem:** Alle Artikel wurden beim Start auf einmal aus SQLite geladen.
Bei großen Beständen führte das zu spürbaren Verzögerungen und hohem
Speicherverbrauch.

**Lösung:**
- `ScrollController` mit `_onScroll()`-Listener — erkennt 200px vor
  Listenende und löst `_ladeNaechsteSeite()` aus
- `_ladeArtikel()`: setzt `_currentOffset = 0`, `_hasMore = true`,
  `_artikelListe = []` — sauberer Reset bei Pull-to-Refresh
- `_ladeNaechsteSeite()`: lädt offset-basiert nach, Guard verhindert
  Doppel-Requests und Nachladen bei aktiver Suche
- Lade-Footer am Listenende solange `_hasMore = true`
- Web bleibt unverändert: `getFullList()` + `_hasMore = false`
- 2 neue AppConfig-Tokens: `paginationPageSize = 30`,
  `paginationScrollThreshold = 200.0`

**Ergebnis:** Start lädt nur 30 Artikel — weitere Seiten werden
on-demand beim Scrollen nachgeladen.

**Geänderte Dateien:**
- `app/lib/config/app_config.dart` — 2 neue Pagination-Tokens
- `app/lib/screens/artikel_list_screen.dart` — ScrollController,
  Pagination-State, _ladeNaechsteSeite(), Lade-Footer

**Chore (O-005): Deprecated DokumenteButton entfernt**
- 5 Dateien gelöscht (Button, Stub, Utils, 2 Testdateien)
- `cached_network_image` bleibt — anderweitig aktiv genutzt
- `flutter analyze`: 0 Issues nach Cleanup

### v0.7.7+2 — 2026-04-07 — P-001: Kamera-Vorschau-Delay auf Android behoben

**Problem:** `pickImageCamera()` blockierte mehrere Sekunden auf Android, weil
der Crop-Dialog und der anschließende Re-Encode synchron im Capture-Flow liefen.
Zusätzlich waren die Zieldimensionen hardcodiert auf 1600px.

**Lösung:**
- Crop-Dialog aus dem Capture-Flow entfernt — `ensureTargetFormat(crop: false)`
  gibt Bytes sofort zurück
- `maxWidth = 800`, `maxHeight = 800`, `imageQuality = 85` werden direkt an
  `picker.pickImage()` übergeben → kleinere Rohdatei, weniger Re-Encode-Aufwand
- `openCropDialog()` als public static Methode — Screens können Crop on demand
  auslösen
- `ArtikelErfassenScreen`: optionaler „Zuschneiden"-Button erscheint nach Capture
  unterhalb der Vorschau

**Ergebnis:** Kamera → sofortige Vorschau auf Android, Crop bleibt optional.

**Geänderte Dateien:**
- `app/lib/config/app_config.dart` — 3 neue Kamera-Tokens
- `app/lib/services/image_picker_service.dart` — Crop entfernt, AppConfig genutzt
- `app/lib/screens/artikel_erfassen_screen.dart` — `_cropImage()` + Crop-Button

### v0.7.7+1 — 2026-04-06 — T-001 Widget-Tests abgeschlossen

**T-001: Tests für Konfliktlösung — Unit- und Widget-Tests vollständig (77 Tests)**

Alle automatisierbaren Tests für die Konfliktlösungs-Pipeline sind abgeschlossen.

- T-001.3: `SyncService.detectConflicts()` — 9 Tests mit `MockNextcloudClient` und
  `MockArtikelDbService` via Mockito
- T-001.4: `_determineConflictReason()` — 15 Tests für alle Zeitstempel-Szenarien
  (gleich, zeitnah <60s, lokal/remote neuer in Minuten/Stunden/Tagen)
- T-001.5: `ConflictResolutionScreen` Widget-Tests — 20 Tests mit `MockSyncService`
  (UI-Zustand, Navigation, Dialoge, Pop-Result)

**Technische Besonderheit:** Widget-Tests laufen mit `setSurfaceSize(1024×900)`.
Der Standard-Viewport (800×600) ist zu klein für die Side-by-Side-Versionskarten
nach Auswahl (`isSelected=true` fügt `Icons.check_circle` hinzu → +4px Overflow).
`addTearDown` stellt den Default-Viewport nach jedem Test wieder her.

**Ausstehend (manuell):** T-001.6–T-001.12 (erfordern zwei verbundene Geräte).

**Gesamtstand Tests:** 298 Tests, alle grün.

### v0.7.7 — 2026-04-05 — Release: Qualitäts-Release mit Tests & Dokumentation

Dieses Release fasst die v0.7.6+x-Zwischenstände zusammen und bringt die Version auf 0.7.7.

**M-003: Zentrales Error Handling (v0.7.6+3)**
- `AppException`-Hierarchie (`sealed class`): `NetworkException`, `ServerException`, `AuthException`,
  `SyncException`, `StorageException`, `ValidationException`, `UnknownException`
- `AppErrorHandler` mit `classify()`, `log()`, `showSnackBar()`, `showErrorDialog()`
- `sync_conflict_handler.dart` auf `AppErrorHandler` umgestellt
- `SocketException`, `HandshakeException`, `TimeoutException`, `ClientException` automatisch klassifiziert

**M-004: Loading States (v0.7.6+2)**
- `AppLoadingOverlay`, `AppLoadingIndicator`, `AppLoadingButton`
- `ArtikelSkeletonTile` + `ArtikelSkeletonList` mit Shimmer-Animation
- 10 neue `AppConfig`-Tokens für Skeleton und Overlay

**M-006: Input Validation (v0.7.6+1)**
- Pflichtfeld-Validierung mit Inline-Fehlermeldungen
- Duplikat-Check für Name+Ort+Fach und Artikelnummer (lokal + PocketBase)
- Neue DB-Methoden: `existsKombination()`, `existsArtikelnummer()`

**O-002: Unit-Tests für Core-Utilities (v0.7.6+4)**
- 75 Tests für `ArtikelDbService` (In-Memory-SQLite via `sqflite_common_ffi`)
- 64 Tests für `ArtikelModel` (Konstruktor, `toMap`/`fromMap`, Roundtrip, `copyWith`)
- 30 Tests für `ImageProcessingUtils` (Kompression, Rotation, Thumbnail)
- 23 Tests für `UuidGenerator` (RFC-4122-V4-Format, Eindeutigkeit)
- Produktionsbug gefunden und gefixt: `getUnsyncedArtikel()` SQL-Leerstring-Bug

**Dokumentation:**
- `docs/TESTING.md` neu erstellt — beschreibt alle 258 Tests und lokalen Aufruf
- `CHANGELOG.md`, `OPTIMIZATIONS.md`, `HISTORY.md`, `README.md` aktualisiert

### v0.7.5+1 — 2026-04-03 — M-008 abgeschlossen: Backup-Status im Settings-Screen anzeigen

Neues Feature: Backup-Status wird im Settings-Screen als Card angezeigt.

Änderungen:
- BackupStatusService: Liest last_backup.json via HTTP vom PocketBase-Server
- BackupStatusWidget: Farbcodierte Status-Card (Grün <24h, Gelb 1-3d, Rot >3d)
  - Loading/Error/Unknown-States
  - Detail-Zeilen: Zeitpunkt, Datei, Größe, Backup-Anzahl, Rotation
  - Fehler-Details bei fehlgeschlagenem Backup
  - Refresh-Button zum manuellen Aktualisieren
- settings_screen.dart: BackupStatusWidget zwischen PocketBase- und Artikelnummer-Card
- backup.sh: write_status() kopiert last_backup.json nach pb_public für HTTP-Zugriff
- docker-compose.prod.yml: pb_public Volume für Backup-Container ergänzt
- M-008 als erledigt markiert (18/28 Aufgaben abgeschlossen)

### v0.7.5+0 — 2026-04-02 — M-007 abgeschlossen: UI für Konfliktlösung

**Kontext:** Prüfung des M-007-Status ergab, dass die Implementierung bereits
vollständig vorhanden war. Die Datei `conflict_resolution_screen.dart` enthielt
`ConflictData`, `ConflictResolution`-Enum, den `ConflictResolutionScreen` mit
Side-by-Side-Vergleich, Multi-Konflikt-Navigation und einen vollständigen
`_MergeDialog` für manuelle Zusammenführung.

**Durchgeführte Arbeiten:**
- OPTIMIZATIONS.md bereinigt: Doppelung M-007 (alt) → K-003 umbenannt
- M-007 als erledigt markiert und nach ✅ Abgeschlossen verschoben
- 37 Unit-Tests erstellt (`conflict_resolution_test.dart`)
- Neue Aufgabe T-001 für ausstehende manuelle Integrationstests erstellt

**Entscheidungen:**
- Widget-Tests für `ConflictResolutionScreen` wurden zurückgestellt, da
  `SyncService` nicht ohne echte `NextcloudClient`/`ArtikelDbService`-Abhängigkeiten
  instanziierbar ist. Stattdessen manuelle Integrationstests (T-001.6–T-001.12).
- `ConflictData` hat keine `differences`/`diffCount`-Getter — der Feld-Vergleich
  erfolgt direkt über die Artikel-Properties in `_buildVersionCard()`. Die Tests
  bilden diese Logik nach.

**Kumulierter Projektfortschritt:**
- 17 von 28 Aufgaben erledigt (61%)
- 0 offene Aufgaben mit hoher Priorität
- Phase 4 (Multi-Plattform & Politur) bei ~45%

---

### v0.7.4+4 — 2026-04-01 — O-004 Batch 2: Sync-Cluster migriert

**Kontext:** Fortsetzung der systematischen Migration hardcodierter UI-Werte
zum Design-System. Batch 2 fokussiert auf alle Sync-bezogenen Dateien.

**Umfang:**
- 193 Hardcodes in 4 Dateien eliminiert (Farben, Spacing, Radien, Font-Sizes)
- `app_theme.dart` — Component-Themes nutzen jetzt AppConfig-Tokens
- `conflict_resolution_screen.dart` — Größte Einzeldatei (82 Hardcodes)
- `sync_error_widgets.dart` — Severity-Farben über colorScheme
- `sync_management_screen.dart` — AppBar und Buttons standardisiert

**Entscheidungen:**
- `Colors.purple` (Merge-Aktion) → `colorScheme.tertiary` — Material 3 Seed
  generiert passende Tertiärfarbe, die sich harmonisch einfügt
- `Colors.orange` (Warnung/Conflict) → `colorScheme.secondary` — semantisch
  korrekt für Warn-Zustände im Material 3 System
- AppBar-Farben entfernt — Standard-Theme aus `app_theme.dart` greift jetzt
  konsistent (war vorher pro Screen manuell überschrieben)
- `_getSeverityColor()` in `sync_error_widgets.dart` nimmt jetzt `BuildContext`
  als Parameter — ermöglicht Theme-Zugriff in StatelessWidget

**Kumulierter O-004-Fortschritt:**
- Batch 1: 109 Hardcodes (sync_progress_widgets, settings_screen)
- Batch 2: 193 Hardcodes (app_theme, conflict_resolution, sync_error, sync_management)
- **Gesamt: 302 von ~591 Hardcodes eliminiert (~51%)**

## [0.7.4+3] - 2026-04-01

### Refactoring (O-004): UI-Hardcoded Werte migrieren — Batch 1
- **109 Hardcodes eliminiert** in 2 Fokus-Dateien + AppConfig erweitert
- Dark Mode funktioniert jetzt korrekt in allen migrierten Widgets
- Kein visuelles Redesign — gleiche Optik, sauberer Code

#### AppConfig (`app/lib/config/app_config.dart`)
- 13 neue Design-Tokens ergänzt:
  - **Icon-Sizes:** `iconSizeXSmall` (14), `iconSizeSmall` (16),
    `iconSizeMedium` (20), `iconSizeLarge` (24)
  - **Stroke:** `strokeWidthThin` (1), `strokeWidthMedium` (2),
    `strokeWidthThick` (3)
  - **Layout:** `infoLabelWidth` (120), `avatarRadiusSmall` (20),
    `dialogContentWidth` (300), `progressIndicatorSize` (32)
  - **Opacity:** `opacitySubtle` (0.1), `opacityLight` (0.2),
    `opacityMedium` (0.3)

#### sync_progress_widgets.dart
- 55 Hardcodes → 0 verbleibend
- `Colors.red/green/blue/orange` → `colorScheme.error/tertiary/primary/secondary`
- `Colors.grey[300/600]` → `colorScheme.surfaceContainerHighest/onSurfaceVariant`
- `Colors.white` → `colorScheme.onPrimary`
- Alle `EdgeInsets`/`SizedBox`/`BorderRadius` → AppConfig-Tokens
- `_getStatusColor()` und `_buildStatChip()` nutzen jetzt `BuildContext`

#### settings_screen.dart
- 54 Hardcodes → 0 verbleibend
- `Colors.green.shade*` → `colorScheme.tertiary/tertiaryContainer`
- `Colors.red.shade*` → `colorScheme.error/errorContainer`
- `Colors.orange.shade*` → `colorScheme.secondary/secondaryContainer`
- `Colors.blue.shade*` → `colorScheme.primary/primaryContainer`
- 6 duplizierte Status-Container → wiederverwendbare `_buildStatusContainer()`
  Methode mit `_StatusType` Enum (DRY-Refactoring)
- SnackBar-Farben → `_showConnectionSnackBar()` Helper extrahiert

### Dokumentation
- `THEMING.md` — Vollständige Token-Referenz mit Tabellen, Farb-Zuordnungstabelle
  für O-004, Dark-Mode-Hinweise für Entwickler
- `OPTIMIZATIONS.md` — O-004 Batch 1 als erledigt markiert, Batch 2–5 Roadmap
  mit Hardcode-Counts, H-002 und M-009 in Abgeschlossen verschoben
- `CHANGELOG.md` — Aktualisiert

---


## 🔒 CORS-Konfiguration & Infrastruktur-Bereinigung — v0.7.4 — 30.03.2026

### H-002: CORS-Konfiguration

**Problem:** Die Umgebungsvariable `CORS_ALLOWED_ORIGINS` war in den Docker-Compose-Dateien
definiert, wurde aber nie an PocketBase übergeben. PocketBase startete ohne `--origins` Flag,
was bedeutet: alle Origins erlaubt (unsicher für Produktion).

**Lösung:** Neues `entrypoint.sh` Script, das `CORS_ALLOWED_ORIGINS` liest und als
`--origins` Flag an PocketBase übergibt.

| Modus | Verhalten |
|---|---|
| Entwicklung (`*`) | PocketBase startet ohne `--origins` (alles erlaubt) |
| Produktion (Domain) | PocketBase startet mit `--origins="https://lager.example.com"` |

**Architektur-Entscheidungen:**
- CORS nur auf PocketBase-Ebene (nicht doppelt in Nginx Proxy Manager)
- Zwei Subdomains: `lager.domain.de` (Frontend) + `api.domain.de` (API)
- Domain-Umzug: Nur `.env.production` + DNS + NPM ändern, kein Rebuild nötig
- Mobile/Desktop Apps nicht betroffen (kein Origin-Header im Browser)

### Infrastruktur-Bereinigung

- `docker-compose.production.yml` (Traefik) **entfernt** — Nginx Proxy Manager ist Standard
- Portainer Stack an Produktions-Setup angeglichen (NPM, `expose` statt `ports`, CORS erzwungen)
- `.env.production` korrigiert: öffentliche URL statt Docker-interner URL

**Geänderte Dateien:**

| Datei | Änderung |
|---|---|
| `server/entrypoint.sh` | NEU — CORS-aware Entrypoint |
| `server/Dockerfile` | MOD — CMD durch entrypoint.sh, CORS ENV |
| `docker-compose.yml` | MOD — command-Block entfernt |
| `docker-compose.production.yml` | GELÖSCHT |
| `.env.production` | MOD — POCKETBASE_URL + CORS korrigiert |
| `docs/DEPLOYMENT.md` | MOD — CORS-Abschnitt + Portainer Stack |
| `docs/ARCHITECTURE.md` | MOD — Diagramm + Projektstruktur aktualisiert |
| `docs/OPTIMIZATIONS.md` | MOD — H-002 als erledigt |

---

## 📎 Dateianhänge & Artikelnummer-Fix — v0.7.2 — 29.03.2026

### M-012: Attachments (Dateianhänge pro Artikel)

**Feature:** Benutzer können Dokumente (PDF, Office, Bilder, Text) an Artikel anhängen.
Max 20 Anhänge pro Artikel, max 10 MB pro Datei.

**Implementierung:**
- PocketBase Collection `attachments` mit File-Upload und Metadaten
- `AttachmentService` (Singleton) — CRUD gegen PocketBase, plattformunabhängig
- `AttachmentModel` — Datenklasse mit MIME-Type-Erkennung und Größenformatierung
- `AttachmentUploadWidget` — Upload-Dialog mit Dateiauswahl und Validierung
- `AttachmentListWidget` — Anhang-Liste mit Download, Bearbeiten, Löschen
- `AnhaengeSektion` im Detail-Screen mit Badge-Counter und BottomSheet

**Problem bei Inbetriebnahme:** Upload schlug mit HTTP 400 fehl.
Zwei Ursachen identifiziert und behoben:
1. `uuid`-Pflichtfeld fehlte im Upload-Body → `UuidGenerator.generate()` ergänzt
2. API-Regeln erforderten Auth (`@request.auth.id != ''`), aber die App hat keinen Login-Flow → Regeln auf offen gesetzt (analog zu `artikel`-Collection)

**Migration:** `1774811640_updated_attachments.js` setzt API-Regeln auf offen.

### Artikelnummer-Anzeige korrigiert

**Problem:** Die Detailansicht zeigte `artikel.id` (SQLite Auto-Increment) statt `artikel.artikelnummer` (fachliche Nummer ab 1000).

**Fix:** `artikel_detail_screen.dart` — `artikel.id` → `artikel.artikelnummer`.
Zusätzlich: Artikelnummer in der Listenansicht ergänzt.

### toPocketBaseMap() erweitert

**Problem:** `updated_at` wurde nicht an PocketBase gesendet, was zu Sync-Inkonsistenzen führen konnte.

**Fix:** `updated_at: updatedAt` in `toPocketBaseMap()` ergänzt.

**Architektur-Entscheidung:** API-Regeln bleiben offen bis ein Login-Flow implementiert wird (M-009). Die App läuft aktuell im LAN/VPN — öffentlicher Zugang erfordert Auth.

---

## 🖥️ WSL2-Entwicklungsumgebung — Bildanzeige-Problem gelöst — 28.03.2026

### K-005: Bilder werden in WSL2-Entwicklung nicht angezeigt

**Problem:** Bei der Entwicklung unter WSL2 wurden Bilder (`Image.memory`) nicht angezeigt.
Der Bereich blieb leer, ohne Fehlermeldung. In der Browser-Konsole erschien:
```
WARNING: Falling back to CPU-only rendering. Reason: webGLVersion is -1
```

**Ursache:** WSL2 bietet keine GPU-Beschleunigung. Chrome in WSL2 hat kein WebGL.
Flutter 3.41+ unterstützt nur noch CanvasKit/Skwasm als Renderer (HTML-Renderer entfernt).
CanvasKit ohne WebGL fällt auf CPU-only Rendering zurück, wobei `Image.memory` nicht korrekt gerendert wird.

**Fehlversuche:**
- `--web-renderer html` → Flag existiert in Flutter 3.41 nicht mehr
- `index.html` mit `renderer: "html"` → Build nicht kompatibel, App startet nicht
- Anderer Browser → Problem ist WSL2, nicht der Browser

**Lösung:** Web-Server-Modus statt `flutter run -d chrome`:
```bash
flutter run -d web-server --web-port 8888 --web-hostname 0.0.0.0
```
Dann im **Windows-Browser** (mit echtem WebGL) öffnen: `http://localhost:8888`

**Betroffene Umgebung:** Nur WSL2-Entwicklung. Produktion (Docker/normaler Server) ist nicht betroffen.

**Dokumentation:** Neues `DEV_SETUP.md` erstellt mit vollständigem Entwicklungs-Workflow.

**Geänderte Dateien:**
- `INSTALL.md` — PocketBase-Start korrigiert (Docker statt Binary), WSL2-Hinweis ergänzt
- `DEV_SETUP.md` — **Neu:** Vollständige Entwicklungsumgebung-Dokumentation

**Erkenntnis:** PocketBase wird im Projekt ausschließlich über Docker betrieben.
Der in der alten Doku beschriebene Weg `cd server && ./pocketbase serve` ist veraltet
und funktioniert nicht, da kein PocketBase-Binary im Repository liegt.

---

## 🔧 Runtime-Konfiguration der PocketBase-URL — 27.03.2026

### K-004: Server-URL zur Laufzeit konfigurierbar

**Problem:** Die PocketBase-URL wurde ausschließlich zur Build-Zeit per `--dart-define=POCKETBASE_URL=...` gesetzt. Das führte zu mehreren Problemen:
- App crashte beim Start wenn die URL fehlte oder ungültig war
- URL-Änderung erforderte einen neuen Build
- Placeholder-URLs (`your-production-server.com`) in Fallbacks verursachten Fehler in Release-Builds
- `localhost` funktionierte auf Android nicht (zeigt auf das Gerät selbst)

**Lösung:** Dreistufige URL-Prioritätskette mit Setup-Screen als Fallback:

| Priorität | Quelle | Beschreibung |
|---|---|---|
| 1 (höchste) | SharedPreferences / localStorage | Vom Benutzer gespeicherte URL |
| 2 | Runtime-Config (Web) / `--dart-define` | Build-Default oder Container-Config |
| 3 (niedrigste) | Setup-Screen | Benutzer gibt URL manuell ein |

**Geänderte Dateien:**
- `app/lib/config/app_config.dart` — Placeholder-Fallbacks entfernt, Validierung entschärft
- `app/lib/services/pocketbase_service.dart` — `needsSetup`/`hasClient`-Flags, robuste `initialize()`
- `app/lib/main.dart` — Setup-Screen-Weiche nach Initialisierung
- `app/lib/screens/settings_screen.dart` — `_resetPocketBaseUrl()` für leeren Default angepasst
- `.github/workflows/docker-build-push.yml` — Placeholder entfernt, URL optional
- `.github/workflows/release.yml` — Optionaler `pocketbase_url`-Input für Demo-Builds

**Neue Dateien:**
- `app/lib/screens/server_setup_screen.dart` — Ersteinrichtungs-Screen

**Architektur-Entscheidung:** Singleton statt Provider für den `PocketBaseService`, weil die URL-Konfiguration **vor** `runApp()` geladen werden muss (bevor ein Widget-Tree existiert). Der bestehende `PocketBaseService` wurde erweitert statt einen neuen Service einzuführen.

**Ergebnis:**
- App startet immer, auch komplett ohne URL-Konfiguration
- Bestehende Installationen mit gespeicherter URL funktionieren ohne Änderung
- `--dart-define` ist optional, kann aber weiterhin für Demo-/Kunden-Builds genutzt werden
- Web-Runtime-Config über `window.ENV_CONFIG` funktioniert unverändert

---

## 📋 Dokumente zum Artikel  - 25.03.2026
### 🗄️ Datenbank (Lokal & Server)
- Neue Tabelle `artikel_dokumente` in der lokalen SQLite-Datenbank mit Feldern für:
 - `id, artikel_uuid` (Fremdschlüssel zum Artikel), `uuid, remote_path`
 - `dateiname, dateityp, dateipfad` (lokal), `remoteDokumentPfad`
 - `beschreibung, erstelltAm, updated_at, deleted, etag`
- PocketBase Collection `artikel_dokumente` als serverseitiges Gegenstück mit File-Field für den Upload
### 📱 Flutter App
- `DokumentModel`: Dart-Klasse für ein einzelnes Dokument
- `DokumentRepository`: CRUD-Operationen gegen die lokale SQLite
- `DokumentSyncService`: Push/Pull-Logik analog zur Bild-Synchronisation
- UI – Dokumente-Tab im Artikel-Detail:
 - Liste aller Dokumente zum Artikel
 - Upload-Button (Dateiauswahl via `file_picker`)
 - Download & Öffnen via `open_file`
 - Löschen mit Soft-Delete
### 🔄 Synchronisation
- Dokumente werden getrennt von Textdaten und Bildern synchronisiert
- Gleiche ETag/UUID-Strategie wie bei Artikeln
- Hard-Delete auf dem Server wenn lokal `deleted = 1`

## 📅 März 2026: Die "Kritische Phase" (Härtung & Optimierung)

In diesem Monat wurde die App von einem Prototyp zu einem produktionsreifen System transformiert. Die Schwerpunkte lagen auf Sicherheit, automatisierter Bereitstellung und Performance.

### Meilensteine Phase 3 & 4
*   **Datenbank-Tuning**: Einführung von 5 strategischen Indizes in PocketBase zur Beschleunigung der Suche bei >10.000 Artikeln.
*   **Artikelnummer-System**: Implementierung einer eindeutigen, für Menschen lesbaren Artikelnummer (Startwert 1000).
*   **Security Hardening**: 
    *   Umstellung auf `expose` statt `ports` in Docker für interne Netzwerk-Isolierung.
    *   Konfiguration von Caddy mit strikten Security-Headern (CSP, HSTS).
    *   Automatisierte PocketBase-Initialisierung (Admin-User & Rules via ENV).
*   **CI/CD**: Erstellung von stabilen GitHub Actions Workflows für plattformübergreifende Releases (Android, Windows, Docker).

---

## 🔍 Zusammenfassung der technischen Analysen (Archiv)

### Analyse der README & Struktur (März 2026)
*   **Problem**: Die Dokumentation war stark fragmentiert und enthielt viele Redundanzen zwischen Root-Verzeichnis und `docs/`.
*   **Lösung**: Modularisierung der Dokumentation in `README.md` (Übersicht), `INSTALL.md` (Setup) und spezialisierte `docs/*.md`.
*   **Ergebnis**: Eine saubere "Single Source of Truth"-Struktur.

### Synchronisations-Architektur (Phase 2 Review)
*   **Konzept**: Offline-First mit Delta-Synchronisation.
*   **Implementierung**: Nutzung von `updated_at` (Unix-Timestamp) und `deleted` (Soft-Delete) zur Minimierung des Datenverkehrs.
*   **Erkenntnis**: Das "Last-Write-Wins"-Verfahren ist für Einzelnutzer ideal, benötigt aber einen Konflikt-Screen für Multi-User-Szenarien.

---

## 🚀 Pull Request Historie (Zusammenfassung)

### PR #33: Dokumentations-Konsolidierung
*   Finalisierung der modularen Dokumentationsstruktur.
*   Verschlankung der `README.md` auf < 200 Zeilen.
*   Archivierung historischer Zusammenfassungen in diese Datei (`HISTORY.md`).

### PR #32: Zentralisierte Konfiguration
*   Einführung von `AppConfig`, `AppTheme` und `AppImages`.
*   Eliminierung von ca. 200+ hartcodierten Werten (Farben, Abstände, Radien).
*   Vollständiger Dark-Mode Support via Material 3.

### PR #30 & #31: Docker & Backup
*   Korrektur des Docker-Build-Contexts auf Repository-Root (erforderlich für geteilte `packages/`).
*   Dokumentation von 3 Backup-Methoden (Admin-UI, tar-Archive, Cron-Jobs).

### PR #29: Datenbank-Indizes & Logging
*   Implementierung des `AppLogService` zur Ablösung von `debugPrint`.
*   Hinzufügen von Indizes für `artikelnummer`, `name` und `uuid`.

---

## 📝 Historische Architektur-Entscheidungen

1.  **Caddy statt Nginx (Container)**: Caddy wurde gewählt, da es HTTPS/HSTS und SPA-Routing mit minimaler Konfiguration (4 Zeilen) ermöglicht.
2.  **Docker-Context auf Root**: Um lokale Pakete (Monorepo-Stil) im Docker-Build nutzen zu können, wurde der Kontext auf die oberste Ebene gehoben.
3.  **Soft-Delete**: Datensätze werden nie physikalisch gelöscht, um Clients über Löschvorgänge während des nächsten Sync-Vorgangs informieren zu können.
4.  **Singleton statt Provider für PocketBaseService**: Die URL-Konfiguration wird vor `runApp()` benötigt, bevor ein Widget-Tree existiert. Ein Provider kann erst innerhalb von `MaterialApp` konsumiert werden – das ist zu spät für die Startup-Entscheidung (Setup-Screen vs. normale App).

---

*Dieses Dokument wird bei Abschluss größerer Meilensteine aktualisiert, um den Projektverlauf nachvollziehbar zu halten.*