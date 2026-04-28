# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Arbeitsübersicht über **aktuellen Projektstatus**, **offene Aufgaben**, **Prioritäten** und **technische Optimierungen** der **Lager_app**.

**Version:** 0.9.4+36 | **Zuletzt aktualisiert:** 28.04.2026

> **Hinweis:**  
> Diese `OPTIMIZATIONS.md` ist das **laufende Arbeitsdokument** für Status, Prioritäten und Roadmap.  
> Wenn eine Maßnahme **abgeschlossen, historisch relevant und versioniert** ist, wird sie in `HISTORY.md` überführt.  
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
- `B-014`, `F-009`, `H-004`, `K-008`, `M-014`, `N-007`, `O-012`, `P-006`, `T-011`

### Vergaberegel
Ein Kürzel gilt **ab dem ersten dokumentierten Auftreten als dauerhaft reserviert** —  
auch dann, wenn der Punkt später verschoben, umbenannt oder nach `Future` verschoben wird.

---

## 🔴 Priorität: Hoch

*(Keine offenen Punkte)*

---

## 🟡 Priorität: Mittel

### T-001: Konfliktlösung, Sync-Hardening und Integrationsverifikation (M-007)
Manuelle Integrationstests und Restverifikation für die inzwischen deutlich gehärtete Konflikt- und Sync-Pipeline.

**Technische Basis, Hardening und service-nahe Tests — weitgehend abgeschlossen ✅**
- [x] **T-001.1** — `ConflictData`: Konstruktor, Felder, Null-Handling
- [x] **T-001.2** — `ConflictResolution` Enum: Alle Werte, `byName`, Index
- [x] **T-001.3** — `SyncService.detectConflicts()`: Mock-Daten, ETag-Abweichung erkennen
- [x] **T-001.4** — `SyncService._determineConflictReason()`: Alle Zeitstempel-Szenarien
- [x] **T-001.5** — `ConflictResolutionScreen`: Widget-Tests mit `SyncService`-Mock
- [x] **T-001.10** — „Überspringen“ → Konflikt bleibt, erscheint beim nächsten Sync erneut
- [x] **T-001.12** — Edge Case: Soft-Delete lokal + Edit remote → Konflikt korrekt erkannt
- [x] Pull überschreibt `force_local`-Datensatz nicht mit Remote-Version
- [x] Pull überschreibt `force_merge`-Datensatz nicht mit Remote-Version
- [x] UI-Fehlerpfad bei Konfliktauflösung bleibt stabil (Snackbar, kein Pop)
- [x] Remote-Delete-Guards für dirty/pending/clean service-nah abgesichert
- [x] Erfolgreicher `force_local`-/`force_merge`-Push bereinigt `pendingResolution` über `markSynced()`-Contract
- [x] Produktive Konfliktlogik für `pendingResolution`, `force_local`, `force_merge`, Skip, Delete-vs-Edit, Remote-Delete-Guards und `useRemote`-Baseline gehärtet
- [x] Duplicate-UUID-Recovery beim Remote-Create service-nah abgesichert
- [x] `_PocketBaseConflictAdapter` interface-/analyzer-konform vervollständigt
- [x] `toPocketBaseMap()` sendet keine lokalen Sync-Metadaten mehr mit
- [x] Modelltests für relevante Sync-Felder sind weitgehend vorhanden
- [x] UTC-Inkonsistenzen im relevanten Modell-/DB-Bereich weitgehend bereinigt

**Manuelle Integrations- und Feldtests**
- [ ] **T-001.6** — Artikel auf Gerät A ändern, offline auf Gerät B ändern → Sync → Konflikt-UI erscheint
- [ ] **T-001.7** — „Lokal behalten“ → Server wird überschrieben
- [ ] **T-001.8** — „Server übernehmen“ → Lokale Daten werden ersetzt
- [ ] **T-001.9** — „Zusammenführen“ → Merge-Dialog, Felder manuell wählen, Ergebnis korrekt
- [ ] **T-001.11** — Mehrere Konflikte gleichzeitig → Navigation Weiter/Zurück, Fortschrittsanzeige
- [ ] End-to-End-Test mit echtem PocketBase-Duplicate-UUID-Fall durchführen
- [ ] Manuell verifizieren: `force_local` überschreibt Remote-Datensatz nach Konfliktentscheidung korrekt
- [ ] Manuell verifizieren: `force_merge` bleibt nach bestätigter Auflösung stabil
- [ ] Manuell verifizieren: übersprungene Konflikte erscheinen im UI beim nächsten Sync erneut
- [ ] Manuell verifizieren: Soft-Delete lokal + Remote-Edit führt weiterhin reproduzierbar zur Konflikt-UI

**Verbleibende technische Restpunkte**
- [x] Artikel-Modell und Persistenz für `kategorie` vervollständigen
- [x] Konflikt-UI/Navigation in `main.dart` gegen parallele Mehrfachöffnung absichern
- [ ] Index-Namen in `DATABASE.md` und `ARCHITECTURE.md` gegen den echten SQLite-Code abgleichen und vereinheitlichen

**Optional / spätere Verfeinerung**
- [ ] Monitoring/Zähler für Duplicate-UUID-Recovery-Häufigkeit prüfen oder ergänzen
- [ ] Optional: UUID-Format serverseitig zusätzlich per Pattern validieren
- [ ] Optional prüfen, ob die Konfliktvergleichsbasis langfristig klarer auf `last_synced_etag` vereinheitlicht oder dokumentiert werden sollte
- [ ] Optional `ConflictCallback` semantisch verbessern, sodass Entscheidungen direkt zurückgegeben werden
- [ ] Optional service-nähere Sync-/Integrationstests mit Fakes für Remote-Records und Persistenzpfade ergänzen
- [ ] Optional gezielte Modelltests für Roundtrip- und `copyWith()`-Null-Semantik ergänzen
- [ ] Optional Semantik von `aktualisiertAm` vs. `updatedAt` dokumentieren oder klarer benennen
- [ ] Optional Konfliktauflösung über dediziertes Interface statt generischem `SyncService` entkoppeln
- [ ] Optional Restprüfung auf konsistente UTC-/Zeitstempel-Semantik in `artikel_db_service.dart`
- [ ] Optional Soft-Delete-/Delete-Abschlusslogik im Sync fachlich weiter vereinfachen

**Hinweis**
Die technische Konfliktlogik wurde mit `fix/sync-hardening2-v0.9.4` bereits deutlich gehärtet. Offen sind vor allem noch echte Geräte-/Server-Integrationsläufe, einige manuelle Verifikationen sowie wenige verbleibende Modell-/Dokumentationspunkte.


### B-014: PocketBase Sync – CREATE-Fehler (HTTP 400) + SyncOnce-Timeout + fehlende Sync-Basis (`last_synced_etag`)
**Typ:** Bug / Befund / Analyse  
**Betrifft:**  
`app/lib/services/pocketbase_sync_service.dart`,  
`app/lib/services/sync_orchestrator.dart`,  
PocketBase Collection `artikel` (Schema + Rules)

**Beobachtung (reale Logs / Geräte-Tests)**
- Beim App-Start / Sync-Lauf treten wiederholt Fehler auf:
  - `ClientException ... statusCode: 400 ... message: Failed to create record.`
  - Quelle: `_pushToPocketBase()` im CREATE-Pfad (`collection(...).create(...)`)
- Zusätzlich schlägt `SyncOrchestrator.runOnce()` gelegentlich mit
  `TimeoutException after 0:01:00 ... Future not completed` fehl, da `syncOnce()`
  im Push-Pfad keine eigenen Request-Timeouts hat und der Orchestrator nach 60 s abbricht.

**Fachlicher Impact**
- Lokale Pending-Datensätze (dirty via `etag IS NULL`) werden nicht remote angelegt → bleiben dauerhaft pending.
- `markSynced()` wird nie erfolgreich erreicht → `etag`/`last_synced_etag` werden nicht gesetzt → keine stabile Konfliktbasis (vgl. `docs/prompt_Sync.txt`: `last_synced_etag` als Baseline, fehlende Basis → konservativer Konflikt-Fall).
- Folgeeffekte: wiederholte Push-Retry-Spiralen und/oder konservative Konflikt-Cases („missing base") können Integrationstests wie **T-001.6** verfälschen oder blockieren.

**Vermutete Ursachen (zu verifizieren)**
1. PocketBase Schema / Create Rules blockieren das CREATE (fehlende Required-Felder, Typmismatch, fehlendes Auth-/Owner-Feld).
2. Push-Requests (`getList` / `create` / `update` / `delete`) laufen ohne eigenen Timeout → der Orchestrator-Timeout (60 s) ist die einzige Bremse.

**Tasks**
- [ ] PocketBase Admin prüfen: `artikel`-Schema (Required-Felder, Typen) + Create/Update Rules; echten Validierungsgrund für 400 identifizieren (Server-Log / Admin UI).
- [ ] In `PocketBaseSyncService._pushToPocketBase()` für `getList` / `create` / `update` / `delete` explizite Request-Timeouts ergänzen, damit Fehler deterministisch und schneller sichtbar werden.
- [ ] Push-Logging um kurze, mobile-lesbare Summary-Lines ergänzen (siehe O-012), z. B. `SYNC|PUSH|CREATE fail uuid=... status=400`.
- [ ] Nach Fix: **T-001.6** (und weitere manuelle Sync-Integrationsfälle) erneut durchführen und Konfliktbasis (`last_synced_etag`) verifizieren.


### O-012: Logging – Sync-Logs mobiltauglich kürzen (Summary-Lines + optionale Details)
**Typ:** Optimierung / Diagnose / UX  
**Betrifft:**  
`docs/LOGGER.md`,  
`app/lib/services/pocketbase_sync_service.dart`,  
`app/lib/services/sync_orchestrator.dart`,  
`app/lib/services/artikel_db_service.dart`

**Problem**
- Fehlerlogs sind auf mobilen Displays schwer lesbar, da Exceptions (z. B. PocketBase `ClientException`) sehr lange Objekte ausgeben.
- Stacktraces dominieren die Ausgabe und erschweren schnelles Scannen nach Status / Operation / UUID.
- Für Analyse und Support ist die Ausgabe zwar vollständig, aber die Signalqualität (Was ist wirklich passiert?) ist zu niedrig.

**Ziel**
Kurze, strukturierte 1-Zeilen-Summaries pro Sync-Operation (Push/Pull/Images), die auf Mobile sofort erfassbar sind — **ohne** mit `docs/LOGGER.md` zu kollidieren.

**Abgrenzung zu `docs/LOGGER.md`**
- Dieser Punkt *ergänzt* `LOGGER.md`, ersetzt sie nicht.
- `logger.e(…, error: e, stackTrace: st)` bei kritischen Fehlern bleibt erhalten (konform zu `LOGGER.md`).
- Zusätzlich wird eine kurze Summary-Line (`logger.w` / `logger.i`) vorangestellt, damit das wichtigste Signal auf Mobile sofort sichtbar ist.
- Neue Log-Events werden in `LOGGER.md` referenziert (Tabelle „Definierte Log-Events"), nicht ersetzt.

**Vorgeschlagenes Summary-Format**
```
SYNC|PUSH|CREATE  fail  uuid=<uuid>  status=400  msg="Failed to create record"
SYNC|PUSH|UPDATE  ok    uuid=<uuid>
SYNC|PULL         fail  status=503   msg="..."
SYNC|IMAGES       ok    downloaded=3  skipped=1  failed=0
```
Details (Exception + Stacktrace) folgen weiterhin als `logger.e`-Eintrag.

**Tasks**
- [ ] `docs/LOGGER.md`: Summary-Format / neue Events als eigenen Abschnitt ergänzen (nur Doku-Änderung, kein Code).
- [ ] `PocketBaseSyncService`: bei Push/Pull/Images zentrale Summary-Logs ergänzen (z. B. `SYNC|PUSH|CREATE fail uuid=... status=400 msg=...`).
- [ ] `SyncOrchestrator` / `ArtikelDbService`: Timeout- und DB-Fehler ebenfalls mit Summary-Line versehen.
- [ ] Optional: „Verbose Logs"-Flag in den Settings prüfen, um Stacktraces nur bei Bedarf dauerhaft einzublenden (Release-freundlich).
- [ ] Dokumentieren, dass Summary-Logs für mobile Lesbarkeit gedacht sind; Details bleiben für forensische Analyse erhalten.

**Nicht-Ziel**
- Keine Änderung am bestehenden Logger-Framework (`AppLogService`) notwendig.
- Keine Entfernung von `error` / `stackTrace` bei kritischen Fehlern (konform zu `docs/LOGGER.md`).


### P-004: Android Kamera-Test abschließen
**Beschreibung:** Android ist aktuell „Build stabil, Kamera-Test ausstehend“.

**Details**
- [ ] Vollständige manuelle Tests der Kamerafunktionalität auf verschiedenen Android-Geräten
- [ ] Prüfen, ob Bilder korrekt aufgenommen, zugeschnitten und hochgeladen werden
- [ ] Ggf. automatisierte Testabdeckung ergänzen


### M-013: Bild-Reset („Bild leeren“) ermöglichen
**Beschreibung:**  
Derzeit lässt sich bei einem bestehenden Artikel kein Bild mehr vollständig entfernen.  
• Setzt der Nutzer `bildPfad = ''`, wird zwar lokal kein Bild mehr angezeigt, beim nächsten Sync bleibt die Datei jedoch weiterhin in PocketBase gespeichert.  
• Ebenso bleibt `remoteBildPfad` erhalten, sodass ein Pull das alte Bild sofort wiederherstellen würde.  
Ziel ist ein konsistenter „Bild leeren“-Workflow, der sowohl lokal als auch remote wirklich entfernt.

**Tasks (Entwurf)**  
1. UI/UX  
   - Im Detail-Screen klaren „Bild entfernen“-Button ergänzen (Icon 🗑️ oder Kontextmenü).  
   - Bestätigungs-Dialog („Bild wirklich löschen?“) zur Vermeidung von Fehlklicks.  
2. Modell / DB  
   - `bildPfad` in DB auf leeren String setzen.  
   - `remoteBildPfad` = `null` markieren, damit Pull nicht erneut lädt.  
3. Sync-Service (`PocketBaseSyncService`)  
   - Beim Push eines Artikels mit leerem `bildPfad` UND vorhandenem Remote-Bild →  
     a) PATCH `body['bild'] = null` senden, um File-Feld in PocketBase zu löschen.  
     b) `remoteBildPfad` lokal in `markSynced()`/`upsert` als `null` persistieren.  
   - Beim Pull: Wenn Remote `bild`-Feld leer ist, sicherstellen, dass lokal ebenfalls `bildPfad = ''` + `remoteBildPfad = null` stehen.  
4. Tests  
   - Unit-Tests für Push-Delete-Pfad (Update mit `body['bild'] = null`).  
   - Pull-Tests: Remote-Bild entfernt → lokale Datei wird gelöscht & DB-Felder geleert.  
   - Widget-Test: Button-Flow im Detail-Screen (Dialog, State-Update, Snackbar).  
5. Optionales Cleanup  
   - Lokale Datei beim „Bild leeren“ auch physisch löschen (Cache-Pfad).  
   - Alte Bild-Versionen in PocketBase evtl. via Cloud-Funktion endgültig löschen.

**Abhängigkeiten:**  
– Keine Blocker, aber greift in bestehende Sync-Hardening-Pfade ein → sorgfältig testen.  
– Ggf. Koordination mit `downloadMissingImages()`-Logik, damit gelöschte Bilder nicht versehentlich neu geladen werden.

- [x] Artikel-Modell und Persistenz für `bildPfad = ''` / `remoteBildPfad = null`
- [x] Sync-Service (`PocketBaseSyncService`) – Push-Delete-Pfad & Pull-Cleanup
- [ ] UI/UX „Bild entfernen“-Button + Bestätigungsdialog
- [ ] Unit- und Widget-Tests für Button-Flow & Delete-Pfad
- [ ] Optionales lokales File-Cleanup (Cache)

---

## 🟢 Priorität: Nice-to-Have

### F-008: Hintergrund-Sync-Intervall konfigurierbar machen
**Beschreibung:** Derzeit ist das automatische Sync-Intervall hart auf 15 Minuten eingestellt.  
Der Nutzer soll im Einstellungs-Screen ein Intervall (1 / 5 / 15 Minuten oder „Nur manuell“) wählen können.  
Wert wird persistiert (`SharedPreferences.sync_interval_seconds`) und vom `SyncScheduler` gelesen. Änderungen greifen ohne App-Neustart.

**Tasks**
- [ ] Settings-UI: Dropdown / Slider mit 1, 5, 15 Min, Aus
- [ ] Neuer/erweiterter `SyncScheduler` oder Refactor von `_startPeriodicSync()`
- [ ] Persistenz in SharedPreferences
- [ ] Unit-Tests: Scheduler startet/aktualisiert Timer korrekt
- [ ] Widget-Test: UI-Einstellung speichert und reflektiert Wert

**Abhängigkeiten:** none  

---

## ⏭️ Future (nicht in Planung)

### H-001: iOS/macOS Vorbereitung
Erfordert Apple Developer Account. Zurückgestellt bis Account verfügbar.

### N-006: Nextcloud-Workflow
WebDAV-Anbindung finalisieren und mit Nextcloud 28+ testen.

---

## 📊 Fortschritts-Übersicht

| Priorität | Gesamt | Erledigt | Offen |
|---|---:|---:|---:|
| ✅ Abgeschlossen | 57 | 51 | 0 |
| 🔴 Hoch | 0 | 0 | 0 |
| 🟡 Mittel | 4 | 0 | 4 |
| 🟢 Nice-to-Have | 1 | 0 | 1 |
| ⏭️ Future | 2 | 0 | 2 |
| **Gesamt** | **65** | **49** | **7** |

---

## ✅ Abgeschlossen

> **Hinweis:** Details zu den abgeschlossenen Punkten stehen in `HISTORY.md`.  
> Hier bleiben sie als kompakter Überblick mit Versionsbezug erhalten.


### B-013: image upload flow, remoteBildPfad support & ghost-file cleanup - erledigt in `v0.9.4+36`
BREAKING: markSynced() signature extended (remoteBildPfad)

#### ✨ Features
* B-013 – PocketBaseSyncService
  * `_buildFiles()` helper + `package:path/path.dart`
  * Upload Multipart-Image in CREATE/UPDATE (skip on Web / 0-byte / identical)
* ArtikelDbService
  * `markSynced(uuid, etag, {remotePath, remoteBildPfad})`
  * `clearBildInfoByUuidSilent(uuid)` – löscht bildPfad & remoteBildPfad ohne Dirty-Flag
* Pull-Pfad entfernt lokale Bildinfos, wenn Remote-Bildfeld leer ist

#### 🛠 Fixes / Refactor
* `_needsConflictBecauseMissingBase()` erwartet jetzt (Artikel lokal, RecordModel remote)
  und nutzt `_extractRecordEtag(remote)` – alle Aufrufe angepasst
* Ghost-Files & schnelle Bildwechsel: Sync hält remoteBildPfad sofort aktuell
* Duplicate-UUID-/Conflict-Pfad unverändert funktionsfähig

#### 🧪 Tests
* `pocketbase_sync_service_upload_test.dart` – verifiziert Image-Multipart bei CREATE/UPDATE
* Bestehende Tests auf neue Signaturen & ISO-Timestamps umgestellt
* Mockito-Mocks per `build_runner` neu generiert
* 692 Tests grün (+3 bewusst skipped)

#### 📚 Docs
* Master-Prompt aktualisiert:
  * neue Methode `clearBildInfoByUuidSilent()`
  * markSynced-Signatur + remote_bild_pfad in DB-Spaltenliste
  * Invariant: remote_bild_pfad nur serverseitig gesetzt/überschrieben
* CHANGELOG-Eintrag B-013 vorbereitet

#### 🔧 Chore
* `flutter analyze` ohne Findings
* Skip-Tests geprüft (bewusst deaktiviert)

Refs #B-013

--- 

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

### B-010: Snackbar-Feedback in Artikelliste fehlt — erledigt in `v0.9.0+25`
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

### B-009: Artikelliste — Ort-Dropdown hardcodiert und falsch platziert — erledigt in `v0.9.0+25`
**Typ:** Bug / Regression (B-007-Commit)  
**Betrifft:** `lib/screens/artikel_list_screen.dart` → AppBar `actions`

Der Ort-Filter-Dropdown wurde als Test-Stub mit hardcodierten Werten
(`Lager 1`, `Lager 2`, `Büro`) in die AppBar `actions` eingefügt.
Er liest keine echten Daten aus `_artikelListe` und ist falsch
platziert (AppBar statt Body/Filter-Leiste).

- Dropdown aus AppBar `actions` entfernen
- Echte Ort-Werte dynamisch aus `_artikelListe` ableiten (distinct, alphabetisch sortiert, „Alle“ als erster Eintrag)
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
- **Smart Sync**: `PocketBaseSyncService` vergleicht nun Datei-Zeitstempel mit PocketBase-Updates
- **Cleanup**: Automatisches Löschen alter Bildversionen im Dateisystem bei Namensänderung
- **UI-Kontrast**: „Letzter Sync“-Zeitstempel auf `onSurface` (Bold) umgestellt für maximale Lesbarkeit

### B-003 bis B-006: Sync-Stabilität — erledigt in `v0.8.5+19`
- ETag-basierte Konflikt-Erkennung vor PATCH
- Korrektur der Bild-Download-Skip-Logik
- Navigator-Init via GlobalKey gefixt

### B-001: Settings-Änderungen werden ohne Speichern übernommen — verifiziert in `v0.8.3+16`
- Dirty-Tracking, Save-Button und Unsaved-Dialog analysiert
- Ergebnis: Verhalten war bereits korrekt implementiert, kein Fix nötig

### B-002: Biometrische Authentifizierung — System-Dialog & Verfügbarkeitsprüfung — abgeschlossen in `v0.8.3+16`
- Nativer System-Dialog bestätigt
- Verfügbarkeitsprüfung vor Aktivierung bestätigt
- Toggle wird nur bei erfolgreicher Probe-Authentifizierung persistiert

---

### F-007: Einstellung — Letzter-Sync-Zeitstempel ein-/ausblenden — erledigt in `v0.9.0+25`, Architektur-Bereinigung in `v0.9.1+29`
**Typ:** Feature  
**Betrifft:** `lib/screens/settings_screen.dart`,
`lib/screens/artikel_list_screen.dart`,
`lib/screens/settings_state.dart`

Toggle in den Einstellungen, der den Sync-Zeitstempel in der
Artikelliste ein- oder ausblendet. Persistenz via SharedPreferences.

- Toggle in den Einstellungen ergänzt
- SharedPreferences-Key: `show_last_sync`
- Reaktive Wirkung ohne App-Neustart via `ValueNotifier<bool>`
- Default fachlich konsistent auf `true` vereinheitlicht
- `showLastSyncNotifier`, Prefs-Key und Default in
  `settings_state.dart` zentralisiert
- `ArtikelListScreen` bezieht den gemeinsamen State nicht mehr aus
  `settings_screen.dart`

F-007 — Hotfix in `v0.9.0+25`:
- `ValueListenableBuilder` in `ArtikelListScreen` ergänzt; Toggle war
  zuvor funktionslos, da der Notifier nie abgehört wurde

F-007 — Architektur-Bereinigung in `v0.9.1+29`:
- `showLastSyncNotifier` aus `settings_screen.dart` herausgelöst
- zentrale, UI-neutrale Datei `settings_state.dart` eingeführt
- gemeinsame State-Abhängigkeit vom Screen entkoppelt

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
- Nextcloud-Status-Icon Farbe angepasst
- Detail-Screen Felder leserlicher (`OutlineInputBorder`)

### F-001 & F-002: Security — erledigt in `v0.8.2+13`
- Biometrische Authentifizierung und konfigurierbare Sperrzeit

### F-003: Artikeldetailansicht — Ort & Fach nebeneinander — erledigt in `v0.8.0+8`
- `Row` mit zwei `Expanded`-Kindern
- Neuer Token `detailFieldSpacing`
- Responsive und Dark-Mode-kompatibel

---

### H-002 & H-003: Infrastruktur — erledigt in `v0.7.1` bis `v0.7.4`
- CORS-Konfiguration und Backup-Automatisierung (Docker)

---

### K-007: Flutter update — erledigt in `v0.9.1+26`
Flutter/Dart:
- Flutter: 3.41.4 → 3.41.7
- Dart: 3.11.1 → 3.11.5

Package Major Updates (`pubspec.yaml`):
- `csv`: ^6.0.0 → ^8.0.0 (`rowSeparator` statt `eol`)
- `device_info_plus`: ^10.1.2 → ^12.4.0
- `file_picker`: ^10.1.0 → ^11.0.2
- `flutter_local_notifications`: ^19.4.1 → ^21.0.0
- `share_plus`: ^10.1.4 → ^12.0.2 (`shareXFiles` statt `shareFiles`)
- `build_runner`: ^2.4.6 → ^2.14.0

Removed:
- `js`: ^0.7.1 (discontinued, ersetzt durch `dart:js_interop` via `web:`)
- `dependency_overrides`-Block (nicht mehr nötig)

CI/CD:
- `flutter-version`: 3.41.4 → 3.41.7 in allen 4 Workflows

Verified: `flutter analyze` clean, spätere Folgearbeiten bis `v0.9.1+29`
auf insgesamt **626 Tests**, **3 übersprungen** erweitert

### K-006: Kaltstart-Bug Fix — erledigt in `v0.8.0`
- Sync-UI-Kopplung und automatischer Bild-Download nach Erst-Setup

### K-001 bis K-005: Fundament — erledigt in `v0.2.0` bis `v0.7.1`
- Bundle IDs, PocketBase Schema, Runtime-URL-Config, WSL2-Support

---

### M-002 bis M-006: Core-Features — erledigt in `v0.7.6+x`
- Zentrales Error Handling, Loading States, Pagination und Input Validation

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
- Neues App-Icon und Native Splash Screen für alle Plattformen

---

### O-011: `AppLockService` testbarer machen
**Typ:** Optimierung / Testbarkeit  
**Betrifft:** `lib/services/app_lock_service.dart`

**Problem**
`AppLockService` ist eng an Singleton-, Persistenz- und Plattformlogik
gekoppelt. Dadurch sind isolierte Tests für App-Lock-Verhalten und
Settings-nahe Lade-/Speicherpfade nur eingeschränkt möglich.

**Ziel**
App-Lock-Verhalten fachlich besser testbar machen, ohne die bestehende
Runtime-API unnötig zu verkomplizieren.

**Mögliche Umsetzung**
- Interface oder abstrahierte Auth-/Storage-Grenzen einführen
- Test-Hooks oder gezielte Overrides für Persistenz/Auth erlauben
- App-Lock-Lade-/Speicherpfade ohne echte Plattformabhängigkeit testbar machen

--- 

### O-010: `SettingsScreen` — Logik in testbaren Controller extrahieren — erledigt in `v0.9.1+29`
**Typ:** Refactoring / Testbarkeit  
**Betrifft:** `lib/screens/settings_screen.dart`,
`lib/screens/settings_controller.dart`,
`lib/screens/settings_state.dart`

`SettingsScreen` wurde fachlich sauber und minimal-invasiv refactored.
Persistente Settings-Logik, Laufzeit-State und Service-Orchestrierung
wurden in einen neuen `SettingsController` ausgelagert.

**Umsetzung**
- `settings_controller.dart` eingeführt
- `SettingsScreen` auf UI-nahe Verantwortung reduziert:
  - Dialoge
  - SnackBars
  - Navigation / Logout-Handling
  - Rendering
- In den Controller verschoben:
  - Laden und Speichern der Settings
  - Dirty-Tracking
  - PocketBase-URL prüfen / speichern / zurücksetzen
  - DB-Status prüfen
  - App-Lock-Status laden / speichern
- `TextEditingController` bewusst pragmatisch im Controller belassen
  (`artikelNummerController`, `pocketBaseUrlController`)

**Testauswirkung**
- `SettingsController` gezielt testbar gemacht
- zusätzliche Tests für Save-/Reset-/Dirty-State-Verhalten ergänzt
- Reject-/Success-Pfade von `saveSettings()` abgesichert

--- 

### T-010: Sync-Hardening für Konfliktbasis, Duplicate-UUID-Recovery, useRemote-Baseline und pending-resolution-Flows — erledigt in `fix/sync-hardening2-v0.9.4`
**Typ:** Testausbau / Sync-Hardening / Konfliktlogik  
**Betrifft:**  
`lib/services/pocketbase_sync_service.dart`,  
`lib/services/conflict_resolution_utils.dart`,  
`lib/main.dart`,  
`test/services/pocketbase_sync_service_test.dart`,  
`test/services/pocketbase_sync_service_conflict_test.dart`,  
`test/services/conflict_resolution_utils_test.dart`,  
`test/screens/conflict_resolution_screen_test.dart`,  
`docs/LOGGER.md`,  
PocketBase-Schema / Admin-Konfiguration (`uuid` als `required` + `unique`)

Die PocketBase-Synchronisation und die Konfliktauflösung wurden in mehreren realen Fehler- und Randfällen gezielt gehärtet.

**Abgedeckte fachliche Verbesserungen**
- Unsichere Fälle ohne stabile Konfliktbasis (`last_synced_etag`) werden konservativ als Konflikt behandelt
- Das gilt für Push-Update, Push-Delete und Pull
- Bewusste Ausnahmen über `pendingResolution = force_local | force_merge` bleiben möglich
- Duplicate-UUID-Race-Conditions beim Remote-Create werden erkannt und über Recovery-Lookup per `uuid` aufgelöst
- Recovery-Erfolg und Recovery-Fehler sind im Log nachvollziehbar dokumentiert
- Die useRemote-Baseline wurde in eine Utility ausgelagert und akzeptiert nur noch belastbare Remote-Baselines
- Der PocketBase-Conflict-Adapter erfüllt das erwartete Interface explizit und analyzer-konform
- UI-Fehlerpfade im `ConflictResolutionScreen` wurden abgesichert (Snackbar, kein versehentliches Schließen)
- Übersprungene Konflikte erscheinen beim nächsten Sync erneut
- Pull überschreibt Datensätze mit `force_local` oder `force_merge` nicht
- Soft-Delete lokal + Remote-Edit wird als Konflikt behandelt
- Remote-Delete-Cleanup ist gegen dirty/pending Datensätze abgesichert
- Lokales Cleanup erfolgt nur für saubere Datensätze nach plausiblem/validem Pull
- Erfolgreiche `force_local`-/`force_merge`-Pushes laufen korrekt über den `markSynced()`-Pfad und bereinigen `pendingResolution` auf Contract-Ebene

**Qualitätsstatus**
- `flutter analyze` grün
- `flutter test` grün

**Hinweis**
Die Bereinigung von `pendingResolution` erfolgt nicht direkt im `PocketBaseSyncService`, sondern über den Contract von `markSynced()` in der DB-Schicht. Die Tests bilden dieses Zusammenspiel nun service-nah ab.

---

### T-009: Ergänzende Tests für `SettingsController` und settings-nahe Persistenzpfade — erledigt in `v0.9.2+32`
**Typ:** Testausbau  
**Betrifft:** `lib/screens/settings_controller.dart`,
`lib/screens/settings_state.dart`

Nach O-010 wurden verbleibende Rand- und Fehlerpfade der
Settings-Logik gezielt durch Unit-Tests abgesichert.

**Abgedeckte Bereiche**
- `saveSettings()`-Fehlerpfad (`SaveSettingsResult.error`)
- Default-Verhalten für `showLastSync`, wenn keine Pref gesetzt ist
- zusätzliche Persistenztests für settings-nahe Werte
- verbleibende Save-/Reset-/Dirty-State-Pfade im Controller konsolidiert abgesichert

**Ergebnis**
- `test/services/settings_controller_test.dart` auf **15 Tests** erweitert
- Settings-nahe Persistenzpfade jetzt gezielt und isoliert testbar
- O-010 fachlich sauber ergänzt und testseitig abgerundet

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

### T-008: ETag-Konflikt-Logik und `downloadMissingImages`-Check-Logik — abgeschlossen in `v0.8.5+19`
- `pocketbase_sync_service_conflict_test.dart` — 11 Tests ✅
- `sync_orchestrator_test.dart` — 9 Tests (erweitert) ✅
- ETag-Grenzwerte, ConflictCallback-Typedef, SyncStatus-Enum abgedeckt ✅
- Gesamtstand: **625 Tests**, 28 Dateien ✅

### T-003 bis T-007: Test-Offensive — erledigt in `v0.8.1+10`
- Unit-Tests für `NextcloudClient`, `MergeDialog`, `AttachmentService`, `BackupStatusService`
- Performance-Test self-contained; `flutter test` läuft ohne manuelle Vorbereitung

---

## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
| 2026-04-18 | v0.9.4+36 | B-013 abgeschlossen: image upload flow, `remoteBildPfad` |
| 2026-04-27 | fix/sync-hardening2-v0.9.4 | T-010 abgeschlossen: Sync-Hardening für Konfliktbasis, Duplicate-UUID-Recovery, useRemote-Baseline und pending-resolution-Flows konsolidiert. Konfliktfälle ohne `last_synced_etag` werden konservativ behandelt, Duplicate-UUID-Recovery inkl. Logging gehärtet, useRemote-Baseline ausgelagert und validiert, UI-Fehlerpfad im `ConflictResolutionScreen` abgesichert sowie service-nahe Tests für Skip-/Force-/Delete-Guards und `markSynced()`-basierte Bereinigung von `pendingResolution` ergänzt. Teststand: 691 Tests grün, 3 übersprungen. |
| 2026-04-23 | v0.9.2+32 | T-009 und O-011 abgeschlossen: ergänzende Tests für `SettingsController` und settings-nahe Persistenzpfade nachgezogen; zugleich `AppLockService` testbarer gemacht, sodass App-Lock-nahe Lade-/Speicherpfade und fachliche Timeout-/State-Logik nun isolierter testbar sind. |
| 2026-04-23 | v0.9.1+29 | O-010 abgeschlossen: `SettingsScreen` fachlich minimal-invasiv in `SettingsController` refactored, UI-/Logik-Trennung verbessert, zusätzliche Controller-Tests ergänzt. F-007 architektonisch bereinigt: `showLastSyncNotifier`, Prefs-Key und Default nach `settings_state.dart` verschoben, Default konsistent auf `true` vereinheitlicht. Teststand auf 626 bestanden, 3 übersprungen aktualisiert. |
| 2026-04-22 | v0.9.1+26 | K-007: Flutter upgrade 3.41.4 → 3.41.7 + package major updates |
| 2026-04-22 | v0.9.0+25 | B-008 abgeschlossen: Card-Layout `ArtikelListScreen` wiederhergestellt (Artikelnummer, Chips, Feldname-Fix). B-009 abgeschlossen: Ort-Dropdown dynamisch aus Artikelliste, in Body integriert, Reset-Button. B-010 abgeschlossen: Snackbar-Feedback bei Sync-Start/-Erfolg/-Fehler. B-011 abgeschlossen: App-Version zeigt korrekten Build-Stand nach neuem Release-Build. B-012 abgeschlossen: Sync-Label `TextOverflow.ellipsis` + `titleSpacing`. F-006 abgeschlossen: Log-Level-Filter als `DropdownButton<Level>`, Default `Level.error`. F-007 abgeschlossen: Sync-Zeitstempel-Toggle via `ValueNotifier` + `SharedPreferences`. O-009 abgeschlossen: 15 Widget-Tests `ArtikelListScreen` grün (625 Tests gesamt). |
| 2026-04-21 | v0.8.9+24 | B-007 abgeschlossen: Intelligenter Bild-Sync (Timestamp-Check) und UI-Politur des Sync-Zeitstempels implementiert. |
| 2026-04-20 | v0.8.6+21 | P-003 abgeschlossen: Bild-Caching via `cached_network_image` integriert. Android-Stabilität auf S20 verifiziert. |
| 2026-04-20 | v0.8.4+20 | Dokumente aktualisiert |
| 2026-04-17 | v0.8.5+19 | B-003 abgeschlossen: `downloadMissingImages` Skip-Logik korrigiert. B-004 abgeschlossen: Konflikt-Callback via `GlobalKey` + `addPostFrameCallback`. B-005 abgeschlossen: ETag-Konflikt-Erkennung vor PATCH. B-006 abgeschlossen: `SyncManagementScreen` auf `SyncOrchestrator` umgestellt. T-008 abgeschlossen: 20 neue Tests (610 gesamt, 28 Dateien). |
| 2026-04-14 | v0.8.4+17 | N-003: App-Icon + N-005: Native Splash Screen als erledigt markiert |
| 2026-04-14 | v0.8.4+17 | F-004 abgeschlossen: NC-Icon auf `statusColorConnected` umgestellt. F-005 abgeschlossen: Detail-Screen Readonly-Felder mit `OutlineInputBorder` + `InputDecorator`, Menge/Artikelnummer als eigene Felder, `+/-` Buttons nur im Edit-Modus, 3 Widget-Tests angepasst |
| 2026-04-14 | v0.8.3+16 | B-001 abgeschlossen: Settings-Save-Verhalten analysiert — Dirty-Tracking, Save-Button und Unsaved-Dialog waren bereits korrekt implementiert. B-002 abgeschlossen: Biometrie-Analyse — automatischer Auth-Start, `FragmentActivity`, Verfügbarkeitsprüfung vor Toggle-Aktivierung bestätigt. OPT-001 neu: `SettingsController`-Extraktion für Testbarkeit |
| 2026-04-13 | v0.8.2+13 | F-001 + F-002 abgeschlossen: App-Lock mit biometrischer Authentifizierung und konfigurierbarer Sperrzeit |
| 2026-04-13 | v0.8.1+12 | T-003 abgeschlossen: 39 Unit-Tests `NextcloudClient` |
| 2026-04-13 | v0.8.1+11 | T-004 abgeschlossen: 18 Widget-Tests `MergeDialog`. O-008 abgeschlossen: `spacingSectionGap`-Token, 3 Stellen ersetzt |
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