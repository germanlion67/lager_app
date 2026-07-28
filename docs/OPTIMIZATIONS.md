# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Arbeitsübersicht über **aktuellen Projektstatus**, **offene Aufgaben**, **Prioritäten** und **technische Optimierungen** der **Lager_app**.

**Version:** 1.1.0+97 | **Zuletzt aktualisiert:** 28.07.2026

> **Hinweis:**  
> Diese `OPTIMIZATIONS.md` ist das **laufende Arbeitsdokument** für Status, Prioritäten und Roadmap.  
> Wenn eine Maßnahme **abgeschlossen, historisch relevant und versioniert** ist, wird sie in `HISTORY.md` überführt.  
> Dadurch bleiben Status-Dokument und Historie sauber getrennt und vermeiden unnötige Dopplungen.

> **Technische Referenz für Sync-Details:**  
> Für Push/Pull, Konflikterkennung, Bild-Sync, Invarianten, Edge Cases und Änderungsverbote gilt primär **`docs/SYNC.md`**.

---

## 🏷️ Kürzel-Register

### Legende
- `B` = Bug / Befund / Verifikation / Analyse
- `F` = Feature / sichtbare Funktion / UX
- `H` = Hosting / Hardening / Infrastruktur / Deployment
- `K` = Kern / Grundlagen / Architektur-Meilenstein
- `M` = Maßnahme / größeres Feature / funktionale Erweiterung
- `N` = Nichtfunktionales / Branding / visuelle Ergänzung
- `O` = Optimierung / Refactoring / Codequalität
- `P` = Performance / Plattform / Laufzeitverbesserung
- `T` = Tests / Testinfrastruktur / Testausbau

### Nächste freie Kürzel
- `B-020`, `F-013`, `H-006`, `K-008`, `M-015`, `N-007`, `O-022`, `P-010`, `T-013`

### Vergaberegel
Ein Kürzel gilt **ab dem ersten dokumentierten Auftreten als dauerhaft reserviert** —  
auch dann, wenn der Punkt später verschoben, umbenannt oder nach `Future` verschoben wird.

Commit-Meldungen  `fix:`- Bugfix,  `feat:`-Neues Future, `docs`- Dokumentation, `style`- Formatierung, `refactor`- Code-Umbau, Future/Fix, `test`- Test hinzugefügt, `chore`- Build, Config, Dependencies
---

##  Priorität: Mittel

---

## 🟢 Priorität: Nice-to-Have

### O-021: State Management modernisieren

**Beschreibung:**
Die App nutzt aktuell `provider` (ChangeNotifier-Pattern) als State-Management-Lösung.
`provider` ist funktional, aber für eine wachsende App mit Sync-Logik, mehreren Services
und reaktiven UI-Zuständen an seine Grenzen gestoßen: Globale `ChangeNotifier`-Ketten,
`ValueNotifier`-Weitergaben über mehrere Widget-Ebenen und manuelle `notifyListeners()`-Aufrufe
erhöhen die Kopplung und erschweren Testbarkeit.

**Ist-Zustand:**
- `provider` genutzt in 8 Dateien (verifiziert per grep, O-015)
- `ValueNotifier<bool>` für `showLastSyncNotifier` — wird über mehrere Widget-Ebenen weitergegeben
- `SettingsController` als `ChangeNotifier` — bereits testbar, aber manuelles `notifyListeners()`
- `SyncOrchestrator`-Zustände werden über Callbacks und direkte Service-Aufrufe propagiert
- Kein einheitliches reaktives Pattern — Mix aus `provider`, `ValueNotifier` und `setState()`

**Ziel:**
Migration zu **Riverpod** (empfohlen) als direktem, typsicherem `provider`-Nachfolger:
- `StateNotifierProvider` ersetzt `ChangeNotifier` → kein manuelles `notifyListeners()` mehr
- `AsyncNotifierProvider` für Sync-Zustände → Loading/Error/Data automatisch abgebildet
- `ref.watch()` / `ref.read()` statt `context.watch()` / `context.read()`
- Providers sind von Widget-Tree unabhängig → deutlich einfacher testbar (kein `MultiProvider`-Wrapper in Tests nötig)

**Nutzen:**
| Bereich | Heute | Mit Riverpod |
|:--|:--|:--|
| Testbarkeit | `ChangeNotifier` braucht Widget-Tree-Wrapper | Provider direkt instanziierbar, kein Flutter-Test-Widget nötig |
| Sync-State | Callbacks + manuelles setState | `AsyncNotifierProvider` mit Loading/Error/Data |
| `showLastSyncNotifier` | `ValueNotifier` über 3 Ebenen weitergegeben | `Provider<bool>` direkt konsumierbar |
| Compile-Sicherheit | `context.read<T>()` erst zur Laufzeit geprüft | Typen zur Compilezeit geprüft |
| Boilerplate | `notifyListeners()` an vielen Stellen | Immutable State, ein `state = ...`-Aufruf |

**Migrationsreihenfolge:**
1. ✅ `showLastSyncNotifier` → `StateProvider<bool>` — abgeschlossen `1.1.0+97` (2026-07-28)
   - `flutter_riverpod ^2.6.1` ergänzt, `ProviderScope` in `main.dart`
   - `showLastSyncProvider` in `settings_state.dart`
   - `SettingsController`: `onShowLastSyncChanged`-Callback als Bridge
   - `SettingsScreen`: `ConsumerStatefulWidget`, setzt Provider via Callback
   - `ArtikelListScreen`: `ValueListenableBuilder` → `Consumer` (`ref.watch`)
   - Tests: `ProviderScope` in `artikel_list_screen_test` ergänzt
2. ⬜ `SyncProgressService extends ChangeNotifier` → Riverpod (komplexer, als Konstruktorparameter übergeben)
3. ⬜ `_rebuildNotifier ValueNotifier<int>` in `artikel_detail_screen.dart` (lokal, niedrige Priorität)
4. ⬜ `SettingsController` selbst als `ChangeNotifierProvider.autoDispose` (optional)

**Abhängigkeiten:** Keine Blocker. Migration schrittweise möglich.

**Aufwand:** ~8–12 Stunden (schrittweise Migration) | **Risiko:** Mittel

--- 

### O-015: Dependency-Hygiene
**Beschreibung:**
`flutter_local_notifications: ^21.0.0` und `provider: ^6.0.3` werden nirgends
im Code importiert (0 Treffer bei grep). Beide Dependencies wurden entfernt.

Weitere Kandidaten (`webdav_client`) werden mit O-014 adressiert.

**Verifiziert per grep:**
- `flutter_local_notifications` → 0 Treffer in `app/lib/` ✅
- `google_fonts` → genutzt in `app_theme.dart` → behalten ✅
- `provider` → **Nachbefund 2026-07-28: 0 Treffer** — `package:provider` wird nirgends
  importiert. `ChangeNotifier` wird direkt aus `flutter/foundation.dart` genutzt,
  nicht über das `provider`-DI-Package. Entfernt. ✅

**Tasks:**
- [x] `flutter_local_notifications` aus pubspec.yaml entfernen ✅
- [x] `provider` aus pubspec.yaml entfernen ✅ (Nachbefund: ebenfalls ungenutzt)
- [x] `flutter pub get` + `flutter test` grün ✅ (1016 Tests bestanden)

**Aufwand:** 10 Minuten | **Risiko:** Sehr niedrig

--- 

### F-010: Nutzerfreundliche Aktivitäts-Logs (UserLogService)
**Beschreibung:**  
Neben den bestehenden technischen Entwickler-Logs (AppLogService) soll eine zweite, menschenlesbare Log-Ebene eingeführt werden. Diese zeigt dem Nutzer verständliche Aktivitätsmeldungen wie „Artikel ‚LED Strip 5m' erstellt und synchronisiert", „Synchronisation abgeschlossen — 3 aktualisiert" oder „Verbindung zum Server verloren" statt technischer Debug-Ausgaben mit UUIDs und ETags.

**Abgrenzung zu O-012:**  
O-012 (Entwickler-Summary-Logs) bleibt unverändert bestehen. F-010 ist eine eigenständige, nutzerseitige Funktion.

**Design-Entscheidungen**
- Eigener `UserLogService` mit eigenem Datenmodell (`UserLogEntry`), getrennt von `AppLogService`
- Viewer als eigener Dialog, erreichbar über den Settings-Screen
- Umschaltung zwischen Entwickler-Log und Nutzer-Log per Einstellung im Settings-Screen
- Sprache: Deutsch, aber lokalisierbar vorbereitet (Nachrichtentexte über Hilfsmethoden oder einfache l10n-Abstraktion, kein volles ARB/intl erforderlich)
- Keine Feldänderungs-Diffs — geloggt wird auf Artikelebene (erstellt / geändert / gelöscht / synchronisiert), nicht auf Feldebene
- Persistenz über App-Neustart hinweg (SQLite-Tabelle `user_log`)
- Automatisches Löschen von Einträgen älter als X Tage (konfigurierbar, Default z. B. 14 Tage), Cleanup beim App-Start oder vor dem Anzeigen

**Geplante Nutzer-Log-Quellen**
- `PocketBaseSyncService` — Push-Ergebnisse (CREATE/UPDATE/DELETE ok/fail), Pull-Zusammenfassung, Verbindungsfehler
- `SyncOrchestrator` — Sync gestartet / abgeschlossen / fehlgeschlagen
- `main.dart` — Login / Logout

**Tasks**
- [ ] `UserLogEntry`-Modell mit `timestamp`, `level`, `message`
- [ ] `UserLogService` mit SQLite-Persistenz (`user_log`-Tabelle)
- [ ] Auto-Cleanup: Einträge älter als X Tage beim Start löschen
- [ ] DB-Migration für `user_log`-Tabelle
- [ ] Nutzer-Log-Aufrufe in `PocketBaseSyncService` (neben bestehenden technischen Logs)
- [ ] Nutzer-Log-Aufrufe in `SyncOrchestrator`
- [ ] Nutzer-Log-Aufrufe in `main.dart` (Auth-Events)
- [ ] Viewer-Dialog (`UserLogDialog`) mit Level-Filter und Löschen-Button
- [ ] Settings-Screen: Umschaltung Entwickler-Log / Nutzer-Log
- [ ] Lokalisierbare Nachrichtentexte vorbereiten
- [ ] Unit-Tests für `UserLogService` (CRUD, Cleanup, Kapazitätsgrenze)
- [ ] Widget-Test für Viewer-Dialog
- [ ] `docs/LOGGER.md` um Nutzer-Log-Konzept ergänzen

**Aufwandsschätzung:** ~5–6 Stunden

**Abhängigkeiten:**  
Keine Blocker. Greift nicht in bestehende Sync-Logik ein — nur additive Log-Aufrufe neben den bestehenden technischen Logs.

--- 

## ⏭️ Future (nicht in Planung)

### H-001: iOS/macOS Vorbereitung
Erfordert Apple Developer Account. Zurückgestellt bis Account verfügbar.

### N-006: Nextcloud-Workflow
WebDAV-Anbindung finalisieren und mit Nextcloud 28+ testen.

---

### O-018: Hardcoded deutsche UI-Strings (Lokalisierungsvorbereitung)
**Beschreibung:**
20+ Stellen in Screens enthalten hardcoded deutsche Strings, vor allem
Fehlermeldungen in SnackBars. Aktuell kein funktionales Problem, aber
Hindernis für spätere Lokalisierung.

**Betroffene Screens:**
- `artikel_erfassen_screen.dart`
- `artikel_detail_screen.dart`
- `list_screen_mobile_actions.dart`
- `list_screen_web_actions.dart`
- `settings_screen.dart`

**Empfehlung:** Erst umsetzen wenn Mehrsprachigkeit tatsächlich geplant wird.
Bis dahin als dokumentierte technische Schuld belassen.

**Aufwand:** ~4–6 Stunden | **Risiko:** Niedrig | **Priorität:** Future

--- 

## 📊 Fortschritts-Übersicht

Die Priorisierung in diesem Dokument ist maßgeblich, die Zählwerte sind jedoch nur dann belastbar, wenn sie aktiv mitgepflegt werden.  
Im Zweifel gilt der inhaltliche Status der einzelnen Punkte über den numerischen Summen.

**Aktuell besonders relevante offene Themen**
- O-021: State Management modernisieren (Riverpod-Migration) — Schritt 1 ✅ abgeschlossen, Schritte 2–4 ausstehend

---

## ✅ Abgeschlossen

> **Hinweis:** Details zu den abgeschlossenen Punkten stehen in `HISTORY.md`.  
> Hier bleiben sie als kompakter Überblick mit Versionsbezug erhalten.


--- 

### P-006: Lighthouse Timespan-Befunde (Laufzeit-Performance, Thumbnails, API-Latenz) — abgeschlossen 2026-07-28 | `1.0.7+94`
**Beschreibung:**
Lighthouse-Timespan-Audit vom 12.05.2026 über ~21 Sekunden Nutzerinteraktion (Login → Artikelliste → Sync).
Ergänzt H-004 (Seitenstart) um Laufzeit-Befunde. Performance-Score: 57, Best Practices: 74.

**Timespan-Ergebnisse:**

| Metrik | Wert | Ziel | Status |
|:--|:--|:--|:--|
| Total Blocking Time | 1.140 ms | < 200 ms | ❌ |
| INP (Interaction to Next Paint) | 250 ms | < 200 ms | 🟡 |
| Cumulative Layout Shift | 0 | < 0,1 | ✅ |
| API-Serverlatenz (`api.germanlion67.de`) | 592 ms | < 200 ms | 🟠 |
| Main-Thread-Arbeit | 4,6 s | < 2 s | ❌ |

**INP-Aufschlüsselung (250 ms):**

| Unterabschnitt | Dauer | Bewertung |
|:--|:--|:--|
| Eingabeverzögerung | 14 ms | ✅ |
| Verarbeitungsdauer | 35 ms | ✅ |
| Präsentationsverzögerung | 199 ms | ❌ Flaschenhals (Flutter CanvasKit Rendering) |

**Thumbnail-Größen (60×60 Thumbnails via PocketBase `?thumb=60x60`):**

| Bild | Transfer | Erwartet | Faktor |
|:--|:--|:--|:--|
| `esp32_terminal_adapter` | 80 KB | ~3–5 KB | 16–27× zu groß |
| `usb_a_steckerkabel` | 60 KB | ~3–5 KB | 12–20× zu groß |
| `mh_sensor` | 19 KB | ~2–3 KB | 6–10× zu groß |

**Hauptursache TBT:** `main.dart.js` mit 4.093 ms Script Evaluation (davon 18 lange Tasks, bis 264 ms einzeln).

---

**Tasks nach Priorität:**

#### Prio 1 — Thumbnail-Größe prüfen und optimieren

- [x] **P-006.1: PocketBase Thumbnail-Generierung prüfen** ✅ — durch P-008 strukturell gelöst
  Befund bestätigt: `thumbs: []` → PocketBase lieferte Originalbild aus.
  Behoben durch Migration `1786000000_updated_artikel_thumbs_p008.js` (P-008).
  Thumbs `60x60`, `400x400`, `1200x1200` konfiguriert.

- [x] **P-006.2: Bilder vor Upload verkleinern** ✅
  **Befund 2026-07-28:** `cameraTargetMaxWidth/Height = 800 px`, `cameraImageQuality = 85`.
  Werte bereits sinnvoll begrenzt. Kein Handlungsbedarf.

#### Prio 2 — API-Latenz untersuchen

- [x] **P-006.3: PocketBase Thumbnail-Caching prüfen** ✅
  **Befund 2026-07-28:** Erster Abruf 360 ms (Generierung), Folgeabrufe 157–218 ms (Cache).
  PocketBase cachet Thumbnails korrekt. Die 592 ms aus dem Lighthouse-Audit waren
  Cold-Cache-Messungen. Kein Handlungsbedarf.

  ```bash
  # Erster Abruf (ggf. Generierung):
  time curl -s -o /dev/null "https://api.germanlion67.de/api/files/artikel/q6zz1lqszs1ent0/27_esp32_terminal_adapter_pslchsymkr.jpg?thumb=60x60"
  # Zweiter Abruf (Cache):
  time curl -s -o /dev/null "https://api.germanlion67.de/api/files/artikel/q6zz1lqszs1ent0/27_esp32_terminal_adapter_pslchsymkr.jpg?thumb=60x60"
  ```

  **Wirkung:** Klärung ob Latenz einmalig (Generierung) oder dauerhaft

#### Prio 3 — Bewusst akzeptiert

- **INP Präsentationsverzögerung (199 ms)** — Flutter CanvasKit rendert auf Canvas statt
  nativem DOM. Nicht direkt optimierbar ohne Renderer-Wechsel. WASM-Build (H-004.5)
  könnte hier helfen.
- **18 lange Tasks aus `main.dart.js`** — Flutter-Web-typisch. Gleiche Ursache wie bei
  H-004 (Seitenstart). WASM-Build ist der effektivste Hebel.

---

**Aufwand gesamt:** ~1–2 Stunden (P-006.1–P-006.3)
**Risiko:** Niedrig

--- 



### P-008: PocketBase Thumbnail-Konfiguration optimieren — abgeschlossen 2026-07-21 | `1.0.7+94`
**Beschreibung:**
Analyse vom 20.05.2026 ergab: Das `bild`-Feld der `artikel`-Collection hat
`"thumbs": []` — PocketBase generiert **keine** Thumbnails.
Der `?thumb=60x60`-Query-Parameter im Code wird ignoriert, PocketBase liefert
stattdessen das Originalbild aus (bis zu 5 MB pro Request).

**Thumbnail-Größen:**

| Größe | Verwendung |
|:--|:--|
| `60x60` | Listenansicht |
| `400x400` | Detailansicht |
| `1200x1200` | Vollbildviewer (5× Zoom = 1000px + Reserve) |

**Umgesetzt:**
- [x] Migration `1786000000_updated_artikel_thumbs_p008.js` — `thumbs: ["60x60", "400x400", "1200x1200"]` für Feld `file1962578385` ✅
- [x] `app_config.dart` — `pbThumbGroesseDetail = '400x400'`, `pbThumbGroesseVollbild = '1200x1200'` ✅
- [x] `artikel_bild_widget.dart` — Detail-Fallback nutzt `400x400` statt Originalbild ✅
- [x] `artikel_detail_content.dart` — `_loadRemoteBildUrl()` speichert 400x400-URL; Vollbildviewer nutzt 1200x1200 ✅

**Hinweis:** Bestehende Bilder erhalten neue Thumbnails erst beim nächsten Upload.

**Wirkung:** Thumbnail-Traffic von bis zu 5 MB auf ~5–300 KB pro Bild reduzierbar.


--- 

### P-009: TBT & Speed Index reduzieren (JS-Bundle-Optimierung) — abgeschlossen 2026-07-21 | `1.0.7+94`
**Beschreibung:**
Lighthouse-Timespan-Audit (P-006) zeigt TBT 1.140 ms und Speed Index 6,6 s.
Hauptursache: `main.dart.js` mit 4.093 ms Script Evaluation (18 lange Tasks beim Start).
Alle Build-Flags sind bereits optimal (--wasm, --tree-shake-icons, --no-source-maps).
Die verbleibenden Hebel sind: Brotli-Komprimierung, Preload-Hints und Deferred Loading.

**Ausgangslage (v0.9.9+75):**

| Metrik | Aktuell | Ziel |
|:--|:--|:--|
| Total Blocking Time | 780 ms (ohne Login) | < 400 ms |
| Speed Index | 6,6 s | < 4,0 s |
| Bundle-Größe (Transfer) | ~3.077 KB | < 2.500 KB |

**Tasks:**

- [x] **P-009.1: Brotli + Zstd in Caddy aktivieren** ✅
  `docker-entrypoint.sh`: `encode gzip` → `encode { zstd br gzip }`
  Caddy 2.7.6 unterstützt beide nativ — kein Plugin nötig.
  **Nachbefund 2026-07-21:** `br` fehlte — nur `encode zstd gzip` war aktiv. Korrigiert auf Block-Syntax `encode { zstd br gzip }`.

- [x] **P-009.2: `modulepreload` für `main.dart.mjs` in `index.html`** ✅
  `<link rel="modulepreload" href="main.dart.mjs">` direkt nach preconnect-Links.
  Browser sieht `modulepreload` beim ersten HTML-Parse → `main.dart.mjs` sofort heruntergeladen und geparst.

- [x] **P-009.3: `--pwa-strategy=none` im Dockerfile** ✅
  Kein Service Worker erforderlich (interne App, kein Offline-Bedarf).
  **Nachbefund 2026-07-21:** Flag fehlte im `flutter build web`-Befehl — `flutter_bootstrap.js` enthielt noch SW-Registrierungscode → Browser-404. `--pwa-strategy=none` in `Dockerfile` und `ci.yml` ergänzt.

- [x] **P-009.4: Deferred Loading für sekundäre Screens** ✅
  `ArtikelErfassenScreen`, `SettingsScreen`, `ConflictResolutionScreen` als deferred imports.
  Embedded Panels via `FutureBuilder` + `CircularProgressIndicator.adaptive()`.

- [x] **P-009.5: Web-Build-Verifikation in `ci.yml`** ✅
  Job `build-web-verify` prüft ob `main.dart.wasm` nach dem Build vorhanden ist.

---


## In History überführt

### F-012: Web-Version — UI/UX & Funktionsprobleme (Issue #67) — abgeschlossen 2026-07-14 | `1.0.5+88`
9 Bugs und UX-Probleme der Web-Version aus Issue #67 behoben (alle Änderungen hinter `kIsWeb`-Guards).
Kernfixes: Speichern via `PocketBaseService` (F-012.1), Speichern-Button-Rebuild via `onStateChanged`-Callback (F-012.2), Sync-Elemente ausgeblendet (F-012.3), Widget-Recycling-Bug in Detailansicht (F-012.4), Settings als eingebettetes Panel ohne `Navigator.push` (F-012.5).
Session-Persistenz via `AsyncAuthStore` in `localStorage` (F-012.6), Scanner-Button-Dialog für Web (F-012.7), TAB-Navigation mit `FocusNode`-Kette (F-012.8), Sync-Button ausgeblendet (F-012.9).

---

### M-014: Readonly-User-Rolle — PocketBase API Rules + App-UI-Integration — abgeschlossen 2026-07-13 | `1.0.4+86`
Readonly-Rolle eingeführt: `role`-Feld in `users`-Collection, API Rules für `artikel` und `attachments` um `&& @request.auth.record.role != "readonly"` erweitert.
`PocketBaseService.isReadonlyUser`-Getter ergänzt; Edit-, Speichern-, Löschen- und Bild-Buttons in `ArtikelDetailContent` sowie ➕-Button in `ArtikelListScreen` hinter Readonly-Guard gestellt.
5 Unit-Tests für `isReadonlyUser` ergänzt (T-012.41–45). Verifiziert: `flutter analyze` 0 Issues | `flutter test` 1016/1016 ✅

---

### B-019: Bild verschwindet nach Speichern im embedded Modus (Web) — abgeschlossen 2026-07-11 | `1.0.0+78`
`bildEntfernt`-Bedingung in `_speichernWeb()` nutzte `_bildPfad == null` — im Web immer `true`. Fix: `_remoteBildUrl == null` als zusätzliche Bedingung (URL ist nur `null` wenn Nutzer das Bild explizit entfernt hat).
Nebeneffekte behoben: Spinner-Überlappung vermieden, `setState`-during-build via `addPostFrameCallback` verhindert.
Verifiziert: Web ✅ | `flutter analyze` 0 Issues | `flutter test` 1011/1011 ✅

---

### H-004: Lighthouse-Befunde beheben (Web-Performance, Security-Header, SEO) — abgeschlossen 2026-05-19 | `0.9.9+75`
Lighthouse-Ausgangslage 12.05.2026: Performance 62, SEO 91, TBT 2.510 ms.
`robots.txt` bereitgestellt (H-004.1), HSTS-Header gesetzt (H-004.2), Splash-Bild mit `width`/`height`/`fetchpriority` versehen (H-004.3), `--tree-shake-icons` im Build aktiviert (H-004.4).
WASM-Build umgesetzt — TBT auf 430 ms gesenkt, COOP/COEP-Header im Caddyfile ergänzt (H-004.5). `config.js` wird jetzt zur Laufzeit aus `docker-entrypoint.sh` generiert.
Ergebnis: Performance 62→88, SEO 91→63→100 (nach H-005), TBT 2.510→430 ms.

---

### H-005: SEO-Korrekturen & Sicherheits-Header (Lighthouse-Audit 18./19.05.2026) — abgeschlossen 2026-05-20 | `0.9.9+75`
Lighthouse SEO-Regression 91→63 durch `robots.txt Disallow: /` und fehlende Meta-Tags.
`robots.txt` auf `Allow: /` gesetzt (H-005.1), `<meta name="description">` und `<title>` in `index.html` ergänzt (H-005.2), `X-Frame-Options: SAMEORIGIN` bereits im Caddyfile gesetzt (H-005.3 ✅).
SEO-Score: 63 → **100** ✅ (ohne Login, v0.9.9+75).

---

### T-012: Testlücken bei produktiven Services schließen — abgeschlossen 2026-07-13 | `1.0.4+86`
Testabdeckung für 5 produktiv genutzte Services nachgezogen: `pocketbase_service.dart` (51 Tests), `connectivity_service.dart` (14), `sync_progress_service.dart` (61), `sync_error_recovery.dart` (87), `tag_service.dart` (43).
`database_service.dart` übersprungen (Shim ohne Logik). 5 weitere Unit-Tests für `isReadonlyUser` (T-012.41–45) im Rahmen von M-014 ergänzt.
Gesamt: 1016/1016 Tests grün.

---

### O-014: Nextcloud-Code entkoppeln und entfernen — abgeschlossen 2026-05-16 | `0.9.9+70`

`ConflictData`, `ConflictResolution` und `SyncResult` aus `sync_service.dart` in neue
Datei `lib/services/conflict_types.dart` extrahiert. Alle abhängigen Dateien auf die
neuen Imports umgestellt.

Nextcloud-Referenzen aus `conflict_resolution_screen.dart`, `sync_conflict_handler.dart`,
`pocketbase_conflict_adapter.dart` und `main.dart` entfernt bzw. auf `conflict_types.dart`
umgestellt.

**Gelöschte Dateien:**
- `lib/services/nextcloud_service_interface.dart`
- `lib/services/nextcloud_sync_service.dart`
- `lib/services/sync_service.dart` (Conflict-Types extrahiert, Rest obsolet)
- `lib/widgets/nextcloud_resync_dialog.dart`

**Neue Datei:**
- `lib/services/conflict_types.dart`

`webdav_client` aus `pubspec.yaml` entfernt.
Tests und Mocks angepasst. `flutter analyze`: 0 Issues. `flutter test`: 755/755 (2 skipped).

--- 

### O-020: `_PocketBaseConflictAdapter` aus `main.dart` ausgelagert — abgeschlossen 2026-05-16 | `0.9.9+68`
Neue Datei `lib/services/pocketbase_conflict_adapter.dart`. Klasse ist jetzt public
(`PocketBaseConflictAdapter`) und ohne `main.dart`-Abhängigkeit wiederverwendbar.
`main.dart`: Import ergänzt, `_`-Prefix entfernt, keine Logik geändert.
`artikel_db_service.dart`: Singleton auf `_db` — Aufteilung würde Komplexität erhöhen
ohne Gewinn — kein Handlungsbedarf.

---

### O-019: `print()` in `app_config.dart` durch Logger ersetzt — abgeschlossen 2026-05-16 | `0.9.9+67`
`AppConfig.validateConfig()`: `print()` + `assert`-Wrapper entfernt, durch `_logger.w()`
ersetzt. Warnung erscheint jetzt auch im Release-Build — Placeholder-URL in Produktion
ist ein echtes Konfigurationsproblem, kein reines Debug-Signal.
`// ignore: avoid_print`-Kommentar entfällt. Konsistent mit bestehendem `_logger`-Einsatz
in `AppConfig.init()`.

---

### O-016: Timeout-Konstanten in AppConfig zentralisiert — abgeschlossen 2026-05-16 | `0.9.9+66`
Vier neue Timeout-Konstanten in `AppConfig` ergänzt: `connectivityCheckTimeout` (3s),
`backupStatusTimeout` (5s), `syncPushTimeout` (30s), `syncUploadTimeout` (120s).
`ConnectivityService._tcpCheck()` und `BackupStatusService.fetchStatus()` auf
`AppConfig.*Timeout` umgestellt. Keine Wertänderungen — reine Konstantenverlagerung.

---

### F-011: Responsive/Adaptive Layout für Desktop-Web — abgeschlossen 2026-05-15 | `0.9.8+62`
Mobile-first UI auf Desktop-Monitore ausgeweitet. Drei Stufen umgesetzt.

**Stufe 1** — Maximalbreite (600px, `ConstrainedBox`) ✅  
**Stufe 2** — Breakpoint-Helfer (`lib/core/responsive.dart`), `ArtikelListWidget` als Grid/Liste, `ArtikelDetailWidget` mit responsiver Feldanordnung, `NavigationRail` statt `BottomNavigationBar`, Settings zweispaltig ✅  
**Stufe 3** — Master-Detail ab ≥1024px: `ArtikelDetailContent` extrahiert, `ArtikelDetailScreen` als dünner Scaffold-Wrapper mit `ValueNotifier`-Rebuild, `embedded`-Parameter, `didUpdateWidget` bei Artikelwechsel, `maxContentWidth` auf 1400, neue `AppConfig`-Konstanten (`masterDetailMinWidth`, `masterListFlex`, `masterDetailFlex`, `breakpointTablet`, `breakpointDesktop`). F-011.8 (Sidebar) + F-011.9 (Seitenpanels) offen. 🟡

**Tests:** 50 Widget-Tests grün (24 Detail + 15 List + 11 Erfassen)  
**Risiko:** Niedrig (Stufe 1–2), Mittel (Stufe 3)

---

### O-017: `catch (e)` durch `catch (e, st)` ersetzen — abgeschlossen 2026-05-13 | `0.9.8+57`
`catch (e)` → `catch (e, st)` in `scan_service_stub.dart`, `artikel_import_service.dart` (2×),
`app_log_io.dart` (4×) ersetzt. StackTrace an Logger-Aufrufe durchgereicht.
`pdf_service_shared.dart` war bereits korrekt. Nextcloud-Stellen entfallen mit O-014.
`flutter analyze` grün.

---



### B-018: Artikelnummer wird bei Suche/Scan nicht gefunden — abgeschlossen 2026-05-13 | `0.9.8+57`
Artikelnummer-Feld in SQLite-Suche, PocketBase-Suche und Scanner-Fallback einbezogen.
Web-Fallback-Dialog (Texteingabe) nutzt jetzt denselben Codepfad wie der Scanner.
Verifiziert: Android Scanner ✅, Android Suche ✅, Web Texteingabe ✅

---

### P-007: UI-Performance `ArtikelListScreen` — abgeschlossen 2026-05-13 | `0.9.8+57`
Fünf Befunde in `artikel_list_screen.dart` behoben:

| Kürzel | Maßnahme |
|:---|:---|
| P-007.1 | `_gefilterteArtikel()` gecacht — Invalidierung via `identical()`-Referenzcheck |
| P-007.2 | `setState()` bei Keystroke entfernt — TextField steuert Anzeige intern |
| P-007.3 | `_aktualisiereFilter()` ohne separates `setState()` — 1 statt 2 Rebuilds pro Pagination |
| P-007.4 | `_ArtikelTile` + `_ArtikelInfoChip` als `StatelessWidget` extrahiert |
| P-007.5 | Scroll-Guard `_isLoadingMore`/`_hasMore` vor Pixel-Vergleich verschoben |

`flutter analyze` + `flutter test` grün.

---

### F-008: Hintergrund-Sync-Intervall konfigurierbar — abgeschlossen 2026-05-08 | `0.9.5+54`
Dropdown in Einstellungen: 1 Min / 5 Min / 15 Min (Standard) / Nur manuell.
Callback-Pattern (`onSyncIntervalChanged`) → `SettingsController` → `SharedPreferences` → `main.dart`.
Änderungen greifen sofort ohne App-Neustart. Verifiziert auf SM-A515F.

---

### B-016: `remoteBildPfad` beim Bild-Entfernen nicht in PocketBase geleert — abgeschlossen 2026-05-08 | `0.9.5+51`
Push-Update-Pfad sendet jetzt `body['remoteBildPfad'] = ''` zusammen mit `body['bild'] = null`.
1 Zeile in `pocketbase_sync_service.dart`. PocketBase Admin verifiziert ✅

---

### B-017: Kurzer BlueScreen bei Kamera-Permission-Entzug — abgeschlossen 2026-05-08 | `0.9.5+54`
Bekanntes Android-OS-Verhalten — kein fachlicher Fix nötig. Android beendet Activity bei
Permission-Entzug sofort (Security-Policy), Flutter startet neu. Kein Datenverlust.
Kosmetischer Fix: `ErrorWidget.builder` überschrieben → `SizedBox.shrink()` statt rotem ErrorWidget.

---

### P-004: Android Kamera-Test — abgeschlossen 2026-05-07 | `0.9.5+50`
Vollständige manuelle Verifikation auf SM-A515F (11 Tests). Happy Path, Abbrechen, Crop,
Bild ersetzen, Neuerfassung, Verwerfen-Dialog, Low-Memory-Kill — alle bestanden ✅
Befunde: B-016 (remoteBildPfad), B-017 (BlueScreen bei Permission-Entzug).

---

### O-013: Log-Viewer Default-Level konfigurierbar — abgeschlossen 2026-05-05 | `0.9.5+50`
Standard-Filter-Level (Trace–Fatal) in App-Einstellungen wählbar, via `SharedPreferences`
persistiert. Neue „Entwickler"-Card im Settings-Screen. ~94 Zeilen, ~25 Minuten.

---

### F-009: Kategorie-Eingabe in der Artikel-UX — abgeschlossen 2026-05-04 | `0.9.4+49`
Kategorie-Feld (Freitext, max 50 Zeichen) in Erfassen- und Detail-Screen. Chip in
Listenansicht. Kategorie-Filter als zweites Dropdown neben Ort-Filter (UND-verknüpft,
dynamisch aus Artikelliste). Keine Modell-/DB-/Sync-Änderungen nötig.
Verifiziert auf A515F + S20, PocketBase E2E bestätigt.

---

### T-001: Konfliktlösung, Sync-Hardening und Integrationsverifikation — abgeschlossen 2026-05-04 | `0.9.4+48`
Umfassende Absicherung der Konflikt- und Sync-Pipeline.

**Technisch abgesichert:** ConflictData/ConflictResolution/SyncResult, `detectConflicts()`,
`_determineConflictReason()`, Snapshot-Persistenz, Remote-Delete-Guards, Duplicate-UUID-Recovery,
`toPocketBaseMap()` (UTC-Timestamps, `artikelnummer`-Guard, keine Sync-Metadaten),
UTC-Konsistenz in `artikel_db_service.dart`, Zeitstempel-Semantik in `DATABASE.md`.

**Manuell verifiziert:** `force_local`, `force_merge`, `useRemote`, `skip`, Mehrfachkonflikte
(sequentiell), Soft-Delete lokal + Remote-Edit, UUID-Kollision als konservativer Konfliktfall
(T-001.18). Orchestrator-Timeout während offener Konflikt-UI nicht mehr reproduzierbar.

**Bewusst nicht umgesetzt:** Monitoring für Duplicate-UUID-Fallbacks, ETag-Vereinfachung,
ConflictCallback-Umbau, zusätzliche Modell-Randfälle, Interface-Entkopplung, Soft-Delete-Refactoring.

**Technische Referenz:** `docs/SYNC.md`

---

### M-013: Bild-Reset („Bild leeren") — abgeschlossen 2026-05-04 | `0.9.4+46`
Kontextsensitiver AppBar-Button (ein Button statt zwei): „Bild hinzufügen" / „Bild ändern".
BottomSheet mit Datei / Kamera / Zuschneiden / Bild entfernen (rot, mit Bestätigungsdialog).
Push sendet `body['bild'] = null`, Pull ruft `clearBildInfoByUuidSilent()` auf.
Lokale Bilddatei + Thumbnail physisch gelöscht, Image-Cache invalidiert.
Crop funktioniert jetzt auch für bestehende lokale Bilder.

**Folgefix `0.9.4+47`:** `artikel.copyWith(...)` an `ArtikelDetailBild` übergeben →
Placeholder sofort sichtbar. `CachedNetworkImage.evictFromCache()` vor `clearBildInfoByUuidSilent()`
→ kein 404-Log in Listenansicht.

---

### O-012: Sync-Logs mobil-lesbar — abgeschlossen 2026-05-04 | `0.9.4+44`
Strukturierte 1-Zeilen-Summary-Lines für Push/Pull/Orchestrator eingeführt, in `docs/LOGGER.md`
dokumentiert. Verbose-Flag bewusst verworfen — Log-Level-Filter (F-006) deckt den Use Case ab.

---

### T-001.18: UUID-Kollision als konservativer Konfliktfall — abgeschlossen 2026-05-03 | `0.9.4+42`
„Lokal offline neu erzeugt, vor erstem Sync gleicher Remote-Datensatz vorhanden" → bewusst
konservativer Konfliktfall (nicht stiller Auto-Recovery). Nach `useLocal`-Auflösung erfolgreicher
Folgesync, keine Dublette, kein Retry-Loop.

---

### T-001 (Ergänzung): Bildpfad-Testlücke + Delete-Konfliktfall — abgeschlossen 2026-05-03 | `0.9.4+41`
`_extractBildName()` und `remoteBildPfad` nach CREATE/UPDATE für `List<String>`, `String`,
`null` und leere Werte regressionssicher abgesichert. Soft-Delete lokal + Remote-Edit
erneut manuell verifiziert inkl. Gegenprobe.

---

### B-015: Orchestrator-Timeout während offener Konflikt-UI — abgeschlossen 2026-05-02 | `0.9.4+41`
Timeout-Behandlung konfliktbewusst: Während aktiver Benutzerauflösung kein Timeout.
Regelmäßige Wait-Logs während offener UI. Echte Netzwerkfehler weiterhin korrekt als
Fehler behandelt. Verhaltenstests in `sync_orchestrator_test.dart` ergänzt.

---

### B-003: `remoteBildPfad` nach CREATE/UPDATE in PocketBase — abgeschlossen 2026-04-30 | `0.9.4+39`
Follow-up-PATCH nach Bild-Upload setzt `remoteBildPfad` in PocketBase.
`downloadMissingImages()` erkennt Bild auf anderen Geräten korrekt (`downloaded=1`).
Verifiziert via Logs + PocketBase-Record (Δ created→updated = 147ms) ✅

---

### B-014 + O-012 (Anteil) — abgeschlossen 2026-04-29 | `0.9.4+37`
HTTP 400 CREATE behoben (`artikelnummer`-Guard + vollständiges PocketBase-Schema).
`markSynced()` Spaltennamen-Fix. Push-Timeouts (30s statt 60s Orchestrator-Timeout).
Summary-Logs für Sync-Phasen eingeführt.

---

### B-013: Image Upload Flow, `remoteBildPfad`, Ghost-File-Cleanup — abgeschlossen 2026-04-28 | `0.9.4+36`
Multipart-Bild-Upload in CREATE/UPDATE (`_buildFiles()`-Helper). `markSynced()` um
`remoteBildPfad` erweitert. `clearBildInfoByUuidSilent()` neu. Pull-Pfad entfernt
lokale Bildinfos bei leerem Remote-Feld. 692 Tests grün (+3 skipped).

---

### K-007: Flutter Update — abgeschlossen 2026-04-22 | `0.9.1+26`
Flutter 3.41.4 → 3.41.7, Dart 3.11.1 → 3.11.5. Package-Major-Updates: `csv`, `device_info_plus`,
`file_picker`, `flutter_local_notifications`, `share_plus`, `build_runner`.
`js`-Package entfernt (→ `dart:js_interop`). CI/CD-Workflows aktualisiert.

---

### T-009: Ergänzende Tests `SettingsController` — abgeschlossen 2026-04-23 | `0.9.2+32`
`saveSettings()`-Fehlerpfad, `showLastSync`-Default, Save-/Reset-/Dirty-State-Pfade abgesichert.
`settings_controller_test.dart` auf 15 Tests erweitert.

---

### O-010: `SettingsScreen` — Logik in testbaren Controller extrahieren — abgeschlossen 2026-04-23 | `0.9.1+29`
Settings-Logik (Laden/Speichern, Dirty-Tracking, PB-URL, DB-Status, App-Lock) in neuen `SettingsController` extrahiert. `SettingsScreen` auf UI-Verantwortung reduziert (Dialoge, SnackBars, Navigation, Rendering). `TextEditingController` bewusst pragmatisch im Controller belassen. Controller gezielt testbar gemacht, Save-/Reset-/Dirty-State- und Reject-/Success-Pfade abgesichert.

---

### F-007: Einstellung — Letzter-Sync-Zeitstempel ein-/ausblenden — abgeschlossen 2026-04-23 | `0.9.1+29`
Toggle in den Einstellungen zum Ein-/Ausblenden des Sync-Zeitstempels in der Artikelliste. Persistenz via `SharedPreferences` (`show_last_sync`), reaktiv via `ValueNotifier<bool>`, Default `true`. Hotfix `v0.9.0+25`: `ValueListenableBuilder` ergänzt (Toggle war zuvor funktionslos). Architektur-Bereinigung `v0.9.1+29`: State in `settings_state.dart` zentralisiert, Screen-Abhängigkeit entkoppelt.

---

### O-009: Widget-Tests `ArtikelListScreen` — abgeschlossen 2026-04-22 | `0.9.0+25`
Import-Pfad, Pflichtfelder (`erstelltAm`/`aktualisiertAm`) und Suchfeld-Label (`'Suche…'`) korrigiert. `_pumpScreenWithArtikel()`-Helper ergänzt. 15 Widget-Tests grün. Gesamtstand: **625 Tests**, 28 Dateien.

---

### F-006: Log-Level-Filter als Dropdown statt Button-Reihe — abgeschlossen 2026-04-22 | `0.9.0+25`
Log-Level-Button-Reihe (Trace–Fatal) passte auf schmalen Displays (360dp) nicht in eine Zeile. Ersetzt durch `DropdownButton<Level>` mit Default `Level.error`. Auf S20 verifiziert.

---

### B-012: Letzter-Sync-Zeitstempel auf schmalen Displays abgeschnitten — abgeschlossen 2026-04-22 | `0.9.0+25`
Sync-Label in AppBar konkurrierte auf 360dp mit Action-Icons. Fix: `TextOverflow.ellipsis` und `Flexible`-Wrapper ergänzt. Auf S20 verifiziert.

---

### B-011: App-Version zeigt veralteten Build-Stand — abgeschlossen 2026-04-22 | `0.9.0+25`
Kein Code-Fehler — `_getAppVersion()` via `PackageInfo.fromPlatform()` korrekt implementiert. Ursache: veraltete APK installiert (kein Build nach Version-Bump). Nach Neuinstallation korrekte Version bestätigt.

---

### B-010: Snackbar-Feedback in Artikelliste fehlt — abgeschlossen 2026-04-22 | `0.9.0+25`
Nach Sync-Erfolg/-Fehler fehlte Snackbar-Feedback (Regression aus B-007). Snackbar bei Sync-Start, -Erfolg und -Fehler in `ArtikelListScreen` ergänzt. 


## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
| 2026-07-28 | 1.0.7+94 | P-006 vollständig abgeschlossen. P-006.2: `cameraTargetMaxWidth/Height = 800 px`, `cameraImageQuality = 85` — bereits sinnvoll begrenzt, kein Handlungsbedarf. P-006.3: Thumbnail-Caching verifiziert — erster Abruf 360 ms (Generierung), Folgeabrufe 157–218 ms (Cache). PocketBase cachet korrekt, die 592 ms aus dem Lighthouse-Audit waren Cold-Cache-Messungen. |
| 2026-07-21 | 1.0.7+94 | P-008: PocketBase Thumbnail-Konfiguration — abgeschlossen. Migration + AppConfig-Konstanten + Widget-Anpassungen. P-006.1 damit gelöst. |
| 2026-07-21 | 1.0.7+94 | P-009: TBT & Speed Index reduzieren — abgeschlossen. Nachbefund: Brotli (`br`) in Caddy ergänzt, `--pwa-strategy=none` in Dockerfile + ci.yml nachgezogen. |
| 2026-07-14 | 1.0.5+88 | F-012: Web-Version — UI/UX & Funktionsprobleme (Issue #67)  — abgeschlossen |
| 2026-07-13 | 1.0.4+86 | M-014: Readonly-User-Rolle — PocketBase API Rules + App-UI-Integration - Abgeschlossen |
| 2026-07-11 | 1.0.0+78 | M-014 neu: Readonly-User-Rolle — PocketBase API Rules + App-UI-Guards dokumentiert. |
| 2026-05-20 | 0.9.9+75 | H-005.3: X-Frame-Options bereits im Caddyfile vorhanden —
als ✅ erledigt markiert. H-005 vollständig abgeschlossen. |
| 2026-05-20 | 0.9.9+75 | LIGHTHOUSE.md in HISTORY.md überführt und gelöscht. OPTIMIZATION.md auf Version 0.9.9+75 aktualisiert: H-005 vollständig eingetragen (H-005.1 ✅, H-005.2 ✅, H-005.3 ❌ offen), Score-Tabelle in H-004 um Endzustand ergänzt, Verweis auf HISTORY.md für Audit-Rohdaten ergänzt, Fortschritts-Übersicht aktualisiert. |
| 2026-05-19 | 0.9.9+75 | H-005 umgesetzt: robots.txt auf Allow: / gesetzt (H-005.1),
Meta-Description und Title in index.html ergänzt (H-005.2). SEO-Score 63 → 100
(ohne Login). H-005.3 (X-Frame-Options) offen. Score-Tabelle aktualisiert. |
| 2026-05-17 | 0.9.9+71 | T-012 (anteilig): `pocketbase_service_test.dart` erstellt (51 Tests). Abdeckung: `initialize()` URL-Prioritäten, Race-Condition-Guard, `needsSetup`, `updateUrl()` mit Health-Check-Fake, `resetToDefault()`, URL-Validierung, `login()`/`logout()`, `LoginTimeoutException`, `refreshAuthToken()`, `requestPasswordReset()`, Auth-Getter, `checkHealth()`. Strategie: `PocketBaseService.testable()` + manuelle Fakes, kein build_runner. `sync_error_recovery_test.dart`: 87 Tests, Recovery-Strategien und Retry-Logik. Gesamt: 806 Tests grün (+2 skipped). |
| 2026-05-16 | 0.9.9+70 | O-014 abgeschlossen: Nextcloud-Code vollständig entfernt. `ConflictData`/`ConflictResolution`/`SyncResult` in `conflict_types.dart` extrahiert. 4 Dateien gelöscht (`nextcloud_service_interface.dart`, `nextcloud_sync_service.dart`, `sync_service.dart`, `nextcloud_resync_dialog.dart`). `nextcloud_client.dart` neu implementiert (testbar). `webdav_client` aus pubspec.yaml entfernt. Tests angepasst. 755/755 grün. |
| 2026-05-16 | 0.9.9+68 | O-016 abgeschlossen: Timeout-Konstanten in AppConfig zentralisiert (connectivityCheckTimeout, backupStatusTimeout, syncPushTimeout, syncUploadTimeout). O-019 abgeschlossen: print() in app_config.dart durch _logger.w() ersetzt, assert-Wrapper entfernt. O-020 abgeschlossen: _PocketBaseConflictAdapter in eigene Datei ausgelagert (pocketbase_conflict_adapter.dart), Klasse public. |
| 2026-05-15 | 0.9.8+62 | F-011.7 abgeschlossen: Master-Detail-Layout für Desktop. `ArtikelDetailContent` als eigenständiges Widget extrahiert, `ArtikelDetailScreen` als dünner Scaffold-Wrapper mit ValueNotifier-Rebuild, Master-Detail in `ArtikelListScreen` ab ≥1024px (NavigationRail + Liste links, Detail rechts), `maxContentWidth` auf 1400 erhöht, `ConstrainedBox` nur Mobile/Tablet, `_ladeAnhangCount()` try/catch für Test-Kompatibilität, neue AppConfig-Konstanten für Breakpoints und Flex-Werte. 50 Widget-Tests grün (24 Detail + 15 List + 11 Erfassen). |
| 2026-05-13 | 0.9.8+57 | P-007 abgeschlossen: `_gefilterteArtikel()` gecacht (P-007.1), setState() bei Keystroke entfernt (P-007.2), `_aktualisiereFilter()` ohne separates setState() (P-007.3), `_ArtikelTile` + `_ArtikelInfoChip` als StatelessWidgets extrahiert (P-007.4), Scroll-Guard früher im `_onScroll()`-Pfad (P-007.5). B-018 abgeschlossen: Artikelnummer in Suche (SQLite + PocketBase) und Scanner-Fallback einbezogen. O-017 abgeschlossen: catch (e, st) in scan_service_stub.dart, artikel_import_service.dart (2×), app_log_io.dart (4×) ergänzt; pdf_service_shared.dart war bereits korrekt. flutter analyze + flutter test grün. |
| 2026-05-08 | 0.9.5+54 | F-008: Sync-Intervall konfigurierbar (1/5/15 Min oder nur manuell). Dropdown in Einstellungen, Callback-Pattern für sofortige Übernahme ohne App-Neustart. |
| 2026-05-08 | 0.9.5+51 | P-004 abgeschlossen: Android-Kamera vollständig manuell verifiziert (8 Tests auf A515F). B-016 behoben: `remoteBildPfad` wird beim Bild-Entfernen jetzt in PocketBase geleert (1 Zeile in Push-Update-Pfad). B-017 behoben: `ErrorWidget.builder` unterdrückt roten ErrorWidget-Flash bei Activity-Restart nach Permission-Änderung (kosmetisch, erwartetes Android-OS-Verhalten). |
| 2026-05-05 | 0.9.5+50 | O-013 umgesetzt: Log-Viewer Default-Level in App-Einstellungen konfigurierbar |
| 2026-05-04 | 0.9.4+49 | F-009 umgesetzt: Kategorie-Feld in Erfassen/Detail/Liste, Kategorie-Filter neben Ort-Filter, Chip in Listenansicht. |
| 2026-05-04 | 0.9.4+48 | T-001 abgeschlossen: Konfliktlösung, Sync-Hardening und Integrationsverifikation vollständig abgehakt. UUID-Pattern serverseitig abgesichert, UTC-Konsistenz geprüft (sauber), Zeitstempel-Semantik in DATABASE.md dokumentiert, verbleibende Optional-Punkte bewusst als „nicht benötigt" gestrichen. |
| 2026-05-04 | 0.9.4+46 | M-013 abgeschlossen: Bild-Reset („Bild leeren") ermöglichen |
| 2026-05-04 | 0.9.4+44 | O-012 abgeschlossen: Verbose-Flag geprüft und bewusst verworfen — Log-Level-Filter (F-006) deckt den Use Case ab. |
| 2026-05-03 | 0.9.4+43 | Sync-Dokumentation konsolidiert: `docs/SYNC.md` als technische Referenz für Push/Pull, Konflikterkennung, Edge Cases, Invarianten und Änderungsverbote ergänzt; `prompt.txt` als allgemeiner Arbeitskontext erweitert. |
| 2026-05-03 | 0.9.4+43 | `ARCHITECTURE.md` und `DATABASE.md` gegen den aktuellen SQLite-/Sync-Stand konsolidiert; Indexnamen gegen den echten Code verifiziert und vereinheitlicht. |
| 2026-05-03 | 0.9.4+42 | E-001 real eingeordnet: Die Konstellation „lokal offline neu erzeugt, vor erstem Sync gleicher Remote-Datensatz bereits vorhanden“ wird nun fachlich als gewünschter konservativer Konfliktfall bewertet. Nach manueller Auflösung (`useLocal`) erfolgreicher Folgesync ohne Dublette oder Retry-Loop. |
| 2026-05-03 | 0.9.4+41 | T-001 weiter konsolidiert: `_extractBildName()` / `remoteBildPfad` service-nah testseitig ergänzt; M-004 erneut manuell verifiziert inklusive erfolgreicher Gegenprobe ohne Remote-Änderung. |
| 2026-05-02 | 0.9.4+41 | T-011 abgeschlossen: Snapshot-Persistenz in `ArtikelDbService` sowie Zeitstempel- und `artikelnummer`-Regeln in `Artikel.toPocketBaseMap()` testseitig regressionssicher ergänzt. DB-Testisolation für Singleton/In-Memory-Setup stabilisiert. Teststand: 707 Tests grün, 3 übersprungen. |
| 2026-05-02 | 0.9.4+41 | B-015 weiter eingegrenzt: konfliktbewusste Timeout-Semantik des Orchestrators ist jetzt per Verhaltenstests abgesichert; offen bleibt die produktive UX-/Ablaufbehandlung längerer Merge-Interaktion. |
| 2026-04-30 | 0.9.4+41 | T-001 manuell weiter bestätigt: `useLocal`, `useRemote`, `skip` und Mehrfachkonflikte im echten Geräte-/Server-Lauf verifiziert. Gemischte Auflösungen (`skip`, `useRemote`, `useLocal`) funktionieren sequentiell; nur übersprungene Konflikte erscheinen im Folgesync erneut. Merge fachlich bestätigt, aber mit bekanntem Orchestrator-Timeout-Befund bei längerer UI-Interaktion. |
| 2026-04-30 | 0.9.4+39 | B-003 abgeschlossen: `remoteBildPfad` wird nach CREATE/UPDATE via Follow-up-PATCH korrekt in PocketBase geschrieben. Verifikation via Flutter-Logs (SYNC\|PUSH\|CREATE ok, downloaded=1) und PocketBase-Record-Inspektion (Δ created→updated = 147ms). |
| 2026-04-29 | 0.9.4+37 | fix/sync-hardening2-v0.9.4(B-014): HTTP 400 CREATE, Push-Timeouts, markSynced-Spaltenname, Summary-Logs |
| 2026-04-28 | 0.9.4+36 | fix/sync-hardening2-v0.9.4 B-013 abgeschlossen: image upload flow, `remoteBildPfad` |
| 2026-04-23 | 0.9.2+32 | T-009 und O-011 abgeschlossen: ergänzende Tests für `SettingsController` und settings-nahe Persistenzpfade nachgezogen; zugleich `AppLockService` testbarer gemacht, sodass App-Lock-nahe Lade-/Speicherpfade und fachliche Timeout-/State-Logik nun isolierter testbar sind. |
| 2026-04-23 | 0.9.1+29 | O-010 abgeschlossen: `SettingsScreen` fachlich minimal-invasiv in `SettingsController` refactored, UI-/Logik-Trennung verbessert, zusätzliche Controller-Tests ergänzt. F-007 architektonisch bereinigt: `showLastSyncNotifier`, Prefs-Key und Default nach `settings_state.dart` verschoben, Default konsistent auf `true` vereinheitlicht. Teststand auf 626 bestanden, 3 übersprungen aktualisiert. |
| 2026-04-22 | 0.9.1+26 | K-007: Flutter upgrade 3.41.4 → 3.41.7 + package major updates |
| 2026-04-22 | 0.9.0+25 | B-008 abgeschlossen: Card-Layout `ArtikelListScreen` wiederhergestellt (Artikelnummer, Chips, Feldname-Fix). B-009 abgeschlossen: Ort-Dropdown dynamisch aus Artikelliste, in Body integriert, Reset-Button. B-010 abgeschlossen: Snackbar-Feedback bei Sync-Start/-Erfolg/-Fehler. B-011 abgeschlossen: App-Version zeigt korrekten Build-Stand nach neuem Release-Build. B-012 abgeschlossen: Sync-Label `TextOverflow.ellipsis` + `titleSpacing`. F-006 abgeschlossen: Log-Level-Filter als `DropdownButton<Level>`, Default `Level.error`. F-007 abgeschlossen: Sync-Zeitstempel-Toggle via `ValueNotifier` + `SharedPreferences`. O-009 abgeschlossen: 15 Widget-Tests `ArtikelListScreen` grün (625 Tests gesamt). |
| 2026-04-21 | 0.8.9+24 | B-007 abgeschlossen: Intelligenter Bild-Sync (Timestamp-Check) und UI-Politur des Sync-Zeitstempels implementiert. |
| 2026-04-20 | 0.8.6+21 | P-003 abgeschlossen: Bild-Caching via `cached_network_image` integriert. Android-Stabilität auf S20 verifiziert. |
| 2026-04-17 | 0.8.5+19 | B-003 abgeschlossen: `downloadMissingImages` Skip-Logik korrigiert. B-004 abgeschlossen: Konflikt-Callback via `GlobalKey` + `addPostFrameCallback`. B-005 abgeschlossen: ETag-Konflikt-Erkennung vor PATCH. B-006 abgeschlossen: `SyncManagementScreen` auf `SyncOrchestrator` umgestellt. T-008 abgeschlossen: 20 neue Tests (610 gesamt, 28 Dateien). |
| 2026-04-14 | 0.8.4+17 | N-003: App-Icon + N-005: Native Splash Screen als erledigt markiert |
| 2026-04-14 | 0.8.4+17 | F-004 abgeschlossen: NC-Icon auf `statusColorConnected` umgestellt. F-005 abgeschlossen: Detail-Screen Readonly-Felder mit `OutlineInputBorder` + `InputDecorator`, Menge/Artikelnummer als eigene Felder, `+/-` Buttons nur im Edit-Modus, 3 Widget-Tests angepasst |
| 2026-04-14 | 0.8.3+16 | B-001 abgeschlossen: Settings-Save-Verhalten analysiert — Dirty-Tracking, Save-Button und Unsaved-Dialog waren bereits korrekt implementiert. B-002 abgeschlossen: Biometrie-Analyse — automatischer Auth-Start, `FragmentActivity`, Verfügbarkeitsprüfung vor Toggle-Aktivierung bestätigt. OPT-001 neu: `SettingsController`-Extraktion für Testbarkeit |
| 2026-04-13 | 0.8.2+13 | F-001 + F-002 abgeschlossen: App-Lock mit biometrischer Authentifizierung und konfigurierbarer Sperrzeit |
| 2026-04-13 | 0.8.1+12 | T-003 abgeschlossen: 39 Unit-Tests `NextcloudClient` |
| 2026-04-13 | 0.8.1+11 | T-004 abgeschlossen: 18 Widget-Tests `MergeDialog`. O-008 abgeschlossen: `spacingSectionGap`-Token, 3 Stellen ersetzt |
| 2026-04-13 | 0.8.1+10 | T-005 abgeschlossen: 34 Tests `AttachmentService` |
| 2026-04-13 | 0.8.0+8 | F-003: Artikeldetailansicht — Ort & Fach nebeneinander |
| 2026-04-13 | 0.8.0+7 | O-007 abgeschlossen: 15 Tests `ImagePickerService` |
| 2026-04-13 | 0.8.0+7 | T-006 abgeschlossen: `BackupStatusService` formal abgenommen |
| 2026-04-13 | 0.8.0+6 | T-007 abgeschlossen: Performance-Test self-contained |
| 2026-04-13 | 0.8.0+5 | P-005 als erledigt markiert: Ziel-Versionen bereits in `pubspec.yaml`, `connectivity_plus`-Migration umgesetzt |
| 2026-04-12 | 0.8.0+5 | T-002 abgeschlossen: 17 Unit-Tests `PocketBaseSyncService` |
| 2026-07-09 | 0.9.9+75 | F-012.4 abgeschlossen: Titel und Buttons in Detailansicht beim ersten Klick korrekt. `super.key` in `_DetailPanelHeader`-Konstruktor ergänzt, `_detailContentKey` von `final` auf nicht-final geändert, `GlobalKey()` bei jedem `_onArtikelTap()` neu erzeugt, `ValueKey(uuid)` auf `_DetailPanelHeader` gesetzt. 3 Änderungen in `artikel_list_screen.dart`. |

---

[Zurück zur README](../README.md) | [Zur HISTORY](HISTORY.md) | [Zum Changelog](../CHANGELOG.md)