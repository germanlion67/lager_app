# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Arbeitsübersicht über **aktuellen Projektstatus**, **offene Aufgaben**, **Prioritäten** und **technische Optimierungen** der **Lager_app**.

**Version:** 0.9.1+26 | **Zuletzt aktualisiert:** 22.04.2026

> **Hinweis:**  
> Diese `OPTIMIZATIONS.md` ist das **laufende Arbeitsdokument** für Status, Prioritäten und Roadmap.  
> Wenn eine Maßnahme **Abgeschlossene, historisch relevante und versioniert ist** wird sie in `HISTORY.md` überfürt.  
> Dadurch bleiben Status-Dokument und Historie sauber getrennt und vermeiden unnötige Dopplungen.

---

## 🏷️ Kürzel-Register

### Legende
- `B` = Bug / Befund / Verifikation / Analyse
- `F` = Feature / sichtbare Funktion / UX
- `H` = Hosting / Hardening / Infrastruktur / Deployment
- `K` = Kern / Grundlagen / Architektur-Meilenstein
- `M` = Maßnahme / größeres Feature / funktionale Erweiterung
- `N` = Nichtfunktionales / Branding / visuelle Ergänzung
- `O` = Optimierung / Refactoring / Codequalität
- `P` = Performance / Plattform / Laufzeitverbesserung
- `T` = Tests / Testinfrastruktur / Testausbau

### Nächste freie Kürzel
- `B-013`, `F-008`, `H-004`, `K-008`, `M-013`, `N-007`, `O-011`, `P-006`, `T-009`

### Vergaberegel
Ein Kürzel gilt **ab dem ersten dokumentierten Auftreten als dauerhaft reserviert** —  
auch dann, wenn der Punkt später verschoben, umbenannt oder nach `Future` verschoben wird.

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


### P-004: Android Kamera-Test abschließen
**Beschreibung:** Android ist aktuell „Build stabil, Kamera-Test ausstehend“.

**Details**
- [ ] Vollständige manuelle Tests der Kamerafunktionalität auf verschiedenen Android-Geräten
- [ ] Prüfen, ob Bilder korrekt aufgenommen, zugeschnitten und hochgeladen werden
- [ ] Ggf. automatisierte Testabdeckung ergänzen

### O-010: `SettingsScreen` — Logik in testbaren Controller extrahieren
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

*(Keine offenen Punkte)*

## ⏭️ Future (nicht in Planung)

### H-001: iOS/macOS Vorbereitung
Erfordert Apple Developer Account. Zurückgestellt bis Account verfügbar.

### N-006: Nextcloud-Workflow
WebDAV-Anbindung finalisieren und mit Nextcloud 28+ testen.

---

## 📊 Fortschritts-Übersicht

| Priorität | Gesamt | Erledigt | Offen |
|---|---|---|---|
| ✅ Abgeschlossen | 54 | 46 | 0 |
| 🔴 Hoch | 0 | 0 | 0 |
| 🟡 Mittel | 3 | 0 | 3 |
| 🟢 Nice-to-Have | 0 | 0 | 0 |
| ⏭️ Future | 2 | 0 | 2 |
| **Gesamt** | **62** | **57** | **5** |


---

## ✅ Abgeschlossen

> **Hinweis:** Details zu den abgeschlossenen Punkten stehen in `HISTORY.md`.  
> Hier bleiben sie als kompakter Überblick mit Versionsbezug erhalten.

### B-012: Letzter-Sync-Zeitstempel auf schmalen Displays abgeschnitten — erledigt in `v0.9.0+25`
**Typ:** Bug / Regression (B-007-Commit)
**Betrifft:** `lib/screens/artikel_list_screen.dart` → AppBar `title`

Das Sync-Label hat kein `overflow`-Handling und konkurriert auf 360dp
mit Action-Icons um Platz. Kein `TextOverflow`, kein `Flexible`-Wrapper.

- `overflow: TextOverflow.ellipsis` am Text ergänzen
- `Text` in `Flexible` wrappen um Layout-Constraints zu respektieren
- Nach B-009-Fix (Dropdown-Entfernung) erneut auf S20 prüfen — Problem könnte sich dadurch bereits teilweise lösen

---

### B-011: App-Version zeigt veralteten Build-Stand — erledigt in `v0.9.0+25`
**Typ:** Bug / Build-Prozess
**Betrifft:** Build-Pipeline, kein Code-Fehler

`_getAppVersion()` in `settings_screen.dart` ist korrekt implementiert
und liest via `PackageInfo.fromPlatform()` aus den nativen
Build-Artefakten. Die angezeigte Version 0.8.8+23 stammt aus der
installierten APK — es wurde kein neuer Build nach dem Version-Bump
auf 0.8.9+24 erstellt oder die falsche APK installiert.

- `flutter build apk --release` mit aktuellem Stand ausführen
- Neue APK auf S20 installieren (vorherige deinstallieren)
- Version in Settings verifizieren → muss 0.8.9+24 zeigen
- Hinweis: `pubspec.yaml` zeigt bereits 0.9.0+25 —
      nach nächstem Release-Build wird 0.9.0+25 erscheinen ✅

--- 

### B-010: Snackbar-Feedback in Artikelliste fehlt  — erledigt in `v0.9.0+25`
**Typ:** Bug / Regression (B-007-Commit)
**Betrifft:** `lib/screens/artikel_list_screen.dart`

Nach Sync-Erfolg/-Fehler gibt es kein Snackbar-Feedback mehr.
Der `SyncStatus`-Listener ruft bei `success` nur `_ladeArtikel()` auf.
Fehler-Pfade zeigen keine Rückmeldung.

- Snackbar bei `SyncStatus.success` ergänzen
- Snackbar bei `SyncStatus.error` ergänzen (Fehlertext aus Provider)
- Snackbar bei manuellem Sync-Start ergänzen
- `ScaffoldMessenger`-Erreichbarkeit nach Dropdown-Entfernung (B-009) verifizieren

---

### B-009: Artikelliste — Ort-Dropdown hardcodiert und falsch platziert  — erledigt in `v0.9.0+25`
**Typ:** Bug / Regression (B-007-Commit)
**Betrifft:** `lib/screens/artikel_list_screen.dart` → AppBar `actions`

Der Ort-Filter-Dropdown wurde als Test-Stub mit hardcodierten Werten
('Lager 1', 'Lager 2', 'Büro') in die AppBar `actions` eingefügt.
Er liest keine echten Daten aus `_artikelListe` und ist falsch
platziert (AppBar statt Body/Filter-Leiste).

- Dropdown aus AppBar `actions` entfernen
- Echte Ort-Werte dynamisch aus `_artikelListe` ableiten (distinct, alphabetisch sortiert, „Alle" als erster Eintrag)
- Filter-UI in die Suchleiste im Body integrieren
- Filterlogik mit `_gefilterteArtikel()` verbinden (bereits korrekt)

---

### B-008: Artikelliste — Beschreibung, Artikelnummer und Fach fehlen — erledigt in `v0.9.0+25`
**Typ:** Bug / Regression (B-007-Commit)
**Betrifft:** `lib/screens/artikel_list_screen.dart` → `_buildArtikelTile()`

`_buildArtikelTile()` wurde auf ein minimales `ListTile` reduziert.
Vor B-007 war es ein reichhaltigeres Card-Widget mit allen Feldern.
Wiederherstellen als `Card` mit Artikelnummer, Name, Beschreibung,
Ort, Fach und Menge.

- `_buildArtikelTile()` auf Card-Layout mit allen Feldern erweitern
- Artikelnummer, Beschreibung und Fach wieder einblenden
- Auf S20 (360dp) und Tablet verifizieren

---

### B-007: Intelligenter Bild-Sync & UI-Optimierung — erledigt in `v0.8.9+24`
- **Smart Sync**: `PocketBaseSyncService` vergleicht nun Datei-Zeitstempel mit PocketBase-Updates.
- **Cleanup**: Automatisches Löschen alter Bildversionen im Dateisystem bei Namensänderung.
- **UI-Kontrast**: "Letzter Sync"-Zeitstempel auf `onSurface` (Bold) umgestellt für maximale Lesbarkeit.

### B-003 bis B-006: Sync-Stabilität — erledigt in `v0.8.5+19`
- ETag-basierte Konflikt-Erkennung vor PATCH.
- Korrektur der Bild-Download-Skip-Logik.
- Navigator-Init via GlobalKey gefixt.

### B-001: Settings-Änderungen werden ohne Speichern übernommen — verifiziert in `v0.8.3+16`
- Dirty-Tracking, Save-Button und Unsaved-Dialog analysiert
- Ergebnis: Verhalten war bereits korrekt implementiert, kein Fix nötig

### B-002: Biometrische Authentifizierung — System-Dialog & Verfügbarkeitsprüfung — abgeschlossen in `v0.8.3+16`
- Nativer System-Dialog bestätigt
- Verfügbarkeitsprüfung vor Aktivierung bestätigt
- Toggle wird nur bei erfolgreicher Probe-Authentifizierung persistiert

--- 

### F-007: Einstellung — Letzter-Sync-Zeitstempel ein-/ausblenden — erledigt in `v0.9.0+25`
**Typ:** Feature
**Betrifft:** `lib/screens/settings_screen.dart`,
             `lib/screens/artikel_list_screen.dart`

Toggle in den Einstellungen, der den Sync-Zeitstempel in der
Artikelliste ein- oder ausblendet. Persistenz via SharedPreferences.

- Toggle in `_buildPocketBaseCard()` oder neue Sync-Card ergänzen (SharedPreferences Key: `show_last_sync`, Default: `true`)
- `ArtikelListScreen` liest Präferenz in `initState()`
- Reaktiv: Änderung wirkt ohne App-Neustart (z.B. via `ValueNotifier` oder Provider)
- Auf S20 und Tablet verifizieren
F-007 — Hotfix: ValueListenableBuilder in ArtikelListScreen ergänzt; Toggle war funktionslos da Notifier nie abgehört wurde.

---

### F-006: Log-Level-Filter als Dropdown statt Button-Reihe — erledigt in `v0.9.0+25`
**Typ:** Feature / UX-Verbesserung
**Betrifft:** Log-Dialog (`AppLogService.showLogDialog()`)

Button-Reihe für Trace/Debug/Info/Warn/Error/Fatal passt auf schmalen
Displays nicht in eine Zeile. Ersetzen durch `DropdownButton<Level>`
mit Default-Wert `Level.error`.

- Log-Dialog-Code lokalisieren (vermutlich `app_log_service.dart` oder separater Dialog)
- Button-Reihe durch `DropdownButton<Level>` ersetzen
- Default: `Level.error`
- Gefilterte Log-Ausgabe weiterhin korrekt aktualisieren
- Auf S20 (360dp) verifizieren

--- 

### F-004 & F-005: UI-Politur — erledigt in `v0.8.4+17`
- Nextcloud-Status-Icon Farbe angepasst.
- Detail-Screen Felder leserlicher (OutlineInputBorder).

### F-001 & F-002: Security — erledigt in `v0.8.2+13`
- Biometrische Authentifizierung und konfigurierbare Sperrzeit.

### F-003: Artikeldetailansicht — Ort & Fach nebeneinander — erledigt in `v0.8.0+8`
- `Row` mit zwei `Expanded`-Kindern
- Neuer Token `detailFieldSpacing`
- Responsive und Dark-Mode-kompatibel

--- 

### H-002 & H-003: Infrastruktur — erledigt in `v0.7.1` bis `v0.7.4`
- CORS-Konfiguration und Backup-Automatisierung (Docker).

--- 

### K-007: Flutter update — erledigt in `v0.9.1+26`
Flutter/Dart:
- Flutter: 3.41.4 → 3.41.7
- Dart: 3.11.1 → 3.11.5

Package Major Updates (pubspec.yaml):
- csv: ^6.0.0 → ^8.0.0 (rowSeparator statt eol)
- device_info_plus: ^10.1.2 → ^12.4.0
- file_picker: ^10.1.0 → ^11.0.2
- flutter_local_notifications: ^19.4.1 → ^21.0.0
- share_plus: ^10.1.4 → ^12.0.2 (shareXFiles statt shareFiles)
- build_runner: ^2.4.6 → ^2.14.0

Removed:
- js: ^0.7.1 (discontinued, ersetzt durch dart:js_interop via web:)
- dependency_overrides Block (nicht mehr nötig)

CI/CD:
- flutter-version: 3.41.4 → 3.41.7 in allen 4 Workflows

Verified: flutter analyze clean, 610 tests passing"


### K-006: Kaltstart-Bug Fix — erledigt in `v0.8.0`
- Sync-UI-Kopplung und automatischer Bild-Download nach Erst-Setup.

### K-001 bis K-005: Fundament — erledigt in `v0.2.0` bis `v0.7.1`
- Bundle IDs, PocketBase Schema, Runtime-URL-Config, WSL2-Support.

--- 

### M-002 bis M-006: Core-Features — erledigt in `v0.7.6+x`
- Zentrales Error Handling, Loading States, Pagination und Input Validation.

### M-008: Backup-Status in der App anzeigen — erledigt in `v0.7.5+1`
- `BackupStatusService` liest `last_backup.json` via HTTP
- `BackupStatusWidget` mit Farbcodierung
- Integration im Settings-Screen
- `backup.sh` kopiert Status-JSON nach `pb_public`

### M-007: UI für Konfliktlösung — erledigt in `v0.7.5+0`
- `ConflictResolutionScreen` mit Side-by-Side-Vergleich
- `ConflictData` + `ConflictResolution` Enum
- Merge-Dialog
- Integration mit `SyncConflictHandler` und `SyncService`
- Entscheidungs-Callbacks (`useLocal`, `useRemote`, `merge`, `skip`)

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

--- 

### N-003 & N-005: Branding — erledigt in `v0.8.4+17`
- Neues App-Icon und Native Splash Screen für alle Plattformen.

--- 

### O-009: Widget-Tests `ArtikelListScreen` — abgeschlossen in `v0.9.0+25`
- Import-Pfad korrigiert: `artikel.dart` → `artikel_model.dart`
- `erstelltAm` / `aktualisiertAm` als Pflichtfelder im Testartikel ergänzt
- `_pumpScreenWithArtikel()` Helper für Dropdown-Tests via `initialArtikel`
- Suchfeld-Label korrigiert: `'Suche...'` → `'Suche…'` (U+2026)
- Alle 15 Widget-Tests grün ✅
- Gesamtstand: **625 Tests**, 28 Dateien ✅

### O-008: Magic-Number-Arithmetik in Spacing-Tokens — erledigt in `v0.8.1+11`
- Neuer Token `spacingSectionGap`
- 3 Stellen `spacingXLarge - 4` ersetzt
- Reines Rename-/Token-Refactoring

### O-007: Tests für `ImagePickerService` nach P-001 — erledigt in `v0.8.0+7`
- 15 Tests, alle grün
- `FakeImagePicker`, Plattform-Checks, Guard-Pfade und Kamera-Flows abgedeckt

### O-006: Widget-Tests `ArtikelErfassenScreen` — erledigt in `v0.7.7+5`
- 11 Tests, alle grün
- Render, Validierung, Abbrechen-Pfade abgedeckt
- `tester.view.physicalSize` + `scrollUntilVisible()` für `ListView`

### O-005: Deprecated Code entfernt — erledigt in `v0.7.7+4`
- `_dokumente_button.dart` gelöscht
- `_dokumente_button_stub.dart` gelöscht
- `dokumente_utils.dart` gelöscht
- Zugehörige Testdateien gelöscht
- `flutter analyze`: 0 Issues

### O-002: Unit-Tests für `ArtikelDbService` — erledigt in `v0.7.6+4`
- Alle CRUD-Methoden abgedeckt inkl. `setBildPfadByUuidSilent()` ✅

### O-004: UI-Hardcoded Werte migrieren — erledigt in `v0.7.4+3` bis `v0.7.4+7`
- ~600 Hardcodes über 5 Batches migriert ✅
- ~41 bewusst beibehalten (dokumentiert in `THEMING.md`) ✅
- 28 neue `AppConfig`-Tokens ✅
- Dark Mode korrekt in allen Widgets ✅
- Alle `withOpacity` → `withValues` migriert ✅

### O-001: Bereinigung von `debugPrint` — erledigt in `v0.3.0`
- Alle `debugPrint`-Aufrufe durch `AppLogService` ersetzt
- Verbleibende 8 Aufrufe in `app_log_io.dart` sind absichtlich
  *(zirkuläre Abhängigkeit)*

--- 

### P-003: Bild-Caching — erledigt in `v0.8.6+21`
- Integration von `cached_network_image`
- `ArtikelBildWidget` nutzt persistenten Cache für Remote-Bilder
- Kein Flackern/Neu-Laden beim Scrollen in der Liste
- Cache-Invalidierung bei ETag-Änderung sichergestellt

### P-005: Dependency-Update — erledigt in `v0.8.0+5`
- `cupertino_icons`, `shared_preferences`, `mockito`, `connectivity_plus` aktualisiert
- `connectivity_plus`-API-Migration bereits umgesetzt
- `dependency_overrides` bereinigt

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

--- 

### T-008: ETag-Konflikt-Logik und downloadMissingImages-Check-Logik — abgeschlossen in `v0.8.5+19`
- `pocketbase_sync_service_conflict_test.dart` — 11 Tests ✅
- `sync_orchestrator_test.dart` — 9 Tests (erweitert) ✅
- ETag-Grenzwerte, ConflictCallback-Typedef, SyncStatus-Enum abgedeckt ✅
- Gesamtstand: **625 Tests**, 28 Dateien ✅

### T-003 bis T-007: Test-Offensive — erledigt in `v0.8.1+10`
- Unit-Tests für `NextcloudClient`, `MergeDialog` und `AttachmentService`, `BackupStatusService`.
- Performance-Test self-contained. `flutter test` läuft ohne manuelle Vorbereitung

--- 


## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
| 2026-04-22 | v0.9.1+26 | K-007: flutter upgrade 3.41.4 → 3.41.7 + package major updates |
| 2026-04-22 | v0.9.0+25 | B-008 abgeschlossen: Card-Layout ArtikelListScreen wiederhergestellt (Artikelnummer, Chips, Feldname-Fix). B-009 abgeschlossen: Ort-Dropdown dynamisch aus Artikelliste, in Body integriert, Reset-Button. B-010 abgeschlossen: Snackbar-Feedback bei Sync-Start/-Erfolg/-Fehler. B-011 abgeschlossen: App-Version zeigt korrekten Build-Stand nach neuem Release-Build. B-012 abgeschlossen: Sync-Label TextOverflow.ellipsis + titleSpacing. F-006 abgeschlossen: Log-Level-Filter als DropdownButton<Level>, Default Level.error. F-007 abgeschlossen: Sync-Zeitstempel-Toggle via ValueNotifier + SharedPreferences. O-009 abgeschlossen: 15 Widget-Tests ArtikelListScreen grün (625 Tests gesamt). |
| 2026-04-21 | v0.8.9+24 | B-007 abgeschlossen: Intelligenter Bild-Sync (Timestamp-Check) und UI-Politur des Sync-Zeitstempels implementiert. |
| 2026-04-20 | v0.8.6+21 | P-003 abgeschlossen: Bild-Caching via `cached_network_image` integriert. Android-Stabilität auf S20 verifiziert. |
| 2026-04-20 | v0.8.4+20 | Dokumente aktualisiert |
| 2026-04-17 | v0.8.5+19 | B-003 abgeschlossen: downloadMissingImages Skip-Logik korrigiert. B-004 abgeschlossen: Konflikt-Callback via GlobalKey + addPostFrameCallback. B-005 abgeschlossen: ETag-Konflikt-Erkennung vor PATCH. B-006 abgeschlossen: SyncManagementScreen auf SyncOrchestrator umgestellt. T-008 abgeschlossen: 20 neue Tests (610 gesamt, 28 Dateien) |
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