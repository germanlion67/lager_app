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

### 1.2 Tabelle: `sync_meta`
Speichert den Status der letzten erfolgreichen Synchronisation.
*   **`last_sync`**: Unix-Timestamp (ms) des letzten Durchlaufs. Nur Datensätze mit `updated_at > last_sync` werden im nächsten Zyklus geprüft.

---

## 🔄 2. Synchronisations-Prozess

Die Synchronisation folgt einem strikten Ablauf, um Datenkonsistenz über mehrere Geräte zu gewährleisten.

### 2.1 Ablauf-Diagramm
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

## 🚀 4. Performance & Indizes

Um Abfragen bei großen Datenbeständen zu beschleunigen, sind folgende Indizes aktiv:

| Index | Ziel |
|---|---|
| `idx_unique_artikelnummer` | Schneller Zugriff via Fach-ID |
| `idx_sync_delta` | Optimiert Abfragen auf `updated_at` & `deleted` |
| `idx_search_name` | Schnelle Suche im Artikelnamen |
| `idx_uuid_lookup` | Schneller Abgleich bei Push/Pull |

---

## 📐 5. System-Schaubild

```text
       ┌───────────────┐           ┌───────────────┐
       │  Flutter App  │           │  PocketBase   │
       │   (Client)    │           │   (Server)    │
       ├───────────────┤           ├───────────────┤
       │  SQLite DB    │◄─────────►│  SQLite DB    │
       │ (artikel.db)  │   REST    │  (data.db)    │
       └───────┬───────┘    API    └───────┬───────┘
               │                           │
       ┌───────▼───────┐           ┌───────▼───────┐
       │ Lokale Bilder │◄─────────►│  PB Storage   │
       │  (/images)    │  HTTP     │  (/storage)   │
       └───────────────┘           └───────────────┘
```

---

[Zurück zur README](../README.md) | [Zum Projekt-Status](CHECKLIST.md)