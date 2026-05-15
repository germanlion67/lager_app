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

## 0.1 Einordnung der Betriebsarchitektur

Das oben gezeigte Diagramm beschreibt die **produktive Laufzeit- und Deployment-Topologie**
(Reverse Proxy, Web-Frontend, PocketBase, Volumes, Backups).

Davon zu unterscheiden ist die **Anwendungsarchitektur innerhalb der Flutter-App**
(z. B. `main.dart`, Services, lokale SQLite, Sync-Orchestrierung, Konflikt-UI).

Kurz gesagt:
- **Deployment-Topologie** beantwortet: *Wo laufen welche Dienste?*
- **App-Architektur** beantwortet: *Wie arbeiten UI, lokale Persistenz und Sync fachlich zusammen?*

Für operative Details wie Compose-Dateien, Proxy-Setup, Backups und Release-Abläufe ist
primär `DEPLOYMENT.md` maßgeblich.

--- 

## 1. 🏗️ High-Level Architektur

Die Lager_app folgt einem **Hybrid-Cloud-Modell** (Offline-First). Sie ist so konzipiert, dass sie auf mobilen Geräten ohne permanente Internetverbindung funktioniert, während die Web-Version direkt mit dem Backend kommuniziert.

### 1.1 Plattform-Strategie

| Komponente | Mobile (Android/iOS) | Desktop (Linux/Win) | Web (Docker/Caddy) |
| :--- | :--- | :--- | :--- |
| **Frontend** | Flutter Native | Flutter Native | Flutter Web (SPA) |
| **Lokale DB** | SQLite (`sqflite`) | SQLite (FFI) | Keine (Direktzugriff) |
| **Dateisystem** | Pfad-basiert (Images, Docs) | Pfad-basiert (Images, Docs) | Browser Blob/Memory |
| **Sync-Logik** | Hintergrund-Worker (15 min) | Timer-basiert (15 min) | Nicht erforderlich |
| **Kamera/Scanner** | `image_picker`, `mobile_scanner` | Nicht verfügbar | Nicht verfügbar |
| **App-Lock** | `local_auth` (Biometrie + PIN) | Nicht verfügbar | Nicht verfügbar |
| **Logging** | Datei + Konsole | Datei + Konsole | Nur Konsole |
| **Runtime-Config** | `--dart-define` / `SharedPreferences` | `--dart-define` / `SharedPreferences` | `window.ENV_CONFIG` (Caddy) |

---

## 2. 🚀 App-Einstieg & Navigation (`main.dart`)

### 2.1 Initialisierungsreihenfolge

1. `AppConfig.init()` — Runtime-Konfiguration laden (Web: `window.ENV_CONFIG`)
2. `AppConfig.validateForRelease() + validateConfig()`
3. `FlutterError.onError` + `PlatformDispatcher.instance.onError` — globale Fehler
4. `platform.initDesktopDatabase()` — SQLite-FFI-Init (nur Native)
5. `PocketBaseService().initialize()` — PB-Client aufbauen
6. `AppLockService().init()` — Biometrie-Service (nur Native)
7. `runApp(MyApp())`

### 2.2 Screen-Prioritätskette (`_buildHome()`)

| Priorität | Screen | Bedingung |
| :--- | :--- | :--- |
| 1 | `ServerSetupScreen` | Keine PB-URL konfiguriert |
| 2 | Lade-Spinner | Auth-Token wird geprüft (Auto-Login) |
| 3 | `LoginScreen` | Nicht eingeloggt (außer `PB_DEV_MODE=1`) |
| 4 | `AppLockScreen` | App gesperrt (Biometrie-Overlay über Haupt-App) |
| 5 | `ArtikelListScreen` | Normalzustand |

### 2.3 PocketBase URL — Prioritätskette

| Priorität | Quelle | Beschreibung |
| :--- | :--- | :--- |
| 1 | `SharedPreferences` (`pocketbase_url`) | Persistiert vom Setup-Screen |
| 2 | `RuntimeEnvConfig.pocketBaseUrl()` | Web: `window.ENV_CONFIG.POCKETBASE_URL` |
| 3 | `--dart-define=POCKETBASE_URL=...` | Build-Argument |
| 4 | `ServerSetupScreen` | Erststart-Eingabe durch den Nutzer |

**Plattformhinweis:**
- **Web** kann die Server-URL zusätzlich zur Laufzeit über `window.ENV_CONFIG` erhalten
  (typisch via Container-Start / Webserver-Setup), ohne dass dafür zwingend ein neuer
  Flutter-Web-Build erforderlich ist.
- **Native Plattformen** nutzen primär persistierte Einstellungen (`SharedPreferences`)
  oder Build-Konfigurationen (`--dart-define`); eine echte Web-Runtime-Injektion existiert dort nicht.

Welche Quelle im Einzelfall tatsächlich greift, bestimmt der aktuelle Produktivcode.


### 2.4 Dev-Mode

```bash
flutter run --dart-define=PB_DEV_MODE=1  # überspringt Login-Screen
```

---

## 3. 🔐 Authentifizierung & App-Lock

### 3.1 Login-Flow (M-009, ab v0.7.3)

- `LoginScreen`: E-Mail/Passwort, Validierung, Loading-State
- Auto-Login beim Start: Token-Refresh via `PocketBaseService.refreshAuthToken()`
- Logout: `PocketBaseService.logout()` + Sync-Timer stoppen
- Auth-Gate in `main.dart` mit Screen-Prioritätskette (siehe 2.2)

### 3.2 App-Lock (F-001/F-002, ab v0.8.2)

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

## 4. 📂 Projektstruktur (Übersicht)

```text
lager_app/
├── app/                    # Flutter Hauptanwendung
│   ├── lib/
│   │   ├── config/         # Zentrale Steuerung (AppConfig, AppTheme, AppImages)
│   │   ├── core/           # Plattform-Abstraktion (Logger, Exceptions, Responsive)
│   │   ├── models/         # Datenklassen (Artikel, Attachment)
│   │   ├── screens/        # UI-Pages (23 Dateien + Conditional Imports)
│   │   ├── services/       # Business-Logik (40 Dateien + Conditional Imports)
│   │   ├── utils/          # Helfer (Validierung, UUID, Image-Tools)
│   │   └── widgets/        # Wiederverwendbare UI-Komponenten (13 Widgets)
│   └── test/               # Testsuite
├── packages/               # Lokale Dart-Pakete (runtime_env_config)
├── server/                 # PocketBase Backend + Backup-Container
├── docs/                   # Dokumentation
└── .github/                # CI/CD Workflows
```

→ **Vollständige Dateistruktur mit allen Dateien:** [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

---

## 5. 💾 Datenmodell

Das Herzstück der Anwendung ist die Collection `artikel`. Ergänzt wird sie durch die Collection `attachments` für Dateianhänge.

### 5.1 Collection: `artikel`

| Feld | Typ | Beschreibung | Index |
| :--- | :--- | :--- | :--- |
| `id` | `INTEGER` | Lokaler Auto-Increment PK (nur SQLite) | — |
| `uuid` | `TEXT` | Globaler Identifier (RFC-4122 V4), geräteübergreifend eindeutig; serverseitig als `required` + `unique` abgesichert | ✅ `idx_artikel_uuid` |
| `artikelnummer` | `INTEGER` | Fachliche ID (≥ 1), automatisch vergeben; PocketBase-Schema: `min: 1` | ✅ `idx_artikel_artikelnummer` |
| `name` | `TEXT` | Bezeichnung des Artikels (Pflicht, 2–100 Zeichen) | ✅ `idx_artikel_name` |
| `menge` | `INTEGER` | Lagerbestand (≥ 0, max 999.999) | — |
| `ort` | `TEXT` | Lagerort (Pflichtfeld) | ✅ `idx_artikel_name_ort_fach` |
| `fach` | `TEXT` | Lagerfach (Pflichtfeld) | ✅ `idx_artikel_name_ort_fach` |
| `beschreibung` | `TEXT` | Freitext | — |
| `kategorie` | `TEXT` | Kategorie (optional) | — |
| `remote_path` | `TEXT` | PocketBase Record-ID (Verbindung zum Server) | — |
| `updated_at` | `INTEGER` | Unix-Timestamp in ms für lokale Änderungsverfolgung / Delta-Sync | ✅ `idx_artikel_updated_at` |
| `deleted` | `INTEGER` | Soft-Delete (0 = aktiv, 1 = gelöscht) | ✅ `idx_artikel_deleted` |
| `etag` | `TEXT` | Aktueller Sync-Zustand; `NULL` oder leer bedeutet lokale Änderung pending | — |
| `last_synced_etag` | `TEXT` | Letzter erfolgreich bestätigter Remote-Stand — stabile Vergleichsbasis für Konflikterkennung | — |
| `pending_resolution` | `TEXT` | Offene Nutzerentscheidung für den nächsten Sync (`force_local`, `force_merge`) | — |
| `bildPfad` | `TEXT` | Lokaler Pfad Originalbild | — |
| `thumbnailPfad` | `TEXT` | Lokaler Pfad Vorschaubild | — |
| `thumbnailEtag` | `TEXT` | ETag des zuletzt heruntergeladenen Thumbnails | — |
| `remoteBildPfad` | `TEXT` | Dateiname auf PocketBase — wird ausschließlich durch `markSynced()` nach Push oder `upsertArtikel()` nach Pull gesetzt | — |
| `erstelltAm` | `TEXT` | ISO 8601 UTC-Erstellungsdatum | — |
| `aktualisiertAm` | `TEXT` | ISO 8601 UTC-Änderungsdatum | — |
| `device_id` | `TEXT` | Gerätekennung (optional, für Multi-Device-Tracking) | — |

**Wichtige fachliche Invariante:**  
`uuid` ist nicht nur clientseitig relevant, sondern zusätzlich serverseitig in PocketBase als **required** und **unique** abgesichert.

**DB-Version:** `6`

**Migrationen:**
- v4: `artikelnummer`
- v5: `last_synced_etag`, `pending_resolution`
- v6: `conflict_snapshots`-Tabelle (`uuid`, `snapshot_json`, `saved_at`)

### 5.2 Collection: `attachments` (ab v0.7.2)

Dateianhänge pro Artikel. Unterstützt PDF, Office-Dokumente, Bilder und Textdateien.

| Feld | Typ | Beschreibung | Index |
| :--- | :--- | :--- | :--- |
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

### 5.3 `toPocketBaseMap()` — PocketBase-Payload

Nur diese Felder werden an PocketBase übertragen:

| Feld | Bemerkung |
| :--- | :--- |
| `name` | Pflicht |
| `menge` | Pflicht |
| `ort` | Pflicht |
| `fach` | Pflicht |
| `beschreibung` | Pflicht |
| `kategorie` | Optional |
| `uuid` | Pflicht |
| `updated_at` | Unix-Timestamp |
| `deleted` | `bool` (nicht `int`) |
| `device_id` | Optional |
| `erstelltAm` | UTC-ISO-8601-String |
| `aktualisiertAm` | UTC-ISO-8601-String |
| `artikelnummer` | Nur wenn `!= null && >= 1` — PocketBase-Schema: `min: 1` |

Bewusst **nicht** übertragen:

| Feld | Grund |
| :--- | :--- |
| `last_synced_etag` | Lokales Sync-Steuerfeld |
| `pending_resolution` | Lokales Konflikt-Steuerfeld |
| `bildPfad` | Geht separat als `MultipartFile` über Feld `bild` |
| `remoteBildPfad` | Nur lokale Referenz auf PocketBase-Dateiname |

### 5.4 `_extractBildName()` — PocketBase-Bild-Normalisierung

PocketBase liefert das Feld `bild` nach File-Upload als `List<String>`,
nicht zwingend als `String`. Die Hilfsmethode normalisiert beide Fälle:

```dart
String? _extractBildName(dynamic data) {
  final raw = _asStringDynamicMap(data)['bild'];
  if (raw == null) return null;
  if (raw is List && raw.isNotEmpty) return raw.first.toString();
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  return null;
}
```

`_extractBildName()` ist die **einzige zulässige Stelle** zur Normalisierung
von PocketBase `bild` zu `remoteBildPfad`. Sie wird nach CREATE und UPDATE
aufgerufen und das Ergebnis via `markSynced(..., remoteBildPfad: ...)` persistiert.

---

## 6. 🔄 Synchronisations-Logik (Offline-First)

Die mobile und native Desktop-App arbeitet **offline-first** mit lokaler SQLite-Datenbank und synchronisiert gegen PocketBase.  
Die Web-Version arbeitet direkt gegen das Backend und benötigt diese lokale Sync-Logik nicht.

### 6.1 Grundprinzip

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
   - Unterstützte Fachfälle: Lokal behalten, Server übernehmen, Zusammenführen, Überspringen, Soft-Delete lokal vs. Remote-Änderung.

6. **Duplicate-UUID-Recovery**
   - Wenn ein `create()` wegen bereits vorhandener `uuid` fehlschlägt, wird der bestehende Remote-Datensatz erneut per `uuid` gesucht.
   - Der lokale Datensatz wird anschließend an diesen Remote-Eintrag angehängt, statt bei jedem weiteren Sync erneut zu scheitern.

---

## 7. 🔀 Konfliktauflösung

### 7.1 Root Cause des alten Verhaltens

Der frühere Mechanismus verwendete `etag` gleichzeitig als:
1. Dirty-Marker
2. letzten bekannten Remote-Stand

Das war fachlich instabil, weil lokale Änderungen `etag = null` setzten und damit
die Vergleichsbasis für spätere Konflikterkennung verloren ging. Das Ergebnis war
in problematischen Fällen faktisch **„last write wins"**.

### 7.2 Neue Sync-Metadaten

| Feld | Bedeutung |
| :--- | :--- |
| `etag` | Aktueller Sync-Zustand; `NULL` bedeutet lokale Änderung pending |
| `last_synced_etag` | Letzter erfolgreich bestätigter Remote-Stand |
| `pending_resolution` | Bewusste Nutzerentscheidung für genau einen nächsten Sync-Versuch |

### 7.3 `pending_resolution`-Werte

| Wert | Bedeutung |
| :--- | :--- |
| `NULL` | Keine offene Sonderbehandlung |
| `force_local` | Nutzer will lokale Version beim nächsten Sync bewusst pushen |
| `force_merge` | Nutzer will manuell erzeugte Merge-Version beim nächsten Sync pushen |

### 7.4 Zielverhalten bei Konflikten

#### 7.4.1 Normaler Edit-vs-Edit-Konflikt

Wenn der Remote-Stand von `last_synced_etag` abweicht und keine offene Force-Resolution existiert:
- Konflikt erkennen
- `onConflictDetected` auslösen
- `ConflictResolutionScreen` anzeigen
- kein blindes Überschreiben

#### 7.4.2 Fehlende Konfliktbasis

Wenn lokal Änderungen vorliegen, remote bereits ein passender Datensatz existiert, aber `last_synced_etag` leer ist:
- Fall konservativ als Konflikt behandeln
- kein optimistisches Update oder Delete
- bewusste Nutzerauflösung erforderlich, außer es liegt bereits `force_local` oder `force_merge` vor

#### 7.4.3 useLocal

Wenn Nutzer **„Lokal behalten"** wählt:
- `_db.markForForceLocal(uuid)` setzt `pending_resolution = force_local` und `etag = null`
- nächster Sync darf den Serverstand gezielt überschreiben
- nach erfolgreichem Push werden `etag` und `last_synced_etag` aktualisiert
- `pending_resolution` wird wieder auf `null` gesetzt

#### 7.4.4 useRemote

Wenn Nutzer **„Server übernehmen"** wählt:
- `requireRemoteBaselineEtag(remoteVersion)` prüft, ob eine belastbare Baseline vorhanden ist
  - zulässig: `remoteVersion.etag` oder `remoteVersion.lastSyncedEtag`
  - nicht zulässig: `remotePath`, leerer String
  - fehlt eine belastbare Baseline: Abbruch mit `StateError`
- `_db.upsertArtikel(remoteVersion, etag: remoteEtag)` übernimmt Remote-Version lokal
- `_db.clearPendingResolution(uuid)` löscht offene Sonderbehandlung
- Konflikt ist damit sofort aufgelöst

#### 7.4.5 merge

Wenn Nutzer **„Zusammenführen"** wählt:
- Merge-Ergebnis wird lokal gespeichert
- `pending_resolution = force_merge`
- nächster Sync darf diese Merge-Version gezielt hochladen
- nach erfolgreichem Push wird der Zustand wieder bereinigt

#### 7.4.6 skip

Wenn Nutzer **„Überspringen"** wählt:
- keine Auflösung wird persistiert
- Datensatz bleibt pending
- Konflikt erscheint beim nächsten Sync erneut

#### 7.4.7 delete vs remote edit

Wenn lokal ein Soft-Delete markiert wurde, der Remote-Datensatz aber seit `last_synced_etag` verändert wurde oder keine stabile Vergleichsbasis vorhanden ist:
- keine direkte Remote-Löschung
- Konflikt statt blindem Delete
- bewusste Auflösung durch den Nutzer erforderlich

---

## 8. Sync-Invarianten (niemals brechen)

| Invariante | Bedeutung |
| :--- | :--- |
| `uuid` ist stabil | Nie ändern — geräteübergreifender Identifier |
| `remote_path` = PocketBase Record-ID | Verbindung zum Server — nie ohne sauberen Sync neu belegen |
| `etag = NULL` oder leer | Lokaler Datensatz ist dirty / pending |
| `last_synced_etag` bleibt bei normalen lokalen Änderungen erhalten | Vergleichsbasis für spätere Konflikterkennung |
| `pending_resolution = force_local` | Nächster Sync darf bewusst lokal überschreiben |
| `pending_resolution = force_merge` | Nächster Sync darf bewusst Merge-Ergebnis pushen |
| `deleted = 1` | Soft-Delete lokal; tatsächliche Server-Löschung nur ohne Konflikt |
| `setBildPfadByUuidSilent()` | Setzt nur `bildPfad`, löst keinen normalen Datensync-Trigger aus |
| `clearBildInfoByUuidSilent()` | Löscht Bildinformationen lokal, löst keinen normalen Datensync aus |
| `toPocketBaseMap()` überträgt keine lokalen Konflikt-Steuerfelder | `last_synced_etag` und `pending_resolution` bleiben lokal |
| `toPocketBaseMap()` überträgt `erstelltAm`/`aktualisiertAm` als UTC-ISO-Strings | Zeitstempel-Konsistenz mit PocketBase |
| `_extractBildName()` ist die einzige Normalisierungsstelle für PocketBase `bild` | Verhindert stille Fehler bei `List<String>` vs. `String` |
| `remoteBildPfad` wird nur durch `markSynced()` oder `upsertArtikel()` gesetzt | Keine manuellen lokalen Schreibzugriffe |
| `saveRemoteConflictSnapshot()` / `loadRemoteConflictSnapshot()` sind die einzigen Stellen für `conflict_snapshots` | Kapselt Snapshot-Persistenz vollständig |
| Konflikt-Callback pro UUID maximal einmal pro `syncOnce()`-Lauf | UUID-Guard im Push-Pfad verhindert Doppelauslösung |
| Pull-Delete-Block nur wenn `remoteUuids` nicht leer | Schützt vor versehentlichem Massendelete bei leerer Remote-Liste |

---

## 9. 🔀 Konflikt-Erkennung & Callback-Registrierung

### 9.1 Konflikt-Snapshot-Strategie

Der Konflikt-Callback wird ausschließlich im **Push-Pfad** ausgelöst,
niemals direkt im Pull-Pfad. Das verhindert doppelte Callback-Auslösungen
und stellt sicher, dass Remote-Bildinformationen im Konflikt-Objekt
vollständig vorhanden sind.

**Ablauf:**

1. **Pull** erkennt potenziellen Konflikt (lokal dirty + Remote geändert):
   - speichert Remote-Stand via `saveRemoteConflictSnapshot()` in `conflict_snapshots`
   - löst **keinen** Callback aus

2. **Push** verarbeitet denselben Datensatz:
   - lädt Snapshot via `loadRemoteConflictSnapshot()`
   - ruft `_emitConflictIfPossible(lokal, snapshot)` **genau einmal** auf
   - UUID-Guard verhindert doppelten Callback im selben Sync-Zyklus

**Fachlicher Effekt:**
- Pull und Push sind sauber entkoppelt
- Konflikt-Callback pro UUID maximal einmal pro `syncOnce()`-Lauf
- Snapshots älter als 24 Stunden werden von `loadRemoteConflictSnapshot()` ignoriert

### 9.2 ConflictCallback Typedef

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

Der Callback wird intern über `_emitConflictIfPossible(lokal, remote)` aufgerufen.
Ein UUID-Guard stellt sicher, dass pro `syncOnce()`-Lauf jede UUID maximal einmal
einen Callback auslöst. Der Callback wird vom `SyncOrchestrator` gesetzt und leitet
Konflikte an den `ConflictResolutionScreen` weiter.

### 9.3 Callback-Registrierung via GlobalKey

Die Registrierung erfolgt nach dem ersten Frame, damit ein nutzbarer
`NavigatorState` verfügbar ist. Die Navigation zum
`ConflictResolutionScreen` läuft über ein `GlobalKey<NavigatorState>`.

Der UI-Flow ist zusätzlich gegen doppelte parallele Öffnungen des
Konflikt-Screens gehärtet.

### 9.4 DB-Reopen nach App-Resume

Nach einem Hintergrundwechsel (`AppLifecycleState.resumed`) wird die
SQLite-Verbindung explizit wiederhergestellt, bevor ein neuer Sync startet:

`openDatabase()` ist idempotent und bei bereits geöffneter DB ein No-op.

---

## 10. 🖼️ Bild-Synchronisation

Die Bild-Sync-Logik arbeitet getrennt von den Textdaten. Produktiv relevant ist vor allem der Download fehlender oder veralteter lokaler Bilddateien.

### 10.1 Download-Logik

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

### 10.2 Bild-Fallback-Kette (Mobile/Desktop)

Nach einem Kaltstart existieren keine lokalen Bilddateien. Die Widgets
nutzen eine 4-stufige Fallback-Kette:

| Priorität | Quelle | Widget |
| :--- | :--- | :--- |
| 1 | Lokales Thumbnail (`thumbnailPfad`) | `_LocalThumbnail` |
| 2 | Lokales Vollbild (`bildPfad`) | `_LocalThumbnail` / `ArtikelDetailBild` |
| 3 | PocketBase-URL via `CachedNetworkImage` | `_buildPbFallback()` / `_buildPbDetailFallback()` |
| 4 | Placeholder-Icon | `_BildPlaceholder` / `_Placeholder` |

Die Bilder werden im Hintergrund von `downloadMissingImages()` heruntergeladen.
Beim nächsten Laden der Artikelliste (nach `SyncStatus.success`) werden die
lokalen Dateien verwendet.

---

## 11. 🔁 SyncStatusProvider Interface

### 11.1 Warum ein Interface?

`ArtikelListScreen` muss auf Sync-Events reagieren (z.B. um die Artikelliste
nach einem erfolgreichen Sync neu zu laden), braucht aber nicht die volle
`SyncOrchestrator`-API. Das `SyncStatusProvider`-Interface bietet:

- **Lose Kopplung:** Screen kennt nur den Stream, nicht den Orchestrator
- **Testbarkeit:** `FakeSyncStatusProvider` ermöglicht Unit-Tests ohne echten Sync-Mechanismus
- **Single Responsibility:** Orchestrator bleibt für Sync zuständig, Screen nur für Darstellung

### 11.2 Datenfluss

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

### 11.3 SyncManagementScreen

`SyncManagementScreen` erhält eine `SyncOrchestrator`-Instanz als Parameter
und ruft `orchestrator.runOnce()` auf — nicht `SyncService` direkt.

**Korrekt:**

```dart
orchestrator.runOnce();
```

---

## 12. 🚀 Performance & Indizes

### 12.1 Lokale SQLite-Indizes (`artikel`-Tabelle)

| Index | Spalte(n) | Zweck |
| :--- | :--- | :--- |
| `idx_artikel_uuid` | `uuid` | Schneller Abgleich bei Push/Pull |
| `idx_artikel_updated_at` | `updated_at` | Delta-Sync-Abfragen |
| `idx_artikel_deleted` | `deleted` | Soft-Delete-Filterung |
| `idx_artikel_name` | `name` | Schnelle Suche im Artikelnamen |
| `idx_artikel_name_ort_fach` | `name`, `ort`, `fach` | Duplikat-Check (Kombination) |
| `idx_artikel_artikelnummer` | `artikelnummer` | Duplikat-Check (Artikelnummer) |

> **Hinweis:** `idx_artikel_artikelnummer` ist kein UNIQUE-Index.
> Die Eindeutigkeit von `artikelnummer` wird fachlich über `existsArtikelnummer()` geprüft, nicht über einen DB-Constraint.

> **Hinweis:** `updated_at` und `deleted` haben getrennte Indizes — es gibt keinen kombinierten `idx_sync`-Index.

### 12.2 PocketBase-Indizes (`attachments`-Collection)

| Index | Zweck |
| :--- | :--- |
| `idx_attachments_artikel_uuid` | Zugriff auf Anhänge eines Artikels |
| `idx_attachments_uuid` | UUID-basierter Abgleich |
| `idx_attachments_sort` | Sortierreihenfolge |
| `idx_attachments_deleted` | Soft-Delete-Filterung |

---

## 13. 🎛️ F-006 / F-007 — Log-Dialog & Sync-Zeitstempel-Toggle

### 13.1 F-006: Log-Level-Filter als Dropdown

Der In-App Log-Dialog verwendet einen `DropdownButton<Level>` statt der
früheren horizontalen Button-Reihe.

**O-013:** Der Default-Level wird beim Öffnen aus `SharedPreferences`
geladen (Key: `logViewerDefaultLevelPrefsKey`, Fallback: `error`).
Jede Änderung im Dropdown wird sofort persistiert. Konfigurierbar
auch über die Entwickler-Card im Settings-Screen.

### 13.2 F-007: Sync-Zeitstempel-Toggle (ValueNotifier-Pattern)

Der Sync-Zeitstempel in der `ArtikelListScreen`-AppBar kann in den
Einstellungen ein- und ausgeblendet werden.

---

## 14. 🧩 Screen-/Controller-Trennung (O-010)

Seit `v0.9.1+29` wird im Settings-Bereich zwischen UI und fachlicher Logik
klarer getrennt:

- `SettingsScreen`: Rendering, Dialoge, SnackBars, Navigation, Logout-Handling
- `SettingsController`: Laden/Speichern der Settings, Dirty-Tracking,
  PocketBase-URL-Prüfung, App-Lock-Status, DB-Status
- `settings_state.dart`: UI-neutraler geteilter Settings-State
  (`showLastSyncNotifier`, Prefs-Key, Defaultwert)

### 14.1 Settings-Cards (Übersicht)

| Card | Inhalt | Seit |
| :--- | :--- | :--- |
| Benutzerkonto | Login-Status, E-Mail, Logout | v0.7.3 |
| PocketBase Server | URL, Verbindungstest, Sync-Zeitstempel-Toggle | v0.5.0 |
| Backup-Status | `BackupStatusWidget` | v0.8.0 |
| Sicherheit | App-Lock, Biometrie, Timeout-Slider | v0.8.2 |
| Artikelnummer | Start-Nummer, DB-Löschung | v0.6.0 |
| **Entwickler** | Log-Viewer Default-Level (Dropdown, `SharedPreferences`) | **v0.9.5 (O-013)** |
| App-Information | Version, Plattform, Auth-Status | v0.5.0 |

---

## 14a. 📐 Responsive Layout & Master-Detail (F-011.7)

### 14a.1 Breakpoints (`lib/core/responsive.dart`)

| ScreenSize | Breite | Verhalten |
| :--- | :--- | :--- |
| `mobile` | < 600px | Klassische Navigation, `Navigator.push` |
| `tablet` | 600–1023px | Klassische Navigation, `Navigator.push` |
| `desktop` | ≥ 1024px | Master-Detail-Layout inline |

Breakpoint-Werte in `AppConfig`:
- `breakpointTablet` = 600
- `breakpointDesktop` = 1024

### 14a.2 Master-Detail auf Desktop

Ab Desktop-Breite zeigt `ArtikelListScreen` ein zweigeteiltes Layout:

```text
┌──────────────────────────────────────────────────────┐
│ AppBar (Titel, Suche, Sync, Filter, Settings)        │
├──────────────────┬───────────────────────────────────┤
│  NavigationRail  │                                   │
│  + Artikelliste  │   ArtikelDetailContent            │
│  (flex 2)        │   (flex 3)                        │
│                  │                                   │
│  ► Artikel A     │   Name: Artikel B                 │
│    Artikel B ◄── │   Menge: 42                       │
│    Artikel C     │   Ort: Regal 3 ...                │
│                  │                                   │
├──────────────────┴───────────────────────────────────┤
│ Platzhalter wenn kein Artikel ausgewählt             │
└──────────────────────────────────────────────────────┘
```

- Ausgewählter Artikel wird visuell in `primaryContainer` hervorgehoben
- Detail-Panel hat eigenen Header mit Titel, Actions und Close-Button
- Platzhalter-Widget wenn kein Artikel ausgewählt


### 14a.3 Widget-Architektur

| Widget                   | Datei                                      | Rolle                              |  
|:-------------------------|:-------------------------------------------|:-----------------------------------|  
| `ArtikelDetailContent`   | `lib/widgets/artikel_detail_content.dart` | Eigenständiges Widget mit gesamter Detail-Logik |  
| `ArtikelDetailScreen`     | `lib/screens/artikel_detail_screen.dart`   | Dünner Scaffold-Wrapper für Mobile-Navigation |  
| `ArtikelListScreen`       | `lib/screens/artikel_list_screen.dart`     | Master-Detail-Host auf Desktop     |


#### ArtikelDetailContent ist das zentrale Detail-Widget:

ArtikelDetailContent ist das zentrale Detail-Widget:

- `embedded`-Parameter: `true` = Desktop-Panel (kein eigener Scaffold), `false` = Mobile-Scaffold
- `onStateChanged`-Callback: informiert den Wrapper über State-Änderungen (AppBar-Rebuild)
- `buildActions(ColorScheme)`: liefert AppBar-Actions als Liste
- `titleText`: liefert den aktuellen Titel
- `hasUnsavedChanges`: für PopScope/Verwerfen-Dialog
- `didUpdateWidget`: reinitialisiert bei Artikelwechsel (Desktop)

`ArtikelDetailScreen` (Mobile):

- `ValueNotifier`-basierter Rebuild-Mechanismus für AppBar-Synchronisation
- `PopScope` mit Verwerfen-Dialog bei ungespeicherten Änderungen

### 14a.4 maxContentWidth

- `AppConfig.maxContentWidth` = 1400
- `ConstrainedBox` wird nur auf Mobile/Tablet angewendet (in `main.dart`)
- Desktop nutzt die volle Viewport-Breite für Master-Detail

--- 

## 15. 🎨 Design-System & Konfiguration

Um die Wartbarkeit zu erhöhen, nutzt die App eine dreistufige Konfiguration in `app/lib/config/`:

1. **`AppConfig`**: Hält technische Konstanten.
2. **`AppTheme`**: Implementiert Material 3 mit Unterstützung für `ThemeMode.system`.
3. **`AppImages`**: Verwaltet Asset-Pfade und Feature-Flags.

Responsive-Logik ist in `lib/core/responsive.dart` gekapselt (siehe Abschnitt 14a).

---

## 16. 🛠️ Plattform-Abstraktion (Conditional Imports)

Da `dart:io` im Web nicht existiert, nutzt die App **Conditional Imports**.
Dies verhindert Compiler-Fehler auf verschiedenen Plattformen.

---

## 17. 🛡️ Sicherheits-Architektur

1. **PocketBase Rules**: Zugriff im Produktionsmodus strikt an Auth/Rollen gebunden.
2. **Caddy Security**: gehärtete HTTP-Header.
3. **Network Isolation**: interne Docker-Kommunikation.
4. **Datei-Validierung**: MIME-Type-Prüfung serverseitig.
5. **App-Lock**: biometrische Sperre auf nativen mobilen Plattformen.

---

## 18. 📄 Dokument-Verwaltung

Der Artikel-Detail-Screen enthält einen dedizierten **Dokumente-Tab** für Upload, Öffnen und Löschen von Anhängen.

---

## 19. Wartungs-Notiz

> **Zuletzt aktualisiert:** F-011.7 / 0.9.8+62 (2026-05-15)
> Responsive Breakpoints und Master-Detail-Layout dokumentiert (Abschnitt 14a)
> ArtikelDetailContent als eigenständiges Widget dokumentiert
> ArtikelDetailScreen als dünner Scaffold-Wrapper mit ValueNotifier-Rebuild
> Projektstruktur: `core/` um Responsive ergänzt, Widgets auf 13 aktualisiert
> maxContentWidth auf 1400 erhöht, ConstrainedBox nur Mobile/Tablet
> Architekturtext gegen historische ETag-only-Beschreibungen konsolidiert
> Konflikterkennung auf `last_synced_etag` als stabile Vergleichsbasis dokumentiert
> Fehlende Konfliktbasis bei bestehendem Remote-Datensatz als konservativer Konfliktfall nachgezogen
> `pending_resolution` für `force_local` und `force_merge` konsolidiert
> Guard gegen doppelte Konflikt-UI-Öffnung berücksichtigt
> Duplicate-UUID-Recovery im Create-Pfad dokumentiert
> Serverseitige UUID-Absicherung (`required` + `unique`) nachgezogen
> Logging für Duplicate-UUID-Recovery als aktueller Sync-Bestandteil berücksichtigt
> Konflikt-Snapshot-Strategie (Pull→Snapshot, Push→Callback) ergänzt
> `toPocketBaseMap()` — übertragene und ausgeschlossene Felder dokumentiert
> `_extractBildName()` als einzige Normalisierungsstelle für PocketBase `bild` dokumentiert
> `remoteBildPfad`-Invariante und Snapshot-Methoden-Invariante ergänzt
> Datenmodell-Tabelle um `thumbnailEtag`, `aktualisiertAm`, `device_id`, DB-Version und Migrationen ergänzt
> `artikelnummer`-Regel (`>= 1`) und PocketBase-Schema-Hintergrund dokumentiert
> Pull-Delete-Guard (`remoteUuids.isNotEmpty`) als Invariante nachgezogen
> `useRemote`-Fail-fast via `requireRemoteBaselineEtag()` dokumentiert
> Abschnittsnummerierung (1–19 + 14a) durchgängig ergänzt
> Indexnamen gegen `artikel_db_service.dart` verifiziert und korrigiert
> Teststand: 24 + 15 + 11 = 50 Detail/List/Erfassen-Tests grün

[Zurück zur README](../README.md) | [Zu den Installationsdetails](../INSTALL.md) | [Vollständige Projektstruktur](PROJECT_STRUCTURE.md) | [CI/CD & Deployment](../DEPLOYMENT.md)