# 🧪 Tests – Übersicht & lokaler Aufruf

Dieses Dokument beschreibt alle automatisierten Tests der **Lager_app**, ihre Zielsetzung und wie sie lokal ausgeführt werden.

**Version:** 0.9.2+32 | **Zuletzt aktualisiert:** 23.04.2026

---

## 🚀 Schnellstart

```bash
# Alle Tests ausführen (aus dem app/-Verzeichnis)
cd lager_app/app
flutter test
```

> 💡 Beim ersten Aufruf einmalig `flutter pub get` ausführen.

✅ **642 Tests bestanden, 3 skipped, 0 Fehler**

> `--exclude-tags performance` ist optional verfügbar, aber nicht erforderlich.  
> Der Performance-Test ist self-contained und erzeugt seine Testdaten automatisch.

---

## 📋 Testübersicht

| Datei | Kategorie | Tests | Aufgabe |
| :-- | :-- | :--: | :-- |
| `test/conflict_resolution_test.dart` | Unit + Widget | 77 | T-001 |
| `test/models/artikel_model_test.dart` | Unit | 64 | O-002 |
| `test/models/attachment_model_test.dart` | Unit | 30 | O-002 |
| `test/models/nextcloud_credentials_test.dart` | Unit | 4 | — |
| `test/services/app_lock_service_test.dart` | Unit | 13 | O-011 |
| `test/services/artikel_db_service_test.dart` | Integration | 75 | O-002 |
| `test/services/artikel_export_service_test.dart` | Unit + Widget | 2 | — |
| `test/services/artikel_import_service_test.dart` | Unit | 4 | — |
| `test/services/app_log_service_test.dart` | Unit | 14 | — |
| `test/services/attachment_service_test.dart` | Unit | 34 | T-005 |
| `test/services/backup_status_service_test.dart` | Unit | 15 | — |
| `test/services/backup_status_test.dart` | Unit | 22 | T-006 |
| `test/services/image_picker_service_test.dart` | Unit + Widget | 15 | O-007 |
| `test/services/nextcloud_client_test.dart` | Unit | 39 | T-003 |
| `test/services/nextcloud_listfiles_test.dart` | Unit | 1 | — |
| `test/services/pocketbase_sync_service_test.dart` | Unit | 17 | T-002 |
| `test/services/pocketbase_sync_service_conflict_test.dart` | Unit | 11 | T-008 |
| `test/services/settings_controller_test.dart` | Unit | 15 | O-010 / T-009 |
| `test/services/sync_orchestrator_test.dart` | Unit | 9 | T-008 |
| `test/services/sync_status_provider_test.dart` | Unit | 5 | K-006 |
| `test/utils/attachment_utils_test.dart` | Unit | 28 | — |
| `test/utils/image_processing_utils_test.dart` | Unit | 30 | O-002 |
| `test/utils/uuid_generator_test.dart` | Unit | 23 | O-002 |
| `test/widgets/artikel_detail_screen_test.dart` | Widget | 24 | O-006 |
| `test/widgets/artikel_erfassen_test.dart` | Widget | 11 | O-006 |
| `test/widgets/artikel_list_screen_test.dart` | Widget | 15 | O-009 |
| `test/widgets/login_screen_test.dart` | Widget | 1 | — |
| `test/widgets/merge_dialog_test.dart` | Widget | 18 | T-004 |
| `test/widgets/server_setup_screen_test.dart` | Widget | 3 | — |
| `test/performance/import_500_smoke_test.dart` | Performance | 1 | T-007 |
| `test/helpers/fake_sync_status_provider.dart` | Test-Helper | — | K-006 |
| `test/helpers/no_op_nextcloud_service.dart` | Test-Helper | — | O-006 |
| `test/mocks/sync_service_mocks.dart` | Test-Helper | — | T-001 |
| `test/mocks/sync_service_mocks.mocks.dart` | Generated Mock | — | T-001 |
| **Gesamt** |  | **645** |  |

> Hinweis: Die Dateiübersicht ist auf den Stand **0.9.2+32** angehoben.  
> Für neu hinzugekommene Testdateien sollten die exakten Testanzahlen bei der nächsten vollständigen Testinventur nachgetragen werden.

---

## 🔬 Test-Beschreibungen

### `services/nextcloud_client_test.dart` — T-003 (39 Tests)

**Ziel:** Unit-Tests für `NextcloudClient` — alle WebDAV-Operationen (HEAD, MKCOL, PROPFIND, GET, PUT, DELETE) gegen einen injizierten `MockClient` ohne Netzwerk.

#### Strategie
- `MockClient` aus `package:http/testing.dart`
- Optionaler `http.Client? client`-Parameter im `NextcloudClient`-Konstruktor  
  (rückwärtskompatibel — Default: `http.Client()`)
- PROPFIND-XML-Responses als Inline-Fixtures
- `RemoteItemMeta`-Datenklasse separat getestet (`equality`, `copyWith`, `toString`)

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `RemoteItemMeta` | 3 | `equality` (path+etag), `copyWith`, `toString` |
| `testConnection()` | 5 | 200, 404, 500, Exception, Auth-Header korrekt |
| `createFolder()` | 4 | 201 Created, 405 Already Exists, 500, Exception |
| `listItemsEtags()` | 7 | 1 Item, Multi-Item, leer, 403, Non-JSON-Filter, kein ETag, custom Path |
| `downloadItem()` | 3 | 200 OK, 404 Not Found, Netzwerkfehler |
| `uploadItem()` | 5 | 201+ETag, If-Match Header, 412 Conflict, 500, kein ETag |
| `deleteItem()` | 4 | 204, 404 idempotent, 500, Exception |
| `uploadAttachment()` | 4 | 201+ETag, Content-Type, Default `application/octet-stream`, 500 |
| `downloadAttachment()` | 2 | 200+Bytes, 404 |
| `URI-Auflösung` | 2 | items-Pfad, attachments-Pfad korrekt aufgelöst |

#### Produktionscode-Abhängigkeit
- `NextcloudClient`: Feld `final http.Client _client`, optionaler Konstruktor-Parameter
- Alle HTTP-Aufrufe über `_client.*` statt Top-Level-`http.*`

```bash
flutter test test/services/nextcloud_client_test.dart
```

---

### `conflict_resolution_test.dart` — T-001 (77 Tests)

**Ziel:** Vollständige Konfliktlösungs-Pipeline bis zum UI-Merge.

**Abgedeckte Klassen:** `ConflictData`, `ConflictResolution` (Enum), `SyncService.detectConflicts()`, `ConflictResolutionScreen`

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `T-001.1: ConflictData` | 11 | Konstruktor, Pflichtfelder, Null-Handling |
| `T-001.2: ConflictResolution Enum` | 6 | Enum-Werte, Index, `byName` |
| `T-001.3: detectConflicts()` | 9 | ETag-Vergleich, Konflikt-Erkennung, Fehlerbehandlung |
| `T-001.4: _determineConflictReason()` | 15 | Zeitstempel-Szenarien (gleich, zeitnah, lokal/remote neuer) |
| `T-001.5: Widget-Tests` | 20 | `ConflictResolutionScreen` UI, Navigation, Dialog, Pop-Result |
| `T-001.extra: Feld-Vergleiche` | 10 | Artikel-Properties als Vergleichsgrundlage |
| `T-001.extra: Collections` | 4 | `ConflictData` in Listen, Resolution-Tracking |

**Besonderheit:** Widget-Tests laufen mit `setSurfaceSize(1024×900)` — der Standard-Viewport (800×600) ist zu klein für die Side-by-Side-Versionskarten nach Auswahl. `addTearDown` stellt den Default-Viewport nach jedem Test wieder her.

```bash
flutter test test/conflict_resolution_test.dart
```

---

### `services/pocketbase_sync_service_test.dart` — T-002 & B-007 (17 Tests)

**Ziel:** Unit-Tests für die PocketBase-Sync-Logik — Push, Pull, Fehlerbehandlung, inkl. der neuen Smart-Sync-Logik für Bilder.

**Strategie:**
- Manuelle Fakes statt `@GenerateMocks` — `PocketBaseService` und `ArtikelDbService` sind Singletons mit Factory-Konstruktoren
- `TestableSyncService` repliziert die Sync-Logik mit injizierbaren Fakes
- `FakeRecordService` erweitert `RecordService` mit exakten Methoden-Signaturen (PocketBase SDK v0.23.2)
- `RecordModel.fromJson()` statt Konstruktor-Parameter für `id`/`created`/`updated`
- Kein Netzwerk, kein SQLite, kein Dateisystem, kein `build_runner` nötig

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| Push: Create | 1 | Neuer Artikel → `create()`, `markSynced` mit `remotePath` |
| Push: Update | 1 | Bestehender Artikel → `update()`, kein `create()` |
| Push: Delete | 1 | Soft-deleted → `delete()` + `markSynced('deleted')` |
| Push: Delete (nicht remote) | 1 | Gelöscht aber remote nicht vorhanden → nur `markSynced` |
| Push: Fehlerbehandlung | 1 | Exception bei Artikel 1 → Artikel 2 wird trotzdem verarbeitet |
| Push: Auth/Owner | 1 | `owner` wird im Body gesetzt wenn authentifiziert |
| Pull: Insert | 1 | Neuer Remote-Record → `upsertArtikel()` |
| Pull: Lösch-Sync | 1 | Lokal vorhanden, remote nicht → `deleteArtikel()` |
| Pull: Leere UUIDs | 1 | Kein Lösch-Check wenn `remoteUuids` leer |
| `syncOnce`: `lastSyncTime` | 1 | Wird nach erfolgreichem Sync gesetzt |
| `syncOnce`: Fehler | 1 | Allgemeiner Fehler wird abgefangen, kein Throw |
| `syncOnce`: Nur Pull | 1 | Keine Pending Changes → kein Push, nur Pull |
| UUID-Sanitization | 1 | Anführungszeichen werden aus UUID entfernt |
| Image: kein `remoteBildPfad` | 1 | Überspringt Download |
| Image: kein `remotePath` | 1 | Überspringt Download |
| Image: URL leer | 1 | Überspringt Download |
| Image: Bild existiert | 1 | Überspringt Download wenn lokal vorhanden |

```bash
flutter test test/services/pocketbase_sync_service_test.dart
```

---

### `services/pocketbase_sync_service_conflict_test.dart` + `services/sync_orchestrator_test.dart` — T-008 (20 Tests)

**Ziel:** Unit-Tests für ETag-basierte Konflikt-Erkennung in `PocketBaseSyncService` und `downloadMissingImages`-Skip-Logik im `SyncOrchestrator`.

**Strategie:**
- Reine Unit-Tests ohne Netzwerk, SQLite oder Dateisystem
- ETag-Logik als isolierte Funktion mit Laufzeit-Parametern getestet  
  (`dead_code`-Lint vermieden durch lokale Funktion statt `false && X`)
- `Artikel()`-Konstruktor: `erstelltAm`/`aktualisiertAm` als `DateTime` (nicht `String`)
- `ConflictCallback`-Typedef direkt auf Typ-Kompatibilität geprüft

| Gruppe | Tests | Datei | Was wird geprüft |
| :-- | :--: | :-- | :-- |
| ConflictCallback Typedef | 1 | conflict_test | Typ-Kompatibilität des Callbacks |
| `onConflictDetected` initial | 1 | conflict_test | Initial `null` nach Konstruktor |
| ETag-Konflikt-Logik (Unit) | 5 | conflict_test | Leer, gleich, verschieden, `deleted`, leerer Remote |
| downloadMissingImages Datei-Check | 3 | conflict_test | Leerer Pfad, nicht-existent, existiert mit Inhalt |
| ConflictCapture Integration | 1 | conflict_test | Callback mit korrekten lokalen + Remote-Artikeln |
| ConflictCallback Typedef (Orchestrator) | 2 | orchestrator_test | Zuweisung, Exception-Handling |
| SyncStatus Enum | 2 | orchestrator_test | Vollständigkeit, exhaustiver Switch |
| ETag Grenzwerte | 2 | orchestrator_test | Whitespace-Unterschied, beide leer |

**Fixes während Test-Erstellung:**
- `Artikel()`-Konstruktor: `erstelltAm`/`aktualisiertAm` sind `DateTime`, nicht `String` — alle Test-Instanzen auf `DateTime.now()` umgestellt
- `dead_code`-Lint: `false && X`-Muster durch lokale Funktion mit Laufzeit-Parametern ersetzt
- `expected_token`: fehlende `});` nach `test()` und `group()` ergänzt

```bash
flutter test test/services/pocketbase_sync_service_conflict_test.dart
flutter test test/services/sync_orchestrator_test.dart

# Beide zusammen:
flutter test test/services/pocketbase_sync_service_conflict_test.dart \
             test/services/sync_orchestrator_test.dart
```

---

### `services/attachment_service_test.dart` — T-005 (34 Tests)

**Ziel:** Unit-Tests für `AttachmentService` — alle CRUD-Operationen gegen PocketBase ohne Netzwerk, ohne Dateisystem.

**Strategie:**
- `PocketBaseService.overrideForTesting(FakePocketBase)` injiziert Fake-Client in den echten `AttachmentService`-Singleton — testet den **echten Code**, nicht eine Kopie
- `FakeAttachmentRecordService extends RecordService` mit Callback-Handlern
- `PocketBaseService.dispose()` im `tearDown` räumt Singleton-State auf
- `fakeClientException()` Helper — PocketBase SDK v0.23.2 nutzt `originalError:` statt `message:`
- Reiner `test()`-Block — kein `testWidgets`, kein `tester.runAsync()` nötig

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `getForArtikel()` | 6 | Leere Liste, 3 Ergebnisse, Filter/Sort, `perPage`-Limit, PB-Fehler, fehlende Felder |
| `countForArtikel()` | 4 | 0 Ergebnis, korrekte Anzahl, PB-Fehler, effiziente Query (`perPage=1`) |
| `upload()` | 10 | Happy-Path, Body-Felder, Limit=20, Limit>20, PB-Fehler, null/leere Felder, `MultipartFile`-Dateiname |
| `updateMetadata()` | 4 | Erfolg, Trimming, null→leerer String, PB-Fehler |
| `delete()` | 4 | Erfolg, korrekte ID, PB-Fehler, Netzwerkfehler |
| `deleteAllForArtikel()` | 4 | Alle löschen, keine vorhanden, teilweise Fehler, `getForArtikel`-Fehler |
| Integration | 2 | Upload→Get-Roundtrip, Grenzwert 19 vs 20 |

```bash
flutter test test/services/attachment_service_test.dart
```

---

### `models/attachment_model_test.dart` — O-002 (30 Tests)

**Ziel:** Vollständige Abdeckung des `AttachmentModel` — reine Modell-Logik ohne Abhängigkeiten.

**Abgedeckte Klassen:** `AttachmentModel`, `kErlaubteMimeTypes`, `kMaxAttachmentBytes`, `kMaxAttachmentsPerArtikel`

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| Konstruktor | 2 | Pflichtfelder, nullable optionale Felder |
| `fromPocketBase()` | 7 | Vollständiger Record, Null-Handling, String→int, double→int, UTC-Datum, ungültiges Datum, Parameter-Priorität |
| `dateiGroesseFormatiert` | 8 | null, 0, Bytes, KB, MB, Grenzwerte (1 KB, 1 MB, 10 MB) |
| `typLabel` | 7 | Bild, PDF, Word, Excel/CSV, Text, Fallback (unbekannt + null) |
| `istBild` | 3 | true für image/*, false für andere, false bei null |
| `copyWith()` | 3 | Identische Kopie, Teilüberschreibung, `downloadUrl` |
| Gleichheit | 4 | `==` nur auf `id`, `!=`, `hashCode`, `toString()` |
| Konstanten | 4 | Whitelist enthält erwartete Typen, keine unsicheren Typen, Limits |

```bash
flutter test test/models/attachment_model_test.dart
```

---

### `services/artikel_db_service_test.dart` — O-002 (75 Tests)

**Ziel:** Integrationstests für alle Methoden des `ArtikelDbService`.

**Strategie:**
- `sqflite_common_ffi` mit `inMemoryDatabasePath` — kein Dateisystem nötig
- `injectDatabase()` (`@visibleForTesting`) für saubere Test-Isolation
- `ArtikelDbServiceTestHelper` für wiederverwendbaren In-Memory-Setup

| Methode | Was wird geprüft |
| :-- | :-- |
| `insertArtikel()` | Einfügen, UUID-Eindeutigkeit, `ConflictAlgorithm` |
| `getAlleArtikel()` | Pagination, deleted-Filter |
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
| `setBildPfadByUuidSilent()` | Setzt nur `bildPfad` — kein `updated_at`, kein Sync-Trigger |
| `setThumbnailEtagByUuid()` / `setRemoteBildPfadByUuid()` | ETag + Remote-Pfad |
| `getUnsyncedArtikel()` | Nicht synchronisierte Artikel |

> ⚠️ **Hinweis:** Dieser Test setzt `sqflite_common_ffi` voraus. Unter Linux/Windows läuft er nativ. Unter macOS kann eine zusätzliche FFI-Konfiguration nötig sein.

```bash
flutter test test/services/artikel_db_service_test.dart
```

---

### `services/settings_controller_test.dart` — O-010 / T-009 (15 Tests)

**Ziel:** Unit-Tests für den ausgelagerten `SettingsController` — fachliche Settings-Logik ohne UI testen.

**Abgedeckte Bereiche:**
- Dirty-State-Verhalten bei Änderung und Rücksetzen auf Initialwerte
- Persistenz von `showLastSync` inklusive `false`
- `resetPocketBaseUrl()` entfernt ungespeicherte Änderungen korrekt
- `saveSettings()` Erfolgspfad:
  - `SaveSettingsResult.success`
  - URL wird übernommen
  - Dirty-State wird zurückgesetzt
- `saveSettings()` Reject-Pfad:
  - `SaveSettingsResult.pocketBaseUrlRejected`
  - URL wird auf Initialwert zurückgesetzt
  - `pbConnectionOk` wird korrekt auf `false` gesetzt
- `saveSettings()` Fehlerpfad:
  - `SaveSettingsResult.error`, wenn `updateUrl()` eine Exception wirft
- Artikelstartnummer:
  - wird gespeichert, wenn `isDatabaseEmpty == true`
  - wird nicht gespeichert, wenn `isDatabaseEmpty == false`

**Strategie:**
- Controller isoliert testen statt UI über Widget-Mocks zu treiben
- Service-Abhängigkeiten gezielt injizieren bzw. testbar machen
- Fokus auf Save-/Reset-/Dirty-State-Logik und SharedPreferences-nahe Pfade
- Fehlerpfade über Fake-Services abdecken

```bash
flutter test test/services/settings_controller_test.dart
```

---

### `widgets/merge_dialog_test.dart` — T-004 (18 Tests)

**Ziel:** Widget-Tests für den `_MergeDialog` im `ConflictResolutionScreen`.

**Strategie:**
- `_MergeDialog` ist private → wird über den "Manuell zusammenführen"-Button geöffnet (echter Nutzerfluss)
- `MockSyncService` aus `test/mocks/sync_service_mocks.mocks.dart`
- `setSurfaceSize(1024×900)` (wie T-001.5)
- Felder mit Unterschied isoliert testen, um Index-Probleme bei `find.widgetWithText()` zu vermeiden

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| Grundstruktur | 6 | Titel, Icons, Buttons, Feld-Labels, Bild-Label |
| Konflikt-Anzeige | 4 | Lokal/Remote-Karten, Warning-Icons, identische Werte, Initialwerte |
| Feld-Auswahl | 3 | Lokal-Button, Remote-Button, manuelle Eingabe |
| Bild-Auswahl | 3 | Radio-Optionen, „Kein Bild", initiale Selektion |
| Zusammenführen-Aktion | 4 | Dialog schließt, korrekte Werte, leerer Name, manuelle Edits |
| Dialog schließen | 2 | Abbrechen, Close-Icon |
| Menge-Feld | 2 | Ungültige Menge Fallback, Remote-Menge per Button |

```bash
flutter test test/widgets/merge_dialog_test.dart
```

---

### `services/backup_status_test.dart` — T-006 (22 Tests)

**Ziel:** Vollständige Abdeckung der `BackupStatus`-Modell-Logik und des `BackupAge`-Enums.

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `fromJson()` | 4 | Vollständiges JSON, Null-Handling, String→int-Koercion, Fehler-Status |
| `isSuccess` / `isError` | 3 | success, error, unknown |
| `lastBackupTime` | 2 | Unix→DateTime UTC, Epoch bei 0 |
| `ageCategory` | 4 | fresh (<24h), aging (24–72h), critical (>72h), critical bei Error |
| `ageText` | 6 | „Nie", Stunden, Tage, ⚠️-Warnung, Singular „Tag", Plural „Tagen" |
| `BackupStatus.unknown` | 3 | Defaults, weder success/error, `ageText` „Nie" |

```bash
flutter test test/services/backup_status_test.dart
```

---

### `services/image_picker_service_test.dart` — O-007 (15 Tests)

**Ziel:** Tests für `ImagePickerService` — `pickImageCamera()`, `isCameraAvailable`, `openCropDialog()`.

#### Strategie
- `FakeImagePicker extends ImagePicker` überschreibt `pickImage()` vollständig — kein Platform-Channel-Mock nötig
- `overrideImagePicker` + `maxFileSizeBytesOverride` (`@visibleForTesting`) für saubere Injektion
- `debugDefaultTargetPlatformOverride` steuert `isCameraAvailable` pro Test

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `PickedImage`-Datenklasse | 4 | `empty`, `hasImage` true/false/leer |
| `isCameraAvailable` | 5 | Linux, Windows, macOS → false; Android, iOS → true |
| `openCropDialog()` | 2 | null-bytes → null, leere bytes → null |
| `pickImageCamera()` | 4 | Kamera nicht verfügbar, Picker null, Datei zu groß, Happy-Path |

#### Wichtige Patterns

| Pattern | Falsch ❌ | Richtig ✅ |
| :-- | :-- | :-- |
| `debugDefaultTargetPlatformOverride` zurücksetzen | `addTearDown` | `try/finally` im Testbody |
| `XFile` mit In-Memory-Bytes | `XFile(path, bytes: data)` | `XFile.fromData(data, name: '...')` |
| Async mit `compute()` / `readAsBytes()` | Direkt `awaiten` in `testWidgets` | `tester.runAsync(() => ...)` |
| Testbarer Größencheck | 10-MB-`Uint8List` | `maxFileSizeBytesOverride` + kleine Bytes |

```bash
flutter test test/services/image_picker_service_test.dart
```

---

### `utils/attachment_utils_test.dart` (28 Tests)

**Ziel:** Vollständige Abdeckung der Attachment-Validierung und Hilfsfunktionen.

**Abgedeckte Funktionen:** `validateAttachment()`, `mimeTypeFromExtension()`, `iconForMimeType()`, `colorForMimeType()`, `AttachmentValidation`

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `validateAttachment()` | 13 | Gültige PDF/Bild, Limit erreicht/überschritten, zu groß, genau am Limit, leer, unerlaubter MIME, HTML, Erweiterungs-Fallback, alle erlaubten MIMEs, Prüf-Priorität |
| `mimeTypeFromExtension()` | 11 | PDF, JPG/JPEG, PNG, WebP, DOC/DOCX, XLS/XLSX, CSV, TXT, ODT, unbekannt, ohne Erweiterung |
| `iconForMimeType()` | 8 | Bild, PDF, Word, Excel, CSV, Text, Fallback, null |
| `colorForMimeType()` | 8 | Blau/Rot/Indigo/Grün/BlueGrey/Grau für alle Kategorien + null |
| `AttachmentValidation` | 2 | `ok()` gültig, `fehler()` ungültig mit Nachricht |

```bash
flutter test test/utils/attachment_utils_test.dart
```

---

### `utils/image_processing_utils_test.dart` — O-002 (30 Tests)

**Ziel:** Vollständige Abdeckung der Bild-Verarbeitungsfunktionen.

#### Strategie
- `TestWidgetsFlutterBinding` erforderlich (wegen `compute()`)
- Echter JPEG-/PNG-Byte-Payload als Fixture (minimal, valide)

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `ensureTargetFormat()` | ~10 | JPEG-Kompression, Qualitätsstufen, Fehler-Fallback |
| `generateThumbnail()` | ~10 | Thumbnail-Erzeugung, Größe, null bei Fehler |
| `rotateClockwise()` | ~10 | Quadratische + rechteckige Bilder, 4 Richtungen, leere Bytes |

```bash
flutter test test/utils/image_processing_utils_test.dart
```

---

### `utils/uuid_generator_test.dart` — O-002 (23 Tests)

**Ziel:** Abdeckung des `UuidGenerator`-Helpers.

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `generate()` | ~8 | RFC-4122-V4-Format (8-4-4-4-12), Version-Bit, Variant-Bit, Nicht-Leer |
| Eindeutigkeit | 1 | 10.000 UUIDs ohne Kollision |
| `isValid()` | ~7 | Gültige/ungültige UUIDs (alle Versionen) |
| `isValidV4()` | ~6 | Nur V4-Format, Abgrenzung zu V1/V5, Sonderzeichen |
| Klassen-Eigenschaften | 1 | Kann nicht instanziiert werden (nur static) |

```bash
flutter test test/utils/uuid_generator_test.dart
```

---

### `services/sync_status_provider_test.dart` — K-006 (5 Tests)

**Ziel:** Tests für das `SyncStatusProvider`-Interface und den `FakeSyncStatusProvider` Test-Double.

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| Initial State | 1 | `isSyncing` ist initial false |
| State-Änderungen | 3 | `emitRunning` / `emitSuccess` / `emitError` setzen `isSyncing` korrekt |
| Stream | 1 | `syncStatus` emittiert korrekte Event-Sequenz |

```bash
flutter test test/services/sync_status_provider_test.dart
```

---

### `services/nextcloud_listfiles_test.dart` (1 Test)

**Ziel:** Test für die Nextcloud-Dateilisten-Funktion.

- WebDAV-PROPFIND-Response-Parsing

```bash
flutter test test/services/nextcloud_listfiles_test.dart
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

### `models/nextcloud_credentials_test.dart` (4 Tests)

**Ziel:** Tests für die `NextcloudCredentials`-Datenklasse.

- Konstruktor mit allen Feldern, Standard-Werte, URI-Parsing

```bash
flutter test test/models/nextcloud_credentials_test.dart
```

---

### `services/artikel_import_service_test.dart` (4 Tests)

**Ziel:** Tests für den `ArtikelImportService` (JSON-Import).

- Gültiges JSON parsen, ungültiges JSON (Fehlerfall), leere Liste, Mock für `path_provider`

```bash
flutter test test/services/artikel_import_service_test.dart
```

---

### `services/artikel_export_service_test.dart` (2 Tests)

**Ziel:** Tests für den `ArtikelExportService` (ZIP-Export).

- Export gibt `null` zurück bei leerer Artikelliste, `FileSelectorPlatform` korrekt gemockt

```bash
flutter test test/services/artikel_export_service_test.dart
```

---

### `widgets/artikel_erfassen_test.dart` — O-006 (11 Widget-Tests)

**Ziel:** Widget-Tests für `ArtikelErfassenScreen`.

**Strategie:**
- `sqflite_common_ffi` In-Memory-DB via `injectDatabase()`
- `pump(Duration)` statt `pumpAndSettle()` — ignoriert laufende HTTP-Timer

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| Render | ~4 | Formularfelder, AppBar-Titel, Pflichtfeld-Markierungen |
| Bild-Buttons | ~4 | IconButtons für Kamera/Galerie/Crop |
| Validierung | ~3 | Pflichtfelder, Fehlermeldungen |

```bash
flutter test test/widgets/artikel_erfassen_test.dart
```

---

### `widgets/artikel_detail_screen_test.dart` — O-006 (24 Widget-Tests)

**Ziel:** Widget-Tests für `ArtikelDetailScreen`.

**Strategie:**
- `sqflite_common_ffi` In-Memory-DB via `injectDatabase()`
- `pump(Duration)` statt `pumpAndSettle()`

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| Render | ~6 | Artikelname, Felder, AppBar |
| Name editierbar | ~4 | Inline-Edit, Speichern, Abbrechen |
| Crop-Button | ~3 | Button vorhanden, Icon korrekt |
| AppBar-Aktionen | ~5 | Bearbeiten, Löschen, Teilen |
| Navigation | ~6 | Zurück-Navigation, Pop-Result |

```bash
flutter test test/widgets/artikel_detail_screen_test.dart
```

---

### `widgets/artikel_list_screen_test.dart` — O-009 (15 Widget-Tests)

**Ziel:** Widget-Tests für `ArtikelListScreen`.

**Strategie:**
- `sqflite_common_ffi` In-Memory-DB via `injectDatabase()`
- `NoOpNextcloudService` — Timer-freier Test-Double via `NextcloudServiceInterface`
- `initialArtikel: []` — überspringt async DB-Load, `_isLoading` sofort `false`
- `pump()` reicht — kein `pumpAndSettle()`, kein `runAsync()`, kein Timer-Workaround
- `syncStatusProvider: FakeSyncStatusProvider` für Sync-UI-Tests

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| Render | 4 | AppBar-Titel, Suchfeld, Dropdown, DB-Icon |
| QR-Button | 2 | QR-Button neben Suchfeld |
| Neuer Artikel AppBar | 4 | AppBar-Buttons, Navigation zu ErfassenScreen |
| Menü | 2 | `more_vert` Button, Menü-Einträge |
| Suche | 2 | Texteingabe, Leer-Hinweis |
| DB-Icon Farbe | 1 | Icon-Farbe nicht null |

**Fixes in v0.9.0+25:**
- Import-Pfad korrigiert: `artikel.dart` → `artikel_model.dart`
- `erstelltAm` / `aktualisiertAm` als Pflichtfelder im Testartikel ergänzt
- `_pumpScreenWithArtikel()` Helper hinzugefügt (Dropdown-Test via `initialArtikel`)
- Suchfeld-Label korrigiert: `'Suche...'` → `'Suche…'` (U+2026, 1:1 aus Widget)

```bash
flutter test test/widgets/artikel_list_screen_test.dart
```

---

### `performance/import_500_smoke_test.dart` — T-007 (1 Performance-Test)

**Ziel:** Smoke-Test für Existenz und Struktur eines 500-Artikel-Datensatzes.

**Test-Ablauf:**

| Schritt | Aktion |
| :-- | :-- |
| `setUpAll()` | Erzeugt `test_data/import_500.json` (500 Artikel) + 10 PNG-Fixtures (1×1 Pixel) |
| Test | Prüft Existenz, JSON-Struktur (Liste, 500 Einträge) und Bild-Fixtures (Index 0–9) |
| `tearDownAll()` | Löscht `test_data/images/`, `test_data/import_500.json` und `test_data/` (wenn leer) |

```bash
# Im regulären flutter test automatisch enthalten:
flutter test

# Gezielt ausführen:
flutter test test/performance/import_500_smoke_test.dart

# Optional überspringen:
flutter test --exclude-tags performance
```

**Für manuelle Großdatensätze (1000+, 5000+):**
```bash
dart run tool/generate_import_dataset.dart --count 1000
```

---

## 🛠️ Einzelne Testgruppen ausführen

```bash
# Alle Unit-Tests
flutter test test/models/ test/utils/ test/services/

# Nur Widget-Tests
flutter test test/widgets/

# Nur O-006 Widget-Tests
flutter test test/widgets/artikel_erfassen_test.dart \
             test/widgets/artikel_detail_screen_test.dart \
             test/widgets/artikel_list_screen_test.dart

# Nur O-002 Tests (Core-Utilities + DB)
flutter test test/services/artikel_db_service_test.dart \
             test/utils/uuid_generator_test.dart \
             test/utils/image_processing_utils_test.dart \
             test/models/artikel_model_test.dart \
             test/models/attachment_model_test.dart

# Nur Attachment-bezogene Tests
flutter test test/services/attachment_service_test.dart \
             test/models/attachment_model_test.dart \
             test/utils/attachment_utils_test.dart

# Nur PocketBase Sync (T-002)
flutter test test/services/pocketbase_sync_service_test.dart

# Nur ETag-Konflikt + Orchestrator (T-008)
flutter test test/services/pocketbase_sync_service_conflict_test.dart \
             test/services/sync_orchestrator_test.dart

# Nur MergeDialog (T-004)
flutter test test/widgets/merge_dialog_test.dart

# Verbose-Ausgabe
flutter test --reporter expanded

# Bei Fehlern: Stack-Trace anzeigen
flutter test --reporter expanded --no-pub
```

---

## 🔧 Voraussetzungen

| Anforderung | Details |
| :-- | :-- |
| Flutter SDK | ≥ 3.41.7 |
| Betriebssystem | Linux, Windows oder macOS |
| `flutter pub get` | Einmalig im `app/`-Verzeichnis ausführen |
| `--exclude-tags performance` | Optional — nicht erforderlich |
| macOS + `sqflite_ffi` | Ggf. zusätzliche FFI-Konfiguration nötig |

---

## 🚫 Manuelle Integrationstests (T-001)

Die folgenden Tests sind **nicht automatisierbar** und müssen manuell durchgeführt werden (erfordern zwei verbundene Geräte oder Browser-Tabs):

| Test | Beschreibung |
| :-- | :-- |
| T-001.6 | Artikel auf Gerät A ändern, offline auf Gerät B ändern → Sync → Konflikt-UI erscheint |
| T-001.7 | „Lokal behalten" → Server wird überschrieben |
| T-001.8 | „Server übernehmen" → Lokale Daten werden ersetzt |
| T-001.9 | „Zusammenführen" → Merge-Dialog, Felder manuell wählen, Ergebnis korrekt |
| T-001.10 | „Überspringen" → Konflikt bleibt, erscheint beim nächsten Sync erneut |
| T-001.11 | Mehrere Konflikte gleichzeitig → Navigation Weiter/Zurück, Fortschrittsanzeige |
| T-001.12 | Edge Case: Soft-Delete lokal + Edit remote → Konflikt korrekt erkannt |

---

## 🧰 Test-Infrastruktur

### Test-Helpers (`test/helpers/`)

| Datei | Beschreibung | Verwendet in |
| :-- | :-- | :-- |
| `fake_sync_status_provider.dart` | Test-Double für `SyncStatusProvider` — emittiert kontrollierte Sync-Events | `sync_status_provider_test.dart`, Sync-UI-Tests |
| `no_op_nextcloud_service.dart` | Timer-freier Test-Double via `NextcloudServiceInterface` | `artikel_list_screen_test.dart` |

### Verwendung von `FakeSyncStatusProvider`

```dart
import '../helpers/fake_sync_status_provider.dart';

final fake = FakeSyncStatusProvider();

// In Widget-Test:
ArtikelListScreen(syncStatusProvider: fake);

// Events emittieren:
fake.emitRunning();   // → UI zeigt Lade-Indikator
fake.emitSuccess();   // → UI lädt Artikelliste neu
fake.emitError();     // → UI zeigt Fehlerzustand
fake.emitIdle();      // → UI im Ruhezustand

// Aufräumen:
fake.dispose();
```

### Fake-Klassen für PocketBase Sync (`pocketbase_sync_service_test.dart`)

| Klasse | Beschreibung |
| :-- | :-- |
| `FakePbService` | Minimaler Ersatz für `PocketBaseService` — kontrollierbare Properties |
| `FakeArtikelDbService` | Ersatz für `ArtikelDbService` — speichert Aufrufe für Assertions |
| `FakeRecordService` | Erweitert `RecordService` — Handler-Callbacks für alle CRUD-Operationen |
| `FakePocketBase` | Erweitert `PocketBase` — leitet `collection()` auf `FakeRecordService` um |
| `TestableSyncService` | Repliziert `PocketBaseSyncService`-Logik mit injizierbaren Fakes |
| `istKonfliktFn` (lokal) | Laufzeit-Funktion in T-008 — ersetzt `false && X`-Muster für `dead_code`-Lint |

### Fake-Klassen für AttachmentService (`attachment_service_test.dart`)

| Klasse | Beschreibung |
| :-- | :-- |
| `FakeAttachmentRecordService` | Erweitert `RecordService` — Handler-Callbacks inkl. `perPage` / `page` / `sort` |
| `FakePocketBaseForAttachment` | Erweitert `PocketBase` — leitet `collection()` um |
| `fakeClientException()` | Helper — erzeugt `ClientException` mit `originalError:` (SDK v0.23.2) |

---

## 🔗 Verwandte Dokumente

- **[OPTIMIZATIONS.md](OPTIMIZATIONS.md)** — Aufgaben-Tracking
- **[DATABASE.md](DATABASE.md)** — Datenbankschema und Sync-Logik
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — Gesamtarchitektur
- **[HISTORY.md](HISTORY.md)** — Projekthistorie & Entscheidungslog

---

*Dieses Dokument wird bei jeder neuen Test-Suite aktualisiert.*