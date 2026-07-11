# 🧪 Tests – Übersicht & lokaler Aufruf

Dieses Dokument beschreibt alle automatisierten Tests der **Lager_app**, ihre Zielsetzung und wie sie lokal ausgeführt werden.

**Version:** 1.0.0+78 | **Zuletzt aktualisiert:** 11.07.2026

---

## 🚀 Schnellstart

```bash
# Alle Tests ausführen (aus dem app/-Verzeichnis)
cd lager_app/app
flutter test
```

> 💡 Beim ersten Aufruf einmalig `flutter pub get` ausführen.
>
> Die aktuelle Testbasis im Repository umfasst **36 ausführbare Testdateien**
> plus **5 Hilfsdateien**. Die Zahlen in der Tabelle unten basieren auf den im
> Quelltext vorhandenen `test()`-/`testWidgets()`-Definitionen.
>
> CI verwendet `flutter test`; der Release-Workflow nutzt
> `flutter test --exclude-tags performance`.

F-011.7 Detail/List/Erfassen-Tests: 24 + 15 + 11 = 50 Widget-Tests grün nach
Master-Detail-Refactoring (ArtikelDetailContent-Extraktion, Scaffold-Wrapper mit
ValueNotifier-Rebuild, _ladeAnhangCount try/catch).
---

## 📋 Testübersicht

| Datei | Kategorie | Tests | Aufgabe |
| :-- | :-- | :--: | :-- |
| `test/conflict_resolution_test.dart` | Unit + Widget | 61 | T-001 |
| `test/models/artikel_model_test.dart` | Unit | 94 | O-002 / T-001 |
| `test/models/attachment_model_test.dart` | Unit | 38 | O-002 |
| `test/models/nextcloud_credentials_test.dart` | Unit | 4 | — |
| `test/services/app_lock_service_test.dart` | Unit | 13 | O-011 |
| `test/services/artikel_db_service_test.dart` | Integration | 116 | O-002 / T-001 |
| `test/services/artikel_db_service_test_helper.dart` | Test-Helper | — | ArtikelDbService-Testdaten & Fixtures |
| `test/services/artikel_export_service_test.dart` | Unit + Widget | 2 | — |
| `test/services/artikel_import_service_test.dart` | Unit | 4 | — |
| `test/services/app_log_service_test.dart` | Unit | 14 | — |
| `test/services/attachment_service_test.dart` | Unit | 35 | T-005 |
| `test/services/backup_status_service_test.dart` | Unit | 15 | — |
| `test/services/backup_status_test.dart` | Unit | 23 | T-006 |
| `test/services/connectivity_service_test.dart` | Unit | 14 | T-012 |
| `test/services/conflict_resolution_utils_test.dart` | Unit | 8 | T-001 |
| `test/services/image_picker_service_test.dart` | Unit + Widget | 15 | O-007 |
| `test/services/nextcloud_client_test.dart` | Unit | 39 | T-003 |
| `test/services/nextcloud_listfiles_test.dart` | Unit | 1 | — |
| `test/services/pocketbase_sync_service_test.dart` | Unit | 66 | T-002 |
| `test/services/pocketbase_sync_service_conflict_test.dart` | Unit | 7 | T-008 / T-001 |
| `test/services/pocketbase_service_test.dart` | Unit | 42 | T-012 |
| `test/services/sync_error_recovery_test.dart` | Unit | 87 | T-012 |
| `test/services/sync_progress_service_test.dart` | Unit | 61 | T-012 |
| `test/services/settings_controller_test.dart` | Unit | 15 | O-010 / T-009 |
| `test/services/sync_orchestrator_test.dart` | Unit | 13 | T-008 |
| `test/services/sync_status_provider_test.dart` | Unit | 6 | K-006 |
| `test/services/tag_service_test.dart` | Unit | 43 | — |
| `test/utils/attachment_utils_test.dart` | Unit | 43 | — |
| `test/utils/image_processing_utils_test.dart` | Unit | 30 | O-002 |
| `test/utils/uuid_generator_test.dart` | Unit | 23 | O-002 |
| `test/widgets/artikel_detail_screen_test.dart` | Widget | 24 | O-006 / F-011.7 |
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
| **Gesamt (statisch gezählte Testdefinitionen)** |  | **1005** |  |

> Hinweis: Die Dateisummen dienen der Übersicht und können sich bei Testumbauten
> ändern. Maßgeblich für den tatsächlichen Lauf bleibt die Ausgabe von
> `flutter test` in der jeweils verwendeten Flutter-Version.

---

## 🔬 Test-Beschreibungen

### `/services/pocketbase_service_test.dart` — T-012 (51 Tests)

#### Strategie
`PocketBaseService.testable()` + manuelle Fakes
(`_HealthCheckCapturingService`, `_FakeAuthRecordService`).
`PocketBaseService.dispose()` in `tearDown` für Singleton-Cleanup.
Kein Netzwerk, kein `build_runner`.

--- 

### `services/connectivity_service_test.dart` — T-012 (14 Tests)

**Ziel:** Unit-Tests für `ConnectivityService` — WiFi-Erkennung, Timeout-Verhalten und Fehlerbehandlung ohne Netzwerk, ohne `IOOverrides`.

#### Strategie
- `DnsLookup`-Typedef + `static dnsLookupOverride` (`@visibleForTesting`) im Service
- Direkte Lambda-Fakes statt `IOOverrides` oder Zonen-Overhead
- `tearDown` setzt `dnsLookupOverride = null` nach jedem Test zurück
- Läuft vollständig auf Linux/WSL2 ohne NetworkManager-Abhängigkeit

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `isConnected()` | 5 | true bei Adresse, false bei leerer Liste, SocketException, Timeout, unbekannter Exception |
| `isWifi()` | 5 | true bei Adresse, false bei leerer Liste, SocketException, Timeout, unbekannter Exception |
| Konsistenz `isConnected` / `isWifi` | 2 | Beide true bei Netz, beide false bei SocketException |
| Timeout-Verhalten | 2 | `isConnected()` + `isWifi()` hängen nicht bei Timeout |

#### Produktionscode-Abhängigkeit
- `ConnectivityService`: `typedef DnsLookup`, `static DnsLookup? dnsLookupOverride`, `_lookup()`-Wrapper
- Alle `InternetAddress.lookup()`-Aufrufe laufen über `_lookup()` — im Test auf Fake umgeleitet

```bash
flutter test test/services/connectivity_service_test.dart
```

---

### `services/sync_error_recovery_test.dart` — T-012 (87 Tests)

**Ziel:** Unit-Tests für `SyncErrorRecoveryService` und `SyncError` — Fehlerklassifizierung, Recovery-Strategien, Retry-Logik und Batch-Recovery ohne Netzwerk.

#### Strategie
- `SyncErrorRecoveryService` mit `retryDelay: Duration.zero` und `exponentialBackoffBase: Duration.zero` — Tests laufen in < 1 s
- `Logger(level: Level.off)` unterdrückt Log-Output im Testlauf
- Kein Netzwerk, kein Dateisystem, kein `build_runner`
- `SyncError.fromException()` direkt getestet — kein Fake nötig

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `SyncError.fromException()` — ErrorType | 12 | `SocketException` → network, `HttpException` → network, `TimeoutException` → timeout, `FileSystemException` → storage, 401/authentication → authentication, 409 → conflict, 500/503 → server, 400/404 → client, unbekannt → unknown |
| `SyncError.fromException()` — Severity | 8 | authentication → critical, network → medium, server → high, conflict → medium, storage → high, timeout → low, client → high, unknown → medium |
| `SyncError.fromException()` — User-Messages | 8 | Jeder ErrorType liefert deutschen Nutzertext (Netzwerkfehler, Authentifizierungsfehler, Serverfehler, Konflikt, Speicherfehler, Timeout, Client-Fehler, Unbekannter Fehler) |
| `SyncError.fromException()` — SuggestedActions | 7 | network → checkConnection+retry, authentication → relogin+checkCredentials, server → retryLater+contactAdmin, conflict → resolveConflict+skipItem, storage → checkStorage+clearCache, timeout → retry+adjustTimeout, client → viewLogs+reportBug |
| `SyncError.fromException()` — Felder | 6 | `id` Format `error_*`, `technicalDetails` enthält Original-Exception-String, `itemId`/`itemName`, `context`, `stackTrace`, `timestamp` |
| `SyncError` Getter — `isRetryable` | 5 | network/timeout/server → true, authentication/conflict → false |
| `SyncError` Getter — `requiresUserAction` | 3 | critical severity → true, conflict type → true, network → false |
| `RecoveryAction` Extension | 5 | Alle Actions haben nicht-leere `title` + `description`, `retry`/`relogin` title korrekt, `resolveConflict` description enthält „Konflikt" |
| `SyncErrorRecoveryService.handleError()` | 10 | Gibt `SyncErrorRecoveryResult` zurück, History-Akkumulation, `errorHistory` unmodifiable, network → canRetry, authentication → requiresUserInput + strategy requireUserAction, conflict → strategy resolveConflict, timeout → shouldSkip, itemId/itemName Weitergabe |
| History-Limit | 2 | Maximal 500 Einträge, älteste werden entfernt |
| `performRetry()` | 3 | Erfolgreicher Retry gibt Ergebnis zurück, Exception nach `maxRetries`, retryCount-Reset bei Erfolg |
| `performBatchRecovery()` | 5 | Leere Liste → alles 0, low-severity → skipped, retryable Erfolg → successful, fehlschlagende Retries → remainingErrors, nicht-retryable conflict → failed |
| `clearOldErrors()` | 2 | Entfernt Fehler älter als maxAge, `maxAge=Duration.zero` löscht alle |
| `generateErrorReport()` | 6 | Leere History → totalErrors 0, enthält summary/errorsByType/errorsBySeverity/recentErrors, mostCommonType null/korrekt, criticalErrors gezählt, recentErrors max 10 |
| `BatchRecoveryResult` | 5 | `total` = successful+failed+skipped, `hasRemainingErrors` true/false, `successRate` korrekt, Division-by-zero bei total=0 |

```bash
flutter test test/services/sync_error_recovery_test.dart
```

---

### `services/sync_progress_service_test.dart` — T-012 (61 Tests)

**Ziel:** Unit-Tests für `SyncProgressService` — Operation-Lifecycle, Stream-Events, Stats-Tracking, History-Limit und ChangeNotifier-Integration.

#### Strategie
- `SyncProgressService()` direkt instanziiert — kein Fake nötig
- `service.dispose()` in `tearDown` für sauberen Stream-Cleanup
- `Future.microtask(() {})` für Stream-Event-Assertions (kein `pumpAndSettle`)
- Kein Netzwerk, kein Dateisystem, kein `build_runner`

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `startOperation()` | 6 | ID-Format `sync_<timestamp>`, `currentOperation` mit Status initializing, `isSyncing` true, Stats-Reset, Event auf `operationStream`, Event auf `statsStream` |
| `updateOperation()` | 3 | Status/Progress/Message aktualisiert, kein Crash ohne aktive Operation, Event auf `operationStream` |
| `completeOperation()` | 6 | `currentOperation` null + `isSyncing` false, History-Eintrag mit completed+progress 1.0, Standard-Nachricht enthält „erfolgreich", benutzerdefinierte Nachricht, kein Crash ohne aktive Operation, `totalDuration` in Stats gesetzt |
| `failOperation()` | 5 | Status error in History, Error-Objekt gespeichert, Fehlermeldung in `stats.errors`, StackTrace gespeichert, kein Crash ohne aktive Operation |
| `cancelOperation()` | 3 | Status cancelled in History, Standard-Nachricht enthält „abgebrochen", kein Crash ohne aktive Operation |
| `setTotalItems()` | 3 | Korrekt gesetzt, negative Werte ignoriert, 0 akzeptiert |
| `incrementStat()` | 7 | processed/uploaded/downloaded/conflict/error/skipped je +1, unbekannter Typ → `AssertionError` |
| `decrementStat()` | 3 | processed dekrementiert, Underflow-Schutz bei 0, Underflow-Schutz für alle Typen |
| `updateStats()` Progress-Berechnung | 4 | Progress aus processedItems/totalItems, clamp auf 1.0, kein Update bei totalItems=0, error-String zu `stats.errors` |
| History-Limit | 2 | Max 100 Einträge, älteste werden entfernt (Op 0–4 weg, Op 5 ist erster) |
| `clearHistory()` | 1 | History wird geleert |
| `getLastOperationReport()` | 5 | Leere Map bei leerer History, enthält operation/statistics/performance, successRate 0% bei totalItems=0, itemsPerSecond 0 bei duration=0, successRate korrekt berechnet ((processed-errors)/total) |
| `SyncOperation` Getter | 4 | `isActive` true bei laufender Op, `isCompleted` true nach complete, `isError` true nach fail, `statusText` gibt deutschen Text zurück |
| `SyncStats` Getter | 5 | `progressPercentage` 0 bei totalItems=0, korrekt berechnet, `hasErrors` true bei errorItems>0, `hasConflicts` true bei conflictItems>0, `isCompleted` true bei processedItems≥totalItems |
| `ChangeNotifier` | 2 | `notifyListeners` bei startOperation, `notifyListeners` bei completeOperation |
| `dispose()` | 2 | Schließt StreamController ohne Fehler, Streams nach dispose geschlossen |

```bash
flutter test test/services/sync_progress_service_test.dart
```

--- 


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

### `conflict_resolution_test.dart` — T-001 (61 Tests)

**Ziel:** Abdeckung des Konfliktauflösungs-Flows im UI-/Resolution-Scope.

**Abgedeckte Bereiche:**
- `ConflictData`
- `ConflictResolution`
- `ConflictResolutionScreen`
- Nutzerentscheidungen für Konflikte
- Merge-Dialog und Übergabe des Merge-Ergebnisses

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `T-001.1: ConflictData` | 11 | Konstruktor, Pflichtfelder, Null-Handling |
| `T-001.2: ConflictResolution Enum` | 6 | Enum-Werte, Index, `byName` |
| `T-001.5: Widget-Tests` | 20 | `ConflictResolutionScreen` UI, Navigation, Dialog, Pop-Result |
| `T-001.9` | — | Merge-Dialog öffnet sich, Felder werden gewählt, Ergebnis wird korrekt weitergegeben |
| `T-001.10` | — | Skip speichert keine Auflösung im UI-Flow |
| `T-001.11` | — | Mehrere Konflikte, Fortschritt `(1/2)`, Weiter-Navigation, Hilfe-Dialog |
| `T-001.extra: Feld-Vergleiche` | 10 | Artikel-Properties als Vergleichsgrundlage |
| `T-001.extra: Collections` | 4 | `ConflictData` in Listen, Resolution-Tracking |

**Wichtiger fachlicher Hinweis:**  
Diese Testdatei prüft den **UI-/Resolution-Flow**. Die eigentliche produktive Konflikterkennung gegen den echten `PocketBaseSyncService` ist zusätzlich in `pocketbase_sync_service_conflict_test.dart` abgesichert.

**Besonderheit:**  
Widget-Tests laufen mit `setSurfaceSize(1024×900)` — der Standard-Viewport ist für die Side-by-Side-Versionskarten zu klein. `addTearDown` stellt den Default-Viewport nach jedem Test wieder her.

```bash
flutter test test/conflict_resolution_test.dart
```

---

### `services/pocketbase_sync_service_test.dart` — T-002 (66 Tests)

**Ziel:** Unit-Tests für die PocketBase-Sync-Logik — Push, Pull, Fehlerbehandlung, inklusive Smart-Sync-Logik für Bilder.

**Strategie:**
- Manuelle Fakes statt `@GenerateMocks`
- `TestableSyncService` repliziert die Sync-Logik mit injizierbaren Fakes
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


### `services/pocketbase_sync_service_conflict_test.dart` + `services/sync_orchestrator_test.dart` — T-008 / T-001 (7+13 Tests)

**Ziel:** Fachlich belastbare Absicherung der Konflikterkennung und des Konfliktverhaltens im Sync-Umfeld.

### Was seit v0.9.3 zusätzlich abgesichert ist
- Konflikterkennung basiert auf `last_synced_etag` statt allein auf `etag`
- bewusste Force-Resolution-Zustände sind testbar
- Skip-Recall beim nächsten Sync ist gegen den echten Produktivservice abgesichert
- Delete-vs-Remote-Edit wird als echter Konflikt erkannt

| Gruppe | Tests | Datei | Was wird geprüft |
| :-- | :--: | :-- | :-- |
| ConflictCallback Typedef | 1 | conflict_test | Typ-Kompatibilität des Callbacks |
| `onConflictDetected` initial | 1 | conflict_test | Initial `null` nach Konstruktor |
| Konfliktlogik Baseline/Remote | 5 | conflict_test | Vergleich gegen synchronisierte Baseline statt Dirty-Flag allein |
| Skip-Recall beim nächsten Sync | — | conflict_test | Übersprungene Konflikte erscheinen erneut |
| Force-Resolution-Verhalten | — | conflict_test | `force_local` / `force_merge` werden fachlich respektiert |
| Delete-vs-Remote-Edit | — | conflict_test | Lokales Soft-Delete + Remote-Änderung erzeugt Konflikt |
| ConflictCapture Integration | 1 | conflict_test | Callback mit korrekten lokalen + Remote-Artikeln |
| ConflictCallback Typedef (Orchestrator) | 2 | orchestrator_test | Zuweisung, Exception-Handling |
| SyncStatus Enum | 2 | orchestrator_test | Vollständigkeit, exhaustiver Switch |
| ETag-/Baseline-Grenzwerte | 2 | orchestrator_test | Randfälle für Vergleichslogik |

**Wichtiger fachlicher Hinweis:**  
Diese Tests decken nicht nur eine isolierte Hilfsfunktion ab, sondern sichern zentrale Konfliktfälle gegen den produktiven Sync-Kontext ab.  
Insbesondere **T-001.10** und **T-001.12** werden hier entscheidend fachlich belegt.

```bash
flutter test test/services/pocketbase_sync_service_conflict_test.dart
flutter test test/services/sync_orchestrator_test.dart

# Beide zusammen:
flutter test test/services/pocketbase_sync_service_conflict_test.dart \
             test/services/sync_orchestrator_test.dart
```

---

### `services/conflict_resolution_utils_test.dart` — T-001 (8 Tests)

**Ziel:** Unit-Tests für `requireRemoteBaselineEtag` — Hilfsfunktion zur Baseline-ETag-Ermittlung für die Konflikterkennung.

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `requireRemoteBaselineEtag` | 8 | ETag vorhanden, Fallback auf `lastSyncedEtag`, Leer-/Whitespace-Handling, Trimming, `StateError` wenn beide fehlen |

```bash
flutter test test/services/conflict_resolution_utils_test.dart
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

### `models/attachment_model_test.dart` — O-002 (38 Tests)

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

### `services/artikel_db_service_test.dart` — O-002 / T-001 (116 Tests)

**Ziel:** Integrationstests für alle Methoden des `ArtikelDbService`, einschließlich der Sync-Metadaten für die Konfliktauflösung.

**Strategie:**
- `sqflite_common_ffi` mit `inMemoryDatabasePath`
- `injectDatabase()` (`@visibleForTesting`) für saubere Test-Isolation
- `ArtikelDbServiceTestHelper` für wiederverwendbaren In-Memory-Setup

**Zusätzlich fachlich relevant für v0.9.3:**
- Persistenz von `last_synced_etag`
- Persistenz von `pending_resolution`
- Zustandsübergänge für normale lokale Änderungen
- Zustandsübergänge für erfolgreiche Synchronisation
- Rücksetzen bewusster Konfliktentscheidungen

| Methode / Bereich | Was wird geprüft |
| :-- | :-- |
| `insertArtikel()` | Einfügen, UUID-Eindeutigkeit, `ConflictAlgorithm` |
| `getAlleArtikel()` | Pagination, deleted-Filter |
| `updateArtikel()` | Feldaktualisierung, `updated_at` |
| `deleteArtikel()` | Soft-Delete (`deleted=1`) |
| `getArtikelByUUID()` | Treffer, kein Treffer |
| `getArtikelByRemotePath()` | Treffer, kein Treffer |
| `getPendingChanges()` | Pending-/Dirty-Filter |
| `markSynced()` | `etag`, `last_synced_etag` und `remote_path` setzen |
| `upsertArtikel()` | Insert + Update-Pfad |
| Sync-Metadaten | `last_synced_etag` bleibt bei normalen lokalen Änderungen erhalten |
| Force-Resolution | `pending_resolution` kann gesetzt und zurückgesetzt werden |
| `searchArtikel()` | Suche nach Name/Beschreibung |
| `existsKombination()` / `existsArtikelnummer()` | Duplikat-Erkennung |
| `setLastSyncTime()` / `getLastSyncTime()` | Persistierung des Sync-Zeitstempels |
| `isDatabaseEmpty()` | Leere DB erkennen |
| `getMaxArtikelnummer()` | Höchste Artikelnummer |
| `deleteAlleArtikel()` | Alle Einträge löschen |
| `insertArtikelList()` | Batch-Insert |
| `updateBildPfad()` / `updateRemoteBildPfad()` | Bild-Pfad-Updates |
| `setBildPfadByUuid()` / `setThumbnailPfadByUuid()` | UUID-basierte Bild-Updates |
| `setBildPfadByUuidSilent()` | Setzt nur `bildPfad` — kein `updated_at`, kein normaler Sync-Trigger |
| `setThumbnailEtagByUuid()` / `setRemoteBildPfadByUuid()` | ETag + Remote-Pfad |
| `getUnsyncedArtikel()` | Nicht synchronisierte Artikel |

> ⚠️ **Hinweis:** Dieser Test setzt `sqflite_common_ffi` voraus. Unter Linux/Windows läuft er nativ. Unter macOS kann zusätzliche FFI-Konfiguration nötig sein.

```bash
flutter test test/services/artikel_db_service_test.dart
```

---

### `models/artikel_model_test.dart` — O-002 / T-001 (94 Tests)

**Ziel:** Absicherung des `Artikel`-Modells inklusive der neuen Sync-Metadaten.

**Zusätzlich fachlich relevant für v0.9.3:**
- `lastSyncedEtag` wird korrekt serialisiert und deserialisiert
- `pendingResolution` wird korrekt serialisiert und deserialisiert
- `copyWith()` transportiert die neuen Felder korrekt
- PocketBase-Mapping enthält keine lokalen Sync-Steuerinformationen

**Abgedeckte Bereiche:**
- Konstruktor
- `toMap()`
- `fromMap()`
- Roundtrip
- `copyWith()`
- Gleichheit / `hashCode`
- Modellkonsistenz für lokale Sync-Metadaten

```bash
flutter test test/models/artikel_model_test.dart
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

### `services/backup_status_test.dart` — T-006 (23 Tests)

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

### `utils/attachment_utils_test.dart` (43 Tests)

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

### `services/sync_status_provider_test.dart` — K-006 (6 Tests)

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

**Strategie:**
- `TestDefaultBinaryMessengerBinding` + Channel-Mock für `path_provider` (`getApplicationDocumentsDirectory`)
- Alle Tests laufen ohne Skip

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| JSON-Import | 4 | Gültiges JSON parsen, ungültiges JSON (Fehlerfall), leere Liste, Dateistruktur |

```bash
flutter test test/services/artikel_import_service_test.dart
```

---

### `services/artikel_export_service_test.dart` (2 Tests)

**Ziel:** Tests für den `ArtikelExportService` (ZIP-Export + Nextcloud-Backup).


**Strategie:**
- `FileSelectorPlatform` via Test-Implementierung injiziert
- Nextcloud-Test nutzt `AppLogService.memoryOutput` direkt — kein Logger-Mock nötig
- `MissingPluginException` von `flutter_secure_storage` wird im Produktivcode gefangen und geloggt

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| `backupToZipFile` | 1 | Export gibt `null` zurück bei leerer Artikelliste (skip: UI-Abhängigkeit) |
| `backupZipToNextcloud` | 1 | Fehler wird intern gefangen, Error-Log mit "Nextcloud"-Kontext geschrieben |

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

### `widgets/artikel_detail_screen_test.dart` — O-006 / F-011.7 (24 Widget-Tests)

**Ziel:** Widget-Tests für `ArtikelDetailScreen` und `ArtikelDetailContent`.

**Strategie:**
- `sqflite_common_ffi` In-Memory-DB via `injectDatabase()`
- `pump(Duration)` statt `pumpAndSettle()`
- `ArtikelDetailScreen` ist seit F-011.7 ein dünner Scaffold-Wrapper
- Gesamte Detail-Logik liegt in `ArtikelDetailContent`
- `ValueNotifier`-basierter Rebuild synchronisiert AppBar-Actions
- `_ladeAnhangCount()` mit try/catch abgesichert (PocketBase nicht verfügbar in Tests)

| Gruppe | Tests | Was wird geprüft |
| :-- | :--: | :-- |
| Render | ~6 | Artikelname, Felder, AppBar |
| Name editierbar | ~4 | Inline-Edit, Speichern, Abbrechen |
| Crop-Button | ~3 | Button vorhanden, Icon korrekt |
| AppBar-Aktionen | ~5 | Bearbeiten, Löschen, Teilen |
| Navigation | ~6 | Zurück-Navigation, Pop-Result, Verwerfen-Dialog |

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
- Test-Viewport ist 1080px breit → Mobile-Modus → kein Master-Detail-Layout
  (Desktop-Master-Detail wird bei ≥1024px aktiviert, benötigt dedizierte Tests)


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

### Offene Test-Lücke: Desktop Master-Detail (F-011.7)

Die bestehenden Widget-Tests für `ArtikelListScreen` laufen mit einem Viewport < 1024px
und testen daher nur den Mobile-Modus. Dedizierte Tests für das Desktop-Master-Detail-Layout
(≥1024px Viewport) sind noch nicht vorhanden.

**Empfohlene zukünftige Testfälle:**
- Viewport ≥1024px → Master-Detail-Layout wird angezeigt
- Artikelauswahl in der Liste → Detail-Panel zeigt korrekten Artikel
- Artikelwechsel → `didUpdateWidget` reinitialisiert Content
- Close-Button im Detail-Panel → Platzhalter wird angezeigt
- Ungespeicherte Änderungen → Verwerfen-Dialog bei Artikelwechsel
- Viewport-Resize unter 1024px → Fallback auf Mobile-Layout

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

# Nur O-006 / F-011.7 Widget-Tests
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

# Nur Sync-Recovery + Progress (T-012)
flutter test test/services/sync_error_recovery_test.dart \
             test/services/sync_progress_service_test.dart

``` 

---



## 🚫 Manuelle Integrationstests (T-001)

Die folgenden Szenarien waren ursprünglich als manuelle Integrationstests formuliert.  
Für **v0.9.3** ist ein wesentlicher Teil inzwischen zusätzlich automatisiert abgesichert.

| Test | Beschreibung | Status |
| :-- | :-- | :-- |
| T-001.6 | Artikel auf Gerät A ändern, offline auf Gerät B ändern → Sync → Konflikt-UI erscheint | Weiterhin primär manuell |
| T-001.7 | „Lokal behalten" → Server wird überschrieben | Fachlich automatisiert abgesichert, optional zusätzlich manuell prüfbar |
| T-001.8 | „Server übernehmen" → Lokale Daten werden ersetzt | Fachlich automatisiert abgesichert, optional zusätzlich manuell prüfbar |
| T-001.9 | „Zusammenführen" → Merge-Dialog, Felder manuell wählen, Ergebnis korrekt | Durch Widget-Tests fachlich abgesichert, optional zusätzlich manuell prüfbar |
| T-001.10 | „Überspringen" → Konflikt bleibt, erscheint beim nächsten Sync erneut | Automatisiert abgesichert |
| T-001.11 | Mehrere Konflikte gleichzeitig → sequentielle Bearbeitung mit Fortschrittsanzeige | Durch Widget-Tests fachlich abgesichert |
| T-001.12 | Edge Case: Soft-Delete lokal + Edit remote → Konflikt korrekt erkannt | Automatisiert abgesichert |

**Wichtiger Hinweis:**  
Für den Release-Stand **0.9.3** gelten insbesondere **T-001.7 bis T-001.12** fachlich als umgesetzt und automatisiert nachvollziehbar abgesichert.

---

## 🧰 Test-Infrastruktur

### Test-Helpers (`test/helpers/`)

| Datei | Beschreibung | Verwendet in |
| :-- | :-- | :-- |
| `fake_sync_status_provider.dart` | Test-Double für `SyncStatusProvider` — emittiert kontrollierte Sync-Events | `sync_status_provider_test.dart`, Sync-UI-Tests |
| `no_op_nextcloud_service.dart` | Timer-freier Test-Double via `NextcloudServiceInterface` | `artikel_list_screen_test.dart` |
| `artikel_db_service_test_helper.dart` | Wiederverwendbarer In-Memory-DB-Setup für `ArtikelDbService`-Tests | `artikel_db_service_test.dart` |


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

### Testbarkeit des echten PocketBaseSyncService

Seit dem Abschluss von T-001.10 und T-001.12 wurde zusätzlich die produktive
Sync-Logik testbarer gemacht:

- `PocketBaseSyncService` kann über schlanke Service-Contracts näher an der echten Produktivlogik getestet werden
- Konflikt-Recall und Delete-vs-Edit wurden dadurch nicht nur theoretisch, sondern gegen den realen Sync-Service abgesichert

---

### Fake-Klassen für AttachmentService (`attachment_service_test.dart`)

| Klasse | Beschreibung |
| :-- | :-- |
| `FakeAttachmentRecordService` | Erweitert `RecordService` — Handler-Callbacks inkl. `perPage` / `page` / `sort` |
| `FakePocketBaseForAttachment` | Erweitert `PocketBase` — leitet `collection()` um |
| `fakeClientException()` | Helper — erzeugt `ClientException` mit `originalError:` (SDK v0.23.2) |

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

## 🔗 Verwandte Dokumente

- **[OPTIMIZATIONS.md](OPTIMIZATIONS.md)** — Aufgaben-Tracking
- **[DATABASE.md](DATABASE.md)** — Datenbankschema und Sync-Logik
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — Gesamtarchitektur
- **[HISTORY.md](HISTORY.md)** — Projekthistorie & Entscheidungslog

---

*Dieses Dokument wird bei jeder neuen Test-Suite aktualisiert.*