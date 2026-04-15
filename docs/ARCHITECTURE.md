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
│   └── test/               # 590 Tests (3 skipped), 26 Testdateien
├── packages/               # Lokale Dart-Pakete (runtime_env_config)
├── server/                 # PocketBase Backend + Backup-Container
├── docs/                   # Dokumentation (16 Dateien)
└── .github/                # CI/CD Workflows (4 Pipelines)
```

→ **Vollständige Dateistruktur mit allen Dateien:** [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

---

## 💾 Datenmodell (PocketBase Schema)

Das Herzstück der Anwendung ist die Collection `artikel`. Ergänzt wird sie durch die Collection `artikel_dokumente` für die Dokumentenverwaltung.

### Collection: `artikel`

| Feld           | Typ       | Beschreibung                                       | Index              |
| :------------- | :-------- | :------------------------------------------------- | :----------------- |
| `id`           | `INTEGER` | Lokaler Auto-Increment PK (nur SQLite)             | —                  |
| `uuid`         | `TEXT`    | Globaler Identifier (RFC-4122 V4), geräteübergreifend eindeutig | ✅ `idx_uuid`      |
| `artikelnummer`| `INTEGER` | Fachliche ID (≥ 1000), automatisch vergeben        | ✅ `idx_unique_an` |
| `name`         | `TEXT`    | Bezeichnung des Artikels (Pflicht, 2–100 Zeichen)  | ✅ `idx_search_name` |
| `menge`        | `INTEGER` | Lagerbestand (≥ 0, max 999.999)                    | —                  |
| `ort`          | `TEXT`    | Lagerort (Pflichtfeld)                             | —                  |
| `fach`         | `TEXT`    | Lagerfach (Pflichtfeld)                            | —                  |
| `beschreibung` | `TEXT`    | Freitext                                           | —                  |
| `kategorie`    | `TEXT`    | Kategorie                                          | —                  |
| `remote_path`  | `TEXT`    | PocketBase Record-ID (Verbindung zum Server)       | —                  |
| `updated_at`   | `INTEGER` | Unix-Timestamp ms (Delta-Sync)                     | ✅ `idx_sync`      |
| `deleted`      | `INTEGER` | Soft-Delete (0 = aktiv, 1 = gelöscht)              | ✅ `idx_sync`      |
| `etag`         | `TEXT`    | `NULL` = lokale Änderung ausstehend (Pending)      | —                  |
| `bildPfad`     | `TEXT`    | Lokaler Pfad Originalbild                          | —                  |
| `thumbnailPfad`| `TEXT`    | Lokaler Pfad Vorschaubild                          | —                  |
| `remoteBildPfad`| `TEXT`    | Dateiname auf PocketBase                           | —                  |
| `erstelltAm`   | `TEXT`    | ISO 8601 Erstellungsdatum                          | —                  |

### Collection: `artikel_dokumente`

Jedes Dokument ist über `artikel_uuid` eindeutig einem Artikel zugeordnet.
Unterstützte Dateitypen: PDF, DOCX, XLSX, TXT und weitere.

| Feld                 | Typ       | Beschreibung                                       | Index                |
| :------------------- | :-------- | :------------------------------------------------- | :------------------- |
| `artikel_uuid`       | `TEXT`    | FK → `artikel.uuid`                                | ✅ `idx_dok_artikel_uuid` |
| `uuid`               | `TEXT`    | Globaler Identifier des Dokuments                  | ✅ `idx_dok_uuid`    |
| `remote_path`        | `TEXT`    | PocketBase Record-ID                               | —                    |
| `dateiname`          | `TEXT`    | Originaler Dateiname (z.B. datenblatt.pdf)         | —                    |
| `dateityp`           | `TEXT`    | MIME-Type (z.B. application/pdf)                   | —                    |
| `dateipfad`          | `TEXT`    | Lokaler Pfad (nur Native)                          | —                    |
| `remoteDokumentPfad` | `TEXT`    | Dateiname auf PocketBase                           | —                    |
| `beschreibung`       | `TEXT`    | Optionale Beschreibung                             | —                    |
| `erstelltAm`         | `TEXT`    | ISO 8601                                           | —                    |
| `updated_at`         | `INTEGER` | Unix-Timestamp ms (Delta-Sync)                     | ✅ `idx_dok_sync`    |
| `deleted`            | `INTEGER` | Soft-Delete (0 = aktiv, 1 = gelöscht)              | ✅ `idx_dok_sync`    |
| `etag`               | `TEXT`    | `NULL` = lokale Änderung ausstehend (Pending)      | —                    |

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

### Synchronisations-Logik (Offline-First)

Der Sync-Prozess nutzt das **Last-Write-Wins** Prinzip in Verbindung mit einem **Soft-Delete** Mechanismus:
1.  **Push**: Lokale Änderungen (SQLite) werden anhand der `uuid` zu PocketBase gepusht.
2.  **Pull**: Datensätze, deren `updated_at` neuer als der letzte Sync-Zeitpunkt ist, werden heruntergeladen.
3.  **Conflict**: Bei gleichzeitiger Änderung wird der Nutzer über den `ConflictResolutionScreen` zur Entscheidung aufgefordert.
4.  **Dokumente**: Werden in einem **separaten Sync-Zyklus** behandelt — unabhängig von Textdaten und Bildern.

### Sync-Invarianten (niemals brechen)
| Invariante                 | Bedeutung                                            |
| :------------------------- | :--------------------------------------------------- |
| `uuid` ist stabil          | Nie ändern — geräteübergreifender Identifier         |
| `remote_path` = PB Record-ID | Verbindung zum Server — nie überschreiben ohne Sync  |
| `etag` = `NULL`            | Lokale Änderung ausstehend — muss gepusht werden     |
| `deleted` = `1`            | Soft-Delete lokal → Hard-Delete beim nächsten Push   |
| `setBildPfadByUuidSilent()`| Setzt nur `bildPfad`, löst keinen Sync-Trigger aus   |


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
4.  **Datei-Validierung**: Beim Dokument-Upload wird der MIME-Type serverseitig geprüft, um unerwünschte Dateitypen abzuweisen.
5. **App-Lock (F-001/F-002)**: Auf nativen Plattformen (Android, Desktop) kann die App mit biometrischer Authentifizierung (`local_auth`) gesperrt werden. Bei nicht verfügbarer Biometrie greift der Geräte-PIN als Fallback. Die Sperrzeit ist konfigurierbar (Standard: 5 Minuten Inaktivität).

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

[Zurück zur README](../README.md) | [Zu den Installationsdetails](../INSTALL.md) | [Vollständige Projektstruktur](PROJECT_STRUCTURE.md) | [CI/CD & Deployment](../DEPLOYMENT.md)