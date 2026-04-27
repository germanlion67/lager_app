# 📐 System-Architektur & Design

Dieses Dokument beschreibt die technische Architektur der **Lager_app**, die Datenstrukturen und die grundlegenden Design-Entscheidungen.

---
```text
┌────────────────────────────────────────────────────────────────┐
│                          INTERNET                              │
└───────────────────────┬────────────────────────────────────────┘
                        │
                        │ HTTPS (443) / HTTP (80)
                        │
┌───────────────────────▼────────────────────────────────────────┐
│                 Nginx Proxy Manager                            │
│  ┌──────────────────────────────────────────────────────┐      │
│  │ • SSL Termination (Let's Encrypt / automatisch)      │      │
│  │ • Reverse Proxy                                      │      │
│  │ • Security Headers                                   │      │
│  │ • SPA Routing (Flutter Web)                          │      │
│  └──────────────────────────────────────────────────────┘      │
└────────┬────────────────────────────┬──────────────────────────┘
         │                            │
         │ :8081                      │ :8080
         │ (internal)                 │ (internal)
┌────────▼──────────────┐   ┌────────▼────────────────────────────┐
│  Flutter Web Frontend │   │  PocketBase Backend                 │
│  ┌─────────────────┐  │   │  ┌───────────────────────────────┐  │
│  │ Caddy Server    │  │   │  │ • REST API                    │  │
│  │ • Static Files  │  │   │  │ • Admin UI                    │  │
│  │ • SPA Routing   │  │   │  │ • File Storage                │  │
│  │ • env-config.js │  │   │  │ • Real-time Subscriptions     │  │
│  └─────────────────┘  │   │  │ • CORS (--origins Flag)       │  │
│                       │   │  └───────────────────────────────┘  │
└───────────────────────┘   │  ┌───────────────────────────────┐  │
                            │  │ Auto-Initialization           │  │
                            │  │ • Create Admin User           │  │
                            │  │ • Apply Migrations            │  │
                            │  │ • Setup Collections           │  │
                            │  └───────────────────────────────┘  │
                            └───┬─────────────────────────────────┘
                                │
                        ┌───────▼───────┐
                        │  Volumes      │
                        │  • pb_data    │◄──── Backup-Container
                        │  • pb_public  │      • Cron (konfigurierbar)
                        │  • pb_backups │      • SQLite WAL-Checkpoint
                        └───────────────┘      • tar.gz + Rotation
                                               • E-Mail / Webhook
                                               • last_backup.json
```

## 🏗️ High-Level Architektur

Die Lager_app folgt einem **Hybrid-Cloud-Modell** (Offline-First). Sie ist so konzipiert, dass sie auf mobilen Geräten ohne permanente Internetverbindung funktioniert, während die Web-Version direkt mit dem Backend kommuniziert.

### Plattform-Strategie

| Komponente      | Mobile (Android/iOS)                  | Desktop (Linux/Win)             | Web (Docker/Caddy)                     |
| :-------------- | :------------------------------------ | :------------------------------ | :------------------------------------- |
| **Frontend**    | Flutter Native                        | Flutter Native                  | Flutter Web (SPA)                      |
| **Lokale DB**   | SQLite (`sqflite`)                    | SQLite (FFI)                    | Keine (Direktzugriff)                  |
| **Dateisystem** | Pfad-basiert (Images, Docs)           | Pfad-basiert (Images, Docs)     | Browser Blob/Memory                    |
| **Sync-Logik**  | Hintergrund-Worker (15 min)           | Timer-basiert (15 min)          | Nicht erforderlich                     |
| **Kamera/Scanner**| `image_picker`, `mobile_scanner`      | Nicht verfügbar                 | Nicht verfügbar                        |
| **App-Lock**    | `local_auth` (Biometrie + PIN)        | Nicht verfügbar                 | Nicht verfügbar                        |
| **Logging**     | Datei + Konsole                       | Datei + Konsole                 | Nur Konsole                            |
| **Runtime-Config**| `--dart-define` / `SharedPreferences` | `--dart-define` / `SharedPreferences` | `window.ENV_CONFIG` (Caddy)            |

---
## 🚀 App-Einstieg & Navigation (main.dart)
### Initialisierungsreihenfolge
1. `AppConfig.init()` — Runtime-Konfiguration laden (Web: window.ENV_CONFIG)
2. `AppConfig.validateForRelease() + validateConfig()`
3. `FlutterError.onError` + `PlatformDispatcher.instance.onError` — globale Fehler
4. `platform.initDesktopDatabase()` — SQLite-FFI-Init (nur Native)
5. `PocketBaseService().initialize()` — PB-Client aufbauen
6. `AppLockService().init()` — Biometrie-Service (nur Native)
7. `runApp(MyApp())`

### Screen-Prioritätskette (_buildHome())
| Priorität | Screen              | Bedingung                                     |
| :-------- | :------------------ | :-------------------------------------------- |
| 1         | `ServerSetupScreen` | Keine PB-URL konfiguriert                     |
| 2         | Lade-Spinner        | Auth-Token wird geprüft (Auto-Login)          |
| 3         | `LoginScreen`       | Nicht eingeloggt (außer `PB_DEV_MODE=1`)      |
| 4         | `AppLockScreen`     | App gesperrt (Biometrie-Overlay über Haupt-App) |
| 5         | `ArtikelListScreen` | Normalzustand                                 |

### PocketBase URL — Prioritätskette
| Priorität | Quelle                             | Beschreibung                                  |
| :-------- | :--------------------------------- | :-------------------------------------------- |
| 1         | `SharedPreferences` (`pocketbase_url`) | Persistiert vom Setup-Screen                  |
| 2         | `RuntimeEnvConfig.pocketBaseUrl()` | Web: `window.ENV_CONFIG.POCKETBASE_URL`       |
| 3         | `--dart-define=POCKETBASE_URL=...` | Build-Argument                                |
| 4         | `ServerSetupScreen`                | Erststart-Eingabe durch den Nutzer            |

### Dev-Mode
```bash
flutter run --dart-define=PB_DEV_MODE=1  # überspringt Login-Screen
```

--- 

## 🔐 Authentifizierung & App-Lock
### Login-Flow (M-009, ab v0.7.3)
  - `LoginScreen`: E-Mail/Passwort, Validierung, Loading-State
  - Auto-Login beim Start: Token-Refresh via `PocketBaseService.refreshAuthToken()`
  - Logout: `PocketBaseService.logout()` + Sync-Timer stoppen
  - Auth-Gate in `main.dart` mit Screen-Prioritätskette (siehe oben)

### App-Lock (F-001/F-002, ab v0.8.2)
  - Paket: `local_auth: ^3.0.1`
  - Service: `AppLockService` (Singleton, SharedPreferences-Persistenz)
  - Screen: `AppLockScreen` — automatischer Biometrie-Start via `addPostFrameCallback`
  - Fallback: Geräte-PIN/Pattern wenn Biometrie nicht verfügbar
  - Timeout: Konfigurierbar in Minuten (Slider im Settings-Screen, Standard: 5 Min)
  - Lifecycle: `WidgetsBindingObserver` → `onAppPaused()` / `onAppResumed()`
  - Verfügbarkeitsprüfung: `canCheckBiometrics` + `isDeviceSupported()` vor Aktivierung
  - Probe-Auth: Bei Toggle-Aktivierung wird einmalig `authenticate()` aufgerufen
  - Nur Native: `kIsWeb`-Guard in `main.dart`

--- 

## 📂 Projektstruktur (Übersicht)

```text
lager_app/
├── app/                    # Flutter Hauptanwendung
│   ├── lib/
│   │   ├── config/         # Zentrale Steuerung (AppConfig, AppTheme, AppImages)
│   │   ├── core/           # Plattform-Abstraktion (Logger, Exceptions)
│   │   ├── models/         # Datenklassen (Artikel, Attachment)
│   │   ├── screens/        # UI-Pages (23 Dateien + Conditional Imports)
│   │   ├── services/       # Business-Logik (40 Dateien + Conditional Imports)
│   │   ├── utils/          # Helfer (Validierung, UUID, Image-Tools)
│   │   └── widgets/        # Wiederverwendbare UI-Komponenten (12 Widgets)
│   └── test/               # Testsuite
├── packages/               # Lokale Dart-Pakete (runtime_env_config)
├── server/                 # PocketBase Backend + Backup-Container
├── docs/                   # Dokumentation
└── .github/                # CI/CD Workflows
```

→ **Vollständige Dateistruktur mit allen Dateien:** [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

---

## 💾 Datenmodell (PocketBase Schema)

Das Herzstück der Anwendung ist die Collection `artikel`. Ergänzt wird sie durch die Collection `attachments` für Dateianhänge.

### Collection: `artikel`

| Feld | Typ | Beschreibung | Index |
| :--- | :--- | :--- | :--- |
| `id` | `INTEGER` | Lokaler Auto-Increment PK (nur SQLite) | — |
| `uuid` | `TEXT` | Globaler Identifier (RFC-4122 V4), geräteübergreifend eindeutig | ✅ `idx_uuid` |
| `artikelnummer` | `INTEGER` | Fachliche ID (≥ 1000), automatisch vergeben | ✅ `idx_unique_an` |
| `name` | `TEXT` | Bezeichnung des Artikels (Pflicht, 2–100 Zeichen) | ✅ `idx_search_name` |
| `menge` | `INTEGER` | Lagerbestand (≥ 0, max 999.999) | — |
| `ort` | `TEXT` | Lagerort (Pflichtfeld) | — |
| `fach` | `TEXT` | Lagerfach (Pflichtfeld) | — |
| `beschreibung` | `TEXT` | Freitext | — |
| `kategorie` | `TEXT` | Kategorie | — |
| `remote_path` | `TEXT` | PocketBase Record-ID (Verbindung zum Server) | — |
| `updated_at` | `INTEGER` | Unix-Timestamp in ms für lokale Änderungsverfolgung / Delta-Sync | ✅ `idx_sync` |
| `deleted` | `INTEGER` | Soft-Delete (0 = aktiv, 1 = gelöscht) | ✅ `idx_sync` |
| `etag` | `TEXT` | Aktueller Sync-Zustand; `NULL` bedeutet lokale Änderung pending | — |
| `last_synced_etag` | `TEXT` | Letzter erfolgreich bestätigter Remote-Stand als Konfliktvergleichsbasis | — |
| `pending_resolution` | `TEXT` | Offene Nutzerentscheidung für den nächsten Sync (`force_local`, `force_merge`) | — |
| `bildPfad` | `TEXT` | Lokaler Pfad Originalbild | — |
| `thumbnailPfad` | `TEXT` | Lokaler Pfad Vorschaubild | — |
| `remoteBildPfad` | `TEXT` | Dateiname auf PocketBase | — |
| `erstelltAm` | `TEXT` | ISO 8601 Erstellungsdatum | — |

**Wichtige fachliche Invariante:**  
`uuid` ist nicht nur clientseitig relevant, sondern zusätzlich serverseitig in PocketBase als **required** und **unique** abgesichert.

### Collection: `attachments` (ab v0.7.2)

Dateianhänge pro Artikel. Unterstützt PDF, Office-Dokumente, Bilder und Textdateien.

| Feld | Typ | Beschreibung | Index |
|---|---|---|---|
| `artikel_uuid` | Text | Fremdschlüssel zur `artikel.uuid` (UUID-Pattern) | ✅ `idx_attachments_artikel_uuid` |
| `uuid` | Text | Client-seitige Eindeutigkeit | ✅ `idx_attachments_uuid` |
| `datei` | File | Dateianhang (max 10 MB) | — |
| `bezeichnung` | Text | Vom Nutzer vergebener Name | — |
| `beschreibung` | Text | Optionale Beschreibung | — |
| `mime_type` | Text | MIME-Typ der Datei | — |
| `datei_groesse` | Number | Dateigröße in Bytes | — |
| `sort_order` | Number | Sortierreihenfolge | ✅ `idx_attachments_sort` |
| `deleted` | Boolean | Soft-Delete Flag | ✅ `idx_attachments_deleted` |
| `updated_at` | Number | Unix-Timestamp für Sync | — |

**API-Regeln:** Auth-pflichtig seit v0.7.3 (M-009). Wird über PocketBase Collection Rules gesteuert.

---

## 🔄 Synchronisations-Logik (Offline-First)

Die mobile und native Desktop-App arbeitet **offline-first** mit lokaler SQLite-Datenbank und synchronisiert gegen PocketBase.  
Die Web-Version arbeitet direkt gegen das Backend und benötigt diese lokale Sync-Logik nicht.

### Grundprinzip

1. **Lokale Änderungen**
   - Änderungen werden zunächst lokal in SQLite gespeichert.
   - `etag = null` kennzeichnet einen Datensatz als **dirty / pending**.
   - `last_synced_etag` bleibt dabei als letzter bestätigter Remote-Stand erhalten.

2. **Push**
   - Pending-Datensätze werden anhand der `uuid` zum Server synchronisiert.
   - Vor `update()` oder `delete()` wird der aktuelle Remote-Stand gegen `last_synced_etag` geprüft.
   - Fehlt bei bestehendem Remote-Datensatz die stabile Vergleichsbasis in `last_synced_etag`, wird konservativ ein Konflikt angenommen.

3. **Pull**
   - Remote-Änderungen werden geladen und lokal übernommen.
   - Lokale dirty-/pending-Datensätze werden nicht blind überschrieben.
   - Auch im Pull-Pfad gilt: Fehlt bei lokal dirty + vorhandenem Remote-Datensatz die Vergleichsbasis, wird konservativ ein Konflikt erzeugt.

4. **Konflikterkennung**
   - Konflikte werden nicht mehr allein aus `etag` abgeleitet.
   - Vergleichsbasis ist `last_synced_etag` als letzter bestätigter gemeinsamer Stand.

5. **Konfliktauflösung**
   - Nutzerentscheidungen werden lokal persistiert und beim nächsten Sync gezielt respektiert.
   - Unterstützte Fachfälle:
     - Lokal behalten
     - Server übernehmen
     - Zusammenführen
     - Überspringen
     - Soft-Delete lokal vs. Remote-Änderung

6. **Duplicate-UUID-Recovery**
   - Wenn ein `create()` wegen bereits vorhandener `uuid` fehlschlägt, wird der bestehende Remote-Datensatz erneut per `uuid` gesucht.
   - Der lokale Datensatz wird anschließend an diesen Remote-Eintrag angehängt, statt bei jedem weiteren Sync erneut zu scheitern.

---

## 🔀 Konfliktauflösung ab aktuellem Stand

### Root Cause des alten Verhaltens

Der frühere Mechanismus verwendete `etag` gleichzeitig als:
1. Dirty-Marker
2. letzten bekannten Remote-Stand

Das war fachlich instabil, weil lokale Änderungen `etag = null` setzten und damit
die Vergleichsbasis für spätere Konflikterkennung verloren ging. Das Ergebnis war
in problematischen Fällen faktisch **„last write wins“**.

### Neue Sync-Metadaten

| Feld | Bedeutung |
|---|---|
| `etag` | Aktueller Sync-Zustand; `NULL` bedeutet lokale Änderung pending |
| `last_synced_etag` | Letzter erfolgreich bestätigter Remote-Stand |
| `pending_resolution` | Bewusste Nutzerentscheidung für genau einen nächsten Sync-Versuch |

### `pending_resolution`-Werte

| Wert | Bedeutung |
|---|---|
| `NULL` | Keine offene Sonderbehandlung |
| `force_local` | Nutzer will lokale Version beim nächsten Sync bewusst pushen |
| `force_merge` | Nutzer will manuell erzeugte Merge-Version beim nächsten Sync pushen |

### Zielverhalten bei Konflikten

#### Normaler Edit-vs-Edit-Konflikt
Wenn der Remote-Stand von `last_synced_etag` abweicht und keine offene Force-Resolution existiert:
- Konflikt erkennen
- `onConflictDetected` auslösen
- `ConflictResolutionScreen` anzeigen
- kein blindes Überschreiben

#### Fehlende Konfliktbasis
Wenn lokal Änderungen vorliegen, remote bereits ein passender Datensatz existiert, aber `last_synced_etag` leer ist:
- Fall konservativ als Konflikt behandeln
- kein optimistisches Update oder Delete
- bewusste Nutzerauflösung erforderlich, außer es liegt bereits `force_local` oder `force_merge` vor

#### useLocal
Wenn Nutzer **„Lokal behalten“** wählt:
- lokal `pending_resolution = force_local` setzen
- nächster Sync darf den Serverstand gezielt überschreiben
- nach erfolgreichem Push werden `etag` und `last_synced_etag` aktualisiert
- `pending_resolution` wird wieder gelöscht

#### useRemote
Wenn Nutzer **„Server übernehmen“** wählt:
- Remote-Version wird lokal vollständig übernommen
- lokale Vergleichsbasis wird neu gesetzt
- offene Sonderbehandlung wird gelöscht
- Konflikt ist damit sofort aufgelöst

#### merge
Wenn Nutzer **„Zusammenführen“** wählt:
- Merge-Ergebnis wird lokal gespeichert
- `pending_resolution = force_merge`
- nächster Sync darf diese Merge-Version gezielt hochladen
- nach erfolgreichem Push wird der Zustand wieder bereinigt

#### skip
Wenn Nutzer **„Überspringen“** wählt:
- keine Auflösung wird persistiert
- Datensatz bleibt pending
- Konflikt erscheint beim nächsten Sync erneut

#### delete vs remote edit
Wenn lokal ein Soft-Delete markiert wurde, der Remote-Datensatz aber seit `last_synced_etag` verändert wurde oder keine stabile Vergleichsbasis vorhanden ist:
- keine direkte Remote-Löschung
- Konflikt statt blindem Delete
- bewusste Auflösung durch den Nutzer erforderlich

---

## Sync-Invarianten (niemals brechen)

| Invariante | Bedeutung |
| :--- | :--- |
| `uuid` ist stabil | Nie ändern — geräteübergreifender Identifier |
| `remote_path` = PocketBase Record-ID | Verbindung zum Server — nie ohne sauberen Sync neu belegen |
| `etag = NULL` | Lokaler Datensatz ist dirty / pending |
| `last_synced_etag` bleibt bei normalen lokalen Änderungen erhalten | Vergleichsbasis für spätere Konflikterkennung |
| `pending_resolution = force_local` | Nächster Sync darf bewusst lokal überschreiben |
| `pending_resolution = force_merge` | Nächster Sync darf bewusst Merge-Ergebnis pushen |
| `deleted = 1` | Soft-Delete lokal; tatsächliche Server-Löschung nur ohne Konflikt |
| `setBildPfadByUuidSilent()` | Setzt nur `bildPfad`, löst keinen normalen Datensync-Trigger aus |
| `toPocketBaseMap()` überträgt keine lokalen Konflikt-Steuerfelder | `last_synced_etag` und `pending_resolution` bleiben lokal |

---

## 🔀 Konflikt-Erkennung & Callback-Registrierung

### ConflictCallback Typedef

```dart
typedef ConflictCallback = Future<void> Function(
  Artikel lokalerArtikel,
  Artikel remoteArtikel,
);
```

`PocketBaseSyncService` hält einen nullable Konflikt-Callback:

```dart
ConflictCallback? onConflictDetected;
```

Der Callback wird von `SyncOrchestrator` gesetzt und leitet Konflikte
an den `ConflictResolutionScreen` weiter.

### Callback-Registrierung via GlobalKey

Die Registrierung erfolgt nach dem ersten Frame, damit ein nutzbarer
`NavigatorState` verfügbar ist. Die Navigation zum
`ConflictResolutionScreen` läuft über ein `GlobalKey<NavigatorState>`.

Der UI-Flow ist zusätzlich gegen doppelte parallele Öffnungen des
Konflikt-Screens gehärtet.

### DB-Reopen nach App-Resume

Nach einem Hintergrundwechsel (`AppLifecycleState.resumed`) wird die
SQLite-Verbindung explizit wiederhergestellt, bevor ein neuer Sync startet:

`openDatabase()` ist idempotent und bei bereits geöffneter DB ein No-op.

---

### Bild-Synchronisation

Die Bild-Sync-Logik arbeitet getrennt von den Textdaten. Produktiv relevant ist vor allem der Download fehlender oder veralteter lokaler Bilddateien.

```text
downloadMissingImages()
  → Für jeden lokalen Artikel:
      → remoteBildPfad leer? → skip
      → remotePath leer? → skip
      → Lokale Datei fehlt / 0 Bytes? → DOWNLOAD
      → Dateiname hat sich geändert? → DOWNLOAD
      → Artikelstand neuer als lokale Datei? → DOWNLOAD
      → sonst → skip
  → HTTP GET /api/files/artikel/{recordId}/{filename}
  → Speichern in {cacheDir}/images/{uuid}/{filename}
  → setBildPfadByUuidSilent(uuid, localPath)
```

Wichtig:
- Bilddownload ist vom normalen Textsync getrennt
- `setBildPfadByUuidSilent()` löst keinen normalen Datensync aus
- dadurch werden Endlosschleifen durch reine Bildpfad-Updates vermieden

---

## SyncStatusProvider Interface

### Warum ein Interface?

`ArtikelListScreen` muss auf Sync-Events reagieren (z.B. um die Artikelliste
nach einem erfolgreichen Sync neu zu laden), braucht aber nicht die volle
`SyncOrchestrator`-API. Das `SyncStatusProvider`-Interface bietet:

- **Lose Kopplung:** Screen kennt nur den Stream, nicht den Orchestrator
- **Testbarkeit:** `FakeSyncStatusProvider` ermöglicht Unit-Tests ohne
  echten Sync-Mechanismus
- **Single Responsibility:** Orchestrator bleibt für Sync zuständig,
  Screen nur für Darstellung

### Datenfluss

```text
SyncOrchestrator.runOnce()
  → _emit(SyncStatus.running)
  → syncOnce() + downloadMissingImages()
  → _emit(SyncStatus.success)
        ↓
  syncStatus Stream (broadcast)
        ↓
  ArtikelListScreen._syncSubscription
        ↓
  _ladeArtikel() → UI aktualisiert
```

### SyncManagementScreen

`SyncManagementScreen` erhält eine `SyncOrchestrator`-Instanz als Parameter
und ruft `orchestrator.runOnce()` auf — nicht `SyncService` direkt.

**Korrekt:**
```dart
orchestrator.runOnce();
```

### Bild-Fallback-Kette (Mobile/Desktop)

Nach einem Kaltstart existieren keine lokalen Bilddateien. Die Widgets
nutzen eine 4-stufige Fallback-Kette:

| Priorität | Quelle | Widget |
|---|---|---|
| 1 | Lokales Thumbnail (`thumbnailPfad`) | `_LocalThumbnail` |
| 2 | Lokales Vollbild (`bildPfad`) | `_LocalThumbnail` / `ArtikelDetailBild` |
| 3 | PocketBase-URL via `CachedNetworkImage` | `_buildPbFallback()` / `_buildPbDetailFallback()` |
| 4 | Placeholder-Icon | `_BildPlaceholder` / `_Placeholder` |

Die Bilder werden im Hintergrund von `downloadMissingImages()` heruntergeladen.
Beim nächsten Laden der Artikelliste (nach `SyncStatus.success`) werden die
lokalen Dateien verwendet.

---

## 🎛️ F-006 / F-007 — Log-Dialog & Sync-Zeitstempel-Toggle

### F-006: Log-Level-Filter als Dropdown

Der In-App Log-Dialog verwendet einen `DropdownButton<Level>` statt der
früheren horizontalen Button-Reihe.

### F-007: Sync-Zeitstempel-Toggle (ValueNotifier-Pattern)

Der Sync-Zeitstempel in der `ArtikelListScreen`-AppBar kann in den
Einstellungen ein- und ausgeblendet werden.

---

## 🧩 Screen-/Controller-Trennung (O-010)

Seit `v0.9.1+29` wird im Settings-Bereich zwischen UI und fachlicher Logik
klarer getrennt:

- `SettingsScreen`: Rendering, Dialoge, SnackBars, Navigation, Logout-Handling
- `SettingsController`: Laden/Speichern der Settings, Dirty-Tracking,
  PocketBase-URL-Prüfung, App-Lock-Status, DB-Status
- `settings_state.dart`: UI-neutraler geteilter Settings-State
  (`showLastSyncNotifier`, Prefs-Key, Defaultwert)

---

## 🎨 Design-System & Konfiguration

Um die Wartbarkeit zu erhöhen, nutzt die App eine dreistufige Konfiguration in `app/lib/config/`:

1. **`AppConfig`**: Hält technische Konstanten.
2. **`AppTheme`**: Implementiert Material 3 mit Unterstützung für `ThemeMode.system`.
3. **`AppImages`**: Verwaltet Asset-Pfade und Feature-Flags.

---

## 🛠️ Plattform-Abstraktion (Conditional Imports)

Da `dart:io` im Web nicht existiert, nutzt die App **Conditional Imports**.
Dies verhindert Compiler-Fehler auf verschiedenen Plattformen.

---

## 🛡️ Sicherheits-Architektur

1. **PocketBase Rules**: Zugriff im Produktionsmodus strikt an Auth/Rollen gebunden.
2. **Caddy Security**: gehärtete HTTP-Header.
3. **Network Isolation**: interne Docker-Kommunikation.
4. **Datei-Validierung**: MIME-Type-Prüfung serverseitig.
5. **App-Lock**: biometrische Sperre auf nativen mobilen Plattformen.

---

## 📄 Dokument-Verwaltung

Der Artikel-Detail-Screen enthält einen dedizierten **Dokumente-Tab** für Upload, Öffnen und Löschen von Anhängen.

---

### 6. Wartungs-Notiz am Ende des Dokuments

> **Zuletzt aktualisiert:** fix/sync-hardening2-v0.9.4 (2026-04-27)  
> Architekturtext gegen historische ETag-only-Beschreibungen konsolidiert  
> Konflikterkennung auf `last_synced_etag` als stabile Vergleichsbasis dokumentiert  
> Fehlende Konfliktbasis bei bestehendem Remote-Datensatz als konservativer Konfliktfall nachgezogen  
> `pending_resolution` für `force_local` und `force_merge` konsolidiert  
> Guard gegen doppelte Konflikt-UI-Öffnung berücksichtigt  
> Duplicate-UUID-Recovery im Create-Pfad dokumentiert  
> Serverseitige UUID-Absicherung (`required` + `unique`) nachgezogen  
> Logging für Duplicate-UUID-Recovery als aktueller Sync-Bestandteil berücksichtigt

[Zurück zur README](../README.md) | [Zu den Installationsdetails](../INSTALL.md) | [Vollständige Projektstruktur](PROJECT_STRUCTURE.md) | [CI/CD & Deployment](../DEPLOYMENT.md)