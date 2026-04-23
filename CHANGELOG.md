# 📝 Changelog

Alle wichtigen Änderungen am Projekt werden in dieser Datei dokumentiert.

## [0.9.1+29] — 2026-04-23

### Refactoring (O-010): SettingsScreen-Logik in SettingsController ausgelagert

**Ziel:** `SettingsScreen` fachlich sauber und minimal-invasiv entlasten, indem
persistente Settings-Logik, Laufzeit-State und Service-Orchestrierung in einen
neuen `SettingsController` verschoben werden.

**Umsetzung:**
- Neuer `settings_controller.dart` für testbare Settings-Logik
- `SettingsScreen` behält nur UI-nahe Verantwortung:
  - Dialoge
  - SnackBars
  - Navigation / Logout-Handling
  - Rendering
- Persistenz und Orchestrierung aus dem Screen herausgelöst:
  - Laden und Speichern der Settings
  - Dirty-Tracking
  - PocketBase-URL prüfen / speichern / zurücksetzen
  - DB-Status prüfen
  - App-Lock-Status laden / speichern
- `TextEditingController` bewusst pragmatisch im Controller belassen
  (`artikelNummerController`, `pocketBaseUrlController`)

**In den Controller verschobener State:**
- `isDatabaseEmpty`
- `isCheckingConnection`
- `pbConnectionOk`
- `appLockEnabled`
- `appLockBiometricsEnabled`
- `appLockTimeoutMinutes`
- `hasUnsavedChanges`
- `showLastSync`
- Initialwerte für Dirty-Tracking von URL und Artikelnummer

---

### Architektur-Fix (F-007): showLastSync-Status zentralisiert und entkoppelt

**Problem:** `showLastSyncNotifier` lag bisher in `settings_screen.dart`.
Dadurch musste `artikel_list_screen.dart` fachlich unnötig einen Screen
importieren, nur um auf geteilten State zuzugreifen.

**Lösung:**
- Neue Datei `lib/screens/settings_state.dart`
- Zentralisiert:
  - `showLastSyncPrefsKey`
  - `defaultShowLastSync`
  - `showLastSyncNotifier`
- `defaultShowLastSync` fachlich konsistent auf `true` vereinheitlicht
- `SettingsController` und `ArtikelListScreen` nutzen jetzt denselben
  UI-neutralen State aus `settings_state.dart`

**Ergebnis:**
- `showLastSyncNotifier` liegt nicht mehr in `settings_screen.dart`
- gemeinsame Settings-State-Abhängigkeit wurde vom Screen entkoppelt
- `ArtikelListScreen` bezieht den Toggle-State nicht mehr aus einem UI-Screen

---

### Tests: SettingsController gezielt erweitert

**Neue bzw. ergänzte Testabdeckung:**
- Dirty-State wird korrekt zurückgesetzt, wenn Werte wieder auf Initialstand gehen
- `setShowLastSync(false)` wird korrekt persistiert
- `resetPocketBaseUrl()` setzt URL zurück und entfernt ungespeicherte Änderungen
- `saveSettings()` Erfolgspfad:
  - Rückgabe `SaveSettingsResult.success`
  - neue URL übernommen
  - Dirty-State zurückgesetzt
- `saveSettings()` Reject-Pfad:
  - Rückgabe `SaveSettingsResult.pocketBaseUrlRejected`
  - URL wird auf Initialwert zurückgesetzt
  - `pbConnectionOk = false`

**Teststatus:**
- `flutter test`: **626 Tests bestanden**, **3 übersprungen** ✅

---

### Dokumentation / Ergebnis

**Fachliches Ergebnis:**
- O-010 umgesetzt: saubere, testbare Trennung von UI und Logik im Settings-Bereich
- F-007 mitbereinigt: zentraler `showLastSync`-State, konsistenter Default,
  keine unsaubere State-Kopplung mehr über `settings_screen.dart`

**Arbeitsweise:**
- bewusst minimal-invasiv
- keine neue generische Controller-Architektur eingeführt
- keine `AppLockService`-API geraten
- bestehende UI-Struktur weitgehend beibehalten

## [0.9.1+26] — 2026-04-22

### Optimierung (O-010): Flutter & Dependencies auf aktuellen Stand gebracht

**Ziel:** Alle veralteten Packages auf kompatible Versionen aktualisieren und
Breaking-API-Changes beheben.

**Aktualisierte Dependencies:**

| Package | Alt | Neu | Breaking Change |
|:--------|:----|:----|:----------------|
| `share_plus` | v9.x | v11.x | `ShareParams`-API |
| `file_picker` | v8.x | v9.x | — |
| `image_picker` | v1.x | v1.1.x | — |
| `pocketbase` | v0.21.x | v0.23.x | — |
| `flutter_lints` | v4.x | v5.x | — |

**Breaking Change behoben:**

| Problem | Falsch (vorher) | Richtig (jetzt) |
|:--------|:----------------|:----------------|
| `share_plus` v11 API | `SharePlus.instance.share([XFile(...)], text:, subject:)` | `SharePlus.instance.share(ShareParams(files:, text:, subject:))` |

**Build-Verifikation:**

| Platform | Status | Buildzeit |
|:---------|:-------|:----------|
| 🌐 Web (release) | ✅ | 72.9s |
| 🤖 Android APK (debug) | ✅ | 284.7s |
| 🐧 Linux (debug) | ✅ | — |

- `flutter analyze`: **2 Infos** (prefer_const_constructors, unkritisch) ✅
- Alle Plattformen bauen fehlerfrei ✅

---

## [0.9.0+25] — 2026-04-22

### Bugfix (B-008): Artikelliste — Card-Layout mit allen Feldern wiederhergestellt

**Problem:** `_buildArtikelTile()` wurde durch B-007-Commit auf ein minimales
`ListTile` reduziert. Artikelnummer, Beschreibung und Fach fehlten vollständig.

**Lösung:**
- `_buildArtikelTile()` → `Card` + `InkWell` mit vollständigem Feldlayout
- Artikelnummer als `#1234` in Primary-Farbe
- Beschreibung 2-zeilig mit `TextOverflow.ellipsis`
- Ort, Fach und Menge als Info-Chips mit Icons
- Auf S20 (360dp) und Tablet verifiziert

**Fixes während Umsetzung:**

| Problem | Falsch (vorher) | Richtig (jetzt) |
|:--------|:----------------|:----------------|
| Feldname | `artikel.artikelNummer` | `artikel.artikelnummer` |
| Null-Check | `.isNotEmpty` | `!= null` |
| Border-Radius Token | `borderRadiusSmall` (existiert nicht) | `borderRadiusXSmall` |
| Verbindungs-Icon Farbe | `Colors.green` hardcodiert | `AppConfig.statusColorConnected` |
| Verbindungs-Icon Fehler | `Colors.red` hardcodiert | `colorScheme.error` |
| Sync-Spinner Größe | `20` hardcodiert | `AppConfig.progressIndicatorSizeSmall` |

---

### Bugfix (B-009): Ort-Dropdown — dynamisch aus Artikelliste, in Body integriert

**Problem:** Ort-Filter-Dropdown war als Test-Stub mit hardcodierten Werten
(`'Lager 1'`, `'Lager 2'`, `'Büro'`) in die AppBar `actions` eingefügt.
Keine echten Daten, falsche Platzierung.

**Lösung:**
- Dropdown aus AppBar `actions` entfernt
- Echte Ort-Werte dynamisch aus `_artikelListe` abgeleitet (distinct, alphabetisch)
- „Alle Orte" als erster Eintrag
- ×-Reset-Button bei aktivem Filter
- Dropdown nur sichtbar wenn Orte vorhanden
- Filter-UI in Body-Suchleiste integriert
- Filterlogik mit `_gefilterteArtikel()` verbunden

---

### Bugfix (B-010): Snackbar-Feedback bei Sync-Ereignissen ergänzt

**Problem:** Nach Sync-Erfolg/-Fehler gab es kein Snackbar-Feedback.
`SyncStatus`-Listener rief bei `success` nur `_ladeArtikel()` auf.
Fehler-Pfade zeigten keine Rückmeldung.

**Lösung:**
- `_showSnackBar()` Hilfsmethode ergänzt
- Snackbar bei Sync-Start, Sync-Erfolg und Sync-Fehler
- `ScaffoldMessenger`-Erreichbarkeit nach B-009-Fix verifiziert

---

### Bugfix (B-012): Sync-Label-Overflow in AppBar behoben

**Problem:** Sync-Zeitstempel-Label hatte kein `overflow`-Handling und
konkurrierte auf 360dp mit Action-Icons um Platz.

**Lösung:**
- `overflow: TextOverflow.ellipsis` + `maxLines: 1` am Sync-Label
- `titleSpacing: 0` + `Padding` verhindert AppBar-Overflow

---

### Feature (F-006): Log-Level-Filter als Dropdown

**Problem:** Button-Reihe für Trace/Debug/Info/Warn/Error/Fatal passte auf
schmalen Displays nicht in eine Zeile.

**Lösung:**
- `DropdownButton<Level>` ersetzt horizontale Button-Reihe
- Default: `Level.error`
- Dynamische Level-Farbe im Dropdown-Container
- Leer-State mit `check_circle_outline`-Icon + Level-Name
- AppConfig-Tokens durchgängig, `textTheme.*` statt hardcodierte `fontSize`
- Aktiver-Filter-Badge zeigt gewähltes Level farbig
- Auf S20 (360dp) verifiziert

---

### Feature (F-007): Sync-Zeitstempel-Toggle in Einstellungen

**Problem:** Kein Weg, den Sync-Zeitstempel in der Artikelliste
ein- oder auszublenden.

**Lösung:**
- Toggle in Settings-Screen (`_buildPocketBaseCard()`)
- SharedPreferences-Key: `show_last_sync` (Default: `true`)
- `ValueNotifier<bool> showLastSyncNotifier` — reaktiv ohne App-Neustart
- `ArtikelListScreen` liest Präferenz in `initState()`
- Auf S20 und Tablet verifiziert

**Architektur-Entscheidung (ValueNotifier):**

| Alternative | Problem |
|:------------|:--------|
| SharedPreferences direkt in `initState()` | Nicht reaktiv — braucht App-Neustart |
| Provider / Riverpod | Overhead für eine einzelne bool-Präferenz |
| InheritedWidget | Zu viel Boilerplate |
| **ValueNotifier ✅** | Leichtgewichtig, kein extra Package, sofortige Wirkung |

F-007 — Hotfix: ValueListenableBuilder in ArtikelListScreen ergänzt; Toggle war funktionslos da Notifier nie abgehört wurde.

---

### Tests (O-009): Widget-Tests ArtikelListScreen abgeschlossen

- Import-Pfad korrigiert: `artikel.dart` → `artikel_model.dart`
- `erstelltAm` / `aktualisiertAm` als Pflichtfelder im Testartikel ergänzt
- `_pumpScreenWithArtikel()` Helper hinzugefügt (Dropdown-Test via `initialArtikel`)
- Suchfeld-Label korrigiert: `'Suche...'` → `'Suche…'` (U+2026, 1:1 aus Widget)
- Alle 15 Widget-Tests grün ✅

---

### Dokumentation
- `docs/TESTING.md` — O-006 → O-009 umbenannt, Testzahl 610 → 625,
  `artikel_list_screen_test.dart` vollständig dokumentiert, Änderungslog ergänzt
- `docs/OPTIMIZATIONS.md` — Version auf 0.9.0+25, O-009 als abgeschlossen,
  B-008/B-009/B-010/B-012 als erledigt, F-006/F-007 als erledigt,
  Wartungs-Historie aktualisiert
  

## [0.8.9+24] — 2026-04-21

### Bugfix (B-007): Intelligenter Bild-Sync & UI-Optimierung

**Problem:** Bilder wurden nicht aktualisiert, wenn bereits eine lokale Datei existierte, selbst wenn in PocketBase ein neues Bild hochgeladen wurde. Zudem war der "Letzter Sync"-Zeitstempel in der AppBar bei hellem/dunklem Hintergrund schwer lesbar.

**Lösung:**
- **`PocketBaseSyncService`**:
  - Die Methode `downloadMissingImages` prüft nun den Zeitstempel: Wenn `artikel.aktualisiertAm` neuer ist als das Erstellungsdatum der lokalen Datei, wird ein Re-Download erzwungen.
  - Erkennung von Dateinamensänderungen (PocketBase-Suffixe) integriert.
  - Automatisches Bereinigen des lokalen Artikel-Bildverzeichnisses vor dem Speichern neuer Versionen, um Datenmüll zu vermeiden.
- **`ArtikelListScreen`**:
  - Visuelle Aufwertung des Zeitstempels: Nutzung von `colorScheme.onSurface` und `FontWeight.bold` für perfekte Lesbarkeit (analog zum Ort-Filter-Dropdown).

---

## [0.8.6+21] — 2026-04-20

### Performance (P-003): Bild-Caching für Remote-Bilder
- **Integration von `cached_network_image`**: Remote-Bilder werden nun lokal zwischengespeichert, um unnötigen Netzwerk-Traffic und Flackern beim Scrollen zu vermeiden.
- **Optimierte Listen-Performance**: Die Artikelliste reagiert deutlich flüssiger, da Bilder sofort aus dem Cache geladen werden.
- **ETag-Awareness**: Der Cache erkennt Änderungen am Server über den ETag-Vergleich und aktualisiert Bilder nur bei Bedarf.

### Stabilität & Android
- **WSL2-USB Fix**: Dokumentation der USB-Initialisierung für Android-Geräte unter WSL2 (via `usbipd`).
- **Verifikation auf Samsung S20**: Erfolgreicher Test des gesamten Deployment-Flows inkl. Kamera-Anbindung auf physikalischer Hardware.

--- 

## [0.8.5+19] — 2026-04-17

### Bugfix (B-003): Bild-Download-Skip-Logik in downloadMissingImages korrigiert

**Problem: aus Test T-001.7** Bilder wurden nie heruntergeladen, weil die Skip-Bedingung
invertiert war — `dateiExistiert && dateiHatInhalt` wurde als Skip-Kriterium
ausgewertet, aber die Negation fehlte.

**Lösung:**
- `downloadMissingImages()` in `pocketbase_sync_service.dart`:
  Skip nur wenn `bildPfad.isNotEmpty && dateiExistiert && dateiHatInhalt`
  — andernfalls Download auslösen
- Logik jetzt korrekt: existierende Datei mit Inhalt → überspringen,
  alles andere → herunterladen


### Bugfix (B-004):  aus Test T-001.7 - Konflikt-Callback-Registrierung nach Navigator-Init via GlobalKey

**Problem:** `onConflictDetected`-Callback wurde vor dem Navigator-Init
registriert — `Navigator.of(context)` warf einen Fehler weil kein
`MaterialApp`-Kontext verfügbar war.

**Lösung:**
- `GlobalKey<NavigatorState>` in `main.dart` eingeführt
- Callback-Registrierung via `addPostFrameCallback` nach erstem Frame
- DB-Reopen nach App-Resume (`didChangeAppLifecycleState`) vor Sync-Start
  sicherstellt, dass SQLite-Verbindung nach Hintergrundwechsel aktiv ist


### Bugfix (B-005):  aus Test T-001.7 - ETag-basierte Konflikt-Erkennung vor PATCH in PocketBaseSyncService

**Problem:** Jeder Push überschrieb Remote-Änderungen ohne Konflikt-Check —
`updated` Timestamp des Remote-Records wurde nicht mit lokalem ETag verglichen.

**Lösung:**
- Vor jedem PATCH: Remote-Record laden, `updated`-Timestamp mit lokalem
  `etag` vergleichen
- Bei Abweichung: `onConflictDetected`-Callback aufrufen statt blind zu überschreiben
- ETag = PocketBase `updated`-Timestamp (ISO 8601), nicht Record-ID

**Konflikt-Erkennungs-Logik:**
final istKonflikt = lokalerEtag.isNotEmpty &&
    lokalerEtag != 'deleted' &&
    remoteUpdated.isNotEmpty &&
    lokalerEtag != remoteUpdated;


### Bugfix (B-006):  aus Test T-001.7 - SyncManagementScreen nutzt SyncOrchestrator statt SyncService

**Problem:** `SyncManagementScreen` rief `SyncService` direkt auf und umging
dabei den `SyncOrchestrator` — Status-Stream, Conflict-Handling und
`downloadMissingImages()` wurden nicht ausgeführt.

**Lösung:**
- `SyncManagementScreen` erhält `SyncOrchestrator`-Instanz als Parameter
- Sync-Start über `orchestrator.runOnce()` statt direktem `SyncService`-Aufruf
- Status-Updates korrekt über `syncStatus`-Stream empfangen


### Tests (T-008): ETag-Konflikt-Logik und downloadMissingImages-Check-Logik

**Neue Testdateien:**
- `test/services/pocketbase_sync_service_conflict_test.dart` — **11 Tests**
- `test/services/sync_orchestrator_test.dart` — **9 Tests** (erweitert)

**Abgedeckte Gruppen:**

| Gruppe | Tests | Szenarien |
|--------|-------|-----------|
| ConflictCallback Typedef | 1 | Typ-Kompatibilität |
| PocketBaseSyncService.onConflictDetected | 1 | Initial null |
| ETag-Konflikt-Logik (Unit) | 5 | Leer, gleich, verschieden, deleted, leerer Remote |
| downloadMissingImages Datei-Check | 3 | Leerer Pfad, nicht-existent, existiert mit Inhalt |
| ConflictCapture Integration | 1 | Callback mit korrekten Artikeln |
| ConflictCallback Typedef (Orchestrator) | 2 | Zuweisung, Exception-Handling |
| SyncStatus Enum | 2 | Vollständigkeit, exhaustiver Switch |
| ETag Grenzwerte | 2 | Whitespace-Unterschied, beide leer |

**Fixes während Test-Erstellung:**
- `Artikel()`-Konstruktor: `erstelltAm`/`aktualisiertAm` sind `DateTime`,
  nicht `String` — alle Test-Instanzen auf `DateTime.now()` umgestellt
- `dead_code`-Lint: `false && X`-Muster durch lokale Funktion mit
  Laufzeit-Parametern ersetzt (Compiler kann Wert nicht zur Compile-Zeit auflösen)
- `expected_token`: fehlende `});` nach `test()` und `group()` ergänzt

**Gesamtstand:**

| Vorher | Nachher | Differenz |
|--------|---------|-----------|
| 590 Tests, 26 Dateien | **610 Tests**, 28 Dateien | **+20 Tests**, +2 Dateien |

- `flutter analyze`: **0 Issues** ✅
- `flutter test`: **610 bestanden**, 3 übersprungen ✅

---

## [0.8.4+17] — 2026-04-14

### Optimierung (N-003): App-Icon für alle Plattformen
- Neues App-Logo (`app_logo.png`) mit Lager-/Warehouse-Design erstellt
- `flutter_launcher_icons` für alle Plattformen generiert:
  - Android: mipmap-hdpi bis mipmap-xxxhdpi
  - iOS: Alle AppIcon-Größen (20x20 bis 1024x1024)
  - Web: favicon.png, Icon-192, Icon-512, maskable Icons
  - Windows: app_icon.ico
- Adaptive Icons für Android (Vordergrund + Hintergrund)

### Optimierung (N-005): Native Splash Screen
- `flutter_native_splash` Konfiguration in `pubspec.yaml`
- Light Mode: Blauer Hintergrund (#1976d2) mit App-Logo
- Dark Mode: Dunkler Hintergrund (#121212) mit App-Logo
- Android 12+ Splash-API unterstützt (android_12 Block)
- Web Splash Screen generiert (CSS + index.html)
- Alle Plattformen: Android, iOS, Web


### UI-Verbesserung (F-004): Nextcloud-Status-Icon Farbe angleichen
- Nextcloud-Online-Icon verwendet jetzt `AppConfig.statusColorConnected`
  (Material Green 500) — konsistent mit PocketBase-Status-Icon ✅
- Farbsemantik vereinheitlicht: Grün = verbunden, Rot = getrennt, Grau = unbekannt ✅
- Kein neuer AppConfig-Token nötig — `statusColorConnected` wiederverwendet ✅

### UI-Verbesserung (F-005): Detail-Screen Felder leserlicher darstellen
**Problem:** Felder im Readonly-Modus des Detail-Screens waren schwer lesbar
(zu blass, zu wenig Kontrast durch `disabledColor`).

**Lösung:**

#### Readonly-Felder (`artikel_detail_screen.dart`)
- Alle Felder nutzen jetzt `OutlineInputBorder` statt `UnderlineInputBorder` ✅
- `filled: true` mit `fillColor: surfaceContainerLow` (Readonly) vs.
  `surface` (Edit-Modus) für klare visuelle Unterscheidung ✅
- Text-Farbe: volle Opazität via `colorScheme.onSurface` statt `disabledColor` ✅
- Readonly-Felder bleiben als schreibgeschützt erkennbar durch getönten Hintergrund ✅

#### Menge & Artikelnummer als eigene Felder
- Menge und Artikelnummer werden jetzt als `InputDecorator` mit Label dargestellt
  statt als inline `"Menge: 5"` / `"Art.-Nr.: 1001"` Text ✅
- Menge-Feld mit +/- `IconButton`s — nur im Edit-Modus sichtbar (statt disabled) ✅
- Beide Felder nebeneinander in einer `Row` (je 50% Breite) ✅

#### Dark Mode
- Kontrast in Light und Dark Mode korrekt ✅
- `surfaceContainerLow` / `surface` passen sich automatisch an ✅

### Tests
- 3 Widget-Tests in `artikel_detail_screen_test.dart` an neues Layout angepasst:
  - „Menge wird angezeigt": `find.text('Menge')` + `find.text('5')`
    statt `find.textContaining('Menge: 5')` ✅
  - „Artikelnummer wird angezeigt": `find.text('Artikelnummer')` + `find.text('1001')`
    statt `find.textContaining('Art.-Nr.: 1001')` ✅
  - „Menge erhöhen/verringern nur im Edit-Modus aktiv": Buttons existieren im
    View-Modus nicht mehr (statt disabled) ✅
- `flutter analyze`: **0 Issues** ✅
- `flutter test`: **590 bestanden**, 3 übersprungen ✅

## [0.8.4+16] — 2026-04-14

### B-001: Settings-Änderungen werden ohne Speichern übernommen — Erledigt in v0.8.3+14 ✅
- Dirty-Tracking war bereits implementiert (`_hasUnsavedChanges`, `_isDirty()`) ✅
- Unsaved-Changes-Dialog bei Zurück-Navigation vorhanden (`_onWillPop()`) ✅
- Save-Button mit Dirty-State-Kopplung vorhanden (`_buildSaveButton()`) ✅
- `onChanged`-Handler ändern nur lokalen State, keine direkten Service-Aufrufe ✅
- Alle Persistierung gebündelt in `_saveSettings()` (nur durch Save-Button) ✅
- Snackbar-Feedback nach erfolgreichem Speichern ✅
- Analyse: Kein Code-Fix nötig — Verhalten war bereits korrekt implementiert ✅

### B-002: Biometrische Authentifizierung — System-Dialog & Verfügbarkeitsprüfung — Erledigt in v0.8.3+14 ✅

**B-002.1: Nativer System-Dialog**
- `_authenticate()` ruft `auth.authenticate()` korrekt auf ✅
- `AuthenticationOptions(biometricOnly: true)` gesetzt ✅
- Automatischer Start via `addPostFrameCallback` in `initState()` ✅
- Fallback-Button für manuellen Retry vorhanden ✅
- Android: `FlutterFragmentActivity` in `MainActivity.kt` bestätigt ✅

**B-002.2: Verfügbarkeitsprüfung beim Einschalten**
- `canCheckBiometrics` + `isDeviceSupported()` wird vor Aktivierung geprüft ✅
- Bei nicht verfügbarer Biometrie: Toggle zurückgesetzt + Fehlermeldung ✅
- Probe-`authenticate()` bei Aktivierung durchgeführt ✅
- Nur bei erfolgreicher Probe wird `setBiometricsEnabled(true)` persistiert ✅



## [0.8.4+15] — 2026-04-13

### Feature: App-Lock & Biometrie Einstellungen (Settings UI)

**Ziel:** Nutzer können App-Lock, Biometrie und Sperrzeit direkt in den
Einstellungen konfigurieren.

#### SettingsScreen (`lib/screens/settings_screen.dart`)
- Neue Sektion „Sicherheit" (nur auf Nicht-Web-Plattformen sichtbar)
- Schalter „App-Lock aktivieren" – liest/schreibt `AppLockService().isEnabled`
- Schalter „Biometrie verwenden" – liest/schreibt `AppLockService().isBiometricsEnabled`
- Slider „Sperrzeit" (1–30 Minuten) – nur sichtbar wenn App-Lock aktiv,
  persistiert via `AppLockService().setTimeoutSeconds()`

#### AppLockService (`lib/services/app_lock_service.dart`)
- Neuer SharedPreferences-Key `app_lock_biometrics_enabled`
- Getter `isBiometricsEnabled` und Setter `setBiometricsEnabled(bool)`
- `init()` lädt den neuen Key (Standard: `true`)

#### AppLockScreen (`lib/screens/app_lock_screen.dart`)
- Automatische biometrische Auth wird nur gestartet, wenn
  `AppLockService().isBiometricsEnabled == true`
- Button-Text/-Icon passt sich dem Biometrie-Status an

- `flutter analyze`: **0 neue Issues**



### Feature (F-001): Biometrische Authentifizierung (Mobile)

**Ziel:** App-Sperre mit biometrischer Authentifizierung (Fingerabdruck/Gesichtserkennung)
und Fallback auf Geräte-PIN/Pattern für mobile Plattformen.

**Implementierung:**

#### AppLockService (`lib/services/app_lock_service.dart`)
- Singleton mit `WidgetsBindingObserver` für App-Lifecycle-Erkennung
- `SharedPreferences`-Persistenz für Aktivierungsstatus und Timeout-Dauer
- `didChangeAppLifecycleState()`: Erkennt Background/Foreground-Wechsel
- Inaktivitäts-Timer mit konfigurierbarer Dauer (Standard: 5 Minuten)
- `isLocked` / `isEnabled` State-Management
- `init()` / `dispose()` Lifecycle-Methoden

#### AppLockScreen (`lib/screens/app_lock_screen.dart`)
- Vollbild-Sperrbildschirm mit Lock-Icon und Statustext
- `local_auth 3.0.1` API: `biometricOnly`, `sensitiveTransaction`,
  `persistAcrossBackgrounding` (keine `AuthenticationOptions`-Klasse)
- Automatischer Start der biometrischen Authentifizierung bei Anzeige
- Fallback auf Geräte-PIN/Pattern wenn Biometrie nicht verfügbar
- `_isBiometricAvailable` Check via `canCheckBiometrics` + `isDeviceSupported()`
- Loading-State während Authentifizierung
- `onUnlocked` Callback bei erfolgreicher Entsperrung

#### Integration (`lib/main.dart`)
- `AppLockService().init()` im App-Start (nur nicht-Web)
- Plattform-Guard: `!kIsWeb`

### Feature (F-002): Konfigurierbare App-Sperrzeit

- Timeout-Dauer in `AppLockService` konfigurierbar
- Persistent in SharedPreferences gespeichert
- App sperrt automatisch nach Inaktivitäts-Timeout bei Hintergrundwechsel

### Neue Dateien
- `lib/services/app_lock_service.dart`
- `lib/screens/app_lock_screen.dart`

### Geänderte Dateien
- `lib/main.dart` — `AppLockService().init()` Aufruf hinzugefügt

### Technische Details

**local_auth 3.0.1 API:**
- Kein `options:` Parameter, kein `AuthenticationOptions`-Klasse
- Direkte Parameter: `biometricOnly`, `sensitiveTransaction`, `persistAcrossBackgrounding`
- `authMessages` mit Default-Werten für iOS, Android, Windows

**App-Lock-Flow:**

App startet → AppLockService.init()
→ SharedPreferences laden (isEnabled, timeout)
→ WidgetsBindingObserver registrieren

App → Background:
→ Zeitstempel speichern

App → Foreground:
→ Zeitdifferenz prüfen
→ Falls > timeout → isLocked = true → AppLockScreen anzeigen

AppLockScreen:
→ Biometrie verfügbar? → authenticate()
→ Nicht verfügbar? → Geräte-PIN/Pattern
→ Erfolg → onUnlocked() → isLocked = false

- `flutter analyze`: **0 Issues**
- `flutter test`: **590 bestanden**, 3 übersprungen

### Dokumentation
- `docs/OPTIMIZATIONS.md` — F-001 + F-002 als abgeschlossen markiert,
  Fortschritts-Übersicht aktualisiert (38/45 erledigt), Phase 4 auf 60%
- `CHANGELOG.md` — Aktualisiert für v0.8.2+13


## [0.8.1+12] — 2026-04-13

### Tests (T-003): Unit-Tests NextcloudClient — 39 Tests

**Ziel:** Vollständige Unit-Test-Abdeckung für `NextcloudClient` — alle WebDAV-Operationen
(HEAD, MKCOL, PROPFIND, GET, PUT, DELETE) gegen einen injizierten `MockClient`.

**Strategie:**
- `MockClient` aus `package:http/testing.dart` — kein Netzwerk nötig
- Optionaler `http.Client? client`-Parameter im Konstruktor (rückwärtskompatibel)
- Alle 8 HTTP-Stellen von Top-Level `http.*` / lokalen `http.Client()` auf `_client.*` umgestellt
- PROPFIND-XML-Responses als Inline-Fixtures
- `RemoteItemMeta`-Datenklasse separat getestet

**Abgedeckte Gruppen (39 Tests):**

| Gruppe | Tests | Szenarien |
|---|---|---|
| RemoteItemMeta | 3 | equality, copyWith, toString |
| testConnection() | 5 | 200, 404, 500, Exception, Auth-Header |
| createFolder() | 4 | 201, 405, 500, Exception |
| listItemsEtags() | 7 | 1 Item, Multi-Item, leer, 403, Non-JSON-Filter, kein ETag, custom Path |
| downloadItem() | 3 | 200, 404, Netzwerkfehler |
| uploadItem() | 5 | 201+ETag, If-Match, 412 Conflict, 500, kein ETag |
| deleteItem() | 4 | 204, 404 idempotent, 500, Exception |
| uploadAttachment() | 4 | 201+ETag, Content-Type, Default-CT, 500 |
| downloadAttachment() | 2 | 200+Bytes, 404 |
| URI-Auflösung | 2 | items-Pfad, attachments-Pfad |

**Neue Datei:**
- `test/services/nextcloud_client_test.dart`

**Geänderte Datei:**
- `lib/services/nextcloud_client.dart` — `http.Client` injizierbar via optionalem
  `client`-Parameter, alle HTTP-Aufrufe über `_client` statt Top-Level/lokale Instanzen

**Gesamtstand:**

| Vorher | Nachher | Differenz |
|---|---|---|
| 551 Tests, 25 Dateien | **590 Tests**, 26 Dateien | **+39 Tests**, +1 Datei |

- `flutter analyze`: **0 Issues**
- `flutter test`: **590 bestanden**, 3 übersprungen

### Dokumentation
- `docs/TESTING.md` — T-003 Tests dokumentiert, Gesamtzahl auf 590 aktualisiert
- `docs/OPTIMIZATIONS.md` — T-003 als abgeschlossen markiert,
  Fortschritts-Übersicht aktualisiert (36/45 erledigt)
- `CHANGELOG.md` — Aktualisiert für T-003


## [0.8.1+11] — 2026-04-13

### Tests (T-004): Widget-Tests Merge-Dialog — 18 Tests

**Ziel:** Vollständige Widget-Test-Abdeckung für den `_MergeDialog` im
`ConflictResolutionScreen` — Felder, Auswahl, Zusammenführen, Schließen.

**Strategie:**
- `_MergeDialog` ist private → Zugang über "Manuell zusammenführen"-Button
  im `ConflictResolutionScreen` (echter Nutzerfluss)
- `MockSyncService` wiederverwendet aus T-001.5
- `setSurfaceSize(1024×900)` für Side-by-Side-Karten
- Felder mit Unterschied isoliert testen (genau 1 "Remote"-Button)

**Abgedeckte Gruppen (18 Tests):**

| Gruppe | Tests | Szenarien |
|---|---|---|
| Grundstruktur | 6 | Titel, Icons, Buttons, Labels, Bild-Label |
| Konflikt-Anzeige | 4 | Lokal/Remote-Karten, Warning-Icons, identische Werte, Initialwerte |
| Feld-Auswahl | 3 | Lokal-Button, Remote-Button, manuelle Eingabe |
| Bild-Auswahl | 3 | Radio-Optionen, "Kein Bild", initiale Selektion |
| Zusammenführen | 4 | Dialog schließt, korrekte Werte, leerer Name, manuelle Edits |
| Dialog schließen | 2 | Abbrechen, Close-Icon |
| Menge-Feld | 2 | Ungültige Menge Fallback, Remote-Menge per Button |

**Neue Datei:**
- `test/widgets/merge_dialog_test.dart`

### Refactoring (O-008): Magic-Number-Arithmetik eliminiert

- Neuer Token `AppConfig.spacingSectionGap` (20.0)
- 3× `AppConfig.spacingXLarge - 4` → `AppConfig.spacingSectionGap` in
  `artikel_detail_screen.dart`

**Gesamtstand:**

| Vorher | Nachher | Differenz |
|---|---|---|
| 533 Tests, 24 Dateien | **551 Tests**, 25 Dateien | **+18 Tests**, +1 Datei |

- `flutter analyze`: **0 Issues**
- `flutter test`: **551 bestanden**, 3 übersprungen

### Dokumentation
- `docs/TESTING.md` — T-004 Tests dokumentiert, Gesamtzahl auf 551 aktualisiert
- `docs/OPTIMIZATIONS.md` — T-004 + O-008 als abgeschlossen markiert,
  Fortschritts-Übersicht aktualisiert (35/45 erledigt)
- `CHANGELOG.md` — Aktualisiert für T-004 + O-008


## [0.8.1+10] — 2026-04-13

### Tests (T-005): Unit-Tests AttachmentService — 34 Tests

**Ziel:** Vollständige Unit-Test-Abdeckung für `AttachmentService` — alle CRUD-Operationen
gegen PocketBase ohne Netzwerk und ohne Dateisystem.

**Strategie:**
- `PocketBaseService.overrideForTesting(FakePocketBase)` injiziert Fake-Client
  in den echten `AttachmentService`-Singleton — testet den **echten Code**
- `FakeAttachmentRecordService extends RecordService` mit Callback-Handlern
  (erweitert gegenüber T-002 um `perPage`/`page`/`sort`-Parameter)
- `fakeClientException()` Helper — PocketBase SDK v0.23.2 `ClientException`
  hat keinen `message:`-Parameter, sondern `originalError:`
- `PocketBaseService.dispose()` im `tearDown` räumt Singleton-State auf
- Kein `build_runner`, kein `testWidgets`, kein `tester.runAsync()` nötig

**Abgedeckte Methoden (34 Tests):**

| Methode | Tests | Szenarien |
|---|---|---|
| `getForArtikel()` | 6 | Leer, 3 Ergebnisse, Filter, perPage, PB-Fehler, fehlende Felder |
| `countForArtikel()` | 4 | 0, korrekte Anzahl, PB-Fehler, effiziente Query |
| `upload()` | 10 | Happy-Path, Body-Felder, Limit=20, Limit>20, PB-Fehler (create + count), null/leere Beschreibung, null MIME, Dateiname |
| `updateMetadata()` | 4 | Erfolg, Trimming, null→leerer String, PB-Fehler |
| `delete()` | 4 | Erfolg, korrekte ID, PB-Fehler, Netzwerkfehler |
| `deleteAllForArtikel()` | 4 | Alle löschen, leer, teilweise Fehler, getForArtikel-Fehler |
| Integration | 2 | Upload→Get-Roundtrip, Grenzwert 19 vs 20 |

**Neue Datei:**
- `test/services/attachment_service_test.dart`

**Gesamtstand:**

| Vorher | Nachher | Differenz |
|---|---|---|
| 499 Tests, 23 Dateien | **533 Tests**, 24 Dateien | **+34 Tests**, +1 Datei |

- `flutter analyze`: **0 Issues**
- `flutter test`: **533 bestanden**, 3 übersprungen

### Dokumentation
- `docs/TESTING.md` — T-005 Tests dokumentiert, Fake-Klassen-Tabelle,
  Gesamtzahl auf 533 aktualisiert, Version auf 0.8.1+10
- `docs/OPTIMIZATIONS.md` — T-005 als abgeschlossen markiert,
  Fortschritts-Übersicht aktualisiert (33/45 erledigt), Version auf 0.8.1+10
- `CHANGELOG.md` — Aktualisiert für v0.8.1+10


## [0.8.0+8] – 2026-04-13

### Changed
- **ArtikelDetailScreen (F-003):** „Ort" und „Fach" werden jetzt
  nebeneinander in einer Row (je 50 % Breite) angezeigt statt
  untereinander. Visuelle Trennung über `detailFieldSpacing`-Gap
  zwischen den OutlineInputBorder-TextFields.

### Added
- **AppConfig:** Neuer Token `detailFieldSpacing` (12.0 dp).


## [0.8.0+7] — 2026-04-13

### Tests

- **O-007:** 15 neue Tests für `ImagePickerService` nach P-001 — `PickedImage`-
  Datenklasse, `isCameraAvailable` (5 Plattformen), `openCropDialog()` Guards,
  `pickImageCamera()` alle Pfade (Gesamt: 469 → 484)
- **T-006:** `BackupStatusService` (22 Tests) formal abgenommen —
  HTTP-Mock, Farblogik Grün/Gelb/Rot, Fehlerfall Server nicht erreichbar
  *(Tests existierten seit v0.8.0, Tracking-Eintrag nachgezogen)*

### Geändert

- `ImagePickerService`: `@visibleForTesting maxFileSizeBytesOverride` und
  `_effectiveMaxFileSize`-Getter hinzugefügt — Größencheck in Tests
  ohne 10-MB-Allocation testbar
- `pickImageCamera()`: `_maxFileSizeBytes` → `_effectiveMaxFileSize`

### Dokumentation

- `OPTIMIZATIONS.md`: T-006 und O-007 als abgeschlossen markiert
  (30 → 32 erledigt, 10 → 8 offen)
- `TESTING.md`: O-007-Sektion mit Strategietabelle ergänzt,
  T-006 in Testübersicht verknüpft
  

## [0.8.0+5] - 2026-04-12

### 🧪 Tests (T-002): Unit-Tests PocketBase SyncService — 17 Tests

**Ziel:** Mock-basierte Unit-Tests für die PocketBase-Sync-Logik (Push, Pull,
Fehlerbehandlung, Bild-Download).

**Strategie:**
- Manuelle Fakes statt `@GenerateMocks` — `PocketBaseService` und
  `ArtikelDbService` sind Singletons mit Factory-Konstruktoren,
  `PocketBase`/`RecordService` haben komplexe Vererbungsketten
- `TestableSyncService` repliziert die Sync-Logik mit injizierbaren Fakes
- `FakeRecordService` erweitert `RecordService` mit exakten Methoden-Signaturen
  (PocketBase SDK v0.23.2: `skipTotal: bool`, `http.MultipartFile`)
- `RecordModel.fromJson()` statt Konstruktor-Parameter für `id`/`created`/`updated`
- Kein `build_runner` nötig — keine Code-Generierung

**Abgedeckte Szenarien (17 Tests):**

| Bereich | Tests | Was wird geprüft |
|---|---|---|
| Push: Create | 1 | Neuer Artikel → `create()`, `markSynced` mit remotePath |
| Push: Update | 1 | Bestehender Artikel → `update()`, kein `create()` |
| Push: Delete | 1 | Soft-deleted → `delete()` + `markSynced('deleted')` |
| Push: Delete (nicht remote) | 1 | Gelöscht aber remote nicht vorhanden → nur `markSynced` |
| Push: Fehlerbehandlung | 1 | Exception bei Artikel 1 → Artikel 2 wird trotzdem verarbeitet |
| Push: Auth/Owner | 1 | `owner` wird im Body gesetzt wenn authentifiziert |
| Pull: Insert | 1 | Neuer Remote-Record → `upsertArtikel()` |
| Pull: Lösch-Sync | 1 | Lokal vorhanden, remote nicht → `deleteArtikel()` |
| Pull: Leere UUIDs | 1 | Kein Lösch-Check wenn remoteUuids leer |
| syncOnce: lastSyncTime | 1 | Wird nach erfolgreichem Sync gesetzt |
| syncOnce: Fehler | 1 | Allgemeiner Fehler wird abgefangen, kein Throw |
| syncOnce: Nur Pull | 1 | Keine Pending Changes → kein Push, nur Pull |
| UUID-Sanitization | 1 | Anführungszeichen werden aus UUID entfernt (Finding 5) |
| Image: Skip-Logik | 4 | Überspringt bei fehlendem remoteBildPfad/remotePath/URL/existierendem Bild |

**Neue Datei:**
- `test/services/pocketbase_sync_service_test.dart`

**Geänderte Datei:**
- `lib/services/pocketbase_service.dart` — `PocketBaseService.testable()`
  Konstruktor hinzugefügt (`@visibleForTesting`) für Subclassing in Tests

**Gesamtstand:**

| Vorher | Nachher | Differenz |
|---|---|---|
| 451 Tests, 18 Dateien | **468 Tests**, 19 Dateien | **+17 Tests**, +1 Datei |

- `flutter analyze`: **0 Issues**
- `flutter test`: **468 bestanden**, 3 übersprungen, 1 vorbestehender Fehler

### 📚 Dokumentation
- `docs/TESTING.md` — T-002 Tests dokumentiert, Fake-Klassen-Tabelle,
  Gesamtzahl auf 468 aktualisiert, Version auf 0.8.0+5
- `docs/OPTIMIZATIONS.md` — T-002 als abgeschlossen markiert,
  Fortschritts-Übersicht aktualisiert (28/43 erledigt), Version auf 0.8.0+5
- `CHANGELOG.md` — Aktualisiert für v0.8.0+5


## [0.8.0+1] - 2026-04-11

### 🔑 Infrastruktur: Android Release-Keystore hinzugefügt

- **Neues Feature:** Implementierung eines stabilen Android Release-Keystores für GitHub Actions.
- **Ziel:** Sicherstellung der Update-Fähigkeit von Android-Apps und sauberer Signierung im Release-Workflow.
- **Details:** Ausführliche Anleitung zur Erzeugung des Keystores, Base64-Kodierung für GitHub Secrets, Workflow-Anpassung zur Dekodierung und Nutzung der `key.properties`-Datei, sowie Gradle-Konfiguration für das Signieren von Release-Builds.
- **Sicherheit:** Keystore-Dateien und Passwörter werden niemals im Repository gespeichert (`.gitignore` aktualisiert), sondern sicher über GitHub Secrets verwaltet.
- **Dokumentation:** Detaillierte Schritte und Hinweise sind in der neuen Datei `ANDROID_RELEASE_KEYSTORE.md` zu finden. Ein Verweis wurde in der `README.md` hinzugefügt.


## [0.8.0] - 2026-04-10

### 🎉 Hauptfeature: Kaltstart-Bug Fix

#### Problem
Nach einem Kaltstart (App-Daten gelöscht, neue PocketBase-URL konfiguriert)
blieb die Artikelliste leer, obwohl der Sync im Hintergrund erfolgreich lief.
Bilder wurden nicht heruntergeladen und der Benutzer sah keine Rückmeldung.

#### Ursachen (4 Stück)
1. **Sync-UI-Entkopplung:** ArtikelListScreen wusste nicht, wann der Sync
   abgeschlossen war → Liste wurde nie automatisch neu geladen
2. **Fehlender Bild-Download:** PocketBase-Sync übertrug nur Metadaten
   (remoteBildPfad), lud aber keine Bilddateien herunter
3. **Globaler Image-Cache-Clear:** `imageCache.clear()` verwarf bei jeder
   Bildänderung ALLE gecachten Bilder → Flackern der gesamten Liste
4. **Sofortiger UI-Wechsel nach Setup:** Setup-Screen wechselte sofort
   zur leeren Artikelliste, ohne auf den initialen Sync zu warten

### ✨ Neue Features

#### SyncStatusProvider Interface
- Neues `SyncStatusProvider`-Interface für lose Kopplung zwischen
  `SyncOrchestrator` und UI-Komponenten
- `ArtikelListScreen` hört auf `SyncStatus`-Events und lädt bei
  `success` automatisch die Artikelliste neu
- `FakeSyncStatusProvider` als Test-Double für Widget-Tests
- Sync-Indikator („Synchronisiere Artikel…") bei leerer Liste
  während laufendem Sync

#### Automatischer Bild-Download
- Neue Methode `downloadMissingImages()` in `PocketBaseSyncService`
- Prüft nach jedem Record-Sync alle Artikel auf fehlende lokale Bilder
- Lädt Bilder von der PocketBase File-API herunter (mit Auth-Header)
- Speichert im App-Cache-Verzeichnis
- Neue DB-Methode `setBildPfadByUuidSilent()` — setzt nur `bildPfad`,
  ohne `updated_at`/`etag` zu ändern → kein erneuter Push

#### PocketBase-Bild-Fallback (Mobile/Desktop)
- `_LocalThumbnail` zeigt bei fehlendem lokalen Bild ein PocketBase-
  Thumbnail via `CachedNetworkImage` an (Kaltstart-Überbrückung)
- `ArtikelDetailBild` mit `_buildPbDetailFallback()` für Vollbild-
  Fallback aus PocketBase

#### Setup-Flow mit Sync-Abwarten
- Setup-Screen zeigt Lade-Overlay („Erstmalige Synchronisation…")
  während der initiale Sync läuft
- UI wechselt erst zur Artikelliste, wenn Sync abgeschlossen ist
- Buttons im Setup-Screen werden während Sync deaktiviert

### 🔧 Technisch

#### Neue Dateien
- `lib/services/sync_status_provider.dart` — Interface
- `lib/screens/list_screen_cache_io.dart` — Gezieltes Image-Evict (Mobile/Desktop)
- `lib/screens/list_screen_cache_stub.dart` — No-op für Web
- `test/helpers/fake_sync_status_provider.dart` — Test-Double
- `test/services/sync_status_provider_test.dart` — Unit-Tests

#### Geänderte Dateien
- `lib/services/sync_orchestrator.dart`
  — `implements SyncStatusProvider`
  — `downloadMissingImages()` in `runOnce()` eingebunden
- `lib/services/pocketbase_sync_service.dart`
  — `downloadMissingImages()`, `_buildImageUrl()`, `_buildAuthHeaders()`
  — Neue Imports: `dart:io`, `http`, `path_provider`
- `lib/services/artikel_db_service.dart`
  — Neue Methode `setBildPfadByUuidSilent()`
- `lib/screens/artikel_list_screen.dart`
  — `syncStatusProvider` Parameter + `StreamSubscription`
  — Sync-Indikator bei leerer Liste + laufendem Sync
  — Gezieltes `evictLocalImage()` statt `imageCache.clear()`
  — Conditional Import für Cache-Helper
- `lib/main.dart`
  — `_onServerConfigured()`: Sync abwarten vor UI-Wechsel
  — `_buildHomeWithBackground()`: Orchestrator als `syncStatusProvider`
- `lib/screens/server_setup_screen.dart`
  — `_isSyncingAfterSetup` + Lade-Overlay mit `Stack`
  — Buttons disabled während Sync
- `lib/widgets/artikel_bild_widget.dart`
  — `_LocalThumbnail`: PB-URL-Fallback via `CachedNetworkImage`
  — `ArtikelDetailBild`: `_buildPbDetailFallback()`

#### Performance-Verbesserung
- `_clearImageCache()` evicted jetzt nur das geänderte Bild + Thumbnail
  statt den gesamten Image-Cache zu leeren
- Conditional Import (`list_screen_cache_io.dart` / `_stub.dart`)
  für plattformübergreifende Kompatibilität

### 📚 Dokumentation
- `CHANGELOG.md` — Aktualisiert für v0.8.0
- `OPTIMIZATIONS.md` — Kaltstart-Fix dokumentiert, Version auf 0.8.0
- `TESTING.md` — Neue Tests dokumentiert, Gesamtzahl aktualisiert
- `ARCHITECTURE.md` — SyncStatusProvider Interface dokumentiert
- `DATABASE.md` — `setBildPfadByUuidSilent()` und Bild-Download dokumentiert
- `LOGGER.md` — Neue Log-Events dokumentiert

### ⚙️ Technische Details

**Bild-Fallback-Kette (Mobile/Desktop):**

| Priorität | Quelle | Geschwindigkeit |
|---|---|---|
| 1 (höchste) | Lokales Thumbnail (`thumbnailPfad`) | ⚡ Sofort |
| 2 | Lokales Vollbild (`bildPfad`) | ⚡ Sofort |
| 3 | PocketBase-URL via CachedNetworkImage | 🌐 Netzwerk |
| 4 (niedrigste) | Placeholder-Icon | ⚡ Sofort |

**Sync-Datenfluss:**
SyncOrchestrator.runOnce()
→ _emit(SyncStatus.running)
→ syncOnce() (Push + Pull)
→ downloadMissingImages()
→ _emit(SyncStatus.success)
↓
syncStatus Stream (broadcast)
↓
ArtikelListScreen._syncSubscription
↓
_ladeArtikel() → UI aktualisiert

### 🧪 Tests

#### Neue Test-Dateien (v0.8.0)
- `test/models/attachment_model_test.dart` — **30 Tests**
  Konstruktor, `fromPocketBase()` mit Null/Typ-Koercion, `dateiGroesseFormatiert`
  (B/KB/MB-Grenzen), `typLabel`, `istBild`, `copyWith()`, Gleichheit, Konstanten
- `test/utils/attachment_utils_test.dart` — **28 Tests**
  `validateAttachment()` (Größe, Limit, MIME, Erweiterung, Leer, Prioritäten),
  `mimeTypeFromExtension()`, `iconForMimeType()`, `colorForMimeType()`,
  `AttachmentValidation`
- `test/services/backup_status_test.dart` — **22 Tests**
  `fromJson()` mit Null/Typ-Koercion, `isSuccess`/`isError`, `lastBackupTime` UTC,
  `ageCategory` (fresh/aging/critical), `ageText` (Singular/Plural/Warnung),
  `BackupStatus.unknown`, `BackupAge` Enum

#### Gesamtstand
| Vorher | Nachher | Differenz |
|---|---|---|
| 347 Tests, 15 Dateien | **451 Tests**, 18 Dateien | **+104 Tests**, +3 Dateien |

- `flutter analyze`: **0 Issues**
- `flutter test`: **451 bestanden**, 3 übersprungen
- `docs/TESTING.md` auf v0.8.0 aktualisiert

## [0.7.8] - 2026-04-09 

### ✨ Verbessert - UI Ansicht

#### 🖼️ Artikel-Detail-Screen
- **Artikelname editierbar:** Name kann direkt im Detail-Screen geändert werden
  — neues Textfeld als erstes Eingabefeld, AppBar-Titel aktualisiert sich live
- **Crop-Button:** Nach Bildauswahl erscheint ein „Zuschneiden"-Button
  direkt unter dem Bild (nur im Edit-Modus, nur wenn neues Bild gewählt)
- **Aufgeräumter Body:** Bild-Buttons, Anhänge-Button und Speichern-Button
  aus dem Body entfernt — alle Aktionen jetzt übersichtlich in der AppBar

#### 🎛️ AppBar-Aktionen (Detail-Screen)
- **Bild wählen / Kamera:** Icons erscheinen nur im Edit-Modus
- **Anhänge:** Immer sichtbar, mit Badge-Zähler bei vorhandenen Anhängen
- **Ändern / Speichern:** Edit- und Save-Icon ersetzen den Body-Button
- **PDF-Export & Löschen:** Unverändert, jetzt konsistent in der AppBar

#### 📝 Artikel-Erfassen-Screen
- **Großbuchstabe am Anfang:** `textCapitalization: sentences` für Name,
  Beschreibung, Ort und Fach — Menge und Artikelnummer bleiben numerisch
- **Menge-Feld:** Beim Antippen wird der gesamte Inhalt automatisch
  markiert — die voreingestellte `0` muss nicht mehr manuell gelöscht werden
- **Bild-Buttons kompakter:** „Bilddatei wählen" und „Kamera" jetzt als
  schlanke `IconButton` statt breiter `FilledButton.tonalIcon`

#### 🔍 Artikel-Liste
- **QR-Scanner neben Suchfeld:** Scanner-Button direkt als `IconButton.filled`
  rechts neben dem Suchfeld — kein separater FAB mehr nötig
- **„Neuer Artikel" in AppBar:** `Icons.add` in der AppBar ersetzt den
  `FloatingActionButton.extended` — spart Platz, wirkt aufgeräumter
- **DB-Icon grün bei Verbindung:** PocketBase-Verbindungsicon zeigt nun
  `AppConfig.statusColorConnected` (Material Green 500) statt
  `colorScheme.tertiary` — eindeutigeres visuelles Feedback

### 🔧 Technisch

- `AppConfig.statusColorConnected` (`Color(0xFF4CAF50)`) als neues
  semantisches Token für den Online-Status ergänzt
- `import 'package:flutter/material.dart' show BoxFit, Color, EdgeInsets;`
  in `app_config.dart` um `Color` erweitert
- `AnhaengeSektion.build()` gibt `SizedBox.shrink()` zurück —
  Sheet wird ausschließlich über AppBar-Icon geöffnet
- `FocusNode _mengeFocus` mit automatischer Vollauswahl in
  `artikel_erfassen_screen.dart` eingeführt
- `_nameController` in `artikel_detail_screen.dart` vollständig in
  `initState`, `dispose`, `_speichernWeb`, `_speichernMobile` und
  `_generateArtikelDetailPdf` integriert
- `flutter analyze`: **0 Issues**

## [0.7.7+5] - 2026-04-08

### Test (O-006): Widget-Tests ArtikelErfassenScreen

11 Widget-Tests für `artikel_erfassen_screen.dart`.

**Render:** Pflichtfeld-Labels, Bilddatei-Button, Kamera-Button-Sichtbarkeit,
Speichern + Abbrechen vorhanden.

**Validierung:** Leere Pflichtfelder, Name < 2 Zeichen,
Artikelnummer < 1000, Menge 0 gültig.

**Abbrechen:** Ohne Änderungen kein Dialog, nach Eingabe Dialog,
Weiter bearbeiten schließt Dialog.

### Feature (P-002): Suche Debounce + DB-Suche

**Problem:** Jeder Tastendruck löste sofort einen clientseitigen Filter
über die gesamte geladene Liste aus — bei großen Beständen spürbar träge.

**AppConfig — neue Tokens:**
- `searchDebounceDuration = 300ms`
- `searchResultLimit = 100`

**artikel_list_screen.dart:**
- `_onSuchbegriffChanged()`: Timer(300ms) — feuert erst nach Tipp-Pause
- `_fuehreSucheAus()`: Mobile → `_db.searchArtikel()` (SQL LIKE),
  Web → clientseitig filtern
- Skeleton (count: 4) während laufender DB-Suche
- Pagination-Footer ausgeblendet bei aktiver Suche
- Leermeldung zeigt Suchbegriff an

**Neuer Such-Flow:**
Tastendruck → 300ms Pause → DB-Suche
Feld leeren → sofort zurück zur paginierten Liste
Suche aktiv → kein Pagination-Nachladen

## [0.7.7+4] - 2026-04-07

### Feature (M-005): Pagination für Artikelliste

**Problem:** Alle Artikel wurden beim Start auf einmal aus SQLite geladen —
bei großen Beständen führte das zu spürbaren Verzögerungen und hohem
Speicherverbrauch.

**AppConfig — neue Pagination-Tokens**
- `paginationPageSize = 30`
- `paginationScrollThreshold = 200.0`

**artikel_list_screen.dart**
- `ScrollController` mit `_onScroll()`-Listener
- `_ladeArtikel()`: Reset + erste Seite laden
- `_ladeNaechsteSeite()`: Offset-basiertes Nachladen mit Guard gegen
  Doppel-Requests und aktive Suche
- `ListView.builder`: Lade-Footer (`CircularProgressIndicator`) am
  Listenende solange `_hasMore = true`
- Web: `_hasMore = false` — `getFullList()` lädt weiterhin alles auf einmal

### Chore (O-005): Deprecated Code entfernt

Seit M-012 nicht mehr verwendete Dateien gelöscht.

**Entfernt:**
- `lib/screens/_dokumente_button.dart`
- `lib/screens/_dokumente_button_stub.dart`
- `lib/utils/dokumente_utils.dart`
- `test/dokumente_utils_test.dart`
- `test/widgets/dokumente_button_test.dart`

`cached_network_image` bleibt — wird in `artikel_bild_widget.dart`,
`artikel_detail_screen.dart` und `attachment_list_widget.dart` genutzt.

**Neuer Flow (Mobile/Desktop):**

## [0.7.7+2] - 2026-04-07

### Performance (P-001): Kamera-Vorschau-Delay auf Android behoben

**Problem:** Kamera-Capture auf Android verursachte Multi-Sekunden-Delays vor der
Vorschau, da Crop-Dialog + Re-Encode `pickImageCamera()` synchron blockierten.
Bildbreite war zusätzlich hardcodiert auf 1600px.

**AppConfig — neue Kamera-Tokens**
- `cameraTargetMaxWidth = 800`
- `cameraTargetMaxHeight = 800`
- `cameraImageQuality = 85`

**ImagePickerService**
- `pickImageCamera()` übergibt `maxWidth`/`maxHeight`/`imageQuality` aus AppConfig
  → reduziert Dateigröße direkt an der Quelle
- Automatischer Crop-Dialog entfernt — gibt Bytes sofort nach Capture zurück
  (`ensureTargetFormat(crop: false)`)
- `openCropDialog()` als public static Methode verfügbar

**ArtikelErfassenScreen**
- `_cropImage()`: öffnet `ImageCropDialog`, führt `ensureTargetFormat` auf Ergebnis
  aus und ruft `setState`
- „Zuschneiden" `OutlinedButton` rechts unterhalb der Vorschau,
  nur sichtbar wenn `_bildBytes != null`

**Neuer Flow:**

## [0.7.7+1] - 2026-04-06

### Tests (T-001): Konfliktlösungs-Tests — Widget-Tests abgeschlossen
- **T-001.3** — `SyncService.detectConflicts()`: 9 Tests mit Mockito-Mocks
  (`MockNextcloudClient`, `MockArtikelDbService`)
  - ETag-Übereinstimmung → kein Konflikt
  - ETag-Abweichung → Konflikt erkannt, `downloadItem()` aufgerufen
  - Mehrere Konflikte gleichzeitig
  - Fehlerbehandlung: DB-Fehler, `downloadItem()`-Fehler (graceful)
  - `detectedAt` liegt im erwarteten Zeitfenster
- **T-001.4** — `_determineConflictReason()` via `detectConflicts()`: 15 Tests
  - Gleiche Zeitstempel → `'Gleichzeitige Bearbeitung'`
  - |diff| < 60s → `'Zeitnahe Bearbeitung (Xs Unterschied)'`
  - Grenzfall 60s → `'Lokale Version neuer (1m)'`
  - Lokal neuer: Minuten, Stunden, Tage
  - Remote neuer: Minuten, Stunden
- **T-001.5** — `ConflictResolutionScreen` Widget-Tests: 20 Tests
  - Leere Liste, Fortschrittsanzeige, LinearProgressIndicator
  - `useLocal` / `useRemote` aktiviert `'Auflösen'`-Button
  - `applyConflictResolution()` wird korrekt aufgerufen
  - `skip` ruft `applyConflictResolution()` nicht auf
  - Pop-Result enthält `resolved`/`skipped` als `Map<String, dynamic>`
  - Multi-Konflikt-Navigation (`1/2` → `2/2`)
  - Hilfe-Dialog öffnen/schließen
  - Merge-Dialog öffnet sich

### Bugfix
- `RenderFlex`-Overflow (+4px) in Widget-Tests behoben:
  `setSurfaceSize(1024×900)` + `addTearDown(reset)` in `pumpConflictScreen()`

### Dokumentation
- `docs/TESTING.md` — T-001 auf 77 Tests aktualisiert, Kategorie `Unit + Widget`,
  `setSurfaceSize`-Besonderheit dokumentiert, Gesamtzahl auf 298 aktualisiert
- `OPTIMIZATIONS.md` — T-001 Unit/Widget-Tests als abgeschlossen markiert,
  Version auf 0.7.7+1, Datum auf 06.04.2026
- `HISTORY.md` — Meilenstein v0.7.7+1 dokumentiert
- `CHANGELOG.md` — Aktualisiert

## [0.7.7] - 2026-04-05

### Release-Zusammenfassung
Qualitäts-Release: Zentrales Error Handling, Loading States, Input Validation, umfangreiche Unit-Tests und neue Test-Dokumentation.

### Feature (M-003): Zentrales Error Handling — Abgeschlossen
- Neue `AppException`-Hierarchie (`sealed class`): `NetworkException`, `ServerException`,
  `AuthException`, `SyncException`, `StorageException`, `ValidationException`, `UnknownException`
- Neuer `AppErrorHandler` mit:
  - `classify()` — übersetzt rohe Exceptions automatisch
  - `log()` — level-bewusstes Logging (warning vs. error)
  - `showSnackBar()` — einfacher Fehler-SnackBar
  - `showSnackBarWithDetails()` — SnackBar + Details-Dialog-Button
  - `showErrorDialog()` — modaler Fehler-Dialog
  - `_getSuggestions()` — kontextabhängige Lösungsvorschläge
- `sync_conflict_handler.dart`: rohe `$e`-Strings → `AppErrorHandler`
- `SocketException` / `HandshakeException` / `TimeoutException` / `ClientException` automatisch klassifiziert
- Lint-Fixes: `instantiate_abstract_class`, `unnecessary_null_comparison`, `unreachable_switch_case`

### Feature (M-004): Loading States — Abgeschlossen
- Zentrales `AppLoadingOverlay`-Widget mit optionalem Text
- `AppLoadingIndicator` für Inline-Bereiche
- `AppLoadingButton` ersetzt alle manuellen Spinner-in-Button-Konstrukte
- `ArtikelSkeletonTile` + `ArtikelSkeletonList` mit Shimmer-Animation
- `artikel_list_screen.dart`: Skeleton statt `CircularProgressIndicator`
- `artikel_detail_screen.dart`: Overlay beim Speichern und Löschen
- `sync_management_screen.dart`: Overlay während aktivem Sync
- 10 neue `AppConfig`-Tokens für Skeleton und Overlay

### Feature (M-006): Input Validation — Abgeschlossen
- Pflichtfelder: Name, Ort, Fach mit Inline-Fehlermeldungen
- Name: Mindestlänge 2 Zeichen, max. 100 Zeichen
- Menge: Nur positive Ganzzahlen (≥ 0), max. 999.999, via `FilteringTextInputFormatter`
- Artikelnummer: Automatisch vorgegeben (≥ 1000), manuell änderbar
- Duplikat-Check: Name + Ort + Fach (Kombination), lokal + PocketBase
- Duplikat-Check: Artikelnummer, lokal + PocketBase
- 5 neue `AppConfig`-Tokens für Validierungsgrenzen
- Neue DB-Methoden: `existsKombination()`, `existsArtikelnummer()`

### Tests (O-002): Unit-Tests für Core-Utilities — Abgeschlossen (128 neue Tests)
**ArtikelDbService (75 Tests)**
- `sqflite_common_ffi` mit `inMemoryDatabasePath` — kein Dateisystem nötig
- `injectDatabase()` (`@visibleForTesting`) für saubere Test-Isolation
- `ArtikelDbServiceTestHelper` — wiederverwendbarer In-Memory-Setup
- Abgedeckte Methoden: `insertArtikel`, `getAlleArtikel`, `updateArtikel`, `deleteArtikel`,
  `getArtikelByUUID`, `getArtikelByRemotePath`, `getPendingChanges`, `markSynced`,
  `upsertArtikel`, `searchArtikel`, `existsKombination`, `existsArtikelnummer`,
  `setLastSyncTime`, `getLastSyncTime`, `isDatabaseEmpty`, `getMaxArtikelnummer`,
  `deleteAlleArtikel`, `insertArtikelList`, `updateBildPfad`, `updateRemoteBildPfad`,
  `setBildPfadByUuid`, `setThumbnailPfadByUuid`, `setThumbnailEtagByUuid`,
  `setRemoteBildPfadByUuid`, `getUnsyncedArtikel`

**ArtikelModel (64 Tests)**
- Konstruktor, `isValid()`, `toMap()`, `fromMap()`, Roundtrip, `copyWith()`, `==`/`hashCode`/`toString()`

**ImageProcessingUtils (30 Tests)**
- Kompression, Rotation, Thumbnail-Generierung vollständig abgedeckt
- `rotateClockwise()`: quadratische + rechteckige Bilder, 4 Richtungen
- Randwerte: leere Byte-Arrays, ungültige Formate

**UuidGenerator (23 Tests)**
- Eindeutigkeit: 10.000 UUIDs ohne Kollision
- RFC-4122 V4 Format-Validierung (8-4-4-4-12, version-bit, variant-bit)
- `isValidV4()`: gültige + ungültige Eingaben, Leerstring, Sonderzeichen

### Bugfix
- `getUnsyncedArtikel()` nutzte `""` statt `''` für SQL-Leerstring-Literale
  (auf Mobile nicht sichtbar, von `sqflite_common_ffi` korrekt abgelehnt)

### Dokumentation
- `docs/TESTING.md` — Neues Dokument: alle Tests beschrieben, lokaler Aufruf erklärt
- `OPTIMIZATIONS.md` — O-002 als abgeschlossen markiert, Version auf 0.7.7
- `HISTORY.md` — Meilensteine v0.7.6+x und v0.7.7 dokumentiert
- `README.md` — Link zu TESTING.md ergänzt

## [0.7.5+1] - 2026-04-03

### Feature (M-008): Backup-Status im Settings-Screen anzeigen — Abgeschlossen
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

## [0.7.5+0] - 2026-04-02

### Feature (M-007): UI für Konfliktlösung — Abgeschlossen
- **M-007 als erledigt markiert**: `ConflictResolutionScreen` war bereits vollständig
  implementiert (seit O-004 Batch 2), fehlte nur in der OPTIMIZATIONS.md-Dokumentation
- **K-003 umbenannt**: Alte M-007 (Artikelnummer & Indizes) zu K-003 umbenannt,
  um Doppelung zu beseitigen

### Bestehende Implementierung (verifiziert)
- `ConflictResolutionScreen` mit Side-by-Side-Vergleich (Lokale vs. Remote Version)
- `ConflictData`-Klasse und `ConflictResolution`-Enum in `conflict_resolution_screen.dart`
- Multi-Konflikt-Navigation mit Fortschrittsanzeige und LinearProgressIndicator
- `_MergeDialog` für manuelle Feld-für-Feld-Zusammenführung mit Bild-Auswahl
- Entscheidungs-Callbacks: `useLocal`, `useRemote`, `merge`, `skip`
- Vollständige Integration mit `SyncConflictHandler` und `SyncService`
- Hilfe-Dialog mit Erklärung aller Konfliktarten und Lösungsoptionen

### Tests (T-001)
- **Neue Testdatei:** `app/test/conflict_resolution_test.dart`
  - 37 Unit-Tests in 6 Gruppen
  - T-001.1: `ConflictData` — Konstruktor, Felder, Null-Handling (11 Tests)
  - T-001.2: `ConflictResolution` Enum — Werte, Index, `byName` (6 Tests)
  - T-001.4: Konflikt-Grund-Szenarien (5 Tests)
  - T-001.extra: Feld-Vergleiche über Artikel-Properties (11 Tests)
  - T-001.extra: ConflictData in Collections und Resolution-Tracking (4 Tests)
- **T-001 als neue Aufgabe** in OPTIMIZATIONS.md erstellt (manuelle Integrationstests ausstehend)

### Dokumentation
- `OPTIMIZATIONS.md` — M-007 nach ✅ verschoben, K-003 umbenannt, T-001 erstellt,
  Fortschritts-Übersicht aktualisiert (17/28 erledigt), Version auf 0.7.5+0
- `CHANGELOG.md` — Aktualisiert für v0.7.5+0
- `HISTORY.md` — Meilenstein v0.7.5+0 dokumentiert

## [0.7.4+7] - 2026-04-02

### Refactoring (O-004): UI-Hardcoded Werte migrieren — Batch 5 (Cleanup, O-004 abgeschlossen ✅)
- **~80 Hardcodes migriert** in 11 Dateien, **~41 bewusst beibehalten** (dokumentiert)
- O-004 abgeschlossen: ~560 von ~600 Hardcodes eliminiert (~93%)
- Kein visuelles Redesign — gleiche Optik, sauberer Code

#### list_screen_mobile_actions.dart — 17 Hardcodes → 0
- `Colors.orange/red` (SnackBars) → `colorScheme.secondary/error`
- `Colors.blue/green/orange/purple` (Dialog-Icons) → `colorScheme.primary/tertiary/secondary`
- `SizedBox(width: 8)` → `AppConfig.spacingSmall`

#### nextcloud_settings_screen.dart — 21 Hardcodes → 0
- `Colors.green/red/orange` (Verbindungstest-SnackBars) → `colorScheme.tertiary/error/secondary`
- `Colors.blue/white` (Button-Styling) → `FilledButton` (nutzt Theme automatisch)
- `SizedBox(width: 18, height: 18)` → `AppConfig.iconSizeSmall`
- `fontSize: 14` → `textTheme.bodyMedium`
- Alle `EdgeInsets`/`SizedBox` → AppConfig-Tokens

#### qr_scan_screen_mobile_scanner.dart — 6 migriert, 6 bewusst beibehalten
- `fontSize: 18/14` → `textTheme.bodyLarge/bodyMedium`
- `BorderRadius.circular(16)` → `AppConfig.borderRadiusXLarge`
- `width: 3` → `AppConfig.strokeWidthThick`
- Bewusst beibehalten: `Colors.black54/black/white/red` (Kamera-Overlay-Maskierung)

#### image_crop_dialog.dart — 6 migriert, 5 bewusst beibehalten
- `Colors.red` (Fehler-Icon) → `colorScheme.error`
- `Colors.white` (Text auf schwarzem BG) → `colorScheme.onInverseSurface`
- `SizedBox(width: 18, height: 18)` → `AppConfig.iconSizeSmall`
- `size: 48` → `AppConfig.iconSizeXLarge`
- Alle `EdgeInsets`/`SizedBox` → AppConfig-Tokens
- Bewusst beibehalten: `Colors.black` + `Color.fromRGBO` (Crop-Library-Parameter)

#### artikel_erfassen_screen.dart — 12 Hardcodes → 0
- `const spacing = 12.0` → `AppConfig.spacingMedium`
- `SizedBox(width: 12)` → `AppConfig.spacingMedium`
- `BorderRadius.circular(8)` → `AppConfig.borderRadiusMedium`
- `SizedBox(width: 18, height: 18)` → `AppConfig.iconSizeSmall`
- `strokeWidth: 2` → `AppConfig.strokeWidthMedium`
- `EdgeInsets.all(16)` → `AppConfig.spacingLarge`

#### list_screen_web_actions.dart — 8 Hardcodes → 0
- `Colors.orange/red` (SnackBars) → `colorScheme.secondary/error`

#### artikel_bild_widget.dart — 3 migriert, 2 bewusst beibehalten
- `strokeWidth: 2` → `AppConfig.strokeWidthMedium`
- `strokeWidth: 1.5` → `AppConfig.strokeWidthThin`
- Bewusst beibehalten: `Colors.grey` in Platzhalter-Icons (neutrale Farbe auf AppImages-BG)

#### nextcloud_resync_dialog.dart — 7 Hardcodes → 0
- `Colors.red/green/orange` (SnackBars) → `colorScheme.error/tertiary/secondary`
- `SizedBox(width: 16)` → `AppConfig.spacingLarge`
- `fontSize: 12` → `textTheme.bodySmall`
- `fontWeight: FontWeight.bold` → `textTheme.bodyMedium?.copyWith(fontWeight: ...)`

#### Bewusst beibehalten (dokumentiert, ~41 Stellen)
- `detail_screen_io.dart` (3): Platzhalter-Farben ohne BuildContext
- `list_screen_io.dart` (3): Platzhalter-Farben ohne BuildContext
- `list_screen_mobile_actions_stub.dart` (4): Stub ohne Widget-Tree-Kontext
- `_dokumente_button.dart` (18): Deprecated (M-012-Cleanup)
- `qr_scan_screen_mobile_scanner.dart` (6): Kamera-Overlay-Maskierung
- `image_crop_dialog.dart` (5): Crop-Library-Parameter + Vorschau-BG
- `artikel_bild_widget.dart` (2): Platzhalter-Icons

### Dokumentation
- `THEMING.md` — Batch-5-Status aktualisiert, O-004 als abgeschlossen markiert
- `OPTIMIZATIONS.md` — O-004 als abgeschlossen markiert, Gesamtfortschritt ~93%
- `CHANGELOG.md` — Aktualisiert für v0.7.4+7

## [0.7.4+6] - 2026-04-02

### Refactoring (O-004): UI-Hardcoded Werte migrieren — Batch 4 (Attachment & Setup, ~92 Hardcodes)
- **92 Hardcodes eliminiert** in 4 Dateien + 13 neue AppConfig-Tokens
- Dark Mode funktioniert jetzt korrekt in allen Attachment- und Auth-Widgets
- Kein visuelles Redesign — gleiche Optik, sauberer Code

#### AppConfig (`app/lib/config/app_config.dart`)
- 13 neue Design-Tokens ergänzt:
  - **Icon-Sizes:** `iconSizeXLarge` (48), `iconSizeXXLarge` (64)
  - **Layout:** `loginFormMaxWidth` (400), `setupFormMaxWidth` (480),
    `loginLogoSize` (80), `buttonHeight` (48), `exampleLabelWidth` (85)
  - **Progress:** `progressIndicatorSizeSmall` (20)
  - **Attachments:** `attachmentImageWidth` (56), `attachmentImageHeight` (48),
    `attachmentIconSize` (28), `attachmentIconContainerSize` (48),
    `uploadAreaIconSize` (40)

#### attachment_upload_widget.dart — 28 Hardcodes eliminiert
- `Colors.red/red.shade*` → `colorScheme.error/errorContainer/onErrorContainer`
- `Colors.grey` → `colorScheme.onSurfaceVariant`
- `Colors.white` (Progress-Color) → entfernt (const CircularProgressIndicator)
- `fontSize: 12/13/18` → `textTheme.bodySmall/titleMedium`
- Alle `EdgeInsets`/`SizedBox`/`BorderRadius` → AppConfig-Tokens
- `withOpacity` → `withValues`

#### attachment_list_widget.dart — 23 Hardcodes eliminiert
- `Colors.red` (Löschen-Button, SnackBar) → `colorScheme.error`
- `Colors.grey` (Leertext, Datei-Info) → `colorScheme.onSurfaceVariant`
- `withOpacity(0.1)` → `withValues(alpha: AppConfig.opacitySubtle)`
- `fontSize: 12` → `textTheme.bodySmall`
- `size: 48/28/32/40` → `AppConfig.attachmentIconContainerSize/attachmentIconSize/progressIndicatorSize/uploadAreaIconSize`
- Alle `EdgeInsets`/`SizedBox`/`BorderRadius` → AppConfig-Tokens
- Loading/Empty/Error-States nutzen jetzt `const` wo möglich

#### server_setup_screen.dart — 23 Hardcodes eliminiert
- `Colors.blue.shade*` → `colorScheme.primaryContainer/onPrimaryContainer`
- `Colors.green.shade*` → `colorScheme.tertiaryContainer/onTertiaryContainer`
- `Colors.red.shade*` → `colorScheme.errorContainer/onErrorContainer`
- `Colors.white` (Progress-Color) → `colorScheme.onPrimary`
- `size: 64` → `AppConfig.iconSizeXXLarge`
- `maxWidth: 480` → `AppConfig.setupFormMaxWidth`
- Alle `EdgeInsets`/`SizedBox`/`BorderRadius` → AppConfig-Tokens
- Alle `withOpacity` → `withValues`

#### login_screen.dart — 18 Hardcodes eliminiert
- `Colors.red.shade*` → `colorScheme.errorContainer/onErrorContainer`
- `Colors.grey[600]` → `colorScheme.onSurfaceVariant`
- `size: 80` → `AppConfig.loginLogoSize`
- `height: 48` → `AppConfig.buttonHeight`
- `fontSize: 14/16` → `textTheme.bodyMedium/titleMedium`
- `horizontal: 32.0` → `AppConfig.spacingXXLarge`
- Alle `withOpacity` → `withValues`

### Dokumentation
- `THEMING.md` — 13 neue Tokens dokumentiert, Batch-4-Status aktualisiert
- `CHANGELOG.md` — Aktualisiert für v0.7.4+6
- `CHECKLIST.md` — Batch 4 als erledigt markiert, Gesamtfortschritt ~82%

---

## [0.7.4+5] - 2026-04-02

### Refactoring (O-004): UI-Hardcoded Werte migrieren — Batch 3 (Artikel-Cluster, ~98 Hardcodes)
- **98 Hardcodes eliminiert** in 3 Dateien
- Dark Mode funktioniert jetzt korrekt in allen Artikel-bezogenen Widgets
- Kein visuelles Redesign — gleiche Optik, sauberer Code
- Keine neuen AppConfig-Tokens nötig — alle Werte auf bestehende gemappt

#### artikel_detail_screen.dart — 36 Hardcodes eliminiert
- Colors.white/grey[100] (fillColor) → colorScheme.surface/surfaceContainerLow
- Colors.black (labelStyle/textStyle) → entfernt (Theme greift automatisch)
- Colors.grey[200]/grey[400] (Platzhalter) → colorScheme.surfaceContainerHighest/onSurfaceVariant
- Colors.red (Löschen-Button) → colorScheme.error
- Colors.white/black (Vollbild) → colorScheme.onInverseSurface + Colors.black (BG bleibt schwarz)
- Alle EdgeInsets/SizedBox → AppConfig-Tokens
- BorderRadius.circular(12/16) → AppConfig.cardBorderRadiusLarge/borderRadiusXLarge
- AnhaengeSheet: Handle-Bar + Header nutzen jetzt colorScheme + textTheme

#### artikel_list_screen.dart — 31 Hardcodes eliminiert
- Colors.green[600]/red[600]/grey[600] (Status-Icons) → colorScheme.tertiary/error/onSurfaceVariant
- Colors.red (SnackBar) → colorScheme.error
- Colors.grey (Leertext) → textTheme.titleSmall + colorScheme.onSurfaceVariant
- Colors.blueGrey[600] (Artikelnummer) → textTheme.labelSmall + colorScheme.onSurfaceVariant
- Colors.blue/green/red/orange (Dialog-Icons) → colorScheme.primary/tertiary/error/secondary
- fontSize: 11/12/16 → textTheme.labelSmall/bodySmall/bodyLarge
- PopupMenuItem PDF-Icon: Colors.red → colorScheme.error

#### sync_conflict_handler.dart — 31 Hardcodes eliminiert
- Colors.green/orange/grey/red/blue (SnackBar/Status) → colorScheme.*
- Colors.white (SnackBar textColor) → colorScheme.onTertiary/onError
- Colors.grey[100/300] (Error-Dialog) → colorScheme.surfaceContainerLow/outlineVariant
- buildSyncButton: Colors.blue/white → entfernt (FAB nutzt Theme)
- buildSyncStatus: Statische Methode → _SyncStatusCard Widget (BuildContext für colorScheme)
- Alle EdgeInsets/SizedBox → AppConfig-Tokens

### Dokumentation
- `THEMING.md` — Batch-3-Status aktualisiert
- `CHANGELOG.md` — Aktualisiert für v0.7.4+5
- `CHECKLIST.md` — Batch 3 als erledigt markiert, Gesamtfortschritt ~67%

---

## [0.7.4+4] - 2026-04-01

### Refactoring (O-004): UI-Hardcoded Werte migrieren — Batch 2 (Sync-Cluster)
- **193 Hardcodes eliminiert** in 4 Dateien + 2 neue AppConfig-Tokens
- Dark Mode funktioniert jetzt korrekt in allen Sync-bezogenen Widgets
- Kein visuelles Redesign — gleiche Optik, sauberer Code

#### AppConfig (`app/lib/config/app_config.dart`)
- 2 neue Design-Tokens ergänzt:
  - **Layout:** `infoLabelWidthSmall` (80), `buttonPaddingVertical` (12)

#### app_theme.dart — 10 Hardcodes eliminiert
- `EdgeInsets`-Werte in Component-Themes → `AppConfig.spacingLarge/spacingMedium`
- `BorderRadius.circular(12)` → `AppConfig.cardBorderRadiusLarge`
- `fontSize: 20` → `AppConfig.fontSizeXXLarge`
- ListTile `contentPadding` → `AppConfig.listTilePadding`

#### conflict_resolution_screen.dart — 82 Hardcodes eliminiert
- `Colors.orange/green/blue/purple/grey` → `colorScheme.*`
- AppBar nutzt jetzt Standard-Theme (keine manuellen Farben)
- Merge-Dialog: `Colors.blue/green.withValues` → `colorScheme.*Container`
- Radio-Buttons: `Colors.blue/grey` → `colorScheme.primary/outlineVariant`
- 6 duplizierte Status-Container-Patterns konsolidiert

#### sync_error_widgets.dart — 59 Hardcodes eliminiert
- `_getSeverityColor()` nutzt jetzt `BuildContext` + `colorScheme`
- `Colors.red[700]/orange[700]/blue[700]/grey[700]` → `colorScheme.*`
- `SyncErrorBanner`: `Colors.red[100]/orange[100]` → `colorScheme.*Container`
- Technische Details: `Colors.grey[100]` → `colorScheme.surfaceContainerLow`

#### sync_management_screen.dart — 43 Hardcodes eliminiert
- AppBar nutzt jetzt Standard-Theme (keine manuellen Farben)
- `Colors.blue/orange/red/green` → `colorScheme.primary/secondary/error/tertiary`
- Alle Section-Titel → `textTheme.titleMedium`

### Dokumentation
- `THEMING.md` — 2 neue Tokens dokumentiert, Batch-2-Status aktualisiert
- `OPTIMIZATIONS.md` — Batch 2 als erledigt markiert, Gesamtfortschritt aktualisiert
- `HISTORY.md` — Meilenstein v0.7.4+4 dokumentiert

---

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

## [0.7.4+0] - 2026-03-30

### Sicherheit (H-002)
- **CORS-Konfiguration:** `CORS_ALLOWED_ORIGINS` wird jetzt als `--origins` Flag
  an PocketBase übergeben
- Neues `entrypoint.sh` ersetzt inline CMD im Dockerfile
- Wildcard-Warnung im Container-Log für Entwicklungsumgebungen
- Produktion erzwingt explizite Origins (Container startet nicht ohne)

### Infrastruktur
- Portainer Stack an Produktions-Setup angeglichen (NPM, Netzwerk-Isolation)
- `docker-compose.production.yml` (Traefik) entfernt — Nginx Proxy Manager ist Standard
- `.env.production` korrigiert: öffentliche URL statt Docker-interner URL

### Dokumentation
- DEPLOYMENT.md: CORS-Abschnitt mit Regeln, Prüfung und Domain-Umzug-Anleitung
- DEPLOYMENT.md: Portainer Stack mit NPM und Environment Variables
- OPTIMIZATIONS.md: H-002 als abgeschlossen markiert

---

## [0.7.3] — 2026-03-30

### Added — M-009: Login-Flow & Authentifizierung
- **Login-Screen** (`lib/screens/login_screen.dart`): E-Mail + Passwort Login mit
  Validierung, Loading-State, Fehlermeldungen und optionalem Passwort-Reset-Dialog
- **Auth-Gate in `main.dart`**: Automatische Prüfung des Auth-Status beim App-Start
  mit 4-stufiger Priorität (Setup → Auth-Check → Login → App)
- **Auto-Login**: Token-Refresh beim App-Start via `refreshAuthToken()` —
  PocketBase authStore persistiert Tokens automatisch
- **Logout**: Bestätigungs-Dialog im Settings-Screen mit Navigator-Cleanup
- **Benutzer-Info**: Account-Card im Settings-Screen zeigt angemeldeten User,
  Status-Badge und Auth-Status in der Info-Card
- **Token-Refresh** (`PocketBaseService.refreshAuthToken()`): Erneuert abgelaufene
  Tokens, räumt authStore bei Fehler auf
- **Passwort-Reset** (`PocketBaseService.requestPasswordReset()`): Sendet
  Reset-E-Mail über PocketBase
- **API-Regeln Migration** (`1700000000_set_auth_rules.js`): Collections `artikel`
  und `attachments` erfordern jetzt Authentifizierung (`@request.auth.id != ""`)
  mit Rollback-Migration (Regeln auf offen)

### Changed
- `PocketBaseService`: Neue Methoden `refreshAuthToken()`, `requestPasswordReset()`,
  `currentUserEmail` Getter hinzugefügt
- `main.dart`: Auth-Gate integriert — Sync startet erst nach erfolgreichem Login
- `SettingsScreen`: Optionaler `onLogout` Callback, Account-Card mit Logout-Button

### Security
- API-Regeln für `artikel` und `attachments` von offen auf Auth-pflichtig umgestellt
- Nur authentifizierte Benutzer können Daten lesen, erstellen, bearbeiten und löschen

--- 

## [0.7.2] — 2026-03-29

### Hinzugefügt
- **M-012: Dateianhänge (Attachments)** — Dokumente an Artikel anhängen
  - PocketBase Collection `attachments` mit File-Upload, Bezeichnung, Beschreibung
  - `AttachmentService` — CRUD-Operationen gegen PocketBase (plattformunabhängig)
  - `AttachmentModel` — Datenmodell mit MIME-Type-Erkennung und Größenformatierung
  - `AttachmentUploadWidget` — Upload-Dialog mit Dateiauswahl, Validierung und Fortschritt
  - `AttachmentListWidget` — Anhang-Liste mit Download, Bearbeiten und Löschen
  - `AnhaengeSektion` im Artikel-Detail-Screen mit Badge-Counter
  - Validierung: Max 20 Anhänge/Artikel, Max 10 MB/Datei, erlaubte MIME-Types
- **M-007: Artikelnummer-Anzeige** — Artikelnummer in Listen- und Detailansicht
  - Automatische Vergabe beim Erstellen (Startwert 1000, +1 pro Artikel)
  - `_getNextArtikelnummer()` prüft lokale DB und PocketBase für höchste Nummer
- **PocketBase Migration** `1774811640_updated_attachments.js` — API-Regeln für Attachments geöffnet und Sync-Felder (uuid, etag, device_id, deleted, updated_at) ergänzt

### Geändert
- **`artikel_model.dart`** — `toPocketBaseMap()` sendet jetzt `updated_at` für korrekten Sync
- **`artikel_detail_screen.dart`** — Zeigt `artikel.artikelnummer` statt `artikel.id` als Art.-Nr.
- **`artikel_list_screen.dart`** — Artikelnummer-Zeile in Listenansicht ergänzt
- **`attachment_service.dart`** — UUID wird beim Upload automatisch generiert (Pflichtfeld in PB-Schema)

### Behoben
- **Attachment-Upload 400-Fehler** — `uuid`-Pflichtfeld fehlte im Upload-Body
- **Attachment-Upload 400-Fehler** — API-Regeln erforderten Auth, App hat keinen Login-Flow
- **Artikelnummer nicht in PocketBase** — `toPocketBaseMap()` sendete `artikelnummer` bereits korrekt, aber `updated_at` fehlte
- **Falsche Art.-Nr. in Detailansicht** — Zeigte SQLite-ID statt fachliche Artikelnummer

### Dokumentation
- `CHANGELOG.md` — Aktualisiert für v0.7.2
- `DEPLOYMENT.md` — Attachments-Collection und offene API-Regeln dokumentiert
- `ARCHITECTURE.md` — Attachments-Collection im Datenmodell ergänzt
- `DATABASE.md` — Attachments-Schema und Sync-Felder dokumentiert
- `HISTORY.md` — Meilenstein v0.7.2 dokumentiert
- `OPTIMIZATIONS.md` und `CHECKLIST.md` zusammengelegt
- `M-009` (Login-Flow) als neuer offener Punkt hinzugefügt

### Bekannte Einschränkungen
- **Kein Login-Flow**: Alle PocketBase-Collections haben offene API-Regeln. Für Produktionsumgebungen mit öffentlichem Zugang muss ein Login-Screen implementiert werden (siehe M-009)

---

## [0.7.1] — 2026-03-27

### Hinzugefügt
- **H-003: Automatisierte Backups** — Dedizierter Backup-Container für Produktions-Deployments
  - `server/backup/Dockerfile` — Alpine-basierter Container mit Cron, SQLite3 und SMTP-Support
  - `server/backup/backup.sh` — Backup-Logik mit SQLite WAL-Checkpoint, tar.gz-Archivierung und Integritätsprüfung
  - `server/backup/entrypoint.sh` — Automatische Cron- und SMTP-Konfiguration aus Umgebungsvariablen
  - `scripts/restore.sh` — Interaktives Restore-Script mit Sicherheitskopie und Healthcheck
- **Backup-Container als Service** in `docker-compose.prod.yml`
  - Konfiguration vollständig über `.env.production` (kein manueller Crontab nötig)
  - Rotation alter Backups (konfigurierbar, Standard: 7 Tage)
  - E-Mail-Benachrichtigung (SMTP) bei Erfolg oder Fehler
  - Webhook-Benachrichtigung (Slack, Discord, Gotify, etc.)
  - Status-JSON (`last_backup.json`) für zukünftige App-Anzeige (siehe M-008)
  - Initiales Backup beim ersten Container-Start
- **Backup-Variablen** in `.env.example` und `.env.production.example` ergänzt
  - `BACKUP_ENABLED`, `BACKUP_CRON`, `BACKUP_KEEP_DAYS`
  - `BACKUP_NOTIFY`, `BACKUP_SMTP_*`, `BACKUP_WEBHOOK_URL`
- **M-008** als neuer Optimierungspunkt: Backup-Status im Settings-Screen der App anzeigen

### Geändert
- **DEPLOYMENT.md** — Architektur-Diagramm um Backup-Container erweitert; Backup-Abschnitt komplett überarbeitet mit Container-Dokumentation, Konfigurationsbeispielen und Restore-Anleitung
- **ARCHITECTURE.md** — Architektur-Diagramm um Backup-Container erweitert; Projektstruktur um `scripts/`, `server/backup/`, `server/pb_backups/` und `server/npm/` ergänzt
- **OPTIMIZATIONS.md** — H-003 als abgeschlossen markiert; M-008 hinzugefügt; Fortschritts-Tabelle aktualisiert (7 von 20 erledigt)
- **Maintenance-Workflow** (`.github/workflows/flutter-maintenance.yml`) — `working-directory: ./app` ergänzt, Flutter-Version gepinnt, Linux-Build hinzugefügt, `--exclude-tags performance` ergänzt

### Behoben
- **Maintenance-Workflow** lief im falschen Verzeichnis (Root statt `app/`)
- **`flutter pub outdated`** brach den Workflow ab wenn Pakete veraltet waren (jetzt `|| true`)
- **Windows-Build-Artefakt-Pfad** korrigiert (`app/build/windows/x64/runner/Release`)

--- 

## [0.7.0] - 2026-03-27

### 🎉 Hauptfeatures

#### K-004: Runtime-Konfiguration für PocketBase-URL
- **Server-URL zur Laufzeit konfigurierbar**: Die PocketBase-URL muss nicht mehr zwingend beim Build per `--dart-define` gesetzt werden
- **Setup-Screen beim Erststart**: Wenn keine URL konfiguriert ist, wird ein Einrichtungsbildschirm angezeigt
- **Kein Crash bei fehlender URL**: Die App startet immer, auch ohne vorkonfigurierte Server-URL
- **Alle Plattformen**: Setup-Screen funktioniert auf Mobile, Desktop und Web

### ✨ Neue Features

#### Server-Setup-Screen
- Eingabefeld für Server-URL mit Validierung (Schema, Format, Host)
- Verbindungstest über PocketBase Health-Endpoint
- Beispiel-URLs für Produktion, LAN-Test und Android-Emulator
- Localhost-Warnung auf Android mit Alternativvorschlägen
- Visuelles Feedback (Erfolg/Fehler) beim Verbindungstest

#### Flexible Build-Konfiguration
- `--dart-define=POCKETBASE_URL=...` ist jetzt vollständig optional
- Optionaler URL-Default für Demo- oder Kunden-Builds über CI/CD
- Release-Workflow mit `pocketbase_url`-Input für vorkonfigurierte Builds

### 🔧 Verbesserungen

#### AppConfig
- Placeholder-URLs (`your-production-server.com`, `192.168.178.XX`) als Fallbacks entfernt
- `validateForRelease()` und `validateConfig()` werfen nicht mehr bei fehlender URL
- Leerer String statt Placeholder wenn keine URL-Quelle verfügbar

#### PocketBaseService
- Neues `needsSetup`-Flag: Gibt `true` zurück wenn keine brauchbare URL konfiguriert ist
- Neues `hasClient`-Flag: Prüft ob ein funktionsfähiger Client vorhanden ist
- `initialize()` crasht nie mehr bei fehlender oder ungültiger URL
- Placeholder-URLs werden nicht als gültig behandelt
- `resetToDefault()` behandelt leeren Default korrekt

#### App-Start (main.dart)
- Setup-Screen-Weiche nach `PocketBaseService().initialize()`
- Sync-Services werden nur bei vorhandenem Client initialisiert
- Health-Check nur bei vorhandenem Client
- Nahtloser Übergang vom Setup-Screen zur normalen App

#### Settings-Screen
- `_resetPocketBaseUrl()` behandelt leeren Default korrekt
- Benutzerfreundliche Meldung wenn kein Build-Default vorhanden

#### CI/CD-Workflows
- `docker-build-push.yml`: Placeholder `POCKETBASE_URL=https://your-production-server.com` entfernt
- `docker-build-push.yml`: URL optional über GitHub Secret oder Workflow-Input
- `release.yml`: Neuer optionaler `pocketbase_url`-Input für alle Plattform-Builds
- Release Notes: Hinweis auf Setup-Screen beim ersten Start

### 📚 Dokumentation

- CHANGELOG.md aktualisiert
- HISTORY.md aktualisiert
- DEPLOYMENT.md um Runtime-Konfiguration ergänzt
- INSTALL.md um Setup-Screen-Anleitung ergänzt

### ⚙️ Technische Details

**URL-Prioritätskette (alle Plattformen):**

| Priorität | Quelle | Web | Mobile/Desktop |
|---|---|---|---|
| 1 (höchste) | SharedPreferences / localStorage | ✅ | ✅ |
| 2 | `window.ENV_CONFIG` (Runtime) | ✅ | ❌ |
| 3 | `--dart-define=POCKETBASE_URL` | ✅ | ✅ |
| 4 | Kein Wert → Setup-Screen | ✅ | ✅ |

**Geänderte Dateien:**
- `app/lib/config/app_config.dart` — Placeholder entfernt, Validierung entschärft
- `app/lib/services/pocketbase_service.dart` — needsSetup, robuste initialize()
- `app/lib/main.dart` — Setup-Screen-Weiche
- `app/lib/screens/settings_screen.dart` — _resetPocketBaseUrl angepasst
- `.github/workflows/docker-build-push.yml` — Placeholder entfernt
- `.github/workflows/release.yml` — pocketbase_url-Input

**Neue Dateien:**
- `app/lib/screens/server_setup_screen.dart` — Ersteinrichtungs-Screen

--- 

### 📦 Migration von 0.3.0 auf 0.7.0

1. **Keine Breaking Changes für Endbenutzer**: Bestehende Installationen mit gespeicherter URL in SharedPreferences funktionieren weiterhin ohne Änderung.

2. **Build-Prozess**: `--dart-define=POCKETBASE_URL=...` ist jetzt optional. Bestehende Build-Skripte funktionieren weiterhin, können aber vereinfacht werden.

3. **CI/CD**: Falls `POCKETBASE_URL` als GitHub Secret gesetzt ist, wird es weiterhin als Default verwendet. Andernfalls erscheint der Setup-Screen beim ersten Start.

4. **Docker/Web**: Die bestehende Runtime-Config über `window.ENV_CONFIG` und `docker-entrypoint.sh` funktioniert unverändert.

---

## [0.3.0] - 2026-03-22

### 🎉 Hauptfeatures

#### H-001 & H-005: Release-Automatisierung & Image-Strategie
- **Automatische Release-Notes**: GitHub Release enthält automatisch generierte Release-Notes mit Download-Links
- **Image-Tagging-Strategie**: Vollständige Dokumentation für SemVer-Tags und Docker-Images
- **Production-Images**: docker-compose.prod.yml nutzt jetzt vorgebaute Images (kein lokaler Build)

#### M-007: Artikelnummer & Datenbank-Optimierung
- **Artikelnummer-Feld**: Eindeutige Artikelnummer (1-99999) für jeden Artikel
- **Unique Constraint**: Verhindert doppelte Artikelnummern
- **Performance-Indizes**: 5 neue Indizes für schnelle Abfragen (bis 10.000 Artikel)
- **Volltextsuche**: Optimierte Suche über Name, Beschreibung und Artikelnummer

### ✨ Neue Features

#### M-002: AppLogService Integration
- Debug-Prints in artikel_erfassen_screen.dart durch AppLogService ersetzt
- Debug-Prints in artikel_erfassen_io.dart durch AppLogService ersetzt
- Konsistente Logging-Strategie im gesamten Projekt

#### N-004: Roboto Font
- Roboto als Standard-Schriftart implementiert (via google_fonts)
- Funktioniert auf allen Plattformen (Web, Mobile, Desktop)
- Automatisches Font-Loading ohne Asset-Downloads

### 🔧 Verbesserungen

#### Dokumentation
- `docs/IMAGE_TAGGING_STRATEGIE.md` - Vollständige Image-Tagging-Dokumentation
- `docs/M-007_ARTIKELNUMMER_INDIZES.md` - Detaillierte Datenbank-Optimierungen
- `.env.production.example` erweitert mit VERSION-Variable
- `PRIORITAETEN_CHECKLISTE.md` aktualisiert (20/30 Punkte abgeschlossen)

#### Dependencies (N-001, N-002)
- `mocktail` entfernt (wurde nicht genutzt, mockito beibehalten)
- `dependency_overrides` ausführlich dokumentiert (Grund, Issue-Link, Prüfplan)
- Exakte Version für connectivity_plus_platform_interface (2.0.0)

#### CI/CD (H-001)
- Release-Notes werden automatisch generiert
- Download-Links für Android APK, AAB und Windows-Build
- Plattform-spezifische Installationsanleitungen

### 📚 Dokumentation

- Vollständige Image-Tagging-Strategie dokumentiert
- Performance-Analyse für 10.000 Artikel (O(log n) via B-Tree)
- Verifizierungs-Anleitung für produktionsbereite Deployments
- Dependency-Override mit Issue-Tracking und Wartungsplan

### 🔒 Datenintegrität

- **Unique Constraint**: Artikelnummern sind eindeutig (WHERE NOT deleted)
- **Performance-Indizes**: 
  - `idx_unique_artikelnummer` - Eindeutigkeit garantieren
  - `idx_search_name` - Namens-Suche optimieren
  - `idx_search_beschreibung` - Beschreibungs-Suche optimieren
  - `idx_sync_deleted_updated` - Sync-Abfragen beschleunigen
  - `idx_uuid` - UUID-Lookups optimieren

### ⚙️ Technische Details

**Datenbank-Migration:**
- Neue Migration: `1774186524_added_artikelnummer_indexes.js`
- Rollback-fähig (up/down migration)
- Automatische Ausführung beim PocketBase-Start

**Flutter-Model:**
- `Artikel.artikelnummer` (int?, optional für Abwärtskompatibilität)
- Vollständige Serialisierung (toMap, fromMap, toPocketBaseMap)
- Nullable int parsing (_parseIntNullable helper)

**Docker-Compose:**
- `docker-compose.prod.yml` nutzt nur `image:` (kein `build:`)
- ENV-Variable `VERSION` für flexible Image-Tags
- Unterstützt GHCR und Docker Hub

---

## [0.2.0] - 2026-03-21

### 🎉 Hauptfeatures

#### Automatische PocketBase-Initialisierung
- **K-003 BEHOBEN**: PocketBase wird beim ersten Start vollautomatisch initialisiert
- Admin-Benutzer wird automatisch erstellt (konfigurierbar via ENV-Variablen)
- Collections werden automatisch angelegt
- Migrationen werden automatisch angewendet
- Keine manuelle Konfiguration mehr erforderlich

#### Sicherheits-Verbesserungen
- **K-002 BEHOBEN**: API Rules erfordern jetzt Authentifizierung
- Alle Operationen (list, view, create, update, delete) benötigen Login
- Produktionssichere Konfiguration out-of-the-box
- Keine offenen API-Endpoints mehr

#### Produktions-Deployment
- Vollständige Produktions-Deployment-Dokumentation
- Docker Stack Support für Swarm-Deployments
- GitHub Actions Workflow für automatische Image-Builds
- Pre-built Images über GitHub Container Registry
- Vereinfachter Deployment-Prozess

### ✨ Neue Features

#### Docker & Deployment
- Custom PocketBase Dockerfile mit Initialisierung
- Automatisches Admin-User-Setup via ENV-Variablen
- `docker-stack.yml` für Swarm-Deployments
- `.env.production.example` Template
- GitHub Actions Workflow für Docker Hub/GHCR
- Deployment-Test-Script (`test-deployment.sh`)

#### Dokumentation
- `QUICKSTART.md` - Schnelleinstieg für Dev & Prod
- `docs/PRODUCTION_DEPLOYMENT.md` - Vollständige Produktions-Anleitung
- README aktualisiert mit automatischer Initialisierung
- Umgebungsvariablen-Dokumentation erweitert

#### Konfiguration
- PocketBase Admin-Credentials via ENV konfigurierbar
- Sichere API Rules vorkonfiguriert
- Migrations automatisch angewendet
- Konsistente ENV-Variablen für Dev/Test und Produktion

### 🔧 Verbesserungen

#### Projektstruktur
- `docker-compose.prod.yml` von `app/` nach Root verschoben
- Konsistente Verzeichnisstruktur
- Migrations-Ordner korrekt gemountet
- Init-Script mit ausführbaren Berechtigungen

#### Docker Compose
- Beide Compose-Files nutzen custom PocketBase Image
- Healthchecks erweitert (längere `start_period`)
- Bessere Service-Dependencies
- Klarere Kommentare und Dokumentation

#### Sicherheit
- API Rules mit Authentifizierungspflicht
- Admin-Passwort-Warnung prominent dokumentiert
- `.env` und `.env.production` nicht in Git
- Security-Checklisten in Dokumentation

### 🐛 Bugfixes

- PocketBase Migrations werden jetzt automatisch angewendet
- Collections werden beim ersten Start korrekt erstellt
- API Rules werden korrekt aus Migration übernommen
- Admin-User-Erstellung funktioniert zuverlässig

### 📚 Dokumentation

- Vollständige Produktions-Deployment-Anleitung hinzugefügt
- README aktualisiert mit automatischer Initialisierung
- Umgebungsvariablen vollständig dokumentiert
- Troubleshooting-Guides erweitert
- Quick Start Guide erstellt
- Test-Script für Deployment-Validierung

### 🔒 Sicherheit

- **KRITISCH**: API Rules erfordern jetzt Authentifizierung (K-002)
- Admin-Passwörter werden nicht mehr im Code gespeichert
- ENV-Dateien werden nicht ins Git committed
- Sichere Defaults für Produktion

### ⚠️ Breaking Changes

- **API Rules**: Authentifizierung ist jetzt erforderlich!
  - Bestehende Clients müssen sich anmelden
  - Öffentlicher Zugriff nicht mehr möglich
  - Falls gewünscht: Manuell in PocketBase Admin anpassen

- **Umgebungsvariablen**: Neue Pflicht-Variablen
  - `PB_ADMIN_EMAIL` - für Admin-User-Erstellung
  - `PB_ADMIN_PASSWORD` - für Admin-User-Erstellung
  - Siehe `.env.production.example` für Details

### 📦 Migration von älteren Versionen

Wenn Sie von einer Version vor 1.1.0 upgraden:

1. **Backup erstellen:**
   ```bash
   docker compose exec pocketbase /pb/pocketbase backup /pb_backups
