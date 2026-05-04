# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Arbeitsübersicht über **aktuellen Projektstatus**, **offene Aufgaben**, **Prioritäten** und **technische Optimierungen** der **Lager_app**.

**Version:** 0.9.4+48 | **Zuletzt aktualisiert:** 04.05.2026

> **Hinweis:**  
> Diese `OPTIMIZATIONS.md` ist das **laufende Arbeitsdokument** für Status, Prioritäten und Roadmap.  
> Wenn eine Maßnahme **abgeschlossen, historisch relevant und versioniert** ist, wird sie in `HISTORY.md` überführt.  
> Dadurch bleiben Status-Dokument und Historie sauber getrennt und vermeiden unnötige Dopplungen.

> **Technische Referenz für Sync-Details:**  
> Für Push/Pull, Konflikterkennung, Bild-Sync, Invarianten, Edge Cases und Änderungsverbote gilt primär **`docs/SYNC.md`**.

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
- `B-016`, `F-011`, `H-004`, `K-008`, `M-014`, `N-007`, `O-013`, `P-006`, `T-012`

### Vergaberegel
Ein Kürzel gilt **ab dem ersten dokumentierten Auftreten als dauerhaft reserviert** —  
auch dann, wenn der Punkt später verschoben, umbenannt oder nach `Future` verschoben wird.

---

## 🔴 Priorität: Hoch

---

## 🟡 Priorität: Mittel

### P-004: Android Kamera-Test abschließen
**Beschreibung:** Android ist aktuell „Build stabil, Kamera-Test ausstehend“.

**Details**
- [ ] Vollständige manuelle Tests der Kamerafunktionalität auf verschiedenen Android-Geräten
- [ ] Prüfen, ob Bilder korrekt aufgenommen, zugeschnitten und hochgeladen werden
- [ ] Ggf. automatisierte Testabdeckung ergänzen

--- 


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

### F-010: Nutzerfreundliche Aktivitäts-Logs (UserLogService)
**Beschreibung:**  
Neben den bestehenden technischen Entwickler-Logs (AppLogService) soll eine zweite, menschenlesbare Log-Ebene eingeführt werden. Diese zeigt dem Nutzer verständliche Aktivitätsmeldungen wie „Artikel ‚LED Strip 5m' erstellt und synchronisiert", „Synchronisation abgeschlossen — 3 aktualisiert" oder „Verbindung zum Server verloren" statt technischer Debug-Ausgaben mit UUIDs und ETags.

**Abgrenzung zu O-012:**  
O-012 (Entwickler-Summary-Logs) bleibt unverändert bestehen. F-010 ist eine eigenständige, nutzerseitige Funktion.

**Design-Entscheidungen**
- Eigener `UserLogService` mit eigenem Datenmodell (`UserLogEntry`), getrennt von `AppLogService`
- Viewer als eigener Dialog, erreichbar über den Settings-Screen
- Umschaltung zwischen Entwickler-Log und Nutzer-Log per Einstellung im Settings-Screen
- Sprache: Deutsch, aber lokalisierbar vorbereitet (Nachrichtentexte über Hilfsmethoden oder einfache l10n-Abstraktion, kein volles ARB/intl erforderlich)
- Keine Feldänderungs-Diffs — geloggt wird auf Artikelebene (erstellt / geändert / gelöscht / synchronisiert), nicht auf Feldebene
- Persistenz über App-Neustart hinweg (SQLite-Tabelle `user_log`)
- Automatisches Löschen von Einträgen älter als X Tage (konfigurierbar, Default z. B. 14 Tage), Cleanup beim App-Start oder vor dem Anzeigen

**Geplante Nutzer-Log-Quellen**
- `PocketBaseSyncService` — Push-Ergebnisse (CREATE/UPDATE/DELETE ok/fail), Pull-Zusammenfassung, Verbindungsfehler
- `SyncOrchestrator` — Sync gestartet / abgeschlossen / fehlgeschlagen
- `main.dart` — Login / Logout
- Optional später: Artikel-Erfassung, Einstellungsänderungen

**Tasks**
- [ ] `UserLogEntry`-Modell mit `timestamp`, `level`, `message`
- [ ] `UserLogService` mit SQLite-Persistenz (`user_log`-Tabelle)
- [ ] Auto-Cleanup: Einträge älter als X Tage beim Start löschen
- [ ] DB-Migration für `user_log`-Tabelle
- [ ] Nutzer-Log-Aufrufe in `PocketBaseSyncService` (neben bestehenden technischen Logs)
- [ ] Nutzer-Log-Aufrufe in `SyncOrchestrator`
- [ ] Nutzer-Log-Aufrufe in `main.dart` (Auth-Events)
- [ ] Viewer-Dialog (`UserLogDialog`) mit Level-Filter und Löschen-Button
- [ ] Settings-Screen: Umschaltung Entwickler-Log / Nutzer-Log
- [ ] Lokalisierbare Nachrichtentexte vorbereiten
- [ ] Unit-Tests für `UserLogService` (CRUD, Cleanup, Kapazitätsgrenze)
- [ ] Widget-Test für Viewer-Dialog
- [ ] `docs/LOGGER.md` um Nutzer-Log-Konzept ergänzen

**Aufwandsschätzung:** ~5–6 Stunden

**Abhängigkeiten:**  
Keine Blocker. Greift nicht in bestehende Sync-Logik ein — nur additive Log-Aufrufe neben den bestehenden technischen Logs.

---

## ⏭️ Future (nicht in Planung)

### H-001: iOS/macOS Vorbereitung
Erfordert Apple Developer Account. Zurückgestellt bis Account verfügbar.

### N-006: Nextcloud-Workflow
WebDAV-Anbindung finalisieren und mit Nextcloud 28+ testen.

---

## 📊 Fortschritts-Übersicht

Die Priorisierung in diesem Dokument ist maßgeblich, die Zählwerte sind jedoch nur dann belastbar, wenn sie aktiv mitgepflegt werden.  
Im Zweifel gilt der inhaltliche Status der einzelnen Punkte über den numerischen Summen.

**Aktuell besonders relevante offene Themen**
- optionaler Realtest für den engeren technischen Duplicate-UUID-Recovery-Fallback
- Android-Kamera-Verifikation
- konfigurierbares Sync-Intervall

---

## ✅ Abgeschlossen

> **Hinweis:** Details zu den abgeschlossenen Punkten stehen in `HISTORY.md`.  
> Hier bleiben sie als kompakter Überblick mit Versionsbezug erhalten.

### F-009: Kategorie-Eingabe in der Artikel-UX — abgeschlossen 2026-05-04 | `0.9.4+49`

**Priorität:** Niedrig
**Branch:** fix/sync-hardening2-v0.9.4 (nach Merge: main)
**Entdeckt bei:** B-001 / B-002

### Problem
Die technische Basis für `kategorie` ist inzwischen im Modell, Mapping, Persistenz- und Sync-Pfad vorhanden.  
Offen ist — falls im aktuellen UI-Stand noch nicht umgesetzt — die vollständige und nutzerfreundliche Eingabe bzw. Bearbeitung in der Artikel-UX.

### Gewünschtes Verhalten
- Artikel-Formular enthält ein klar sichtbares Kategorie-Feld (Freitext oder Dropdown)
- Wert lässt sich beim Erstellen und Bearbeiten eines Artikels setzen
- Wert wird lokal persistiert und im Sync korrekt an PocketBase übertragen

### Akzeptanzkriterium
Die Kategorie ist im relevanten Artikel-UI-Flow vollständig nutzbar und die reale End-to-End-Übertragung ist bestätigt.

### Ergebnis
Kategorie-Feld (`String?`) in Erfassen- und Detail-Screen ergänzt (Freitext, `prefixIcon: category_outlined`, max 50 Zeichen). Listenansicht zeigt Kategorie als Chip. Kategorie-Filter als zweites Dropdown neben dem Ort-Filter (`Row` mit zwei `Expanded`, UND-verknüpft). Filter-Werte werden dynamisch aus der Artikelliste abgeleitet (`_aktualisiereFilter()`). `AppConfig.inputMaxLengthKategorie` ergänzt. Keine Änderungen an Modell, DB-Schema oder Sync nötig — technische Basis war bereits vorhanden. Verifiziert auf A515F + S20, PocketBase E2E bestätigt.

--- 

### T-001: Konfliktlösung, Sync-Hardening und Integrationsverifikation (M-007) — abgeschlossen 2026-05-04 | `0.9.4+48`

**Status:** abgeschlossen ✅

Umfassende Absicherung der Konflikt- und Sync-Pipeline durch service-nahe Tests,
manuelle Integrationstests auf echten Geräten gegen PocketBase und gezielte Hardening-Maßnahmen.

**Technische Basis, Hardening und service-nahe Tests**
- [x] T-001.1 — `ConflictData`: Konstruktor, Felder, Null-Handling
- [x] T-001.2 — `ConflictResolution` Enum: Alle Werte, `byName`, Index
- [x] T-001.3 — `SyncService.detectConflicts()`: Mock-Daten, ETag-Abweichung erkennen
- [x] T-001.4 — `SyncService._determineConflictReason()`: Alle Zeitstempel-Szenarien
- [x] T-001.5 — `ConflictResolutionScreen`: Widget-Tests mit `SyncService`-Mock
- [x] T-001.10 — „Überspringen" → Konflikt bleibt, erscheint beim nächsten Sync erneut
- [x] T-001.12 — Edge Case: Soft-Delete lokal + Edit remote → Konflikt korrekt erkannt
- [x] T-001.13 — Pull überschreibt `force_local`-Datensatz nicht mit Remote-Version
- [x] T-001.14 — Pull überschreibt `force_merge`-Datensatz nicht mit Remote-Version
- [x] T-001.16 — Erfolgreicher `force_local`-Push bereinigt `pendingResolution`
- [x] T-001.17 — Erfolgreicher `force_merge`-Push bereinigt `pendingResolution`
- [x] UI-Fehlerpfad bei Konfliktauflösung bleibt stabil (Snackbar, kein Pop)
- [x] Remote-Delete-Guards für dirty/pending/clean service-nah abgesichert
- [x] Produktive Konfliktlogik für `pendingResolution`, `force_local`, `force_merge`, Skip, Delete-vs-Edit, Remote-Delete-Guards und `useRemote`-Baseline gehärtet
- [x] Duplicate-UUID-Recovery beim Remote-Create service-nah abgesichert
- [x] `_PocketBaseConflictAdapter` interface-/analyzer-konform vervollständigt
- [x] `toPocketBaseMap()` sendet keine lokalen Sync-Metadaten mehr mit
- [x] `toPocketBaseMap()` sendet `erstelltAm` und `aktualisiertAm` als UTC-ISO-Strings
- [x] `artikelnummer` wird im PocketBase-Payload nur bei `>= 1` gesendet
- [x] Konflikt-Snapshot-Persistenz (`saveRemoteConflictSnapshot()` / `loadRemoteConflictSnapshot()`) service-nah abgesichert
- [x] Modelltests für relevante Sync-Felder sind weitgehend vorhanden
- [x] UTC-Inkonsistenzen im relevanten Modell-/DB-Bereich weitgehend bereinigt
- [x] Service-nähere Sync-/Integrationstests mit Fakes für Remote-Records und Persistenzpfade ergänzt

**Manuelle Integrations- und Feldtests**
- [x] T-001.6 — Artikel auf Gerät A ändern, offline auf Gerät B ändern → Sync → Konflikt-UI erscheint
- [x] T-001.7 — „Lokal behalten" → Server wird im Folgesync überschrieben
- [x] T-001.8 — „Server übernehmen" → Lokale Daten werden ersetzt
- [x] T-001.9 — „Zusammenführen" → fachlich bestätigt; Merge-Dialog und Feldauswahl funktionieren, Merge-Version wird im Folgesync korrekt gepusht; längere offene Konflikt-UI wird konfliktbewusst als Wartephase behandelt und führt nicht mehr zu einem falschen Orchestrator-Timeout
- [x] T-001.11 — Mehrere Konflikte gleichzeitig → sequentielle Bearbeitung im echten Sync-Lauf mit gemischten Entscheidungen (`skip`, `useRemote`, `useLocal`) erfolgreich bestätigt
- [x] T-001.18 — Reale UUID-Kollision „lokal offline neu erzeugt, vor erstem Sync gleicher Remote-Datensatz bereits vorhanden" als konservativen Konfliktfall verifiziert
- [x] Manuell verifiziert: `force_local` überschreibt Remote-Datensatz nach Konfliktentscheidung korrekt
- [x] Manuell verifiziert: `force_merge` bleibt nach bestätigter Auflösung fachlich stabil; die frühere Timeout-Auffälligkeit während offener Konflikt-UI ist real nicht mehr reproduzierbar
- [x] Manuell verifiziert: übersprungene Konflikte erscheinen im UI beim nächsten Sync erneut
- [x] Manuell verifiziert: Soft-Delete lokal + Remote-Edit führt weiterhin reproduzierbar zur Konflikt-UI; Gegenprobe ohne Remote-Änderung löscht regulär ohne unnötigen Konflikt
- [x] Engerer technischer Duplicate-UUID-Recovery-Fallback im echten `create()`-Race: Ergebnis ist eine Konfliktmeldung — für dieses Projekt gewünschtes konservatives Verhalten

**Einordnung zu T-001.18**
Die reale UUID-Kollision „lokal offline neu erzeugt, vor dem ersten Sync gleicher Remote-Datensatz bereits vorhanden" wird im aktuellen Projekt nicht als stiller Auto-Recovery-Fall bewertet, sondern bewusst als konservativer Konfliktfall. Nach manueller Auflösung (`useLocal`) läuft der Folgesync erfolgreich weiter; es entstehen keine Dubletten und kein Retry-Loop. Der engere Duplicate-UUID-Recovery im `create()`-Catch bleibt davon als technischer Fallback unberührt.

**Verbleibende technische Restpunkte — alle abgeschlossen**
- [x] Artikel-Modell und Persistenz für `kategorie` vervollständigt
- [x] Konflikt-UI/Navigation in `main.dart` gegen parallele Mehrfachöffnung abgesichert
- [x] `test/services/artikel_db_service_test.dart`: Snapshot-Methoden gezielt ergänzt
- [x] `test/models/artikel_model_test.dart`: `toPocketBaseMap()` für Zeitstempel- und `artikelnummer`-Regeln ergänzt
- [x] `test/services/pocketbase_sync_service_test.dart`: `_extractBildName()` und `remoteBildPfad`-Persistenz service-nah ergänzt
- [x] Index-Namen in `DATABASE.md` und `ARCHITECTURE.md` gegen den echten SQLite-Code abgeglichen und vereinheitlicht
- [x] UUID-Format serverseitig per Pattern-Validierung in PocketBase abgesichert
- [x] UTC-Konsistenz in `artikel_db_service.dart` geprüft — alle Zeitstempel-Stellen durchgängig UTC, keine Inkonsistenzen
- [x] Zeitstempel-Semantik (`aktualisiertAm` vs. `updated_at` vs. PocketBase `updated`) in `docs/DATABASE.md` Abschnitt 1.1e dokumentiert

**Bewusst gestrichene Optional-Punkte**
Folgende Punkte wurden als „für dieses Projekt nicht benötigt" bewertet und bewusst nicht umgesetzt:
- Monitoring/Zähler für Duplicate-UUID-Recovery-Fallbacks im `create()`-Pfad — bestehende Sync-Logs reichen für Diagnose aus
- `etag`/`last_synced_etag`-Nutzung langfristig vereinfachen — funktioniert zuverlässig, ist in `docs/SYNC.md` konsolidiert dokumentiert, Vereinfachung birgt Regressionsrisiko ohne fachlichen Nutzen
- `ConflictCallback` semantisch verbessern (Entscheidungen direkt zurückgeben) — aktueller Callback funktioniert stabil, Umbau wäre reines Refactoring ohne fachlichen Gewinn
- Verbleibende Modelltests für zusätzliche Randfälle — Roundtrip, `copyWith()`-Null-Semantik und Sync-relevante Pfade sind bereits abgedeckt
- Konfliktauflösung über dediziertes Interface statt generischem `SyncService` entkoppeln — bei nur einem Sync-Backend kein Mehrwert
- Soft-Delete-/Delete-Abschlusslogik im Sync fachlich vereinfachen — funktioniert korrekt, ist getestet und manuell verifiziert, Refactoring-Risiko ohne akuten Bedarf

**Betroffene Dateien (Auswahl)**
- `lib/services/pocketbase_sync_service.dart`
- `lib/services/artikel_db_service.dart`
- `lib/services/sync_orchestrator.dart`
- `lib/services/conflict_resolution_utils.dart`
- `lib/models/artikel_model.dart`
- `lib/main.dart`
- `lib/screens/conflict_resolution_screen.dart`
- `test/services/pocketbase_sync_service_conflict_test.dart`
- `test/services/pocketbase_sync_service_test.dart`
- `test/services/sync_orchestrator_test.dart`
- `test/services/artikel_db_service_test.dart`
- `test/models/artikel_model_test.dart`
- `test/services/conflict_resolution_utils_test.dart`
- `docs/SYNC.md`
- `docs/DATABASE.md`
- `docs/ARCHITECTURE.md`

**Hinweis**
Die technische Konfliktlogik wurde mit `fix/sync-hardening2-v0.9.4` deutlich gehärtet und in mehreren realen Geräte-/Server-Läufen bestätigt. Die Bildpfad-bezogenen Response-/Persistenzpfade sind im service-nahen Sync-Test ergänzt, der Konfliktfall Soft-Delete lokal + Remote-Edit erneut manuell erfolgreich verifiziert und die UUID-Kollision fachlich als konservativer Konfliktfall eingeordnet.

Die technische Referenz für Sync-Regeln, Invarianten, Edge Cases und Änderungsverbote ist:
- `docs/SYNC.md`

`FakeArtikelDbService` wurde um `saveRemoteConflictSnapshot()` / `loadRemoteConflictSnapshot()` erweitert — die Fake-Infrastruktur ist damit vollständig für die Snapshot-Pfade. Zusätzlich sind Snapshot-Persistenz in `ArtikelDbService`, Zeitstempel-/`artikelnummer`-Regeln in `Artikel.toPocketBaseMap()` sowie `_extractBildName()` / `remoteBildPfad` im service-nahen Sync-Test explizit regressionssicher abgesichert.

--- 

## — M-013: fix: Bild entfernen 2026-05-04 | `v0.9.4+47` 

- **Detail-Screen: Bild nach Entfernen sofort ausgeblendet**
  `ArtikelDetailBild` erhielt bisher das unveränderte `widget.artikel`-Objekt,
  das noch `remoteBildPfad` und `bildPfad` enthielt. Nach „Bild entfernen"
  wurde deshalb das Remote-Bild per PB-Fallback weiterhin angezeigt, bis
  gespeichert und zurücknavigiert wurde.
  → Fix: `artikel.copyWith(...)` mit aktuellem Bild-State an das Widget
  übergeben. Placeholder erscheint jetzt sofort nach dem Entfernen.

- **Listenansicht: 404-Log nach Bild-Entfernung eliminiert**
  Nach `Navigator.pop()` versuchte `CachedNetworkImage` in der Listenansicht
  noch die alte Remote-URL aus dem Cache zu laden → 404.
  → Fix: `CachedNetworkImage.evictFromCache()` wird in `_speichernMobile()`
  aufgerufen, bevor `clearBildInfoByUuidSilent()` die DB-Felder leert.

### Technische Details
- Kein Einfluss auf Sync-Verhalten (Cache-Eviction ist rein clientseitig)
- Kein zusätzlicher API-Call nötig (`_remoteBildUrl` aus State wiederverwendet)
- 754 Tests grün, `flutter analyze` sauber

### M-013: Bild-Reset („Bild leeren") ermöglichen — abgeschlossen 2026-05-04 | `0.9.4+46`
**Status:** abgeschlossen ✅

**Beschreibung:**
Derzeit lässt sich bei einem bestehenden Artikel kein Bild mehr vollständig entfernen.
• Setzt der Nutzer `bildPfad = ''`, wird zwar lokal kein Bild mehr angezeigt, beim nächsten Sync bleibt die Datei jedoch weiterhin in PocketBase gespeichert.
• Ebenso bleibt `remoteBildPfad` erhalten, sodass ein Pull das alte Bild sofort wiederherstellen würde.
Ziel ist ein konsistenter „Bild leeren"-Workflow, der sowohl lokal als auch remote wirklich entfernt.

**Umsetzung:**

1. **UI/UX — Kontextsensitives BottomSheet (Option B)**
   - AppBar: Zwei Bild-Buttons (📷 Kamera + 🖼 Datei) durch einen einzigen kontextsensitiven Button ersetzt.
   - Kein Bild vorhanden → Icon `add_photo_alternate`, Tooltip „Bild hinzufügen".
   - Bild vorhanden → Icon `image`, Tooltip „Bild ändern".
   - Tap öffnet BottomSheet mit allen verfügbaren Aktionen:
     - 🖼 Aus Datei wählen
     - 📷 Kamera (wenn verfügbar)
     - ✂ Zuschneiden (wenn `_pendingBytes` oder lokales Bild vorhanden)
     - 🗑 Bild entfernen (rot, mit Divider — nur wenn Bild vorhanden)
   - Bestätigungsdialog bei „Bild entfernen" (Sheet schließt erst, dann Dialog).
   - Erfassungs-Screen: Einfacher „Entfernen"-Button neben Crop (nur RAM-Cleanup).

2. **Modell / DB**
   - `bildPfad` in DB auf leeren String gesetzt.
   - `remoteBildPfad` = `null` markiert via `clearBildInfoByUuidSilent()`.
   - Artikel als dirty markiert via `markAsModified()` → Sync-Push wird ausgelöst.

3. **Sync-Service (`PocketBaseSyncService`)**
   - Push: Artikel mit leerem `bildPfad` + vorhandenem Remote-Bild → `body['bild'] = null` gesendet.
   - Pull: Remote `bild`-Feld leer → `clearBildInfoByUuidSilent()` lokal aufgerufen.
   - `downloadMissingImages()` überspringt Artikel ohne Remote-Bild korrekt.

4. **Lokales File-Cleanup**
   - Bilddatei und Thumbnail werden beim Entfernen physisch gelöscht.
   - Image-Cache wird invalidiert.
   - Platform-Helper `deleteFileIfExists()` in `detail_screen_io.dart` / `_stub.dart`.

5. **Crop-Erweiterung**
   - Zuschneiden funktioniert jetzt auch für bestehende lokale Bilder (nicht nur `_pendingBytes`).
   - Bytes werden bei Bedarf aus der lokalen Datei geladen → Crop-Dialog → `_pendingBytes` aktualisiert.

6. **Tests**
   - Widget-Tests angepasst: Neue Tooltips (`Bild hinzufügen` / `Bild ändern`), View-Modus-Prüfung.
   - 24/24 Tests grün, `flutter analyze` sauber.

**Betroffene Dateien:**

| Datei | Änderung |
|---|---|
| `artikel_detail_screen.dart` | `_hatBild`, `_showBildOptionen()`, `_cropImageFromAny()`, `_bildEntfernen()`, `_deleteLocalImageFiles()`, AppBar 2→1 Button, Body Crop-Block entfernt, `_speichernMobile()` + `_speichernWeb()` Bild-Entfernung |
| `artikel_erfassen_screen.dart` | „Entfernen"-Button neben Crop |
| `detail_screen_io.dart` | `deleteFileIfExists()` |
| `detail_screen_stub.dart` | `deleteFileIfExists()` No-op |
| `artikel_detail_screen_test.dart` | Tooltips angepasst |

**Abhängigkeiten:**
– Backend-Pfade (DB + Sync) waren bereits in v0.9.x umgesetzt.
– Keine Konflikte mit `downloadMissingImages()`-Logik.

- [x] Artikel-Modell und Persistenz für `bildPfad = ''` / `remoteBildPfad = null`
- [x] Sync-Service (`PocketBaseSyncService`) – Push-Delete-Pfad & Pull-Cleanup
- [x] UI/UX: Kontextsensitives BottomSheet (Hinzufügen/Ändern/Zuschneiden/Entfernen)
- [x] Bestätigungsdialog bei „Bild entfernen"
- [x] Lokales File-Cleanup (Bilddatei + Thumbnail physisch löschen)
- [x] Crop auch für bestehende lokale Bilder (nicht nur pendingBytes)
- [x] Widget-Tests angepasst (24/24 grün)
- [ ] Unit-Tests für Push-Delete-Pfad & Pull-Cleanup (ausstehend)

--- 

### O-012: Sync-Logs mobil-lesbar machen (Summary-Lines pro Operation) — abgeschlossen 2026-05-04 | `0.9.4+44`

Die Summary-Logs für Push/Pull/Orchestrator wurden produktiv eingeführt und in `docs/LOGGER.md` dokumentiert. Die mobilen 1-Zeilen-Zusammenfassungen gehören inzwischen zum produktiven Diagnosepfad.

**Umgesetzt**
- [x] strukturierte Summary-Lines für zentrale Sync-Phasen eingeführt
- [x] `docs/LOGGER.md` um relevante Sync-Log-Events ergänzt
- [x] Orchestrator-Fehler/Timeouts mit Phasenbezug geloggt
- [x] Detail-Logs mit `error` und `stackTrace` bleiben erhalten
- [x] Verbose-Flag (`AppConfig.verboseSync`) geprüft und bewusst verworfen — der bestehende Log-Level-Filter (F-006) deckt den Use Case ab; bei nur 4 `debug`-Level-Logs im Sync-Pfad wäre ein eigenes Flag toter Config-Code

--- 

### T-001.18: Reale UUID-Kollision als konservativer Konfliktfall verifiziert — abgeschlossen 2026-05-03 | `0.9.4+42`
**Beschreibung:**  
Die Konstellation „lokal offline neu erzeugter Artikel, vor dem ersten Sync gleicher Datensatz bereits remote mit identischer `uuid` vorhanden“ wurde real gegen PocketBase geprüft. Im produktiven Lauf wurde dieser Fall nicht als stiller Duplicate-UUID-Recovery-Create-Fall behandelt, sondern bewusst konservativ in die Konflikt-UI überführt.

**Abschlussstand:**  
Dieses Verhalten ist für das Projekt gewünscht und wird daher als fachlich korrekt bewertet. Nach manueller Auflösung mit `useLocal` wurde der bestehende Remote-Datensatz im Folgesync erfolgreich fortgeführt. Es entstanden keine Dubletten und kein Retry-Loop.

**Fachlicher Effekt:**
- bereits vor dem Push erkennbare UUID-Kollisionen mit lokaler fachlicher Neuanlage werden konservativ als Konflikt behandelt
- Konflikt-UI und manuelle Auflösung funktionieren in dieser Konstellation stabil
- der bestehende Remote-Datensatz wird im Folgesync korrekt aktualisiert
- kein Endlos-Retry, keine Dublette
- der engere technische Duplicate-UUID-Recovery-Fallback im `create()`-Pfad bleibt davon unberührt

**Tasks**
- [x] reale UUID-Kollision gegen echtes PocketBase reproduzieren
- [x] Laufverhalten per Logs und Remote-Record-Verlauf auswerten
- [x] gegen den aktuellen Produktivcode prüfen, ob Konflikt oder Auto-Recovery beabsichtigt ist
- [x] als gewünschtes konservatives Projektverhalten bewerten
- [x] Doku- und Statusbewertung entsprechend anpassen

### T-001 (Ergänzung): Bildpfad-Testlücke geschlossen und Delete-Konfliktfall erneut verifiziert — abgeschlossen 2026-05-03 | `0.9.4+41`

**Beschreibung:**  
Die service-nahe Testabdeckung für den PocketBase-Bildrückgabepfad wurde ergänzt. `_extractBildName()` und die Persistenz von `remoteBildPfad` nach CREATE/UPDATE sind nun für `List<String>`, `String`, `null` und leere Werte regressionssicher abgesichert. Zusätzlich wurde der Konfliktfall „lokaler Soft-Delete bei zwischenzeitlicher Remote-Änderung“ erneut manuell erfolgreich verifiziert; die Gegenprobe ohne Remote-Änderung löscht regulär ohne unnötigen Konflikt.

**Abschlussstand:**  
- `flutter test test/services/pocketbase_sync_service_test.dart` grün  
- `_extractBildName()` / `remoteBildPfad` service-nah ergänzt  
- M-004 manuell bestanden  
- Gegenprobe ebenfalls bestanden

**Tasks**
- [x] service-nahe Tests für `_extractBildName()` und `remoteBildPfad` ergänzen
- [x] CREATE-/UPDATE-Pfad im Test-Nachbau an produktiven Bildpfad angleichen
- [x] Soft-Delete lokal + Remote-Edit erneut manuell verifizieren
- [x] Gegenprobe ohne Remote-Änderung durchführen

--- 

### B-015: Orchestrator-Timeout während offener Konflikt-UI / Merge — abgeschlossen 2026-05-02 | `0.9.4+41`
**Beschreibung:**  
Bei längerer Benutzerinteraktion in der Konflikt-UI, insbesondere im Merge-Fall, lief `SyncOrchestrator.runOnce()` zuvor nach 5 Minuten in einen Timeout, obwohl die Konfliktauflösung kurz danach erfolgreich abgeschlossen wurde. Die Timeout-Behandlung ist jetzt konfliktbewusst umgesetzt: Solange aktiv auf Benutzerauflösung gewartet wird, wird die Phase nicht als hängender Sync-Lauf gewertet.

**Abschlussstand:**  
Die Lösung ist produktiv umgesetzt und per Verhaltenstests sowie realem Gerätelauf verifiziert. Während offener Konflikt-UI werden regelmäßige Wait-Logs geschrieben; nach Benutzerentscheidung läuft der Sync regulär weiter und endet erfolgreich. Echte technische Fehler (z. B. Netzwerk-/DNS-Fehler) werden weiterhin korrekt als Fehler behandelt.

**Tasks**
- [x] Timeout-Pfad im Zusammenspiel von `SyncOrchestrator`, Konflikt-Callback und UI-Wartezeit analysieren
- [x] minimal-invasive Lösung umsetzen, sodass Benutzerinteraktion nicht als hängender Sync-Lauf gewertet wird
- [x] Folge-Logs und Verhalten nach manueller Merge-Auflösung erneut real verifizieren
- [x] Testabdeckung in `test/services/sync_orchestrator_test.dart` ergänzen

### B-003 — remoteBildPfad nach CREATE/UPDATE in PocketBase schreiben — abgeschlossen 2026-04-30 | `0.9.4+39`
**Titel:** `remoteBildPfad` wird nach erfolgreichem Bild-Upload nicht in PocketBase zurückgeschrieben  
**Ziel:** Nach CREATE oder UPDATE mit Bild-Upload wird `remoteBildPfad` via Follow-up-PATCH korrekt in PocketBase persistiert, sodass andere Geräte das Bild via `downloadMissingImages()` abrufen können.

**Fachlicher Effekt:**
- `bild`-Feld in PocketBase enthält nach CREATE den von PocketBase generierten Dateinamen (z. B. `1016_g_c003_va6tqzgkk1.jpg`)
- `remoteBildPfad` wird unmittelbar nach dem Upload via Follow-up-PATCH in PocketBase gesetzt
- `downloadMissingImages()` erkennt das Bild auf anderen Geräten korrekt (`downloaded=1` statt `downloaded=0`)
- `setBildPfadByUuidSilent()` wird nach dem Pull korrekt aufgerufen — kein erneutes Dirty-Flag
- Das `updated`-Delta von 147ms zwischen `created` und `updated` im PocketBase-Record belegt den korrekten Follow-up-PATCH

**Verifikation (30.04.2026):**
- Log: `SYNC|PUSH|CREATE remoteBildPfad gesetzt uuid=1cdcc559 bild=1016_g_c003_va6tqzgkk1.jpg` ✅
- Log: `SYNC|PUSH|CREATE ok uuid=1cdcc559` ✅
- Log: `downloadMissingImages end downloaded=1, skipped=16, failed=0` ✅
- PocketBase-Record: `bild` = `remoteBildPfad` = `1016_g_c003_va6tqzgkk1.jpg` ✅
- `created: 11:34:14.380Z` / `updated: 11:34:14.527Z` → Δ = 147ms (Follow-up-PATCH) ✅

**Betroffene Dateien:**
- `lib/services/pocketbase_sync_service.dart` — Follow-up-PATCH nach CREATE/UPDATE mit `remoteBildPfad`
- `lib/services/artikel_db_service.dart` — `setBildPfadByUuidSilent()` im Pull-Pfad

--- 

### B-014 + O-012 (Anteil) — abgeschlossen 2026-04-29 | `0.9.4+37`
**Titel:** HTTP 400 CREATE-Fix, Push-Timeouts, markSynced-Spaltennamen-Fix, Summary-Logs
**Ziel:** Neue Datensätze werden korrekt zu PocketBase gepusht; hängende Push-Requests brechen nach 30s ab statt erst nach 60s Orchestrator-Timeout; remoteBildPfad wird nach erfolgreichem Sync korrekt persistiert; Sync-Phasen sind auf Mobile in einer Zeile lesbar

**Betroffene Dateien:**
- `lib/models/artikel_model.dart` — `toPocketBaseMap()` artikelnummer-Guard
- `lib/services/artikel_db_service.dart` — `markSynced()` Spaltennamen-Fix
- `lib/services/pocketbase_sync_service.dart` — Timeouts + Summary-Logs
- `lib/services/sync_orchestrator.dart` — Phase-Tracking + Summary-Log
- `docs/LOGGER.md` — neue Log-Events in Tabelle
- `PocketBase Admin` — `kategorie`-Feld in Collection `artikel` ergänzen

**Fachlicher Effekt:**
- HTTP 400 bei CREATE wird durch korrekten `artikelnummer`-Guard und vollständiges PocketBase-Schema behoben
- Pending-Datensätze werden nach erfolgreichem Push korrekt über `markSynced()` als synchronisiert markiert — `last_synced_etag` wird gesetzt
- `remoteBildPfad` wird nach CREATE/UPDATE erstmals korrekt in SQLite persistiert
- Einzelne hängende Push-Requests blockieren den Sync-Lauf nicht mehr länger als 30s
- T-001.6 kann nach diesen Fixes sinnvoll ausgeführt werden

**Offene Punkte:**
- PocketBase Admin: `kategorie`-Feld manuell ergänzen

--- 

### B-013: image upload flow, remoteBildPfad support & ghost-file cleanup — abgeschlossen 2026-04-28 | `0.9.4+36`

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

### K-007: Flutter update — abgeschlossen 2026-04-22 | `0.9.1+26`
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

--- 

### T-009: Ergänzende Tests für `SettingsController` und settings-nahe Persistenzpfade — abgeschlossen 2026-04-23 | `0.9.2+32`
**Typ:** Testausbau  
**Betrifft:** `lib/screens/settings_controller.dart`, `lib/screens/settings_state.dart`

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

## In History überführt

---

### O-010: `SettingsScreen` — Logik in testbaren Controller extrahieren — abgeschlossen 2026-04-23 | `0.9.1+29`
Settings-Logik (Laden/Speichern, Dirty-Tracking, PB-URL, DB-Status, App-Lock) in neuen `SettingsController` extrahiert. `SettingsScreen` auf UI-Verantwortung reduziert (Dialoge, SnackBars, Navigation, Rendering). `TextEditingController` bewusst pragmatisch im Controller belassen. Controller gezielt testbar gemacht, Save-/Reset-/Dirty-State- und Reject-/Success-Pfade abgesichert.

---

### F-007: Einstellung — Letzter-Sync-Zeitstempel ein-/ausblenden — abgeschlossen 2026-04-23 | `0.9.1+29`
Toggle in den Einstellungen zum Ein-/Ausblenden des Sync-Zeitstempels in der Artikelliste. Persistenz via `SharedPreferences` (`show_last_sync`), reaktiv via `ValueNotifier<bool>`, Default `true`. Hotfix `v0.9.0+25`: `ValueListenableBuilder` ergänzt (Toggle war zuvor funktionslos). Architektur-Bereinigung `v0.9.1+29`: State in `settings_state.dart` zentralisiert, Screen-Abhängigkeit entkoppelt.

---

### O-009: Widget-Tests `ArtikelListScreen` — abgeschlossen 2026-04-22 | `0.9.0+25`
Import-Pfad, Pflichtfelder (`erstelltAm`/`aktualisiertAm`) und Suchfeld-Label (`'Suche…'`) korrigiert. `_pumpScreenWithArtikel()`-Helper ergänzt. 15 Widget-Tests grün. Gesamtstand: **625 Tests**, 28 Dateien.

---

### F-006: Log-Level-Filter als Dropdown statt Button-Reihe — abgeschlossen 2026-04-22 | `0.9.0+25`
Log-Level-Button-Reihe (Trace–Fatal) passte auf schmalen Displays (360dp) nicht in eine Zeile. Ersetzt durch `DropdownButton<Level>` mit Default `Level.error`. Auf S20 verifiziert.

---

### B-012: Letzter-Sync-Zeitstempel auf schmalen Displays abgeschnitten — abgeschlossen 2026-04-22 | `0.9.0+25`
Sync-Label in AppBar konkurrierte auf 360dp mit Action-Icons. Fix: `TextOverflow.ellipsis` und `Flexible`-Wrapper ergänzt. Auf S20 verifiziert.

---

### B-011: App-Version zeigt veralteten Build-Stand — abgeschlossen 2026-04-22 | `0.9.0+25`
Kein Code-Fehler — `_getAppVersion()` via `PackageInfo.fromPlatform()` korrekt implementiert. Ursache: veraltete APK installiert (kein Build nach Version-Bump). Nach Neuinstallation korrekte Version bestätigt.

---

### B-010: Snackbar-Feedback in Artikelliste fehlt — abgeschlossen 2026-04-22 | `0.9.0+25`
Nach Sync-Erfolg/-Fehler fehlte Snackbar-Feedback (Regression aus B-007). Snackbar bei Sync-Start, -Erfolg und -Fehler in `ArtikelListScreen` ergänzt. 


## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
| 2026-05-04 | 0.9.4+49 | F-009 umgesetzt: Kategorie-Feld in Erfassen/Detail/Liste, Kategorie-Filter neben Ort-Filter, Chip in Listenansicht. |
| 2026-05-04 | 0.9.4+48 | T-001 abgeschlossen: Konfliktlösung, Sync-Hardening und Integrationsverifikation vollständig abgehakt. UUID-Pattern serverseitig abgesichert, UTC-Konsistenz geprüft (sauber), Zeitstempel-Semantik in DATABASE.md dokumentiert, verbleibende Optional-Punkte bewusst als „nicht benötigt" gestrichen. |
| 2026-05-04 | 0.9.4+46 | M-013 abgeschlossen: Bild-Reset („Bild leeren") ermöglichen |
| 2026-05-04 | 0.9.4+44 | O-012 abgeschlossen: Verbose-Flag geprüft und bewusst verworfen — Log-Level-Filter (F-006) deckt den Use Case ab. |
| 2026-05-03 | 0.9.4+43 | Sync-Dokumentation konsolidiert: `docs/SYNC.md` als technische Referenz für Push/Pull, Konflikterkennung, Edge Cases, Invarianten und Änderungsverbote ergänzt; `prompt.txt` als allgemeiner Arbeitskontext erweitert. |
| 2026-05-03 | 0.9.4+43 | `ARCHITECTURE.md` und `DATABASE.md` gegen den aktuellen SQLite-/Sync-Stand konsolidiert; Indexnamen gegen den echten Code verifiziert und vereinheitlicht. |
| 2026-05-03 | 0.9.4+42 | E-001 real eingeordnet: Die Konstellation „lokal offline neu erzeugt, vor erstem Sync gleicher Remote-Datensatz bereits vorhanden“ wird nun fachlich als gewünschter konservativer Konfliktfall bewertet. Nach manueller Auflösung (`useLocal`) erfolgreicher Folgesync ohne Dublette oder Retry-Loop. |
| 2026-05-03 | 0.9.4+41 | T-001 weiter konsolidiert: `_extractBildName()` / `remoteBildPfad` service-nah testseitig ergänzt; M-004 erneut manuell verifiziert inklusive erfolgreicher Gegenprobe ohne Remote-Änderung. |
| 2026-05-02 | 0.9.4+41 | T-011 abgeschlossen: Snapshot-Persistenz in `ArtikelDbService` sowie Zeitstempel- und `artikelnummer`-Regeln in `Artikel.toPocketBaseMap()` testseitig regressionssicher ergänzt. DB-Testisolation für Singleton/In-Memory-Setup stabilisiert. Teststand: 707 Tests grün, 3 übersprungen. |
| 2026-05-02 | 0.9.4+41 | B-015 weiter eingegrenzt: konfliktbewusste Timeout-Semantik des Orchestrators ist jetzt per Verhaltenstests abgesichert; offen bleibt die produktive UX-/Ablaufbehandlung längerer Merge-Interaktion. |
| 2026-04-30 | 0.9.4+41 | T-001 manuell weiter bestätigt: `useLocal`, `useRemote`, `skip` und Mehrfachkonflikte im echten Geräte-/Server-Lauf verifiziert. Gemischte Auflösungen (`skip`, `useRemote`, `useLocal`) funktionieren sequentiell; nur übersprungene Konflikte erscheinen im Folgesync erneut. Merge fachlich bestätigt, aber mit bekanntem Orchestrator-Timeout-Befund bei längerer UI-Interaktion. |
| 2026-04-30 | 0.9.4+39 | B-003 abgeschlossen: `remoteBildPfad` wird nach CREATE/UPDATE via Follow-up-PATCH korrekt in PocketBase geschrieben. Verifikation via Flutter-Logs (SYNC\|PUSH\|CREATE ok, downloaded=1) und PocketBase-Record-Inspektion (Δ created→updated = 147ms). |
| 2026-04-29 | 0.9.4+37 | fix/sync-hardening2-v0.9.4(B-014): HTTP 400 CREATE, Push-Timeouts, markSynced-Spaltenname, Summary-Logs |
| 2026-04-28 | 0.9.4+36 | fix/sync-hardening2-v0.9.4 B-013 abgeschlossen: image upload flow, `remoteBildPfad` |
| 2026-04-23 | 0.9.2+32 | T-009 und O-011 abgeschlossen: ergänzende Tests für `SettingsController` und settings-nahe Persistenzpfade nachgezogen; zugleich `AppLockService` testbarer gemacht, sodass App-Lock-nahe Lade-/Speicherpfade und fachliche Timeout-/State-Logik nun isolierter testbar sind. |
| 2026-04-23 | 0.9.1+29 | O-010 abgeschlossen: `SettingsScreen` fachlich minimal-invasiv in `SettingsController` refactored, UI-/Logik-Trennung verbessert, zusätzliche Controller-Tests ergänzt. F-007 architektonisch bereinigt: `showLastSyncNotifier`, Prefs-Key und Default nach `settings_state.dart` verschoben, Default konsistent auf `true` vereinheitlicht. Teststand auf 626 bestanden, 3 übersprungen aktualisiert. |
| 2026-04-22 | 0.9.1+26 | K-007: Flutter upgrade 3.41.4 → 3.41.7 + package major updates |
| 2026-04-22 | 0.9.0+25 | B-008 abgeschlossen: Card-Layout `ArtikelListScreen` wiederhergestellt (Artikelnummer, Chips, Feldname-Fix). B-009 abgeschlossen: Ort-Dropdown dynamisch aus Artikelliste, in Body integriert, Reset-Button. B-010 abgeschlossen: Snackbar-Feedback bei Sync-Start/-Erfolg/-Fehler. B-011 abgeschlossen: App-Version zeigt korrekten Build-Stand nach neuem Release-Build. B-012 abgeschlossen: Sync-Label `TextOverflow.ellipsis` + `titleSpacing`. F-006 abgeschlossen: Log-Level-Filter als `DropdownButton<Level>`, Default `Level.error`. F-007 abgeschlossen: Sync-Zeitstempel-Toggle via `ValueNotifier` + `SharedPreferences`. O-009 abgeschlossen: 15 Widget-Tests `ArtikelListScreen` grün (625 Tests gesamt). |
| 2026-04-21 | 0.8.9+24 | B-007 abgeschlossen: Intelligenter Bild-Sync (Timestamp-Check) und UI-Politur des Sync-Zeitstempels implementiert. |
| 2026-04-20 | 0.8.6+21 | P-003 abgeschlossen: Bild-Caching via `cached_network_image` integriert. Android-Stabilität auf S20 verifiziert. |
| 2026-04-17 | 0.8.5+19 | B-003 abgeschlossen: `downloadMissingImages` Skip-Logik korrigiert. B-004 abgeschlossen: Konflikt-Callback via `GlobalKey` + `addPostFrameCallback`. B-005 abgeschlossen: ETag-Konflikt-Erkennung vor PATCH. B-006 abgeschlossen: `SyncManagementScreen` auf `SyncOrchestrator` umgestellt. T-008 abgeschlossen: 20 neue Tests (610 gesamt, 28 Dateien). |
| 2026-04-14 | 0.8.4+17 | N-003: App-Icon + N-005: Native Splash Screen als erledigt markiert |
| 2026-04-14 | 0.8.4+17 | F-004 abgeschlossen: NC-Icon auf `statusColorConnected` umgestellt. F-005 abgeschlossen: Detail-Screen Readonly-Felder mit `OutlineInputBorder` + `InputDecorator`, Menge/Artikelnummer als eigene Felder, `+/-` Buttons nur im Edit-Modus, 3 Widget-Tests angepasst |
| 2026-04-14 | 0.8.3+16 | B-001 abgeschlossen: Settings-Save-Verhalten analysiert — Dirty-Tracking, Save-Button und Unsaved-Dialog waren bereits korrekt implementiert. B-002 abgeschlossen: Biometrie-Analyse — automatischer Auth-Start, `FragmentActivity`, Verfügbarkeitsprüfung vor Toggle-Aktivierung bestätigt. OPT-001 neu: `SettingsController`-Extraktion für Testbarkeit |
| 2026-04-13 | 0.8.2+13 | F-001 + F-002 abgeschlossen: App-Lock mit biometrischer Authentifizierung und konfigurierbarer Sperrzeit |
| 2026-04-13 | 0.8.1+12 | T-003 abgeschlossen: 39 Unit-Tests `NextcloudClient` |
| 2026-04-13 | 0.8.1+11 | T-004 abgeschlossen: 18 Widget-Tests `MergeDialog`. O-008 abgeschlossen: `spacingSectionGap`-Token, 3 Stellen ersetzt |
| 2026-04-13 | 0.8.1+10 | T-005 abgeschlossen: 34 Tests `AttachmentService` |
| 2026-04-13 | 0.8.0+8 | F-003: Artikeldetailansicht — Ort & Fach nebeneinander |
| 2026-04-13 | 0.8.0+7 | O-007 abgeschlossen: 15 Tests `ImagePickerService` |
| 2026-04-13 | 0.8.0+7 | T-006 abgeschlossen: `BackupStatusService` formal abgenommen |
| 2026-04-13 | 0.8.0+6 | T-007 abgeschlossen: Performance-Test self-contained |
| 2026-04-13 | 0.8.0+5 | P-005 als erledigt markiert: Ziel-Versionen bereits in `pubspec.yaml`, `connectivity_plus`-Migration umgesetzt |
| 2026-04-12 | 0.8.0+5 | T-002 abgeschlossen: 17 Unit-Tests `PocketBaseSyncService` |

---

[Zurück zur README](../README.md) | [Zur HISTORY](../HISTORY.md) | [Zum Changelog](../CHANGELOG.md)