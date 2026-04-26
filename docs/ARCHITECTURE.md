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
│                       │   |  |                               │  │
└───────────────────────┘   │  └───────────────────────────────┘  │
                            │  ┌───────────────────────────────┐  │
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
  -Nur Native: `kIsWeb`-Guard in `main.dart`


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
│   └── test/               # 626 Tests (3 skipped), 29 Testdateien
├── packages/               # Lokale Dart-Pakete (runtime_env_config)
├── server/                 # PocketBase Backend + Backup-Container
├── docs/                   # Dokumentation (16 Dateien)
└── .github/                # CI/CD Workflows (4 Pipelines)
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
| `etag` | `TEXT` | Aktueller synchronisierter Remote-Stand; `NULL` bedeutet lokale Änderung pending | — |
| `last_synced_etag` | `TEXT` | Letzter erfolgreich bestätigter Remote-Stand als Konfliktvergleichsbasis | — |
| `pending_resolution` | `TEXT` | Offene Nutzerentscheidung für den nächsten Sync (`force_local`, `force_merge`) | — |
| `bildPfad` | `TEXT` | Lokaler Pfad Originalbild | — |
| `thumbnailPfad` | `TEXT` | Lokaler Pfad Vorschaubild | — |
| `remoteBildPfad` | `TEXT` | Dateiname auf PocketBase | — |
| `erstelltAm` | `TEXT` | ISO 8601 Erstellungsdatum | — |

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
   - Pending-Datensätze werden anhand der `uuid` bzw. `remote_path` zum Server synchronisiert.
   - Vor einem Update wird der aktuelle Remote-Stand geprüft.

3. **Pull**
   - Remote-Änderungen werden anhand des Delta-Syncs geladen und lokal übernommen.
   - Fehlende lokale Datensätze werden eingefügt, veränderte aktualisiert.

4. **Konflikterkennung**
   - Konflikte werden nicht mehr allein aus `etag` abgeleitet.
   - Vergleichsbasis ist `last_synced_etag` als letzter bekannter gemeinsamer Stand.

5. **Konfliktauflösung**
   - Nutzerentscheidungen werden lokal persistiert und beim nächsten Sync gezielt respektiert.
   - Unterstützte Fachfälle:
     - Lokal behalten
     - Server übernehmen
     - Zusammenführen
     - Überspringen
     - Soft-Delete lokal vs. Remote-Änderung

---

## 🔀 Konfliktauflösung ab v0.9.3 (T-001.7–T-001.12)

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
Wenn lokal ein Soft-Delete markiert wurde, der Remote-Datensatz aber seit `last_synced_etag` verändert wurde:
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

---

## 🔀 Konflikt-Erkennung & Callback-Registrierung

### Konflikterkennung ab v0.9.3

Vor einem Update oder Delete wird der aktuelle Remote-Stand mit dem lokal
gespeicherten `last_synced_etag` verglichen.

**Vereinfacht gilt:**
- **kein Konflikt**, wenn Remote-Stand unverändert zum letzten bestätigten Stand ist
- **Konflikt**, wenn Remote seit `last_synced_etag` geändert wurde und lokal ebenfalls Änderungen vorliegen
- **Force-Push erlaubt**, wenn `pending_resolution` bewusst gesetzt wurde

### Konfliktfälle

| Fall | Verhalten |
|---|---|
| Neuer lokaler Datensatz ohne Remote-Bezug | Direkt `create()` |
| Lokale Änderung, Remote unverändert seit `last_synced_etag` | Direkt `update()` |
| Lokale Änderung, Remote geändert seit `last_synced_etag` | Konflikt |
| Lokales Soft-Delete, Remote unverändert | Remote darf gelöscht werden |
| Lokales Soft-Delete, Remote geändert seit `last_synced_etag` | Konflikt |
| `pending_resolution = force_local` | Bewusster Überschreib-Push erlaubt |
| `pending_resolution = force_merge` | Bewusster Merge-Push erlaubt |

> **Wichtig:** Die Konfliktprüfung basiert fachlich auf dem zuletzt bestätigten gemeinsamen Stand (`last_synced_etag`) und nicht mehr nur auf dem aktuellen Dirty-Flag.

### ConflictCallback Typedef

```dart
typedef ConflictCallback = Future<void> Function(
  ConflictData conflict,
);
```

`PocketBaseSyncService` hält einen nullable `ConflictCallback`:

```dart
ConflictCallback? onConflictDetected;
```

Der Callback wird von `SyncOrchestrator` gesetzt und leitet Konflikte
an den `ConflictResolutionScreen` weiter.

### Callback-Registrierung via GlobalKey

**Problem:** `onConflictDetected` darf erst registriert werden, wenn ein
verfügbarer Navigator-Kontext existiert.

**Lösung:** Registrierung nach dem ersten Frame über `GlobalKey<NavigatorState>`.

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

MaterialApp(
  navigatorKey: navigatorKey,
  ...
)

WidgetsBinding.instance.addPostFrameCallback((_) {
  syncOrchestrator.onConflictDetected = (conflict) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    await nav.push(MaterialPageRoute(
      builder: (_) => ConflictResolutionScreen(...),
    ));
  };
});
```

---

### DB-Reopen nach App-Resume

Nach einem Hintergrundwechsel (`AppLifecycleState.resumed`) wird die
SQLite-Verbindung explizit wiederhergestellt, bevor ein neuer Sync startet:

```dart
case AppLifecycleState.resumed:
  await artikelDbService.openDatabase();
  await _syncIfConnected();
```

`openDatabase()` ist idempotent und bei bereits geöffneter DB ein No-op.

---

### Bild-Synchronisation (Smart Logic)

Die Bild-Sync-Logik arbeitet getrennt von den Textdaten, um Bandbreite zu sparen und Dateiversionen sauber zu behandeln:

```text
┌─────────────────────────────────────────────────────────┐
│                BILD SYNC (Smart Logic)                  │
│                                                         │
│  Lokal Bild vorhanden?                                  │
│  ├── JA: remoteBildPfad leer oder ETag abweichend?      │
│  │       ├── JA → Bild hochladen → remoteBildPfad setzen│
│  │       └── NEIN: Remote-Bild neuer (Timestamp)?       │
│  │                 ├── JA → Bild laden (Smart Sync)     │
│  │                 └── NEIN → Kein Update nötig         │
│  └── NEIN: remoteBildPfad vorhanden?                    │
│            ├── JA → Bild vom Server laden → bildPfad    │
│            └── NEIN → Kein Bild vorhanden               │
└─────────────────────────────────────────────────────────┘
```

### Sync-Invarianten (niemals brechen)
| Invariante                 | Bedeutung                                            |
| :------------------------- | :--------------------------------------------------- |
| `uuid` ist stabil          | Nie ändern — geräteübergreifender Identifier         |
| `remote_path` = PB Record-ID | Verbindung zum Server — nie überschreiben ohne Sync  |
| `etag` = `NULL`            | Lokale Änderung ausstehend — muss gepusht werden     |
| `etag` = PB `updated`-Timestamp | ISO 8601 — wird nach erfolgreichem PATCH gesetzt. Abweichung vom Remote-Wert löst Konflikt-Erkennung aus (B-005) |
| `deleted` = `1`            | Soft-Delete lokal → Hard-Delete beim nächsten Push   |
| `setBildPfadByUuidSilent()`| Setzt nur `bildPfad`, löst keinen Sync-Trigger aus, Essenziell für Smart Sync, um Endlosschleifen bei Bild-Updates zu verhindern. |


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

### SyncManagementScreen (B-006, ab v0.8.5+19)

`SyncManagementScreen` erhält eine `SyncOrchestrator`-Instanz als Parameter
und ruft `orchestrator.runOnce()` auf — nicht `SyncService` direkt.

**Vorher (falsch):**
```dart
syncService.syncOnce();   // ❌ umgeht Orchestrator, kein Conflict-Handling
```

**Nachher (korrekt):**
```dart
orchestrator.runOnce();   // ✅ Status-Stream, Conflict-Handling, downloadMissingImages()
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
lokalen Dateien verwendet (Priorität 1/2).

---

## 🔀 Konflikt-Erkennung & Callback-Registrierung

### ETag-basierte Konflikt-Erkennung (B-005, ab v0.8.5+19)

Vor jedem PATCH-Request lädt `PocketBaseSyncService` den aktuellen Remote-Record
und vergleicht dessen `updated`-Timestamp mit dem lokal gespeicherten `etag`:

```dart
final istKonflikt = lokalerEtag.isNotEmpty &&
    lokalerEtag != 'deleted' &&
    remoteUpdated.isNotEmpty &&
    lokalerEtag != remoteUpdated;
```

| Zustand | Verhalten |
|---------|-----------|
| `etag` leer (neuer Artikel) | Kein Konflikt-Check — direkt `create()` |
| `etag == remoteUpdated` | Kein Konflikt — direkt `update()` |
| `etag != remoteUpdated` | Konflikt — `onConflictDetected`-Callback |
| `etag == 'deleted'` | Kein Konflikt-Check — direkt `delete()` |
| `remoteUpdated` leer | Kein Konflikt-Check — Remote-Record nicht gefunden |

> **Wichtig:** `etag` = PocketBase `updated`-Timestamp (ISO 8601), **nicht** die Record-ID.

---

### ConflictCallback Typedef

```dart
typedef ConflictCallback = Future<void> Function(
  ConflictData conflict,
);
```

`PocketBaseSyncService` hält einen nullable `ConflictCallback`:

```dart
ConflictCallback? onConflictDetected;
```

Der Callback wird von `SyncOrchestrator` gesetzt und leitet Konflikte
an den `ConflictResolutionScreen` weiter.

---

### Callback-Registrierung via GlobalKey (B-004, ab v0.8.5+19)

**Problem:** `onConflictDetected` wurde vor dem Navigator-Init registriert —
`Navigator.of(context)` warf einen Fehler, weil kein `MaterialApp`-Kontext
verfügbar war.

**Lösung:**

```dart
// main.dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// In MyApp:
MaterialApp(
  navigatorKey: navigatorKey,
  ...
)

// Callback-Registrierung nach erstem Frame:
WidgetsBinding.instance.addPostFrameCallback((_) {
  syncOrchestrator.onConflictDetected = (conflict) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    await nav.push(MaterialPageRoute(
      builder: (_) => ConflictResolutionScreen(...),
    ));
  };
});
```

**Ablauf:**

```text
main.dart
  → runApp(MyApp())
  → addPostFrameCallback()        ← erster Frame gerendert
      → navigatorKey.currentState verfügbar
      → syncOrchestrator.onConflictDetected = Callback
      → _syncIfConnected()        ← Sync startet erst jetzt
```

---

### DB-Reopen nach App-Resume (B-004)

Nach einem Hintergrundwechsel (`AppLifecycleState.resumed`) wird die
SQLite-Verbindung explizit wiederhergestellt, bevor der Sync startet:

```dart
// In didChangeAppLifecycleState():
case AppLifecycleState.resumed:
  await artikelDbService.openDatabase();   // No-op wenn bereits offen
  await _syncIfConnected();
```

`openDatabase()` ist idempotent — wenn `_db != null`, ist der Aufruf ein No-op.

---

### ConflictResolution — useLocal Force-Push

Nach `ConflictResolution.useLocal` wird der Artikel via `markAsModified()`
als dirty markiert:

```dart
// ArtikelDbService.markAsModified():
await db.update('artikel',
  {'etag': null, 'updated_at': DateTime.now().millisecondsSinceEpoch},
  where: 'uuid = ?', whereArgs: [uuid],
);
```

Effekt: Der Artikel erscheint beim nächsten `getPendingChanges()`-Aufruf
und wird vom `PocketBaseSyncService` zum Server gepusht — auch wenn der
Server eine neuere Version hat.

---

## 🎛️ F-006 / F-007 — Log-Dialog & Sync-Zeitstempel-Toggle (ab v0.9.0+25)

### F-006: Log-Level-Filter als Dropdown

Der In-App Log-Dialog verwendet einen `DropdownButton<Level>` statt der
früheren horizontalen Button-Reihe (6 × `FilterChip`).

| Eigenschaft | Vorher | Nachher |
|:------------|:-------|:--------|
| Widget | `ListView` + 6 × `FilterChip` horizontal | `DropdownButton<Level>` |
| Platzbedarf | 44px Höhe + horizontale Scrollbar | Eine Zeile, kein Scrollen |
| Default | `Level.trace` (alles) | `Level.error` (nur Fehler) |
| Farbe | Chip-Farbe fix | Container passt sich dynamisch an Level an |
| Leer-State | Nur Text | `check_circle_outline`-Icon + Level-Name |

**Begründung:** Auf 360dp-Displays (z.B. Samsung S20) passte die Button-Reihe
nicht in eine Zeile. Der Dropdown benötigt nur eine Zeile und skaliert auf
alle Displaybreiten.

---

### F-007: Sync-Zeitstempel-Toggle (ValueNotifier-Pattern)

Der Sync-Zeitstempel in der `ArtikelListScreen`-AppBar kann in den
Einstellungen ein- und ausgeblendet werden.

```text
SettingsScreen / SettingsController
        └─ writes ─► showLastSyncNotifier (settings_state.dart)
                           └─ notifies ─► ArtikelListScreen
                                              rebuild
```
| Alternative                     | Problem                                        |
| :------------------------------ | :--------------------------------------------- |
| `SharedPreferences` direkt in `initState()` | Nicht reaktiv — braucht App-Neustart           |
| `Provider` / `Riverpod`         | Overhead für eine einzelne `bool`-Präferenz    |
| `InheritedWidget`               | Zu viel Boilerplate                            |
| `ValueNotifier` ✅              | Leichtgewichtig, kein extra Package, sofortige Wirkung |

Implementierung:

- SharedPreferences-Key: `show_last_sync` (Default: `true`)
- `showLastSyncNotifier` liegt zentral in `settings_state.dart`
- `SettingsController` lädt/speichert die Präferenz
- `ArtikelListScreen` hört reaktiv auf den Notifier
- Rebuild erfolgt sofort ohne App-Neustart

---

## 🧩 Screen-/Controller-Trennung (O-010)

Seit `v0.9.1+29` wird im Settings-Bereich zwischen UI und fachlicher Logik
klarer getrennt:

- `SettingsScreen`: Rendering, Dialoge, SnackBars, Navigation, Logout-Handling
- `SettingsController`: Laden/Speichern der Settings, Dirty-Tracking,
  PocketBase-URL-Prüfung, App-Lock-Status, DB-Status
- `settings_state.dart`: UI-neutraler geteilter Settings-State
  (`showLastSyncNotifier`, Prefs-Key, Defaultwert)

**Ziel:** bessere Testbarkeit ohne vollständigen Architektur-Umbau.
Die Lösung ist bewusst minimal-invasiv und führt keine zusätzliche
State-Management-Bibliothek ein.

--- 

## 🎨 Design-System & Konfiguration

Um die Wartbarkeit zu erhöhen, nutzt die App eine dreistufige Konfiguration in `app/lib/config/`:

1.  **`AppConfig`**: Hält technische Konstanten (Spacing, Border-Radius, API-Timeouts).
2.  **`AppTheme`**: Implementiert Material 3 mit Unterstützung für `ThemeMode.system`.
3.  **`AppImages`**: Verwaltet Asset-Pfade und Feature-Flags für Hintergrundbilder oder Platzhalter.

**Vorteil**: Design-Änderungen (z.B. von 8px auf 12px Eckenradius) werden an genau einer Stelle geändert und wirken sich auf die gesamte App aus.

---

## 🛠️ Plattform-Abstraktion (Conditional Imports)

Da `dart:io` (Dateisystem) im Web nicht existiert, nutzt die App **Conditional Imports**. Dies verhindert Compiler-Fehler auf verschiedenen Plattformen.

**Beispiel**:
*   `artikel_erfassen_io.dart`: Implementiert Kamera-Zugriff und Datei-Operationen für Android/Linux.
*   `artikel_erfassen_stub.dart`: Implementiert Datei-Upload für Web.
*   `artikel_erfassen_screen.dart`: Importiert automatisch die richtige Version.

Dies gilt analog für die **Dokumenten-Funktionalität**: Auf nativen Plattformen werden Dokumente lokal gespeichert und via `open_file` geöffnet; im Web erfolgt der Zugriff direkt über den Browser-Download-Mechanismus.

→ **Vollständige Liste aller Conditional Imports:** [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

---

## 🛡️ Sicherheits-Architektur

1.  **PocketBase Rules**: Der Zugriff auf die API ist im Produktionsmodus (`PB_DEV_MODE=0`) strikt an Rollen (`reader`/`writer`) gebunden. Dies gilt für `artikel` **und** `artikel_dokumente`.
2.  **Caddy Security**: Der interne Webserver liefert die App mit gehärteten HTTP-Headern aus:
    *   `Content-Security-Policy`: Verhindert XSS.
    *   `Strict-Transport-Security`: Erzwingt HTTPS.
    *   `X-Frame-Options`: Verhindert Clickjacking.
3.  **Network Isolation**: In Docker-Produktions-Setups kommunizieren Frontend und Backend über ein isoliertes internes Netzwerk ohne direkte Port-Exposition.
4.  **Datei-Validierung**: Beim Dokument-Upload wird der MIME-Type serverseitig geprüft, um     unerwünschte Dateitypen abzuweisen.
5. **App-Lock (F-001/F-002)**: Auf nativen mobilen Plattformen kann die App
   mit biometrischer Authentifizierung (`local_auth`) gesperrt werden.
   Bei nicht verfügbarer Biometrie greift der Geräte-PIN als Fallback.
   Die Sperrzeit ist konfigurierbar (Standard: 5 Minuten Inaktivität).

---

## 📄 Dokument-Verwaltung

Der Artikel-Detail-Screen enthält einen dedizierten **Dokumente-Tab**, der folgende Funktionen bietet:

```text
┌─────────────────────────────────────────────────────────┐
│              DOKUMENTE-TAB (Artikel-Detail)             │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📄 datenblatt.pdf          [Öffnen] [Löschen]   │   │
│  │ 📄 einbauanleitung.docx    [Öffnen] [Löschen]   │   │
│  │ 📄 pruefprotokoll.xlsx     [Öffnen] [Löschen]   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [ + Dokument hinzufügen ]                              │
│                                                         │
│  Plattform-Verhalten:                                   │
│  • Native (Android/Linux): Speichern + open_file        │
│  • Web: Direkter Browser-Download                       │
└─────────────────────────────────────────────────────────┘
```

| Aktion | Native | Web |
|---|---|---|
| **Upload** | `file_picker` → lokale Kopie + PocketBase | `file_picker` → direkt zu PocketBase |
| **Öffnen** | Lokal gespeichert → `open_file` | Browser-Download / Inline-Anzeige |
| **Löschen** | Soft-Delete lokal → Hard-Delete beim Sync | Direktes DELETE via REST API |

---
### 6. Wartungs-Notiz am Ende des Dokuments

> **Zuletzt aktualisiert:** v0.9.3 (2026-04-26)  
> T-001.7 bis T-001.12 fachlich abgeschlossen und dokumentiert  
> Sync-Konflikterkennung auf `last_synced_etag` als stabile Vergleichsbasis umgestellt  
> `pending_resolution` für bewusste Nutzerentscheidungen (`force_local`, `force_merge`) ergänzt  
> Konfliktauflösung für „Lokal behalten“, „Server übernehmen“, „Zusammenführen“ und „Überspringen“ konsolidiert  
> Skip-Recall beim nächsten Sync fachlich und automatisiert abgesichert  
> Delete-vs-Remote-Edit als echter Konfliktfall umgesetzt und dokumentiert  
> Architekturtext für Offline-First-Sync von implizitem Last-Write-Wins auf explizite Konfliktauflösung aktualisiert

[Zurück zur README](../README.md) | [Zu den Installationsdetails](../INSTALL.md) | [Vollständige Projektstruktur](PROJECT_STRUCTURE.md) | [CI/CD & Deployment](../DEPLOYMENT.md)