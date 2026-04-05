# 🧪 Tests – Übersicht & lokaler Aufruf

Dieses Dokument beschreibt alle automatisierten Tests der **Lager_app**, ihre Zielsetzung und wie sie lokal ausgeführt werden.

**Version:** 0.7.7 | **Zuletzt aktualisiert:** 05.04.2026

---

## 🚀 Schnellstart

```bash
# Alle Tests ausführen (aus dem app/-Verzeichnis)
cd lager_app/app
flutter test
```

> 💡 Beim ersten Aufruf einmalig `flutter pub get` ausführen.

---

## 📋 Testübersicht

| Datei | Kategorie | Anzahl Tests | Aufgabe |
|---|---|---|---|
| `test/conflict_resolution_test.dart` | Unit | 37 | T-001 |
| `test/models/artikel_model_test.dart` | Unit | 64 | O-002 |
| `test/services/artikel_db_service_test.dart` | Integration | 75 | O-002 |
| `test/utils/image_processing_utils_test.dart` | Unit | 30 | O-002 |
| `test/utils/uuid_generator_test.dart` | Unit | 23 | O-002 |
| `test/services/app_log_service_test.dart` | Unit | 14 | – |
| `test/dokumente_utils_test.dart` | Unit | 3 | – |
| `test/models/nextcloud_credentials_test.dart` | Unit | 4 | – |
| `test/services/artikel_import_service_test.dart` | Unit | 4 | – |
| `test/services/artikel_export_service_test.dart` | Unit | 2 | – |
| `test/widgets/dokumente_button_test.dart` | Widget | 1 | – |
| `test/performance/import_500_smoke_test.dart` | Performance | 1* | – |
| **Gesamt** | | **258** | |

> \* Performance-Test erfordert externe Testdaten (siehe [unten](#performance-tests)).

---

## 🔬 Test-Beschreibungen

### `conflict_resolution_test.dart` — T-001 (37 Tests)

**Ziel:** Testet die Konfliktlösungs-Pipeline aus `M-007`.

**Abgedeckte Klassen:** `ConflictData`, `ConflictResolution` (Enum)

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| T-001.1: ConflictData | 11 | Konstruktor, Pflichtfelder, Null-Handling |
| T-001.2: ConflictResolution Enum | 6 | Enum-Werte, Index, `byName` |
| T-001.4: Konflikt-Grund-Szenarien | 5 | Zeitstempel-Vergleiche |
| T-001.extra: Feld-Vergleiche | 11 | Artikel-Properties als Vergleichsgrundlage |
| T-001.extra: Collections | 4 | ConflictData in Listen, Resolution-Tracking |

```bash
flutter test test/conflict_resolution_test.dart
```

---

### `models/artikel_model_test.dart` — O-002 (64 Tests)

**Ziel:** Vollständige Abdeckung des `Artikel`-Datenmodells.

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| Konstruktor | ~8 | Pflichtfelder, Auto-UUID, Auto-`updatedAt` |
| `isValid()` | ~6 | Gültige und ungültige Kombis (Name, Ort, Fach) |
| `toMap()` | ~10 | Alle Felder, `bool`→`int`, bedingte `id` |
| `fromMap()` | ~20 | Null-Handling, Typ-Koercion, `snake_case`/`camelCase`, UTC |
| Roundtrip | ~5 | `fromMap()` → `toMap()` → `fromMap()` idempotent |
| `copyWith()` | ~8 | Nullable Felder via `_Undefined`-Sentinel |
| `==`, `hashCode`, `toString()` | ~7 | Gleichheit und Darstellung |

```bash
flutter test test/models/artikel_model_test.dart
```

---

### `services/artikel_db_service_test.dart` — O-002 (75 Tests)

**Ziel:** Integrationstests für alle Methoden des `ArtikelDbService`.

**Strategie:**
- `sqflite_common_ffi` mit `inMemoryDatabasePath` — kein Dateisystem nötig
- `injectDatabase()` (`@visibleForTesting`) für saubere Test-Isolation
- `ArtikelDbServiceTestHelper` für wiederverwendbaren In-Memory-Setup

| Methode | Tests |
|---|---|
| `insertArtikel()` | Einfügen, UUID-Eindeutigkeit, ConflictAlgorithm |
| `getAlleArtikel()` | Pagination, `deleted`-Filter |
| `updateArtikel()` | Feldaktualisierung, `updated_at` |
| `deleteArtikel()` | Soft-Delete (`deleted=1`) |
| `getArtikelByUUID()` | Treffer, kein Treffer |
| `getArtikelByRemotePath()` | Treffer, kein Treffer |
| `getPendingChanges()` | `etag=null`-Filter |
| `markSynced()` | ETag + `remote_path` setzen |
| `upsertArtikel()` | Insert + Update-Pfad |
| `searchArtikel()` | Suche nach Name/Beschreibung |
| `existsKombination()` / `existsArtikelnummer()` | Duplikat-Erkennung |
| `setLastSyncTime()` / `getLastSyncTime()` | Persistierung des Sync-Zeitstempels |
| `isDatabaseEmpty()` | Leere DB erkennen |
| `getMaxArtikelnummer()` | Höchste Artikelnummer |
| `deleteAlleArtikel()` | Alle Einträge löschen |
| `insertArtikelList()` | Batch-Insert |
| `updateBildPfad()` / `updateRemoteBildPfad()` | Bild-Pfad-Updates |
| `setBildPfadByUuid()` / `setThumbnailPfadByUuid()` | UUID-basierte Bild-Updates |
| `setThumbnailEtagByUuid()` / `setRemoteBildPfadByUuid()` | ETag + Remote-Pfad |
| `getUnsyncedArtikel()` | Nicht synchronisierte Artikel |

```bash
flutter test test/services/artikel_db_service_test.dart
```

> ⚠️ **Hinweis:** Dieser Test setzt `sqflite_common_ffi` voraus. Unter Linux/Windows läuft er nativ. Unter macOS kann eine zusätzliche FFI-Konfiguration nötig sein.

---

### `utils/image_processing_utils_test.dart` — O-002 (30 Tests)

**Ziel:** Vollständige Abdeckung der Bild-Verarbeitungsfunktionen.

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| `ensureTargetFormat()` | ~10 | JPEG-Kompression, Qualitätsstufen, Fehler-Fallback |
| `generateThumbnail()` | ~10 | Thumbnail-Erzeugung, Größe, `null` bei Fehler |
| `rotateClockwise()` | ~10 | Quadratische + rechteckige Bilder, 4 Richtungen, leere Bytes |

**Strategie:**
- `TestWidgetsFlutterBinding` erforderlich (wegen `compute()`)
- Echter JPEG/PNG-Byte-Payload als Fixture (minimal, valide)

```bash
flutter test test/utils/image_processing_utils_test.dart
```

---

### `utils/uuid_generator_test.dart` — O-002 (23 Tests)

**Ziel:** Abdeckung des `UuidGenerator`-Helpers.

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| `generate()` | ~8 | RFC-4122-V4-Format (8-4-4-4-12), Version-Bit, Variant-Bit, Nicht-Leer |
| Eindeutigkeit | 1 | 10.000 UUIDs ohne Kollision |
| `isValid()` | ~7 | Gültige/ungültige UUIDs (alle Versionen) |
| `isValidV4()` | ~6 | Nur V4-Format, Abgrenzung zu V1/V5, Sonderzeichen |
| Klassen-Eigenschaften | 1 | Kann nicht instanziiert werden (nur `static`) |

```bash
flutter test test/utils/uuid_generator_test.dart
```

---

### `services/app_log_service_test.dart` (14 Tests)

**Ziel:** Tests für den zentralen `AppLogService`.

- Log-Level-Filterung (debug, info, warning, error)
- Log-Datei-Erzeugung und Rotation
- Keine Abstürze bei fehlgeschlagenen Mock-Aufrufen

```bash
flutter test test/services/app_log_service_test.dart
```

---

### `dokumente_utils_test.dart` (3 Tests)

**Ziel:** Tests für `dokumente_utils.dart` (Datei-Sortierung).

- `sortFilesByName()`: Aufsteigend und absteigend
- `sortFilesByTypeThenName()`: Gruppierung nach Dateityp, dann alphabetisch

```bash
flutter test test/dokumente_utils_test.dart
```

---

### `models/nextcloud_credentials_test.dart` (4 Tests)

**Ziel:** Tests für die `NextcloudCredentials`-Datenklasse.

- Konstruktor mit allen Feldern
- Standard-Werte für optionale Felder
- URI-Parsing

```bash
flutter test test/models/nextcloud_credentials_test.dart
```

---

### `services/artikel_import_service_test.dart` (4 Tests)

**Ziel:** Tests für den `ArtikelImportService` (JSON-Import).

- Gültiges JSON parsen
- Ungültiges JSON (Fehlerfall)
- Leere Liste
- Mock für `path_provider`

```bash
flutter test test/services/artikel_import_service_test.dart
```

---

### `services/artikel_export_service_test.dart` (2 Tests)

**Ziel:** Tests für den `ArtikelExportService` (ZIP-Export).

- Export gibt `null` zurück bei leerer Artikelliste
- `FileSelectorPlatform` wird korrekt gemockt

```bash
flutter test test/services/artikel_export_service_test.dart
```

---

### `widgets/dokumente_button_test.dart` (1 Widget-Test)

**Ziel:** Widget-Test für `DokumenteButton`.

- Button ist sichtbar
- BottomSheet öffnet sich
- Leerzustand bei fehlenden Credentials wird angezeigt

```bash
flutter test test/widgets/dokumente_button_test.dart
```

---

### `performance/import_500_smoke_test.dart` (1 Performance-Test) {#performance-tests}

**Ziel:** Smoke-Test für den Import von 500 Artikeln.

> ⚠️ **Erfordert externe Testdaten:**
> ```bash
> dart run tool/generate_import_dataset.dart --count 500
> ```
> Ohne die Datei `test_data/import_500.json` schlägt dieser Test mit einer klaren Fehlermeldung fehl.

```bash
flutter test test/performance/import_500_smoke_test.dart
```

---

## 🛠️ Einzelne Testgruppen ausführen

```bash
# Alle Unit-Tests
flutter test test/models/ test/utils/ test/services/ test/dokumente_utils_test.dart

# Nur Widget-Tests
flutter test test/widgets/

# Nur O-002 Tests (Core-Utilities + DB)
flutter test test/services/artikel_db_service_test.dart \
             test/utils/uuid_generator_test.dart \
             test/utils/image_processing_utils_test.dart \
             test/models/artikel_model_test.dart

# Verbose-Ausgabe (jeder Testname einzeln)
flutter test --reporter expanded

# Bei Fehlern: Stack-Trace anzeigen
flutter test --reporter expanded --no-pub
```

---

## 🔧 Voraussetzungen

| Anforderung | Details |
|---|---|
| Flutter SDK | ≥ 3.41.4 (empfohlen: aktuell) |
| Betriebssystem | Linux, Windows oder macOS |
| `flutter pub get` | Einmalig im `app/`-Verzeichnis ausführen |
| Performance-Test | `dart run tool/generate_import_dataset.dart` |

---

## 🚫 Manuelle Integrationstests (T-001)

Die folgenden Tests sind **nicht automatisierbar** und müssen manuell durchgeführt werden (erfordern zwei verbundene Geräte oder Browser-Tabs):

| Test | Beschreibung |
|---|---|
| T-001.6 | Artikel auf Gerät A ändern, offline auf Gerät B ändern → Sync → Konflikt-UI erscheint |
| T-001.7 | „Lokal behalten" → Server wird überschrieben |
| T-001.8 | „Server übernehmen" → Lokale Daten werden ersetzt |
| T-001.9 | „Zusammenführen" → Merge-Dialog, Felder manuell wählen, Ergebnis korrekt |
| T-001.10 | „Überspringen" → Konflikt bleibt, erscheint beim nächsten Sync erneut |
| T-001.11 | Mehrere Konflikte gleichzeitig → Navigation Weiter/Zurück, Fortschrittsanzeige |
| T-001.12 | Edge Case: Soft-Delete lokal + Edit remote → Konflikt korrekt erkannt |

---

## 🔗 Verwandte Dokumente

- **[OPTIMIZATIONS.md](OPTIMIZATIONS.md)** — Aufgaben-Tracking (O-002, T-001)
- **[DATABASE.md](DATABASE.md)** — Datenbankschema und Sync-Logik
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — Gesamtarchitektur

---

*Dieses Dokument wird bei jeder neuen Test-Suite aktualisiert.*
