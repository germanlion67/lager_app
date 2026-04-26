# 🗄️ Datenbank-Design & Synchronisation

Dieses Dokument bietet eine detaillierte technische Referenz für das Datenmodell, die Synchronisations-Logik und die Performance-Optimierungen der **Lager_app**.

---

## 🏗️ Architektur-Übersicht

Die App nutzt zwei persistente Datenspeicher:

1. **Lokale SQLite (`artikel.db`)**: Offline-Speicher auf dem Endgerät
2. **PocketBase Server (`data.db`)**: Zentrale Datenbank für Multi-Device-Sync

Die native App arbeitet **offline-first** mit lokaler SQLite-Datenbank und synchronisiert gegen PocketBase.  
Die Web-Version arbeitet direkt gegen das Backend und benötigt diese lokale Sync-Datenhaltung nicht.

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
| `remote_path` | TEXT | **PocketBase Record-ID** des zugehörigen Server-Datensatzes |
| `updated_at` | INTEGER | Letzter lokaler Änderungszeitpunkt (Unix ms) |
| `deleted` | INTEGER | Soft-Delete Flag (0 = aktiv, 1 = gelöscht) |
| `etag` | TEXT | Aktueller bestätigter Sync-Stand; `NULL` bedeutet: lokale Änderung pending |
| `last_synced_etag` | TEXT | Letzter erfolgreich bestätigter Remote-Stand als stabile Vergleichsbasis für Konflikterkennung |
| `pending_resolution` | TEXT | Offene Konfliktentscheidung für den nächsten Sync (`force_local`, `force_merge`) |
| `bildPfad` | TEXT | Lokaler Pfad zum Originalbild |
| `thumbnailPfad` | TEXT | Lokaler Pfad zum Vorschaubild |
| `remoteBildPfad` | TEXT | Dateiname des Bildes auf dem Server |
| `erstelltAm` | TEXT | ISO 8601 Erstellungsdatum |

### Bedeutung der Sync-Metadaten

| Feld | Bedeutung |
|---|---|
| `etag` | Aktueller Sync-Zustand; `NULL` = lokaler Datensatz ist dirty / pending |
| `last_synced_etag` | Letzter bestätigter gemeinsamer Remote-Stand |
| `pending_resolution` | Bewusste Nutzerentscheidung für genau einen nächsten Sync-Versuch |

### `pending_resolution`-Werte

| Wert | Bedeutung |
|---|---|
| `NULL` | Keine offene Sonderbehandlung |
| `force_local` | Nutzer hat „Lokal behalten“ gewählt |
| `force_merge` | Nutzer hat ein manuelles Merge-Ergebnis gewählt |

---

### 1.2 Historischer Hinweis: `artikel_dokumente`

Die frühere Dokumenttabelle `artikel_dokumente` ist **nicht mehr der aktuelle fachliche Schwerpunkt** der Dokument-/Anhangsverwaltung.

Wichtiger aktueller Stand:

- Die heute fachlich relevante Lösung für Anhänge läuft über die PocketBase-Collection **`attachments`**
- Die zentrale Flutter-Implementierung erfolgt über:
  - `attachment_model.dart`
  - `attachment_service.dart`
  - `attachment_upload_widget.dart`
  - `attachment_list_widget.dart`
- Dieses Dokument beschreibt deshalb den aktuellen produktiv relevanten Stand primär über **`attachments`** statt über eine ältere `artikel_dokumente`-Zielarchitektur

Falls in Altbeständen, Migrationsständen oder älteren Notizen noch `artikel_dokumente` auftaucht, ist das als historischer bzw. legacy-naher Referenzstand zu verstehen, nicht als bevorzugtes aktuelles Zielmodell.

---

### 1.3 Tabelle: `sync_meta`

Speichert den Status der letzten erfolgreichen Synchronisation.

- **`last_sync`**: Unix-Timestamp (ms) des letzten erfolgreichen Durchlaufs

Dieser Wert dient der Delta-Sync-Optimierung, ist aber **nicht** die primäre Konfliktvergleichsbasis für lokale Änderungen.  
Für Konflikterkennung auf Datensatzebene ist `last_synced_etag` relevant.

---


### 1.4 PocketBase Collection: `attachments`

Dateianhänge pro Artikel. Diese werden in PocketBase verwaltet.

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
| `deleted` | BOOL | ❌ | Soft-Delete Flag |
| `updated_at` | NUMBER | ❌ | Sync-Timestamp |

**Erlaubte MIME-Types:**  
`image/png`, `image/jpeg`, `image/webp`, `application/pdf`,  
`application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`,  
`application/vnd.ms-excel`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`,  
`text/plain`, `text/csv`

**Limits:** Max 20 Anhänge pro Artikel, max 10 MB pro Datei.  
**API-Regeln:** Auth-pflichtig seit v0.7.3 (`@request.auth.id != ''` für alle Operationen).

---

## 🔄 2. Synchronisations-Prozess

Die Synchronisation folgt einem kontrollierten Offline-First-Ablauf, um Datenkonsistenz über mehrere Geräte zu gewährleisten.

### 2.1 Grundprinzip

1. **Lokale Änderungen**
   - Änderungen werden zunächst lokal in SQLite gespeichert
   - `etag = NULL` markiert den Datensatz als pending
   - `last_synced_etag` bleibt als Vergleichsbasis erhalten

2. **Push**
   - Pending-Datensätze werden zum Server synchronisiert
   - Vor `update()` oder `delete()` wird geprüft, ob der Remote-Stand seit `last_synced_etag` verändert wurde

3. **Pull**
   - Neue oder geänderte Remote-Datensätze werden heruntergeladen
   - Lokal erfolgt ein Insert oder Update

4. **Konfliktauflösung**
   - Konflikte werden nicht blind überschrieben
   - Der Nutzer kann lokal behalten, Remote übernehmen, zusammenführen oder überspringen

---

### 2.2 Ablauf-Diagramm (Artikel)

```text
┌──────────────────────────────────────────────────────────────┐
│                         SYNC PROZESS                         │
│                                                              │
│  1. Lese 'last_sync' aus 'sync_meta'                         │
│                                                              │
│  2. LOCAL → REMOTE (Push)                                    │
│     ├── WHERE etag IS NULL AND deleted = 0                   │
│     │     ├── neuer Datensatz → CREATE auf PocketBase        │
│     │     └── bestehender Datensatz → Remote-Stand prüfen    │
│     │           ├── unverändert seit last_synced_etag        │
│     │           │     └── UPDATE                             │
│     │           ├── pending_resolution gesetzt               │
│     │           │     └── bewusster Force-Push               │
│     │           └── Remote geändert                          │
│     │                 └── KONFLIKT                           │
│     │                      └── onConflictDetected()          │
│     └── WHERE etag IS NULL AND deleted = 1                   │
│           ├── Remote unverändert → DELETE                    │
│           └── Remote geändert → KONFLIKT                     │
│                                                              │
│  3. REMOTE → LOCAL (Pull)                                    │
│     ├── Neue/geänderte Records von PocketBase holen          │
│     └── Lokal einfügen oder aktualisieren (upsert)           │
│                                                              │
│  4. Schreibe neuen 'last_sync' Timestamp                     │
└──────────────────────────────────────────────────────────────┘
```

---

### 2.3 Konfliktauflösung ab v0.9.3

#### Warum die frühere Logik nicht ausreichte

Früher wurde `etag` gleichzeitig als:
1. Dirty-Marker
2. letzter bekannter Remote-Stand

verwendet.

Sobald lokale Änderungen `etag = NULL` setzten, ging die Vergleichsbasis verloren.  
Dadurch entstand in kritischen Fällen faktisch **Last-Write-Wins**, obwohl fachlich eine echte Konflikterkennung erforderlich war.

#### Neue fachliche Grundlage

Die Konflikterkennung basiert jetzt auf:
- `etag` als Pending-/Sync-Zustandsmarker
- `last_synced_etag` als letzter bestätigter gemeinsamer Stand
- `pending_resolution` als bewusste Nutzerentscheidung für genau einen nächsten Sync

---

### 2.4 Konfliktfälle

| Fall | Verhalten |
|---|---|
| Neuer lokaler Datensatz ohne `remote_path` | Direkt `create()` |
| Lokale Änderung, Remote unverändert seit `last_synced_etag` | Direkt `update()` |
| Lokale Änderung, Remote geändert seit `last_synced_etag` | Konflikt |
| Lokales Soft-Delete, Remote unverändert | Remote darf gelöscht werden |
| Lokales Soft-Delete, Remote geändert seit `last_synced_etag` | Konflikt |
| `pending_resolution = force_local` | Bewusster lokaler Überschreib-Push |
| `pending_resolution = force_merge` | Bewusster Push des Merge-Ergebnisses |

---

### 2.5 Nutzerentscheidungen im Konfliktfall

| Entscheidung | Lokale Wirkung | Nächster Sync |
|---|---|---|
| **Lokal behalten** | `pending_resolution = force_local` | Server wird bewusst überschrieben |
| **Server übernehmen** | Remote-Version lokal übernehmen | Konflikt sofort aufgelöst |
| **Zusammenführen** | Merge-Version lokal speichern, `pending_resolution = force_merge` | Merge-Version wird bewusst gepusht |
| **Überspringen** | Keine Auflösung persistieren | Konflikt erscheint beim nächsten Sync erneut |

---

### 2.6 Sync-Invarianten

| Invariante | Bedeutung |
|---|---|
| `uuid` ist stabil | Nie ändern — geräteübergreifender Identifier |
| `remote_path` = PocketBase Record-ID | Verbindung zum Server |
| `etag = NULL` | Lokaler Datensatz ist dirty / pending |
| `last_synced_etag` bleibt bei normalen lokalen Änderungen erhalten | Vergleichsbasis für spätere Konflikterkennung |
| `pending_resolution` wird nur für den nächsten Sync verwendet | Kein dauerhafter Zustand |
| `deleted = 1` | Soft-Delete lokal, nicht automatisch konfliktfrei |

---

---

## 🖼️ 3. Bild-Synchronisation

Die Bild-Sync-Logik arbeitet getrennt von den Textdaten, um Bandbreite zu sparen und Bildversionen sauber zu behandeln.

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

### Bild-Download & intelligenter Sync

Seit der Smart-Sync-Logik wird ein Bild nicht nur bei komplett fehlender Datei geladen, sondern auch dann, wenn die lokale Datei älter ist als der fachliche Artikelstand.

```text
downloadMissingImages()
  → getAlleArtikel(limit: 999999)
  → Für jeden Artikel:
      → remoteBildPfad leer? → skip
      → remotePath leer? → skip
      → Lokale Datei prüfen:
          ├── Existiert nicht oder 0 Bytes? → DOWNLOAD
          └── Existiert?
                └── Datei-Datum < artikel.aktualisiertAm? → DOWNLOAD
      → Falls DOWNLOAD:
          1. Alte Dateien im Artikel-Bildordner bereinigen
          2. HTTP GET /api/files/artikel/{recordId}/{filename}
          3. Speichern in {cacheDir}/images/{uuid}/{filename}
          4. setBildPfadByUuidSilent(uuid, localPath)
```

### `setBildPfadByUuidSilent()`

```dart
Future<void> setBildPfadByUuidSilent(String uuid, String bildPfad)
```

Aktualisiert **nur** den lokalen `bildPfad`, ohne `updated_at`, `etag` oder `last_synced_etag` zu verändern.

**Wichtig:**  
Diese Methode verhindert, dass ein reiner Bild-Download versehentlich als normale Textdatenänderung interpretiert und erneut in den Sync-Push gezogen wird.

| Methode | Ändert `bildPfad` | Ändert `updated_at` | Ändert `etag` | Sync-Trigger |
|---|---|---|---|---|
| `setBildPfadByUuid()` | ✅ | ✅ | ❌ | ✅ Ja |
| `setBildPfadByUuidSilent()` | ✅ | ❌ | ❌ | ❌ Nein |
| `markSynced(...)` | ❌ | ❌ | ✅ | ❌ Nein |
| `markAsModified(...)` | ❌ | ✅ | ✅ → `NULL` | ✅ Ja |

---

## 📄 4. Anhänge / Attachments

Anhänge werden **fachlich getrennt** von der SQLite-basierten Artikel-Synchronisation behandelt und in PocketBase über die Collection `attachments` verwaltet.

### 4.1 PocketBase Collection: `attachments`

| Feld | Typ | Required | Beschreibung |
|---|---|---|---|
| `artikel_uuid` | TEXT | ✅ | UUID des zugehörigen Artikels |
| `datei` | FILE | ✅ | Dateianhang (max 10 MB) |
| `bezeichnung` | TEXT | ✅ | Vom Nutzer vergebener Name |
| `beschreibung` | TEXT | ❌ | Optionale Beschreibung |
| `mime_type` | TEXT | ❌ | MIME-Typ |
| `datei_groesse` | NUMBER | ❌ | Dateigröße in Bytes |
| `sort_order` | NUMBER | ❌ | Sortierreihenfolge |
| `uuid` | TEXT | ✅ | Client-seitige UUID |
| `deleted` | BOOL | ❌ | Soft-Delete Flag |
| `updated_at` | NUMBER | ❌ | Sync-Timestamp |

### 4.2 Flutter-Implementierung

| Komponente | Datei | Beschreibung |
|---|---|---|
| Datenklasse | `attachment_model.dart` | Dart-Klasse für Dateianhänge |
| CRUD gegen PocketBase | `attachment_service.dart` | Upload, Download, Update, Delete |
| UI | `artikel_detail_screen.dart` | Öffnet Attachment-Bereich im Detail-Screen |
| Upload-Widget | `attachment_upload_widget.dart` | Upload-Dialog mit Validierung |
| Listen-Widget | `attachment_list_widget.dart` | Liste mit Öffnen, Bearbeiten, Löschen |

### 4.3 UI-Funktionen

- 📎 **Upload**: Dateiauswahl via `file_picker`, Upload zu PocketBase
- 📥 **Download / Öffnen**: lokal speichern bzw. Browser-Download
- 🗑️ **Löschen**: per PocketBase-Operation

---

## 🚀 5. Performance & Indizes

Um Abfragen bei großen Datenbeständen zu beschleunigen, sind folgende Indizes aktiv:

| Index | Tabelle | Ziel |
|---|---|---|
| `idx_unique_artikelnummer` | `artikel` | Schneller Zugriff via Fach-ID |
| `idx_sync_delta` | `artikel` | Optimiert Abfragen auf `updated_at` und `deleted` |
| `idx_search_name` | `artikel` | Schnelle Suche im Artikelnamen |
| `idx_uuid_lookup` | `artikel` | Schneller Abgleich bei Push/Pull |
| `idx_attachments_artikel_uuid` | `attachments` (PB) | Zugriff auf Anhänge eines Artikels |
| `idx_attachments_uuid` | `attachments` (PB) | UUID-basierter Abgleich |
| `idx_attachments_sort` | `attachments` (PB) | Sortierreihenfolge |
| `idx_attachments_deleted` | `attachments` (PB) | Soft-Delete-Filterung |

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
       │ sync_meta     │           │ attachments   │
       └───────┬───────┘           └───────┬───────┘
               │                           │
       ┌───────▼───────┐           ┌───────▼───────┐
       │ Lokale Bilder │◄─────────►│  PB Storage   │
       │  (/images)    │  HTTP     │  (/storage)   │
       └───────────────┘           └───────────────┘
```

---

## Bild-Download & Intelligenter Sync (v0.8.9+24)

Seit Version 0.8.9+24 (B-007) beschränkt sich der Bild-Download nicht mehr nur auf den Kaltstart, sondern führt einen intelligenten Zeitstempel-Vergleich durch, um auch Bild-Updates auf dem Server zu erkennen.

### Download-Logik (Smart Sync)

```text
downloadMissingImages()
  → getAlleArtikel(limit: 999999)
  → Für jeden Artikel:
      → remoteBildPfad leer? → skip
      → remotePath (Record-ID) leer? → skip
      → Lokale Datei prüfen:
          ├── Existiert nicht oder 0 Bytes? → DOWNLOAD
          └── Existiert? 
                └── Datei-Datum < artikel.aktualisiertAm? → DOWNLOAD (Smart Sync)
      
      → Falls DOWNLOAD:
          1. Bereinigung: Lösche alle Dateien im Ordner {cacheDir}/images/{uuid}/
             (verhindert Dateileichen bei Namensänderung durch PocketBase-Suffixe)
          2. HTTP GET /api/files/artikel/{recordId}/{filename}
          3. Speichern in: {cacheDir}/images/{uuid}/{filename}
          4. setBildPfadByUuidSilent(uuid, localPath)
```

1. **Record-Sync:** `syncOnce()` synchronisiert Metadaten inkl.
   `remoteBildPfad` (Dateiname auf PocketBase)
2. **Image-Sync:** `downloadMissingImages()` prüft alle Artikel und
   lädt fehlende Bilder von der PocketBase File-API herunter

### Neue DB-Methode: `setBildPfadByUuidSilent()`

```dart
Future<void> setBildPfadByUuidSilent(String uuid, String bildPfad)
```

Aktualisiert **nur** den lokalen `bildPfad`, ohne `updated_at` oder `etag`
zu ändern.

Wichtig für B-007: Da der Smart Sync Bilder basierend auf `aktualisiertAm` neu lädt, darf dieser Zeitstempel nach dem Download nicht verändert werden, da die App sonst in eine Endlosschleife aus "Lokal ist neuer als Server" (Push-Trigger) und "Server ist neuer als Datei" (Download-Trigger) geraten würde.

**Unterschied zu `setBildPfadByUuid()` und verwandten Methoden:**

| Methode | Ändert `bildPfad` | Ändert `updated_at` | Ändert `etag` | Sync-Trigger |
|---------|-------------------|---------------------|---------------|--------------|
| `setBildPfadByUuid()` | ✅ | ✅ | ❌ | ✅ Ja (wird als pending erkannt) |
| `setBildPfadByUuidSilent()` | ✅ | ❌ | ❌ | ❌ Nein |
| `markSynced(uuid, etag)` | ❌ | ❌ | ✅ Setzt ETag | ❌ Nein |
| `markAsModified(uuid)` | ❌ | ✅ jetzt | ✅ → NULL | ✅ Ja (Pending) |

### Download-Logik

```text
downloadMissingImages()
  → getAlleArtikel(limit: 999999)
  → Für jeden Artikel:
      → bildPfad leer? → skip
      → remotePath (Record-ID) leer? → skip
      → Lokale Datei existiert UND > 0 Bytes? → skip   ← B-003: Negation war invertiert
      → HTTP GET /api/files/artikel/{recordId}/{filename}
      → Speichern in: {cacheDir}/images/{uuid}/{filename}
      → setBildPfadByUuidSilent(uuid, localPath)
```

---

## Wartungsnotiz

> **Zuletzt aktualisiert:** v0.9.3 (2026-04-26)  
> Sync-Metadaten `last_synced_etag` und `pending_resolution` dokumentiert  
> Konflikterkennung von implizitem Last-Write-Wins auf explizite Vergleichsbasis umgestellt  
> T-001.7 bis T-001.12 fachlich abgeschlossen und in der Datenbank-/Sync-Dokumentation nachgezogen  
> Delete-vs-Remote-Edit als Konfliktfall dokumentiert  
> Historische `artikel_dokumente`-Sicht als Legacy-Hinweis eingeordnet, aktuelle Attachment-Realität nachgezogen

--- 

[Zurück zur README](../README.md) | [Zur Architektur](ARCHITECTURE.md) | [Zum Projekt-Status](OPTIMIZATIONS.md)