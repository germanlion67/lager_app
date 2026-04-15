# 🗄️ Datenbank-Design & Synchronisation

Dieses Dokument bietet eine detaillierte technische Referenz für das Datenmodell, die Synchronisations-Logik und die Performance-Optimierungen der **Lager_app**.

---

## 🏗️ Architektur-Übersicht

Die App nutzt zwei persistente Datenspeicher:
1.  **Lokale SQLite (`artikel.db`)**: Offline-Speicher auf dem Endgerät (Pfad: `app/.../artikel.db`).
2.  **PocketBase Server (`data.db`)**: Zentrale Datenbank für Multi-Device Sync (Pfad: `server/pb_data/data.db`).

---

## 📂 1. Lokale Datenbank-Struktur

### 1.1 Tabelle: `artikel` (Haupttabelle)
| Spalte | Typ | Beschreibung |
|---|---|---|
| `id` | INTEGER | Lokaler Auto-Increment Primärschlüssel |
| `artikelnummer` | INTEGER | Fachliche Artikelnummer (1000+) |
| `name` | TEXT | Artikelname |
| `menge` | INTEGER | Aktueller Lagerbestand |
| `ort` / `fach` | TEXT | Lagerhierarchie |
| `beschreibung` | TEXT | Freitextbeschreibung |
| `kategorie` | TEXT | Artikelkategorie |
| `uuid` | TEXT | **Globaler Identifier** (v4), geräteübergreifend eindeutig |
| `remote_path` | TEXT | **PocketBase Record-ID** (Verbindung zum Server) |
| `updated_at` | INTEGER | Letzter Änderungszeitpunkt (Unix ms) |
| `deleted` | INTEGER | Soft-Delete Flag (0 = aktiv, 1 = gelöscht) |
| `etag` | TEXT | ETag für die HTTP-Cache-Validierung |
| `bildPfad` | TEXT | Lokaler Pfad zum Originalbild |
| `thumbnailPfad`| TEXT | Lokaler Pfad zum Vorschaubild |
| `remoteBildPfad`| TEXT | Dateiname des Bildes auf dem Server |
| `erstelltAm` | TEXT | ISO 8601 Erstellungsdatum |

### 1.2 Tabelle: `artikel_dokumente`
Speichert Dokumente (PDF, DOCX, etc.), die einem Artikel zugeordnet sind.

| Spalte | Typ | Beschreibung |
|---|---|---|
| `id` | INTEGER | Lokaler Auto-Increment Primärschlüssel |
| `artikel_uuid` | TEXT | **Fremdschlüssel** zur `artikel.uuid` |
| `uuid` | TEXT | Globaler Identifier des Dokuments (v4) |
| `remote_path` | TEXT | PocketBase Record-ID des Dokuments |
| `dateiname` | TEXT | Originaler Dateiname (z. B. `datenblatt.pdf`) |
| `dateityp` | TEXT | MIME-Type (z. B. `application/pdf`) |
| `dateipfad` | TEXT | Lokaler Pfad zur gespeicherten Datei |
| `remoteDokumentPfad` | TEXT | Dateiname des Dokuments auf dem Server |
| `beschreibung` | TEXT | Optionale Beschreibung des Dokuments |
| `erstelltAm` | TEXT | ISO 8601 Erstellungsdatum |
| `updated_at` | INTEGER | Letzter Änderungszeitpunkt (Unix ms) |
| `deleted` | INTEGER | Soft-Delete Flag (0 = aktiv, 1 = gelöscht) |
| `etag` | TEXT | ETag für HTTP-Cache-Validierung |

### 1.3 Tabelle: `sync_meta`
Speichert den Status der letzten erfolgreichen Synchronisation.
*   **`last_sync`**: Unix-Timestamp (ms) des letzten Durchlaufs. Nur Datensätze mit `updated_at > last_sync` werden im nächsten Zyklus geprüft.

---


### 1.4 PocketBase Collection: `attachments` (ab v0.7.2)

Dateianhänge pro Artikel. Wird ausschließlich in PocketBase gespeichert (kein lokales SQLite-Pendant).

| Feld | Typ | Required | Beschreibung |
|---|---|---|---|
| `artikel_uuid` | TEXT | ✅ | UUID des zugehörigen Artikels |
| `datei` | FILE | ✅ | Dateianhang (max 10 MB) |
| `bezeichnung` | TEXT | ✅ | Vom Nutzer vergebener Name |
| `beschreibung` | TEXT | ❌ | Optionale Beschreibung |
| `mime_type` | TEXT | ❌ | MIME-Typ (z.B. `application/pdf`) |
| `datei_groesse` | NUMBER | ❌ | Dateigröße in Bytes |
| `sort_order` | NUMBER | ❌ | Sortierreihenfolge |
| `uuid` | TEXT | ✅ | Client-seitige UUID |
| `etag` | TEXT | ❌ | Sync-ETag |
| `device_id` | TEXT | ❌ | Geräte-ID |
| `deleted` | BOOL | ❌ | Soft-Delete Flag |
| `updated_at` | NUMBER | ❌ | Sync-Timestamp |

**Erlaubte MIME-Types:**
`image/png`, `image/jpeg`, `image/webp`, `application/pdf`,
`application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`,
`application/vnd.ms-excel`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`,
`text/plain`, `text/csv`

**Limits:** Max 20 Anhänge pro Artikel, max 10 MB pro Datei.

**API-Regeln:** Auth-pflichtig seit v0.7.3 (M-009) — @request.auth.id != '' für alle Operationen.

---

## 🔄 2. Synchronisations-Prozess

Die Synchronisation folgt einem strikten Ablauf, um Datenkonsistenz über mehrere Geräte zu gewährleisten.

### 2.1 Ablauf-Diagramm (Artikel)
```text
┌─────────────────────────────────────────────────────────┐
│                      SYNC PROZESS                       │
│                                                         │
│  1. Lese 'last_sync' aus 'sync_meta'                    │
│                                                         │
│  2. LOCAL → REMOTE (Push)                               │
│     ├── WHERE etag IS NULL AND deleted = 0              │
│     │     └── CREATE oder UPDATE auf PocketBase         │
│     └── WHERE etag IS NULL AND deleted = 1              │
│           └── DELETE auf PocketBase (Hard-Delete)       │
│                                                         │
│  3. REMOTE → LOCAL (Pull)                               │
│     ├── Neue/geänderte Records von PocketBase holen     │
│     └── Lokal einfügen oder aktualisieren (upsert)      │
│                                                         │
│  4. Schreibe neuen 'last_sync' Timestamp                │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Konfliktauflösung (Sync-Identifier Strategie)
*   **`uuid`**: Bleibt immer gleich. Verhindert Duplikate bei Offline-Erstellung.
*   **`remote_path`**: Verknüpft den lokalen Datensatz fest mit dem Server-Record.
*   **`etag`**: Ein Wert von `NULL` signalisiert eine lokale Änderung, die noch nicht hochgeladen wurde ("Pending").

---

## 🖼️ 3. Bild-Synchronisation

Die Bild-Sync-Logik arbeitet getrennt von den Textdaten, um Bandbreite zu sparen.

```text
┌─────────────────────────────────────────────────────────┐
│                       BILD SYNC                         │
│                                                         │
│  Lokal Bild vorhanden?                                  │
│  ├── JA: remoteBildPfad leer oder ETag abweichend?      │
│  │       ├── JA → Bild hochladen → remoteBildPfad setzen│
│  │       └── NEIN → Kein Upload nötig                   │
│  └── NEIN: remoteBildPfad vorhanden?                    │
│            ├── JA → Bild vom Server laden → bildPfad    │
│            └── NEIN → Kein Bild vorhanden               │
└─────────────────────────────────────────────────────────┘
```

---

## 📄 4. Dokument-Synchronisation

Dokumente werden **unabhängig von Textdaten und Bildern** synchronisiert.
Jedes Dokument ist über `artikel_uuid` eindeutig einem Artikel zugeordnet.

### 4.1 PocketBase Collection: `artikel_dokumente`
| Feld                 | Typ       | Required | Beschreibung                                       |
| :------------------- | :-------- | :------- | :------------------------------------------------- |
| `artikel_uuid`       | `TEXT`    | ✅       | UUID des zugehörigen Artikels                     |
| `uuid`               | `TEXT`    | ✅       | Globaler Identifier des Dokuments (v4)             |
| `remote_path`        | `TEXT`    | ❌       | PocketBase Record-ID                               |
| `dateiname`          | `TEXT`    | ✅       | Originaler Dateiname (z.B. datenblatt.pdf)         |
| `dateityp`           | `TEXT`    | ❌       | MIME-Type (z.B. application/pdf)                   |
| `dateipfad`          | `TEXT`    | ❌       | Lokaler Pfad zur gespeicherten Datei (nur Native)  |
| `remoteDokumentPfad` | `TEXT`    | ❌       | Dateiname des Dokuments auf PocketBase             |
| `dokument`           | `FILE`    | ✅       | Die eigentliche Datei (PocketBase File-Field)      |
| `beschreibung`       | `TEXT`    | ❌       | Optionale Beschreibung                             |
| `erstelltAm`         | `TEXT`    | ❌       | ISO 8601 Erstellungsdatum                          |
| `updated_at`         | `NUMBER`  | ❌       | Unix-Timestamp ms (Delta-Sync)                     |
| `deleted`            | `BOOL`    | ❌       | Soft-Delete Flag                                   |
| `etag`               | `TEXT`    | ❌       | ETag — NULL = lokale Änderung ausstehend           |

### 4.2 Ablauf-Diagramm (Dokumente)
```text
┌─────────────────────────────────────────────────────────┐
│                    DOKUMENT SYNC                        │
│                                                         │
│  1. Push (LOCAL → REMOTE)                               │
│     ├── etag IS NULL AND deleted = 0                    │
│     │     ├── remote_path leer → POST (neues Dokument)  │
│     │     └── remote_path gesetzt → PATCH + Datei-Upload│
│     └── etag IS NULL AND deleted = 1                    │
│           └── DELETE auf PocketBase → lokal entfernen   │
│                                                         │
│  2. Pull (REMOTE → LOCAL)                               │
│     ├── Alle Dokumente des Artikels vom Server holen    │
│     ├── Datei herunterladen falls nicht lokal vorhanden │
│     └── Upsert in artikel_dokumente                     │
└─────────────────────────────────────────────────────────┘
```

### 4.3 Flutter-Implementierung
| Komponente        | Tatsächliche Datei            | Beschreibung                                       |
| :---------------- | :---------------------------- | :------------------------------------------------- |
| Datenklasse       | `attachment_model.dart`       | Dart-Klasse für Dateianhänge (MIME-Whitelist, Limits) |
| CRUD gegen PocketBase | `attachment_service.dart`     | Upload, Download, Delete gegen PocketBase REST-API |
| Sync-Logik        | `pocketbase_sync_service.dart`| Push/Pull mit ETag/UUID-Strategie                  |
| SQLite CRUD       | `artikel_db_service.dart`     | Lokale Operationen auf `artikel_dokumente`         |
| UI                | `artikel_detail_screen.dart`  | Dokumente-Tab: Liste, Upload, Download, Öffnen, Löschen |
| Upload-Widget     | `attachment_upload_widget.dart` | Upload-Dialog mit Validierung                      |
| Listen-Widget     | `attachment_list_widget.dart` | Anhang-Liste mit Download, Edit, Delete            |

### 4.4 UI-Funktionen im Dokumente-Tab
*   📎 **Upload**: Dateiauswahl via `file_picker`, Upload zu PocketBase
*   📥 **Download & Öffnen**: Datei lokal speichern und via `open_file` öffnen
*   🗑️ **Löschen**: Soft-Delete lokal → Hard-Delete beim nächsten Sync

---

## 🚀 5. Performance & Indizes

Um Abfragen bei großen Datenbeständen zu beschleunigen, sind folgende Indizes aktiv:

| Index                       | Tabelle             | Ziel                                       |
| :-------------------------- | :------------------ | :----------------------------------------- |
| `idx_unique_artikelnummer`  | `artikel`           | Schneller Zugriff via Fach-ID              |
| `idx_sync_delta`            | `artikel`           | Optimiert Abfragen auf `updated_at` & `deleted` |
| `idx_search_name`           | `artikel`           | Schnelle Suche im Artikelnamen             |
| `idx_uuid_lookup`           | `artikel`           | Schneller Abgleich bei Push/Pull           |
| `idx_dok_artikel_uuid`      | `artikel_dokumente` | Schneller Zugriff auf Dokumente eines Artikels |
| `idx_dok_sync_delta`        | `artikel_dokumente` | Optimiert Sync-Abfragen für Dokumente      |
| `idx_attachments_artikel_uuid`| `attachments` (PB)  | Schneller Zugriff auf Anhänge eines Artikels |
| `idx_attachments_uuid`      | `attachments` (PB)  | Schneller Abgleich bei Push/Pull           |
| `idx_attachments_sort`      | `attachments` (PB)  | Sortierreihenfolge                         |
| `idx_attachments_deleted`   | `attachments` (PB)  | Soft-Delete Filterung                      |

---

## 📐 6. System-Schaubild

```text
       ┌───────────────┐           ┌───────────────┐
       │  Flutter App  │           │  PocketBase   │
       │   (Client)    │           │   (Server)    │
       ├───────────────┤           ├───────────────┤
       │  SQLite DB    │◄─────────►│  SQLite DB    │
       │ (artikel.db)  │   REST    │  (data.db)    │
       │               │    API    │               │
       │ artikel       │◄─────────►│ artikel       │
       │ artikel_dok.  │◄─────────►│ artikel_dok.  │
       │ sync_meta     │           │ attachments   │◄── nur PB (kein SQLite)
       └───────┬───────┘           └───────┬───────┘
               │                           │
       ┌───────▼───────┐           ┌───────▼───────┐
       │ Lokale Bilder │◄─────────►│  PB Storage   │
       │  (/images)    │  HTTP     │  (/storage)   │
       ├───────────────┤           ├───────────────┤
       │ Lok. Dokumente│◄─────────►│  PB Storage   │
       │  (/dokumente) │  HTTP     │  (/storage)   │
       └───────────────┘           └───────────────┘
```

---

## Bild-Download bei Kaltstart (v0.8.0)

Bei einem Kaltstart (App-Daten gelöscht, neue PocketBase-URL) werden
Artikelbilder in zwei Phasen geladen:

1. **Record-Sync:** `syncOnce()` synchronisiert Metadaten inkl.
   `remoteBildPfad` (Dateiname auf PocketBase)
2. **Image-Sync:** `downloadMissingImages()` prüft alle Artikel und
   lädt fehlende Bilder von der PocketBase File-API herunter

### Neue DB-Methode: `setBildPfadByUuidSilent()`

```dart
Future<void> setBildPfadByUuidSilent(String uuid, String bildPfad)
```

Aktualisiert **nur** den lokalen `bildPfad`, ohne `updated_at` oder `etag`
zu ändern. Dadurch wird kein erneuter Push zum Server ausgelöst.

**Unterschied zu `setBildPfadByUuid()`:**

| Methode | Ändert `bildPfad` | Ändert `updated_at` | Sync-Trigger |
|---|---|---|---|
| `setBildPfadByUuid()` | ✅ | ✅ | ✅ Ja (wird als pending erkannt) |
| `setBildPfadByUuidSilent()` | ✅ | ❌ | ❌ Nein |

### Download-Logik

```
downloadMissingImages()
  → getAlleArtikel(limit: 999999)
  → Für jeden Artikel:
      → remoteBildPfad leer? → skip
      → remotePath (Record-ID) leer? → skip
      → Lokale Datei existiert und > 0 Bytes? → skip
      → HTTP GET /api/files/artikel/{recordId}/{filename}
      → Speichern in: {cacheDir}/images/{uuid}/{filename}
      → setBildPfadByUuidSilent(uuid, localPath)
```

--- 

[Zurück zur README](../README.md) | [Zur Architektur](ARCHITECTURE.md) | [Zum Projekt-Status](OPTIMIZATIONS.md)