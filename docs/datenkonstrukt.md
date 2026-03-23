# 📦 Lager App – Datenkonstrukt Dokumentation

> **Erstellt:** 2026-03-19  
> **Zuletzt aktualisiert:** 2026-03-23  
> **Status:** Analysiert & Verifiziert  
> **Zweck:** Vollständige Dokumentation aller Datenbankstrukturen, Felder, Verbindungen und Sync-Logiken der Lager App

---

## 📁 Übersicht: Datenbanken

Die App verwendet **zwei SQLite-Datenbanken**:

| Datenbank | Pfad | Zweck |
|-----------|------|-------|
| **Lokale DB** | `app/.dart_tool/sqflite_common_ffi/databases/artikel.db` | Offline-Speicher auf dem Gerät |
| **PocketBase DB** | `server/pb_data/data.db` | Server-seitiger Sync & Backup |

---

## 🗄️ 1. Lokale Datenbank (`artikel.db`)

### 1.1 Tabelle: `artikel`

Haupttabelle für alle Lagerartikel.

> **Aktuelle Schema-Version:** `4` (PRAGMA user_version)

| # | Spalte | Typ | NOT NULL | Beschreibung |
|---|--------|-----|----------|--------------|
| 0 | `id` | INTEGER | ✅ (PK) | Lokaler Auto-Increment Primärschlüssel |
| 1 | `name` | TEXT | ❌ | Artikelname |
| 2 | `artikelnummer` | INTEGER | ❌ | **Neu (M-007):** Fachliche Artikelnummer |
| 3 | `menge` | INTEGER | ❌ | Lagerbestand (Stückzahl) |
| 4 | `ort` | TEXT | ❌ | Lagerort (z.B. Regal, Raum) |
| 5 | `fach` | TEXT | ❌ | Lagerfach innerhalb des Orts |
| 6 | `beschreibung` | TEXT | ❌ | Freitextbeschreibung des Artikels |
| 7 | `bildPfad` | TEXT | ❌ | Lokaler Dateipfad zum Originalbild |
| 8 | `thumbnailPfad` | TEXT | ❌ | Lokaler Dateipfad zum Thumbnail |
| 9 | `thumbnailEtag` | TEXT | ❌ | ETag des Thumbnails (Cache-Validierung) |
| 10 | `erstelltAm` | TEXT | ❌ | ISO 8601 Erstellungszeitpunkt |
| 11 | `aktualisiertAm` | TEXT | ❌ | ISO 8601 letzter Änderungszeitpunkt |
| 12 | `remoteBildPfad` | TEXT | ❌ | Dateiname des Bildes auf PocketBase-Server |
| 13 | `uuid` | TEXT | ✅ | Geräteübergreifende eindeutige ID (UUID v4) |
| 14 | `updated_at` | INTEGER | ✅ (default 0) | Letzter Änderungszeitpunkt in **Millisekunden** (Unix) |
| 15 | `deleted` | INTEGER | ✅ (default 0) | Soft-Delete Flag: `0` = aktiv, `1` = gelöscht |
| 16 | `etag` | TEXT | ❌ | ETag für HTTP-Cache-Validierung |
| 17 | `remote_path` | TEXT | ❌ | **PocketBase Record-ID** (Fremdschlüssel zum Server) |
| 18 | `device_id` | TEXT | ❌ | Geräte-ID des erstellenden Geräts |
| 19 | `kategorie` | TEXT | ❌ | Artikelkategorie |

#### 🔑 Schlüsselfelder erklärt

```
id             → Lokaler PK (nur auf diesem Gerät gültig)
artikelnummer  → Fachliche Nummer (M-007, menschenlesbar)
uuid           → Globaler Identifier (geräteübergreifend eindeutig)
remote_path    → PocketBase Record-ID (Verbindung zum Server)
deleted        → Soft-Delete (Artikel bleibt lokal erhalten, wird aber als gelöscht markiert)
updated_at     → Sync-Entscheidungsgrundlage (wer ist neuer?)
```

#### Beispieldaten

```
id    uuid                                  name      remote_path       deleted
1000  055e839a-bc16-476b-8c50-f884238e81da  name_4    2vtsq7weii5zn5s   0
1001  a5e48c7f-06d4-a93d-1d69-242886e346b6  a         03wz1edywd6zddc   0
1002  d4b166b8-f2d7-3134-e5f0-4c2fc440a3b2  b         outsgg76xa6svlu   0
1003  c19cc080-8a3d-c22b-25cc-57ccd5430212  name_1    858hlpzkpqu52ug   1  ← gelöscht
1004  f6dda291-2ba1-90ee-dc0a-833f9e67dc6a  name_c    1r0g8bpx7j55h92   0
1005  fc7d9ef7-0fa4-5262-af78-bb1bf4a305d6  name_d    v3qkc9xguw4705x   0
1006  d4ef6295-4913-43a3-9757-fc2b37c8550a  Name_7    tas3qcaf6mzl360   0
1007  0f53a268-6594-4940-b9a8-61824742b428  name_77   30q6u3jsfogee7g   0
```

---

### 1.2 Tabelle: `sync_meta`

Speichert Metadaten über den letzten Synchronisationsvorgang.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| `key` | TEXT | Schlüssel (z.B. `last_sync`) |
| `value` | TEXT/INTEGER | Wert des Schlüssels |
| `updated_at` | INTEGER | Zeitpunkt der letzten Änderung (Unix ms) |

#### Aktueller Eintrag

```
last_sync
1773922514098 → 2026-03-18 ~17:15 Uhr (Unix ms)
```

> **Zweck:** Der `last_sync`-Wert bestimmt, welche Änderungen seit dem letzten Sync neu sind. Nur Datensätze mit `updated_at > last_sync` werden synchronisiert.

---

### 1.3 Indizes (`artikel`)

| Index | Spalte | Zweck |
|-------|--------|-------|
| `idx_artikel_updated_at` | `updated_at` | Schneller Sync-Filter |
| `idx_artikel_uuid` | `uuid` | UUID-Lookup |
| `idx_artikel_deleted` | `deleted` | Soft-Delete-Filter |
| `idx_artikel_name` | `name` | Suche nach Name |

---

### 1.4 Migrationsverlauf

| Version | Änderung |
|---------|----------|
| `1` | Initiales Schema (`id`, `name`, `menge`, `ort`, `fach`, `beschreibung`, `bildPfad`, `erstelltAm`, `aktualisiertAm`, `remoteBildPfad`) |
| `2` | `kategorie` hinzugefügt |
| `3` | `uuid`, `updated_at`, `deleted`, `etag`, `remote_path`, `device_id`, `thumbnailPfad`, `thumbnailEtag` hinzugefügt; UUIDs für Bestandsdaten generiert; Indizes erstellt |
| `4` | **M-007:** `artikelnummer` hinzugefügt |

---

## ☁️ 2. PocketBase Server-Datenbank (`data.db`)

### 2.1 Alle Tabellen

```
artikel        → Hauptdaten (gespiegelt von lokal)
users          → Benutzerkonten
_collections   → PocketBase Collection-Definitionen
_migrations    → DB-Migrationsverlauf
_params        → PocketBase Konfigurationsparameter
_authOrigins   → Auth-Ursprünge
_externalAuths → Externe Auth-Provider (OAuth etc.)
_mfas          → Multi-Factor Authentication Daten
_otps          → One-Time Passwords
_superusers    → PocketBase Admin-Konten
```

### 2.2 Tabelle: `artikel` (PocketBase)

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| `id` | TEXT | PocketBase Record-ID (= `remote_path` in lokaler DB) |
| `name` | TEXT | Artikelname |
| `artikelnummer` | INTEGER | Fachliche Artikelnummer (M-007) |
| `menge` | INTEGER | Lagerbestand |
| *(weitere Felder)* | | Entsprechen den lokalen Feldern |

#### 📊 Beispieldaten

```
id (= remote_path)   name      menge
03wz1edywd6zddc      a         3
outsgg76xa6svlu      b         6
1r0g8bpx7j55h92      name_c    95
v3qkc9xguw4705x      name_d    8
2vtsq7weii5zn5s      name_4    4
tas3qcaf6mzl360      Name_7    10
30q6u3jsfogee7g      name_77   7
```

> **Hinweis:** `name_1` (lokal `deleted=1`) ist **nicht** in PocketBase vorhanden → Hard-Delete auf Server wurde korrekt ausgeführt.

---

## 🔗 3. Verbindungen & Mapping

### 3.1 ID-Mapping zwischen lokal und remote

```
Lokale DB                        PocketBase Server
─────────────────────────────────────────────────────
artikel.id (INTEGER)      ──┐
artikel.uuid (TEXT)       ──┤ Geräte-intern
artikel.artikelnummer     ──┤ Fachliche Nummer (M-007)
artikel.remote_path ────────────────────► artikel.id (TEXT)
```

### 3.2 Bild-Mapping

```
Lokale DB                        PocketBase Server
─────────────────────────────────────────────────────
artikel.bildPfad        → Lokaler Gerätepfad (absolut)
artikel.thumbnailPfad   → Lokaler Thumbnail-Pfad
artikel.remoteBildPfad  → Dateiname auf PocketBase
                          Format: bild_{uuid}_{record_id}.jpg
artikel.thumbnailEtag   → Cache-Validierung für Thumbnail
artikel.etag            → Cache-Validierung für Hauptbild
```

#### Beispiel Bild-Dateiname auf Server:

```
bild_a5e48c7f_06d4_a93d_1d69_242886e346b6_1w1zlzcylo.jpg
└─────────────── uuid ──────────────┘ └─ random ─┘
```

---

## 🔄 4. Sync-Logik

### 4.1 Sync-Ablauf (vereinfacht)

```
┌─────────────────────────────────────────────────────────┐
│                      SYNC PROZESS                       │
│                                                         │
│  1. Lese last_sync aus sync_meta                        │
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
│  4. Schreibe neuen last_sync Timestamp                  │
└─────────────────────────────────────────────────────────┘
```

> **Hinweis:** Pending-Erkennung erfolgt über `etag IS NULL` (nicht `updated_at > last_sync`). `etag = null` bedeutet: Artikel wurde lokal geändert, aber noch nicht mit dem Server synchronisiert.

### 4.2 Soft-Delete vs. Hard-Delete

| Aktion | Lokal | PocketBase |
|--------|-------|------------|
| Artikel löschen | `deleted = 1` gesetzt | Record wird gelöscht |
| Artikel bleibt lokal | ✅ (für Sync-History) | ❌ (endgültig weg) |
| Nach Sync | `deleted = 1` bleibt | Nicht mehr vorhanden |

### 4.3 Konfliktauflösung

```
Grundregel: updated_at entscheidet
─────────────────────────────────
Lokal neuer  (local.updated_at > remote.updated) → Lokal gewinnt  → Push
Remote neuer (remote.updated > local.updated_at) → Remote gewinnt → Pull
Gleich                                           → Keine Aktion
```

### 4.4 Sync-Identifier Strategie

```
uuid        → Wird beim Erstellen generiert (Gerät)
               Bleibt immer gleich, auch nach Server-Sync
               Verhindert Duplikate bei Offline-Erstellung

remote_path → Wird nach erstem erfolgreichen Push gesetzt
               Leer    = noch nie mit Server synchronisiert
               Gefüllt = bekannter PocketBase-Datensatz

etag        → Wird nach erfolgreichem Push/Pull gesetzt
               NULL    = pending (lokale Änderung nicht synchronisiert)
               Wert    = synchronisiert (HTTP-Cache-Validierung)
```

---

## 🖼️ 5. Bild-Sync Logik

```
┌─────────────────────────────────────────────────────────┐
│                       BILD SYNC                         │
│                                                         │
│  Lokal vorhanden (bildPfad gesetzt)?                    │
│  ├── JA:  remoteBildPfad leer?                          │
│  │        ├── JA  → Bild hochladen → remoteBildPfad     │
│  │        │         setzen, etag nullen (dirty)         │
│  │        └── NEIN → ETag vergleichen                   │
│  │              ├── Gleich  → Kein Upload nötig         │
│  │              └── Anders  → Bild neu hochladen        │
│  └── NEIN: remoteBildPfad vorhanden?                    │
│            ├── JA  → Bild herunterladen → bildPfad      │
│            │         setzen                             │
│            └── NEIN → Kein Bild vorhanden               │
└─────────────────────────────────────────────────────────┘
```

> **Hinweis:** Nach jedem Bild-Upload wird `etag = null` gesetzt, damit der nächste Sync-Zyklus den aktualisierten `remoteBildPfad` automatisch zu PocketBase überträgt.

---

## 📐 6. Gesamtarchitektur

```
┌──────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                           │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   UI / Widgets                      │    │
│  └───────────────────┬─────────────────────────────────┘    │
│                      │                                       │
│  ┌───────────────────▼─────────────────────────────────┐    │
│  │            Repository / Service Layer               │    │
│  └──────────┬────────────────────────┬─────────────────┘    │
│             │                        │                       │
│  ┌──────────▼──────────┐  ┌──────────▼──────────────────┐   │
│  │   SQLite (lokal)    │  │       Sync Service           │   │
│  │                     │  │                              │   │
│  │   artikel.db        │  │  - Push/Pull Logik           │   │
│  │   ├── artikel       │  │  - Konfliktauflösung         │   │
│  │   └── sync_meta     │  │  - Bild-Sync                 │   │
│  └─────────────────────┘  └──────────┬───────────────────┘   │
│                                      │                       │
└──────────────────────────────────────┼───────────────────────┘
                                       │ HTTP / REST API
                          ┌────────────▼────────────────────┐
                          │       POCKETBASE SERVER          │
                          │                                  │
                          │  data.db                         │
                          │  ├── artikel                     │
                          │  ├── users                       │
                          │  └── _* (intern)                 │
                          │                                  │
                          │  /api/collections/artikel/...    │
                          └──────────────────────────────────┘
```

---

## ✅ 7. Verifikation (Stand: 2026-03-23)

| Prüfpunkt | Status | Detail |
|-----------|--------|--------|
| Lokale DB vorhanden | ✅ | `artikel.db` mit 8 Einträgen |
| PocketBase DB vorhanden | ✅ | `data.db` mit 7 aktiven Einträgen |
| Schema-Version | ✅ | `PRAGMA user_version = 4` |
| `artikelnummer` in Schema | ✅ | Migration M-007 erfolgreich (`oldVersion < 4`) |
| ID-Mapping korrekt | ✅ | `remote_path` = PocketBase `id` |
| Soft-Delete funktioniert | ✅ | `name_1` lokal `deleted=1`, auf Server gelöscht |
| Sync-Timestamp vorhanden | ✅ | `last_sync = 1773922514098` (2026-03-18 ~17:15) |
| Alle aktiven Artikel synchron | ✅ | 7/7 Artikel auf beiden Seiten identisch |
| `sqlite3` verfügbar | ✅ | Installiert via `apt` |

---

## 📋 8. Changelog

| Datum | Version | Änderung |
|-------|---------|----------|
| 2026-03-19 | v1.0 | Initiale Dokumentation erstellt |
| 2026-03-23 | v1.1 | M-007: `artikelnummer` (DB-Version 4) dokumentiert; Migrationsverlauf ergänzt; Sync-Ablauf präzisiert (`etag IS NULL`); `etag`-Strategie in 4.4 ergänzt; Bild-Sync Hinweis ergänzt; `sync_meta` um `updated_at` ergänzt; Verifikationstabelle aktualisiert |

---

*Dokumentation gepflegt auf Basis von DB-Analyse & Session-Verlauf – Lager App Projekt*