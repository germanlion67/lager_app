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
│  │ • SSL Termination (Let's Encrypt)                    │      │
│  │ • Reverse Proxy                                      │      │
│  │ • Security Headers                                   │      │
│  │ • Rate Limiting (kommt mit H-003)                    │      │
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
│  └─────────────────┘  │   │  │ • Real-time Subscriptions     │  │
│                       │   |  | • CORS (--origins Flag, H-002)│  │
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

| Komponente | Mobile (Android/iOS) | Desktop (Linux/Win) | Web (Docker/Caddy) |
|---|---|---|---|
| **Frontend** | Flutter Native | Flutter Native | Flutter Web (SPA) |
| **Lokale DB** | SQLite (sqflite) | SQLite (FFI) | Keine (Direktzugriff) |
| **Dateisystem** | Pfad-basiert (Images, Docs) | Pfad-basiert (Images, Docs) | Browser Blob/Memory |
| **Sync-Logik** | Hintergrund-Worker | Manueller/Timer Sync | Nicht erforderlich |

---

## 📂 Projektstruktur (Übersicht)

```text
lager_app/
├── app/                    # Flutter Hauptanwendung
│   ├── lib/
│   │   ├── config/         # Zentrale Steuerung (AppConfig, AppTheme, AppImages)
│   │   ├── core/           # Plattform-Abstraktion (Logger, Exceptions)
│   │   ├── models/         # Datenklassen (Artikel, Attachment)
│   │   ├── screens/        # UI-Pages (15 Dateien + Conditional Imports)
│   │   ├── services/       # Business-Logik (30 Dateien + Conditional Imports)
│   │   ├── utils/          # Helfer (Validierung, UUID, Image-Tools)
│   │   └── widgets/        # Wiederverwendbare UI-Komponenten (12 Widgets)
│   └── test/               # 451 Tests, 18 Dateien
├── packages/               # Lokale Dart-Pakete (runtime_env_config)
├── server/                 # PocketBase Backend + Backup-Container
├── docs/                   # Dokumentation (16 Dateien)
└── .github/                # CI/CD Workflows (3 Pipelines)
```

→ **Vollständige Dateistruktur mit allen Dateien:** [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)

---

## 💾 Datenmodell (PocketBase Schema)

Das Herzstück der Anwendung ist die Collection `artikel`. Ergänzt wird sie durch die Collection `artikel_dokumente` für die Dokumentenverwaltung.

### Collection: `artikel`

| Feld | Typ | Beschreibung | Index |
|---|---|---|---|
| `uuid` | Text | Client-seitige Eindeutigkeit (Primary Key) | ✅ `idx_uuid` |
| `artikelnummer` | Number | Fortlaufende ID für Menschen (1000+) | ✅ `idx_unique_an` |
| `name` | Text | Bezeichnung des Artikels | ✅ `idx_search_name` |
| `menge` | Number | Aktueller Bestand (nur Ganzzahlen) | — |
| `ort` / `fach` | Text | Lager-Hierarchie | — |
| `bild` | File | Binärdatei in PocketBase (Max 5MB) | — |
| `deleted` | Boolean | Soft-Delete Flag für den Sync-Prozess | ✅ `idx_sync` |
| `updated_at` | Number | Unix-Timestamp für Delta-Sync | ✅ `idx_sync` |

### Collection: `artikel_dokumente`

Jedes Dokument ist über `artikel_uuid` eindeutig einem Artikel zugeordnet.
Unterstützte Dateitypen: PDF, DOCX, XLSX, TXT und weitere.

| Feld | Typ | Beschreibung | Index |
|---|---|---|---|
| `artikel_uuid` | Text | Fremdschlüssel zur `artikel.uuid` | ✅ `idx_dok_artikel_uuid` |
| `uuid` | Text | Client-seitige Eindeutigkeit des Dokuments | ✅ `idx_dok_uuid` |
| `dateiname` | Text | Originaler Dateiname (z. B. `datenblatt.pdf`) | — |
| `dateityp` | Text | MIME-Type (z. B. `application/pdf`) | — |
| `beschreibung` | Text | Optionale Beschreibung des Dokuments | — |
| `dokument` | File | Die eigentliche Datei (PocketBase File-Field) | — |
| `deleted` | Boolean | Soft-Delete Flag für den Sync-Prozess | ✅ `idx_dok_sync` |
| `updated_at` | Number | Unix-Timestamp für Delta-Sync | ✅ `idx_dok_sync` |

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

[Zurück zur README](../README.md) | [Zu den Installationsdetails](../INSTALL.md) | [Vollständige Projektstruktur](PROJECT_STRUCTURE.md)