# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Arbeitsübersicht über **aktuellen Projektstatus**, **offene Aufgaben**, **Prioritäten** und **technische Optimierungen** der **Lager_app**.

**Version:** 0.8.5+19 | **Zuletzt aktualisiert:** 17.04.2026

> **Hinweis:**  
> Diese `OPTIMIZATIONS.md` ist das **laufende Arbeitsdokument** für Status, Prioritäten und Roadmap.  
> Wenn eine Maßnahme **Abgeschlossene, historisch relevante und versioniert ist** wird sie in `HISTORY.md` überfürt.  
> Dadurch bleiben Status-Dokument und Historie sauber getrennt und vermeiden unnötige Dopplungen.

---

## 🏷️ Kürzel-Register

### Legende
- `K` = Kern / Grundlagen / Architektur-Meilenstein
- `M` = Maßnahme / größeres Feature / funktionale Erweiterung
- `O` = Optimierung / Refactoring / Codequalität
- `T` = Tests / Testinfrastruktur / Testausbau
- `F` = Feature / sichtbare Funktion / UX
- `B` = Bug / Befund / Verifikation / Analyse
- `N` = Nichtfunktionales / Branding / visuelle Ergänzung
- `H` = Hosting / Hardening / Infrastruktur / Deployment
- `P` = Performance / Plattform / Laufzeitverbesserung
- `OPT` = bereichsübergreifendes internes Optimierungsvorhaben

### Nächste freie Kürzel
- `K-007`
- `M-013`
- `O-009`
- `T-009`
- `F-006`
- `B-004 + B-006`
- `N-007`
- `H-004`
- `P-006`
- `OPT-002`

### Vergaberegel
Ein Kürzel gilt **ab dem ersten dokumentierten Auftreten als dauerhaft reserviert** —  
auch dann, wenn der Punkt später verschoben, umbenannt oder nach `Future` verschoben wird.

---

## 📊 Gesamtfortschritt

| Phase | Fortschritt | Status |
|---|---|---|
| Phase 1: Grundlagen | 100% | ✅ |
| Phase 2: Deployment & Security | 100% | ✅ |
| Phase 3: Performance & Optimierung | 100% | ✅ |
| Phase 4: Multi-Plattform & Politur | 100% | ✅ |

### Plattform-Status

| Plattform | Status |
|---|---|
| Web (Chrome) | ✅ Voll funktionsfähig |
| Linux Desktop | ✅ Build & PDF-Export stabil |
| Windows Desktop | ✅ Build & Export stabil |
| Android | ✅ Build stabil, Kamera-Test ausstehend |
| iOS/macOS | ⏸️ Zurückgestellt (Apple Developer Account) |

---

## ✅ Abgeschlossen

> **Hinweis:** Details zu den abgeschlossenen Punkten stehen in `HISTORY.md`.  
> Hier bleiben sie als kompakter Überblick mit Versionsbezug erhalten.

### K-001: Bundle Identifiers
- Android: `com.germanlion67.lagerverwaltung`
- iOS: `com.germanlion67.lagerverwaltung`

### K-002: PocketBase Schema & API Rules — erledigt in `v0.2.0`
- Automatische Initialisierung (Admin-User, Collections, Migrations)
- API Rules konfiguriert

### K-003: Artikelnummer & Indizes — erledigt in `v0.3.0`
- Eindeutige Artikelnummer (1000+)
- 5 Performance-Indizes
- Artikelnummer in Listen- und Detailansicht

### K-004: Runtime-Konfiguration PocketBase-URL — erledigt in `v0.7.0`
- Setup-Screen beim Erststart
- URL-Prioritätskette:
  `SharedPreferences / localStorage` → Runtime-Config bzw. `dart-define` → Setup-Screen
- Kein Crash bei fehlender URL

### K-005: WSL2-Bildanzeige — erledigt in `v0.7.1`
- Web-Server-Modus für WSL2-Entwicklung dokumentiert

### K-006: Kaltstart-Bug Fix — erledigt in `v0.8.0`
- Sync-UI-Kopplung über `SyncStatusProvider`-Interface
- Automatischer Bild-Download nach Record-Sync (`downloadMissingImages()`)
- PocketBase-Bild-Fallback in `_LocalThumbnail` und `ArtikelDetailBild`
- Setup-Flow wartet auf initialen Sync vor UI-Wechsel
- Lade-Overlay im Setup-Screen während Sync
- Gezieltes Image-Cache-Evict statt globalem `imageCache.clear()`
- Neue DB-Methode `setBildPfadByUuidSilent()` (kein Sync-Trigger)
- Conditional Import für plattformübergreifendes Cache-Evict
- `FakeSyncStatusProvider` Test-Double + Unit-Tests

### O-001: Bereinigung von `debugPrint` — erledigt in `v0.3.0`
- Alle `debugPrint`-Aufrufe durch `AppLogService` ersetzt
- Verbleibende 8 Aufrufe in `app_log_io.dart` sind absichtlich
  *(zirkuläre Abhängigkeit)*

### O-002: Unit-Tests für `ArtikelDbService` — erledigt in `v0.7.6+4`
- Alle CRUD-Methoden abgedeckt inkl. `setBildPfadByUuidSilent()` ✅

### O-004: UI-Hardcoded Werte migrieren — erledigt in `v0.7.4+3` bis `v0.7.4+7`
- ~600 Hardcodes über 5 Batches migriert ✅
- ~41 bewusst beibehalten (dokumentiert in `THEMING.md`) ✅
- 28 neue `AppConfig`-Tokens ✅
- Dark Mode korrekt in allen Widgets ✅
- Alle `withOpacity` → `withValues` migriert ✅

### O-005: Deprecated Code entfernt — erledigt in `v0.7.7+4`
- `_dokumente_button.dart` gelöscht
- `_dokumente_button_stub.dart` gelöscht
- `dokumente_utils.dart` gelöscht
- Zugehörige Testdateien gelöscht
- `flutter analyze`: 0 Issues

### O-006: Widget-Tests `ArtikelErfassenScreen` — erledigt in `v0.7.7+5`
- 11 Tests, alle grün
- Render, Validierung, Abbrechen-Pfade abgedeckt
- `tester.view.physicalSize` + `scrollUntilVisible()` für `ListView`

### O-007: Tests für `ImagePickerService` nach P-001 — erledigt in `v0.8.0+7`
- 15 Tests, alle grün
- `FakeImagePicker`, Plattform-Checks, Guard-Pfade und Kamera-Flows abgedeckt

### O-008: Magic-Number-Arithmetik in Spacing-Tokens — erledigt in `v0.8.1+11`
- Neuer Token `spacingSectionGap`
- 3 Stellen `spacingXLarge - 4` ersetzt
- Reines Rename-/Token-Refactoring

### M-002: AppLogService Integration — erledigt in `v0.3.0`
- Konsistentes Logging im gesamten Projekt

### M-003: Error Handling — erledigt in `v0.7.6+3`
- Neue `AppException`-Hierarchie
- Neuer `AppErrorHandler`
- Rohe `$e`-Strings durch klassifiziertes Error Handling ersetzt

### M-004: Loading States — erledigt in `v0.7.6+2`
- `AppLoadingOverlay`, `AppLoadingIndicator`, `AppLoadingButton`
- Skeleton-Widgets für Listen
- Loading-Overlays in Detail- und Sync-Screens
- 10 neue `AppConfig`-Tokens

### M-005: Pagination — erledigt in `v0.7.7+4`
- `ScrollController` mit `_onScroll()`-Listener
- `_ladeNaechsteSeite()` mit Offset-Pagination
- Guard gegen Doppel-Requests
- 2 neue `AppConfig`-Tokens:
  `paginationPageSize`, `paginationScrollThreshold`

### M-006: Input Validation — erledigt in `v0.7.6+1`
- Pflichtfelder: Name, Ort, Fach mit Inline-Fehlermeldungen
- Name: Mindestlänge 2 Zeichen, max. 100 Zeichen
- Menge: Nur positive Ganzzahlen (≥ 0), max. 999.999
- Artikelnummer: Automatisch vorgegeben (≥ 1000), manuell änderbar
- Duplikat-Checks lokal + PocketBase
- Neue DB-Methoden: `existsKombination()`, `existsArtikelnummer()`

### M-007: UI für Konfliktlösung — erledigt in `v0.7.5+0`
- `ConflictResolutionScreen` mit Side-by-Side-Vergleich
- `ConflictData` + `ConflictResolution` Enum
- Merge-Dialog
- Integration mit `SyncConflictHandler` und `SyncService`
- Entscheidungs-Callbacks (`useLocal`, `useRemote`, `merge`, `skip`)

### M-008: Backup-Status in der App anzeigen — erledigt in `v0.7.5+1`
- `BackupStatusService` liest `last_backup.json` via HTTP
- `BackupStatusWidget` mit Farbcodierung
- Integration im Settings-Screen
- `backup.sh` kopiert Status-JSON nach `pb_public`

### M-009: Login-Flow & Authentifizierung — erledigt in `v0.7.3`
- Login-Screen mit E-Mail/Passwort-Validierung und Loading-State
- Auth-Gate in `main.dart` mit Auto-Login
- Logout im Settings-Screen mit Bestätigungs-Dialog
- PocketBase API-Regeln auf Auth umgestellt

### M-012: Dateianhänge (Attachments) — erledigt in `v0.7.2`
- PocketBase Collection `attachments` mit File-Upload
- `AttachmentService` — CRUD gegen PocketBase
- Upload-Widget mit Validierung
- Anhang-Liste mit Download, Bearbeiten, Löschen
- Badge-Counter im Detail-Screen

### H-002: CORS-Konfiguration — erledigt in `v0.7.4+0`
- `CORS_ALLOWED_ORIGINS` wird beim PocketBase-Start als `--origins`-Flag übergeben
- Neues `entrypoint.sh` Script ersetzt inline CMD im Dockerfile
- Wildcard (`*`) als Default für Entwicklung, strikt für Produktion
- Portainer Stack an Produktion angeglichen
- Dokumentation in `DEPLOYMENT.md`

### H-003: Backup-Automatisierung — erledigt in `v0.7.1`
- Dedizierter Backup-Container mit Cron
- SQLite WAL-Checkpoint vor jedem Backup
- Komprimiertes `tar.gz`-Archiv mit Integritätsprüfung
- Rotation alter Backups
- E-Mail- und Webhook-Benachrichtigung
- Status-JSON (`last_backup.json`) für App-Anzeige
- Restore-Script mit Sicherheitskopie und Healthcheck

### N-003: App-Icon — erledigt in `v0.8.4+17`
- Neues App-Logo erstellt
- Launcher-Icons für Android, iOS, Web und Windows generiert

### N-004: Roboto Font — erledigt in `v0.3.0`
- Roboto als Standard-Schriftart via `google_fonts`

### N-005: Native Splash Screen — erledigt in `v0.8.4+17`
- `flutter_native_splash` konfiguriert
- Light/Dark Mode
- Android 12+ Splash-API
- Web Splash Screen

### P-001: Kamera-Vorschau-Delay auf Android — erledigt in `v0.7.7+2`
- Crop-Dialog aus `pickImageCamera()` entfernt
- `maxWidth`/`maxHeight`/`imageQuality` aus `AppConfig`
- Hardcodierte 1600px-Dimensionen entfernt
- `openCropDialog()` als public static Methode

### P-002: Suche Debounce — erledigt in `v0.7.7+5`
- Timer-basierter Debounce (300ms)
- Mobile: `_db.searchArtikel()` (`SQL LIKE`)
- Web: clientseitiger Filter
- Skeleton während DB-Suche
- Pagination-Footer bei aktiver Suche ausgeblendet

### P-005: Dependency-Update — erledigt in `v0.8.0+5`
- `cupertino_icons`, `shared_preferences`, `mockito`, `connectivity_plus` aktualisiert
- `connectivity_plus`-API-Migration bereits umgesetzt
- `dependency_overrides` bereinigt

### T-002: Unit-Tests `PocketBaseSyncService` — erledigt in `v0.8.0+5`
- Push/Pull/Fehler/UUID-Sanitization/Image-Skip-Logik abgedeckt ✅

### T-003: Unit-Tests `NextcloudClient` — erledigt in `v0.8.1+12`
- 39 Tests, alle grün ✅
- HTTP-Zugriffe über injizierbaren `MockClient` testbar gemacht ✅

### T-004: Widget-Tests Merge-Dialog — erledigt in `v0.8.1+11`
- Grundstruktur, Konflikt-Anzeige, Feld-/Bild-Auswahl, Zusammenführen, Schließen ✅

### T-005: Unit-Tests `AttachmentService` — erledigt in `v0.8.1+10`
- Alle CRUD-Operationen + Integration (Upload→Get-Roundtrip, Grenzwert 19 vs 20) ✅

### T-006: Unit-Tests `BackupStatusService` — erledigt in `v0.8.0+7`
- Parsing, Farblogik und Fehlerfälle abgedeckt ✅

### T-007: Performance-Test self-contained — erledigt in `v0.8.0+6`
- Testdaten- und PNG-Fixtures werden automatisch in `setUpAll()` erzeugt ✅
- `flutter test` läuft ohne manuelle Vorbereitung ✅

### F-001: Biometrische Authentifizierung (Mobile) — erledigt in `v0.8.2+13`
- `AppLockService`
- `AppLockScreen`
- `local_auth 3.0.1`
- PIN-/Pattern-Fallback
- Integration in `main.dart`

### F-002: Konfigurierbare App-Sperrzeit — erledigt in `v0.8.2+13`
- Inaktivitäts-Timer mit konfigurierbarer Dauer
- Sperrzeit persistent gespeichert
- Automatische Sperre nach Hintergrundwechsel

### F-003: Artikeldetailansicht — Ort & Fach nebeneinander — erledigt in `v0.8.0+8`
- `Row` mit zwei `Expanded`-Kindern
- Neuer Token `detailFieldSpacing`
- Responsive und Dark-Mode-kompatibel

### F-004: Nextcloud-Status-Icon Farbe angleichen — erledigt in `v0.8.4+17`
- Nextcloud-Online-Icon auf `AppConfig.statusColorConnected` umgestellt

### F-005: Detail-Screen Felder leserlicher darstellen — erledigt in `v0.8.4+17`
- Readonly-Felder mit `OutlineInputBorder`
- Volle Lesbarkeit im Readonly-Modus
- Menge und Artikelnummer als eigene Felder
- `+/-`-Buttons nur im Edit-Modus

### B-001: Settings-Änderungen werden ohne Speichern übernommen — verifiziert in `v0.8.3+16`
- Dirty-Tracking, Save-Button und Unsaved-Dialog analysiert
- Ergebnis: Verhalten war bereits korrekt implementiert, kein Fix nötig

### B-002: Biometrische Authentifizierung — System-Dialog & Verfügbarkeitsprüfung — abgeschlossen in `v0.8.3+16`
- Nativer System-Dialog bestätigt
- Verfügbarkeitsprüfung vor Aktivierung bestätigt
- Toggle wird nur bei erfolgreicher Probe-Authentifizierung persistiert

### B-003: Bild-Download-Skip-Logik in downloadMissingImages — abgeschlossen in `v0.8.5+19`
- Skip-Bedingung war invertiert — Negation fehlte
- Korrigiert: Skip nur wenn `bildPfad.isNotEmpty && dateiExistiert && dateiHatInhalt`
- Bilder werden jetzt korrekt heruntergeladen wenn lokal nicht vorhanden

### B-005: ETag-basierte Konflikt-Erkennung vor PATCH — abgeschlossen in `v0.8.5+20`
- Vor jedem PATCH: Remote-Record laden, `updated`-Timestamp mit lokalem `etag` vergleichen
- Bei Abweichung: `onConflictDetected`-Callback statt blindem Überschreiben
- ETag = PocketBase `updated`-Timestamp (ISO 8601), nicht Record-ID

---

## 🔴 Priorität: Hoch

*(Keine offenen Punkte)*

---

## 🟡 Priorität: Mittel

### T-001: Tests für Konfliktlösung (M-007)
Manuelle Integrationstests für die gesamte Konflikt-Pipeline.

**Unit- und Widget-Tests — Abgeschlossen ✅ (77 Tests)**
- [x] **T-001.1** — `ConflictData`: Konstruktor, Felder, Null-Handling (11 Tests)
- [x] **T-001.2** — `ConflictResolution` Enum: Alle Werte, `byName`, Index (6 Tests)
- [x] **T-001.3** — `SyncService.detectConflicts()`: Mock-Daten, ETag-Abweichung erkennen (9 Tests)
- [x] **T-001.4** — `SyncService._determineConflictReason()`: Alle Zeitstempel-Szenarien (15 Tests)
- [x] **T-001.5** — `ConflictResolutionScreen`: Widget-Tests mit `SyncService`-Mock (20 Tests)

**Manuelle Integrationstests**
- [ ] **T-001.6** — Artikel auf Gerät A ändern, offline auf Gerät B ändern → Sync → Konflikt-UI erscheint
- [ ] **T-001.7** — „Lokal behalten“ → Server wird überschrieben
- [ ] **T-001.8** — „Server übernehmen“ → Lokale Daten werden ersetzt
- [ ] **T-001.9** — „Zusammenführen“ → Merge-Dialog, Felder manuell wählen, Ergebnis korrekt
- [ ] **T-001.10** — „Überspringen“ → Konflikt bleibt, erscheint beim nächsten Sync erneut
- [ ] **T-001.11** — Mehrere Konflikte gleichzeitig → Navigation Weiter/Zurück, Fortschrittsanzeige
- [ ] **T-001.12** — Edge Case: Soft-Delete lokal + Edit remote → Konflikt korrekt erkannt

### P-003: Bild-Caching
Remote-Bilder werden bei jedem Scroll neu geladen.
- [ ] `cached_network_image` Paket einbinden
- [ ] `ArtikelBildWidget` auf `CachedNetworkImage` umstellen
- [ ] Cache-Invalidierung bei ETag-Änderung

### P-004: Android Kamera-Test abschließen
**Beschreibung:** Android ist aktuell „Build stabil, Kamera-Test ausstehend“.

**Details**
- [ ] Vollständige manuelle Tests der Kamerafunktionalität auf verschiedenen Android-Geräten
- [ ] Prüfen, ob Bilder korrekt aufgenommen, zugeschnitten und hochgeladen werden
- [ ] Ggf. automatisierte Testabdeckung ergänzen

### OPT-001: `SettingsScreen` — Logik in testbaren Controller extrahieren
**Typ:** Refactoring / Testbarkeit  
**Betrifft:** `lib/screens/settings_screen.dart`

**Problem**
`SettingsScreen` ist ein monolithischer StatefulWidget (~700 Zeilen), der UI, State-Management und Service-Aufrufe vermischt:
- `initState()` → `SharedPreferences`, `AppLockService`, `PocketBaseService`
- `_loadSettings()` → 3 Service-Aufrufe direkt
- `_saveSettings()` → SharedPreferences + PocketBase + AppLock
- `_testPocketBaseConnection()` → Netzwerk-Call
- Dirty-Tracking → inline in `setState()`
- ~15 `_build*Card()` Methoden → UI

**Konsequenzen**
- ❌ Widget-Tests nur mit erheblichem Mocking-Aufwand
- ❌ `PocketBaseService` ist Singleton ohne DI
- ❌ Dirty-Tracking, Validierung und Save-Logik nicht isoliert testbar
- ❌ UI-Änderungen berühren Business-Logik
- ❌ Aktuell 0% Test-Coverage für Settings

**Lösungsvorschlag**
State und Logik in einen `SettingsController` (`ChangeNotifier`) extrahieren, der per Constructor-Injection testbar wird:

```dart
class SettingsController extends ChangeNotifier {
  final SharedPreferences _prefs;
  final AppLockService _appLock;
  final PocketBaseService _pb;

  SettingsController({
    required SharedPreferences prefs,
    required AppLockService appLock,
    required PocketBaseService pb,
  });

  bool get isDirty => _pbUrl != _originalPbUrl || ...;

  Future<void> load() async {
    // ...
  }

  Future<bool> save() async {
    // ...
  }
}
```

---

## 🟢 Priorität: Nice-to-Have

*(Keine Einträge)*

---

## ⏭️ Future (nicht in Planung)

### H-001: iOS/macOS Vorbereitung
Erfordert Apple Developer Account. Zurückgestellt bis Account verfügbar.

### N-006: Nextcloud-Workflow
WebDAV-Anbindung finalisieren und mit Nextcloud 28+ testen.

---

## 📊 Fortschritts-Übersicht

| Priorität | Gesamt | Erledigt | Offen |
|---|---|---|---|
| ✅ Abgeschlossen | 47 | 47 | 0 |
| 🔴 Hoch | 0 | 0 | 0 |
| 🟡 Mittel | 4 | 0 | 4 |
| 🟢 Nice-to-Have | 0 | 0 | 0 |
| ⏭️ Future | 2 | 0 | 2 |
| **Gesamt** | **53** | **47** | **6** |

---

## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
| 2026-04-20 | v0.8.4+20 | B-005: ETag-basierte Konflikt-Erkennung vor PATCH |
| 2026-04-20 | v0.8.4+19 | B-003: Bild-Download-Skip-Logik in downloadMissingImages korrigiert |
| 2026-04-14 | v0.8.4+17 | N-003: App-Icon + N-005: Native Splash Screen als erledigt markiert |
| 2026-04-14 | v0.8.4+17 | F-004 abgeschlossen: NC-Icon auf `statusColorConnected` umgestellt. F-005 abgeschlossen: Detail-Screen Readonly-Felder mit `OutlineInputBorder` + `InputDecorator`, Menge/Artikelnummer als eigene Felder, `+/-` Buttons nur im Edit-Modus, 3 Widget-Tests angepasst |
| 2026-04-14 | v0.8.3+16 | B-001 abgeschlossen: Settings-Save-Verhalten analysiert — Dirty-Tracking, Save-Button und Unsaved-Dialog waren bereits korrekt implementiert. B-002 abgeschlossen: Biometrie-Analyse — automatischer Auth-Start, FragmentActivity, Verfügbarkeitsprüfung vor Toggle-Aktivierung bestätigt. OPT-001 neu: SettingsController-Extraktion für Testbarkeit |
| 2026-04-13 | v0.8.2+13 | F-001 + F-002 abgeschlossen: App-Lock mit biometrischer Authentifizierung und konfigurierbarer Sperrzeit |
| 2026-04-13 | v0.8.1+12 | T-003 abgeschlossen: 39 Unit-Tests `NextcloudClient` |
| 2026-04-13 | v0.8.1+11 | T-004 abgeschlossen: 18 Widget-Tests MergeDialog. O-008 abgeschlossen: `spacingSectionGap` Token, 3 Stellen ersetzt |
| 2026-04-13 | v0.8.1+10 | T-005 abgeschlossen: 34 Tests `AttachmentService` |
| 2026-04-13 | v0.8.0+8 | F-003: Artikeldetailansicht — Ort & Fach nebeneinander |
| 2026-04-13 | v0.8.0+7 | O-007 abgeschlossen: 15 Tests `ImagePickerService` |
| 2026-04-13 | v0.8.0+7 | T-006 abgeschlossen: `BackupStatusService` formal abgenommen |
| 2026-04-13 | v0.8.0+6 | T-007 abgeschlossen: Performance-Test self-contained |
| 2026-04-13 | v0.8.0+5 | P-005 als erledigt markiert: Ziel-Versionen bereits in `pubspec.yaml`, `connectivity_plus`-Migration umgesetzt |
| 2026-04-12 | v0.8.0+5 | T-002 abgeschlossen: 17 Unit-Tests `PocketBaseSyncService` |
| 2026-04-11 | v0.8.0 | F-001, F-002, F-003 hinzugefügt und in Priorität „Mittel“ einsortiert |
| 2026-04-10 | v0.8.0 | +104 Tests: `AttachmentModel` (30), `attachment_utils` (28), `BackupStatus` (22) |
| 2026-04-10 | v0.8.0 | K-006 abgeschlossen: Kaltstart-Bug Fix |
| 2026-04-08 | v0.7.7+5 | O-006 abgeschlossen: 11 Widget-Tests `ArtikelErfassenScreen` |
| 2026-04-08 | v0.7.7+5 | P-002 abgeschlossen: Debounce 300ms, DB-Suche Mobile, clientseitig Web |
| 2026-04-07 | v0.7.7+4 | M-005 Offset-Pagination, ScrollController, Lade-Footer & O-005 deprecated Dateien entfernt |
| 2026-04-07 | v0.7.7+3 | H-001 nach Future verschoben, T-002–T-006, O-005–O-006, P-002–P-003 neu erfasst |
| 2026-04-07 | v0.7.7+2 | P-001 abgeschlossen: Kamera-Delay auf Android behoben |
| 2026-04-06 | v0.7.7+1 | T-001 Unit- und Widget-Tests abgeschlossen (77 Tests) |
| 2026-04-05 | v0.7.7 | Release `v0.7.7`: Dokumentation aktualisiert, `TESTING.md` erstellt, Version hochgezogen |
| 2026-04-05 | v0.7.6+4 | O-002 abgeschlossen: `ArtikelDbService`, `ArtikelModel`, `ImageProcessingUtils`, `UuidGenerator` |
| 2026-04-05 | v0.7.6+3 | M-003 Zentrales Error Handling abgeschlossen |
| 2026-04-05 | v0.7.6+2 | M-004 Loading States abgeschlossen |
| 2026-04-05 | v0.7.6+1 | M-006 Input Validation abgeschlossen |
| 2026-04-03 | v0.7.5+1 | M-008 als erledigt markiert |
| 2026-04-02 | v0.7.5+0 | M-007 als erledigt markiert, K-003 umbenannt, T-001 erstellt |
| 2026-04-02 | v0.7.4+7 | O-004 Batch 5 erledigt + O-004 abgeschlossen |
| 2026-04-02 | v0.7.4+6 | O-004 Batch 4 erledigt |
| 2026-04-02 | v0.7.4+5 | O-004 Batch 3 erledigt |
| 2026-04-01 | v0.7.4+4 | O-004 Batch 2 erledigt |
| 2026-04-01 | v0.7.4+3 | O-004 Batch 1 erledigt |
| 2026-03-30 | v0.7.4+0 | H-002 (CORS) abgeschlossen |
| 2026-03-29 | v0.7.2 | M-012 (Attachments) abgeschlossen, M-009 hinzugefügt |
| 2026-03-27 | v0.7.1 | H-003 (Backup) abgeschlossen, M-008 hinzugefügt |
| 2026-03-27 | v0.7.0 | K-004 (Runtime-URL) abgeschlossen |
| 2026-03-25 | — | Dokumentation modularisiert |
| 2026-03-24 | — | Produktions-Hardening und Indizierung |
| 2026-03-23 | — | Design-Tokens und Themes |

---

[Zurück zur README](../README.md) | [Zur HISTORY](../HISTORY.md) | [Zum Changelog](../CHANGELOG.md)