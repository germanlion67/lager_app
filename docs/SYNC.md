# 🔄 Sync-Architektur der Lager_app

Dieses Dokument beschreibt die aktuelle Synchronisationslogik der **Lager_app** mit **PocketBase**.  
Es ist die fachlich-technische Referenz für Push, Pull, Konflikterkennung, Konfliktauflösung, Bild-Sync, Timeout-Verhalten und die wichtigsten Invarianten.

Für allgemeine Projektinformationen siehe:
- `prompt.txt`
- `docs/ARCHITECTURE.md`
- `docs/DATABASE.md`
- `docs/LOGGER.md`
- `docs/TESTING.md`
- `docs/OPTIMIZATIONS.md`

---

# 1. Ziel und Grundprinzip

Die App verfolgt ein **Offline-First-Modell**:

- Artikel werden lokal in SQLite gespeichert
- Änderungen können offline entstehen
- ein späterer Sync gleicht lokale und Remote-Daten mit PocketBase ab
- Konflikte werden erkannt statt still überschrieben
- Bilder werden getrennt von der Kernobjekt-Synchronisation behandelt

## Grundsatz
Die Synchronisation soll:
- **lokale Arbeit nicht verlieren**
- **Remote-Änderungen nicht blind überschreiben**
- **bewusste Nutzerentscheidungen respektieren**
- **bei Konflikten konservativ reagieren**
- **nachvollziehbar loggen**
- **testbar bleiben**

---

# 2. Beteiligte Komponenten

## Produktiv relevante Bausteine

### `PocketBaseSyncService`
Verantwortlich für:
- Push lokaler Änderungen nach PocketBase
- Pull von Remote-Datensätzen
- Konflikterkennung auf Datensatzebene
- Bild-Upload bei Create/Update
- Bild-Download für fehlende lokale Bilder
- Snapshot-Speicherung bei Pull-Konflikten
- Recovery bei Create-Races

### `SyncOrchestrator`
Verantwortlich für:
- serielle Ausführung von Sync-Läufen
- Status-Stream für UI
- Timeout-Steuerung
- konfliktbewusste Wartebehandlung
- Bild-Download-Phase nach Kernsync

### `ArtikelDbService`
Verantwortlich für:
- lokale Persistenz
- Pending-Änderungen
- lokale Sync-Metadaten
- Konflikt-Snapshots
- stille Bildpfad-Updates
- Soft-Delete / Löschlogik

### `PocketBaseService`
Verantwortlich für:
- Client-Initialisierung
- Authentifizierung
- URL-/Client-Verfügbarkeit
- Health-Checks

### `main.dart`
Verantwortlich für:
- Initialisierung
- Orchestrator-Aufbau
- Konflikt-Callback-Registrierung
- Konflikt-UI-Navigation
- periodischen Sync
- App-Lifecycle-Kopplung

### `ConflictResolutionScreen`
Verantwortlich für:
- Nutzerentscheidung bei Konflikten
- Auswahl von `useLocal`, `useRemote`, `merge`, `skip`

### `conflict_resolution_utils.dart`
Verantwortlich für:
- Baseline-Schutz bei `useRemote`

---

# 3. High-Level-Ablauf eines Sync-Laufs

Ein normaler produktiver Sync-Lauf sieht aktuell so aus:

1. `SyncOrchestrator.runOnce()`
2. `PocketBaseSyncService.syncOnce()`
3. Push lokaler Änderungen
4. Pull von Remote-Daten
5. lokales `setLastSyncTime()`
6. zurück zum Orchestrator
7. Nachladen fehlender Bilder
8. Status `success` oder `error`
9. nach kurzer Verzögerung Rückkehr zu `idle`

## Wichtige Eigenschaft
Die Bild-Phase ist **nachgelagert**.  
Kernobjekt-Sync und Bild-Download sind also getrennte Phasen.

---

# 4. Sync-Statusmodell

`SyncOrchestrator` verwendet aktuell:

- `idle`
- `running`
- `success`
- `error`

Diese Zustände werden über `SyncStatusProvider` als Stream verfügbar gemacht.

## Typischer UI-Zweck
Die UI kann damit:
- laufenden Sync anzeigen
- Erfolg visualisieren
- Fehlerzustände signalisieren
- nach Erfolg Inhalte neu laden

---

# 5. Guards und Laufzeit-Schutz

## Im Orchestrator
`SyncOrchestrator.runOnce()` schützt gegen:
- Web-Ausführung
- Ausführung nach `dispose()`
- parallele Sync-Läufe

Wenn bereits ein Sync aktiv ist, wird der zweite Aufruf übersprungen.

## In `main.dart`
Zusätzliche Guards schützen gegen:
- doppelte Konflikt-Callback-Registrierung
- mehrere gleichzeitige Konflikt-Screens
- mehrfachen Konflikttrigger für dieselbe UUID

## Ziel
Diese Guards verhindern:
- Race Conditions
- doppelte UI
- inkonsistente Konfliktzustände
- reentrante Sync-Läufe

---

# 6. Push-Phase

## Quelle der Push-Phase
Die Push-Phase verarbeitet:
- `await _db.getPendingChanges()`

Das sind lokale Datensätze mit noch nicht abgeschlossenem Remote-Abgleich.

## Verarbeitete Fälle
Für jeden pending Artikel wird geprüft:

1. existiert ein Remote-Record mit derselben UUID?
2. ist der Artikel soft-deleted?
3. liegt ein Konflikt vor?
4. ist ein Force-Status gesetzt?
5. ist CREATE, UPDATE oder DELETE nötig?

---

## 6.1 UUID-Matching
Remote-Datensätze werden über die Artikel-UUID gesucht.

Die UUID wird für den Filter sanitisiert:
- Anführungszeichen werden entfernt

Beispiel:
```text
uuid = "abc-123"
```

---

## 6.2 Dirty-Zustand
Aktuell gilt ein Artikel als **dirty**, wenn:

- `etag` leer oder nicht gesetzt ist

Kurzform:

- `etag == null` oder leer → lokal nicht sauber synchronisiert

---

## 6.3 Pending-Resolution
Ein gesetztes `pendingResolution` markiert eine bewusste oder noch offene Konfliktentscheidung.

Relevante Werte:
- `force_local`
- `force_merge`

Diese Werte beeinflussen das Konfliktverhalten aktiv.

---

## 6.4 Force-Zustände
### `force_local`
Bedeutet:
- die lokale Version soll bewusst Remote überschreiben

### `force_merge`
Bedeutet:
- eine gemergte lokale Version soll bewusst Remote überschreiben

In beiden Fällen werden bestimmte Konfliktprüfungen absichtlich übersprungen.

---

## 6.5 ETag-/Baseline-Prinzip
Für Konfliktentscheidungen sind besonders wichtig:
- `etag`
- `lastSyncedEtag`

### Bedeutung
- `etag`: aktueller lokaler Synchronisationsmarker
- `lastSyncedEtag`: letzte belastbare gemeinsame Baseline mit Remote

### Grundidee
Wenn Remote sich seit `lastSyncedEtag` verändert hat und lokal ebenfalls Änderungen vorliegen, ist ein Konflikt wahrscheinlich.

---

## 6.6 Konflikt wegen fehlender Baseline
Die Funktion `_needsConflictBecauseMissingBase(...)` behandelt den Fall, dass keine belastbare Baseline vorliegt.

### Verhalten
Wenn **kein Force-Zustand** vorliegt:
- ist `lastSyncedEtag` vorhanden, wird es gegen Remote-Etag verglichen
- fehlt `lastSyncedEtag`, wird konservativ ein Konflikt angenommen, außer:
  - lokales `etag` entspricht zufällig dem Remote-Etag

### Konsequenz
Fehlende Baseline wird bewusst **konservativ** behandelt.

Das schützt vor:
- blindem Überschreiben
- Scheinsynchronität
- Verlust von Remote-Änderungen

---

## 6.7 Konflikt wegen Remote-Änderung seit letzter Synchronisation
Zusätzlich wird geprüft, ob Remote sich seit `lastSyncedEtag` verändert hat.

Wenn gilt:
- kein Force-Zustand
- `lastSyncedEtag` vorhanden
- Remote-Etag ungleich `lastSyncedEtag`

dann liegt ein Konflikt vor.

---

## 6.8 Push-Fall: DELETE
Wenn `artikel.deleted == true`:

### Fall A: Remote existiert nicht mehr
- lokal wird direkt als `deleted` markiert
- kein Remote-Delete nötig

### Fall B: Remote existiert
Dann wird geprüft:
- fehlt belastbare Baseline?
- hat sich Remote seit letzter Baseline geändert?

Wenn ja:
- Konflikt statt Löschung

Wenn nein:
- Remote-Record wird gelöscht
- lokal wird als `deleted` markiert

### Wichtige fachliche Regel
**Lokal löschen + Remote zwischenzeitlich geändert = Konflikt, nicht blind löschen**

---

## 6.9 Push-Fall: UPDATE
Wenn Remote-Record existiert und der lokale Datensatz nicht delete-markiert ist:

1. Konfliktprüfung
2. bei Konflikt: kein Update
3. sonst:
   - Body aus `artikel.toPocketBaseMap()`
   - ggf. `owner` setzen
   - ggf. Bild-Upload anhängen
   - ggf. `bild = null` setzen, wenn lokal kein Bild mehr vorhanden ist
   - Remote aktualisieren
   - lokalen Datensatz als synchron markierten Stand speichern

---

## 6.10 Push-Fall: CREATE
Wenn kein Remote-Record existiert:

1. Body aus lokalem Artikel erzeugen
2. ggf. `owner` setzen
3. ggf. Bilddatei anhängen
4. Create gegen PocketBase
5. Ergebnis-Etag extrahieren
6. lokal als synchron markieren

---

# 7. Create-Recovery bei Race Conditions

## Problem
Ein Create kann auf Serverseite erfolgreich gewesen sein, aber lokal trotzdem als Fehler erscheinen, z. B. bei:
- Antwort-Timeout
- Duplicate-UUID-Rennen

## Produktives Verhalten
Der Service versucht Recovery bei:
- `TimeoutException`
- Duplicate-UUID-/Unique-Constraint-Fehlern

## Ablauf
1. Create liefert keinen sauberen Erfolg
2. Service erkennt Timeout oder Duplicate-UUID-Signal
3. Remote-Lookup per UUID
4. wenn Remote-Record inzwischen existiert:
   - lokaler Datensatz wird an Remote angehängt
   - `markSynced(...)`
5. wenn kein Remote-Record gefunden wird:
   - echter Fehler bleibt bestehen

## Ziel
Vermeidung von:
- Doppel-Create
- inkonsistentem Wiederholen
- fälschlichem dauerhaften Pending-Zustand nach erfolgreichem Server-Create

---

# 8. Pull-Phase

## Quelle
Die Pull-Phase lädt:
- `getFullList()` aus PocketBase

Für jeden Remote-Record wird:
1. ein `Artikel` erzeugt
2. lokaler Datensatz per UUID gesucht
3. über Konflikt, Skip oder Upsert entschieden

---

## 8.1 Remote → lokal
Ein Remote-Record wird lokal per `upsertArtikel(...)` übernommen, wenn:
- kein schützender lokaler Dirty-Zustand entgegensteht
- keine Pending-Resolution aktiv ist
- kein Konflikt erkannt wird

---

## 8.2 Pull schützt lokale Dirty-Datensätze
Wenn lokal ein dirty Datensatz existiert:
- darf Pull ihn nicht blind überschreiben

Es werden unterschieden:
- dirty + Konflikt
- dirty ohne Konflikt
- dirty + pendingResolution

### Verhalten
- **kein automatisches Upsert**
- je nach Fall Konflikt-Snapshot oder bloßes Skip

---

## 8.3 Pull respektiert `pendingResolution`
Wenn lokal `pendingResolution` gesetzt ist:
- Pull überschreibt den Datensatz nicht
- insbesondere `force_local` und `force_merge` bleiben geschützt

Das verhindert, dass eine bewusste Nutzerentscheidung sofort wieder durch Remote verdrängt wird.

---

## 8.4 Pull-Konflikte
Wenn lokal dirty und gleichzeitig:
- Baseline fehlt oder
- Remote seit letzter Baseline geändert wurde

liegt ein Pull-Konflikt vor.

## Produktiv wichtig
Im produktiven `PocketBaseSyncService` wird beim Pull-Konflikt **kein Konflikt-Callback direkt ausgelöst**.

Stattdessen wird:
- ein Remote-Konflikt-Snapshot gespeichert

### Grund
Die Konflikt-UI soll nicht sowohl aus Push als auch aus Pull gleichzeitig getriggert werden.  
Die eigentliche UI-Auslösung erfolgt kontrolliert über den Push-/Orchestrator-/Main-Flow.

---

## 8.5 Pull-Snapshot-Verhalten
Bei erkanntem Pull-Konflikt wird der Remote-Stand lokal gespeichert:
- inklusive Bildinformation, falls vorhanden

Das erlaubt später:
- eine korrekte Konfliktanzeige
- Anzeige der tatsächlichen Remote-Version
- konsistente Bilddarstellung in der Konflikt-UI

---

## 8.6 Pull-Löschabgleich
Nach Verarbeitung der Remote-Liste wird geprüft:
- welche lokalen Datensätze eine `remotePath`-Referenz haben
- aber nicht mehr in `remoteUuids` vorkommen

Diese werden lokal gelöscht, **aber nur wenn**:
- sie nicht dirty sind
- keine `pendingResolution` gesetzt ist

### Fachliche Regel
Saubere lokale Datensätze dürfen als „remote gelöscht“ interpretiert werden.  
Dirty oder pending Datensätze werden geschützt.

---

# 9. Konflikterkennung

## Grundidee
Ein Konflikt liegt vor, wenn lokale und Remote-Version nicht sicher ohne Datenverlust zusammengeführt werden können.

## Typische Konfliktursachen
- Remote wurde seit `lastSyncedEtag` geändert
- lokale Änderungen existieren gleichzeitig
- belastbare Baseline fehlt
- lokal delete, remote edit
- offene bewusste Konfliktentscheidung noch nicht abgeschlossen

## Konservative Regel
Im Zweifel lieber:
- Konflikt melden
- Nutzerentscheidung einholen

statt:
- still überschreiben
- implizit verlieren

---

# 10. Konflikt-Callback und UI

## Registrierung
`main.dart` registriert über den `SyncOrchestrator` einen Konflikt-Callback.

## Aufrufweg
- `SyncOrchestrator.setConflictCallback(...)`
- Backend (`PocketBaseSyncService`) speichert Callback
- bei Push-Konflikt wird `_emitConflictIfPossible(...)` aufgerufen
- `main.dart` öffnet `ConflictResolutionScreen`

## Besonderheit
Die Navigation läuft über:
- `GlobalKey<NavigatorState>`

Dadurch kann Konflikt-UI auch ohne lokalen `BuildContext` aus Service-/Callback-Flows geöffnet werden.

---

# 11. Konfliktwartephase und Timeout-Verhalten

## Problem
Ein Sync kann während offener Konflikt-UI längere Zeit „stehen“, ohne wirklich kaputt zu sein.

## Lösung im Orchestrator
`SyncOrchestrator` verwendet eine konfliktbewusste Timeout-Schleife.

### Verhalten
- `syncOnce()` des Backends wird gestartet
- in kurzen Intervallen wird auf Abschluss gewartet
- bei Poll-Timeout:
  - wenn `isWaitingForConflictResolution == true`, wird weitergewartet
  - sonst zählt die normale Timeout-Uhr weiter

## Konsequenz
Eine offene Konflikt-UI gilt als legitime Wartephase und **nicht** sofort als Fehler.

## Normaler Timeout
Wenn keine Konfliktwartephase aktiv ist und die Gesamtzeit überschritten wird:
- `TimeoutException`
- Orchestrator-Status `error`

---

# 12. Konfliktauflösungen

Die UI unterstützt aktuell die typischen Entscheidungen:

- `useLocal`
- `useRemote`
- `merge`
- `skip`

## 12.1 `useLocal`
Bedeutet:
- lokale Version behalten
- beim nächsten Sync gezielt Remote überschreiben

Produktiv umgesetzt durch:
- `markForForceLocal(uuid)`

---

## 12.2 `useRemote`
Bedeutet:
- Remote-Version lokal übernehmen
- Remote-Version wird neue Baseline

Produktiv umgesetzt durch:
- `upsertArtikel(remoteVersion, etag: baseline)`
- `clearPendingResolution(uuid)`

## Wichtig
Für `useRemote` wird eine belastbare Baseline benötigt.  
Die Utility `requireRemoteBaselineEtag(remoteVersion)` erlaubt nur:

1. `etag`
2. `lastSyncedEtag`

Wenn beides fehlt oder leer ist:
- `StateError`

### Grund
`remotePath` oder leere Ersatzwerte sind keine fachlich belastbare Sync-Baseline.

---

## 12.3 `merge`
Bedeutet:
- Nutzer oder UI erzeugt eine zusammengeführte Version
- diese wird lokal gespeichert
- der nächste Sync soll sie bewusst Remote durchsetzen

Produktiv umgesetzt durch:
- `updateArtikel(mergedVersion)`
- `markForForceMerge(uuid)`

---

## 12.4 `skip`
Bedeutet:
- vorerst keine Änderung
- Konflikt bleibt offen
- beim nächsten Sync kann derselbe Konflikt erneut auftreten

### Fachliche Eigenschaft
`skip` ist keine echte Auflösung, sondern ein bewusstes Vertagen.

---

# 13. Konfliktadapter in `main.dart`

`ConflictResolutionScreen` erwartet aktuell ein `SyncService`-artiges Interface.  
Da der produktive Flow PocketBase-basiert ist und keine Nextcloud-Abhängigkeit mehr verwenden soll, existiert ein minimaler Adapter:

- `_PocketBaseConflictAdapter implements SyncService`

## Zweck
Er implementiert nur das, was der Konfliktscreen wirklich braucht:
- `applyConflictResolution(...)`

Andere Methoden werfen bewusst `UnimplementedError`.

## Vorteil
- minimale Kopplung
- kein unnötiger Legacy-Ballast
- klarer Fokus auf Konfliktauflösung

---

# 14. Bild-Sync

## 14.1 Upload bei Create/Update
Wenn `bildPfad` gesetzt ist und die Datei lokal existiert:
- wird sie als Multipart-Datei mitgesendet

## Upload-Optimierung
Wenn bereits gilt:
- `remoteBildPfad == basename(bildPfad)`

dann wird kein erneuter Upload vorgenommen.

## Ziel
Vermeidung unnötiger Re-Uploads.

---

## 14.2 Entfernen eines Remote-Bilds
Wenn lokal `bildPfad` leer ist, Remote aber ein Bild hat:
- wird bei Update `body['bild'] = null` gesetzt

Damit wird das File-Feld in PocketBase gelöscht.

---

## 14.3 Persistenz des Remote-Bildnamens
Nach erfolgreichem Create/Update wird aus der PocketBase-Antwort der Bildname normalisiert.

PocketBase kann `bild` liefern als:
- `String`
- `List<String>`

Die Hilfslogik `_extractBildName(...)` vereinheitlicht diese Fälle.

Danach wird `remoteBildPfad` lokal gespeichert.

---

## 14.4 Follow-up-Persistenz von `remoteBildPfad`
Nach Create/Update versucht der Service zusätzlich, `remoteBildPfad` in PocketBase zurückzuschreiben.

Das verbessert spätere Bildabgleiche.

Fehlschläge dabei sind warnend, aber nicht fatal für den Kernsync.

---

## 14.5 Download fehlender Bilder
Nach erfolgreichem Kernsync ruft der Orchestrator:

- `downloadMissingImages()`

auf.

Für jeden Artikel wird geprüft:
- gibt es `remoteBildPfad`?
- gibt es `remotePath`?
- fehlt lokal ein Bild oder ist es veraltet/falsch?
- ist eine gültige URL baubar?

Wenn ja:
- HTTP-Download
- Schreiben ins Cache-Verzeichnis
- stilles Aktualisieren des lokalen Bildpfads

---

## 14.6 Entferntes Remote-Bild
Wenn Pull erkennt:
- Remote hat kein Bild mehr
- lokal war noch `remoteBildPfad` gesetzt

dann wird lokal die Bildinfo still bereinigt:
- lokaler Bildpfad löschen
- `remoteBildPfad` zurücksetzen

---

# 15. ETag-/Record-Etag-Ermittlung

Die produktive Logik verwendet als Remote-Etag:
1. `updated`
2. falls leer: `record.id`

## Grund
Nicht jeder Record liefert immer eine brauchbare `updated`-Angabe.  
Die Record-ID dient dann als technischer Fallback.

## Wichtig
Dieser Fallback ist ein technischer Notbehelf, keine perfekte semantische Versionshistorie.

---

# 16. Logging-Konventionen im Sync

Die Sync-Logik verwendet sowohl Detail-Logs als auch kompakte Summary-Lines.

## Typische Summary-Logs
- `SYNC|PUSH|CREATE  ok  uuid=...`
- `SYNC|PUSH|UPDATE  ok  uuid=...`
- `SYNC|PUSH|DELETE  ok  uuid=...`
- `SYNC|PUSH  done  created=... updated=... deleted=... conflicts=... errors=... total=...`
- `SYNC|PULL  done  upserted=... skipped=... conflicts=... deleted=... errors=... total=...`
- `SYNC|PULL  fail  msg="..."`
- `SYNC|ORCHESTRATOR  wait  phase=... state=conflict_ui elapsed=...`
- `SYNC|ORCHESTRATOR  fail  phase=... msg="..."`

## Zweck
Diese Formate sind besonders nützlich für:
- In-App-Logviewer
- mobile Analyse
- schnelle Diagnose ohne Stacktrace-Flut

Für Details siehe:
- `docs/LOGGER.md`

---

# 17. Lifecycle-Kopplung

## Beim Resume
Außerhalb von Web:
- DB wird bei Bedarf wieder geöffnet
- danach kann `_syncIfConnected()` angestoßen werden
- App-Lock kann aktiv werden

## Beim Pause/Detach
Außerhalb von Web:
- App-Lock-Zeitstempel wird aktualisiert
- lokale Ressourcen können bereinigt werden
- DB kann geschlossen werden

## Wichtig
`openDatabase()` wird dabei idempotent verwendet.

---

# 18. Periodischer Sync

Aktuell startet `main.dart` periodische Synchronisation mit:
- `Timer.periodic(...)`
- Standardintervall: 15 Minuten

Vor dem periodischen Lauf wird geprüft:
- kein Web
- Client vorhanden
- kein laufender Sync
- falls `wifi_only_sync == true`: WLAN-Verbindung nötig

## Ziel
Schonender und kontrollierter Hintergrundabgleich.

---

# 19. Web-Verhalten

Sowohl `SyncOrchestrator` als auch `PocketBaseSyncService` überspringen produktive Sync-Läufe auf Web.

## Konsequenz
Web ist derzeit nicht der maßgebliche Referenzpfad für die mobile/desktop Offline-First-Sync-Architektur.

---

# 20. Wichtige Invarianten

Die folgenden Regeln sollten bei Änderungen nicht leichtfertig gebrochen werden:

## Invariante 1
**Lokale dirty Datensätze dürfen nicht blind durch Pull überschrieben werden.**

## Invariante 2
**Fehlende Baseline wird konservativ als Konfliktrisiko behandelt.**

## Invariante 3
**`force_local` und `force_merge` sind bewusste Nutzerentscheidungen und dürfen nicht sofort durch Pull entwertet werden.**

## Invariante 4
**Lokal delete + zwischenzeitlich remote geändert = Konflikt, nicht stiller Delete.**

## Invariante 5
**`skip` beendet den Konflikt nicht endgültig.**

## Invariante 6
**Konflikt-UI darf nicht mehrfach parallel für dieselbe Situation geöffnet werden.**

## Invariante 7
**Bild-Sync darf Kernsync nicht unnötig destabilisieren.**

## Invariante 8
**Create-Races müssen möglichst recovery-fähig behandelt werden.**

---

# 21. Typische Fehlerbilder

## Duplicate-UUID beim Create
Ursache:
- Race Condition
- Timeout nach serverseitigem Erfolg
- wiederholter Create-Versuch

Behandlung:
- Recovery-Lookup per UUID

## Timeout im Orchestrator
Ursache:
- Netzwerkproblem
- hängender Backend-Call
- Bilddownload zu langsam
- echter Deadlock

Spezialfall:
- offene Konflikt-UI wird als legitime Wartephase behandelt

## Wiederkehrender Konflikt nach `skip`
Ursache:
- Konflikt wurde bewusst nicht aufgelöst

Behandlung:
- erwartetes Verhalten, kein Bug an sich

## Pull löscht lokal nicht
Ursache oft:
- lokaler Dirty-Zustand
- `pendingResolution`
- Remote-Liste leer / ungültig

---

# 22. Testbezug

Für genaue Testzahlen und vollständige Testübersicht gilt:
- `docs/TESTING.md`

## Besonders relevante getestete Themen
- Orchestrator-Statuswechsel
- konfliktbewusste Timeout-Wartephase
- Guard gegen parallele `runOnce()`-Läufe
- Push-Konflikte
- Delete-vs-Edit-Konflikte
- Pull-Schutz bei dirty/pending
- `force_local` / `force_merge`
- Duplicate-UUID-Recovery
- Bildfeld-Handling
- `requireRemoteBaselineEtag()`

---

# 23. Grenzen und bewusste Nicht-Ziele

Dieses Dokument beschreibt die aktuelle Architektur, nicht jede historische Zwischenform.

Es macht keine Zusage, dass:
- jede Plattform identisches Verhalten hat
- jeder Edge Case bereits perfekt gelöst ist
- offene Optimierungspunkte bereits abgeschlossen sind

Für offene Restpunkte und geplante Verbesserungen gilt:
- `docs/OPTIMIZATIONS.md`

---

# 24. Änderungsregeln für die Sync-Logik

Bei Änderungen an Sync-Code immer prüfen:

- Push und Pull gemeinsam betrachten
- Delete-Pfade mitdenken
- `lastSyncedEtag` nicht versehentlich entwerten
- `pendingResolution` semantisch korrekt behandeln
- Bild-Upload und Bild-Download getrennt denken
- Snapshot-Verhalten nicht verlieren
- Timeout- und Konfliktwarteverhalten erhalten
- Logs konsistent halten
- bestehende Tests aktualisieren oder erweitern
- `docs/TESTING.md`, `docs/LOGGER.md`, `docs/OPTIMIZATIONS.md` bei Bedarf mitpflegen

---

# 26. Technische Regeln und Invarianten

Dieses Kapitel enthält bewusst strenge Regeln für Änderungen an der Sync-Logik.  
Wenn neue Anforderungen hinzukommen, sollen diese Regeln aktiv geprüft und nur mit gutem Grund verändert werden.

## 26.1 Baseline-Regeln

### Regel 1
Eine Konfliktentscheidung darf nur auf einer fachlich belastbaren Remote-Baseline beruhen.

Zulässige Baseline-Quellen:
- `etag`
- `lastSyncedEtag`

Nicht zulässig:
- `remotePath`
- leere Strings
- Placeholder-Werte ohne Versionsbedeutung

### Regel 2
`requireRemoteBaselineEtag()` darf nicht aufgeweicht werden, nur um UI-Flows „irgendwie“ lauffähig zu machen.

Wenn keine belastbare Baseline vorliegt, ist:
- Fehler werfen
- Konflikt konservativ behandeln

besser als ein semantisch falscher stiller Merge.

### Regel 3
Fehlende Baseline ist kein harmloser Spezialfall, sondern ein Risikosignal.

---

## 26.2 Dirty-/Pending-Regeln

### Regel 4
Ein lokaler dirty Datensatz darf durch Pull niemals blind überschrieben werden.

### Regel 5
Ein Datensatz mit gesetztem `pendingResolution` darf nicht still durch Pull ersetzt werden.

### Regel 6
`force_local` und `force_merge` sind bewusste Nutzerentscheidungen.  
Sie dürfen nicht durch automatische Remote-Übernahme entwertet werden.

### Regel 7
`skip` ist keine Auflösung.  
Ein später erneut auftretender Konflikt nach `skip` ist korrektes Verhalten.

---

## 26.3 Delete-Regeln

### Regel 8
`local delete + remote changed` ist ein Konflikt.

Es ist **nicht zulässig**, in diesem Fall pauschal Remote zu löschen.

### Regel 9
Lokale Löschung darf nur dann automatisch in einen Remote-Delete überführt werden, wenn:
- keine Konfliktlage vorliegt
- keine neuere Remote-Änderung erkannt wurde
- keine fehlende Baseline den Fall unsicher macht

### Regel 10
Ein lokal sauberer Datensatz mit `remotePath`, der im Pull nicht mehr vorkommt, darf lokal gelöscht werden.  
Dirty oder pending Datensätze dürfen dabei nicht gelöscht werden.

---

## 26.4 Push-/Pull-Regeln

### Regel 11
Push und Pull dürfen nie isoliert betrachtet werden.  
Jede Änderung an Push muss auf Pull-Auswirkungen geprüft werden und umgekehrt.

### Regel 12
Eine neue Konfliktprüfung darf nicht nur im Push oder nur im Pull eingebaut werden, wenn die fachliche Semantik eigentlich beide Richtungen betrifft.

### Regel 13
Per-Artikel-Fehler im Push dürfen den gesamten Lauf nicht unnötig abbrechen, wenn die bestehende Architektur bewusst artikelweise robust weiterarbeitet.

### Regel 14
Pull-Konflikte sollen produktiv weiterhin per Snapshot konserviert werden und nicht ungeplant direkte UI-Navigation auslösen.

---

## 26.5 Bild-Sync-Regeln

### Regel 15
Bild-Sync ist nachrangig gegenüber Kernobjekt-Sync.  
Ein Bildproblem darf nicht leichtfertig den gesamten Artikelsync semantisch beschädigen.

### Regel 16
Wenn lokal kein Bild mehr vorhanden ist, Remote aber eines hat, ist `bild = null` beim Update ein bewusstes Fachsignal und darf nicht versehentlich entfernt werden.

### Regel 17
`remoteBildPfad` ist keine dekorative Information, sondern relevante Sync-Metadaten für:
- Re-Upload-Vermeidung
- Download-Entscheidungen
- Konfliktanzeige
- Bildbereinigung

### Regel 18
Die Normalisierung von PocketBase-Bildfeldern (`String` vs. `List<String>`) darf nicht vereinfacht werden, wenn dadurch reale API-Antworten verloren gehen.

### Regel 19
Wenn Pull erkennt, dass Remote kein Bild mehr hat, muss die lokale Bildinfo konsistent bereinigt werden.

---

## 26.6 Orchestrator-Regeln

### Regel 20
`runOnce()` muss gegen parallele Ausführung geschützt bleiben.

### Regel 21
Eine offene Konflikt-UI ist eine legitime Wartephase.  
Die konfliktbewusste Timeout-Logik darf nicht entfernt werden, nur weil ein normaler Timeout-Code „einfacher“ wirkt.

### Regel 22
Statuswechsel (`idle`, `running`, `success`, `error`) sind Teil des UI-Vertrags und dürfen nicht still geändert werden.

### Regel 23
Die Bild-Download-Phase nach erfolgreichem Kernsync ist ein bewusst separierter Schritt.  
Diese Trennung soll nur mit guter Begründung aufgehoben werden.

---

## 26.7 Logging-Regeln

### Regel 24
Summary-Logs im Format `SYNC|...` sind Teil der Diagnosefähigkeit und sollen konsistent gehalten werden.

### Regel 25
Neue Sonderfälle in Push/Pull/Recovery sollen nicht nur funktional behandelt, sondern auch sinnvoll geloggt werden.

### Regel 26
Fehlerlogs dürfen keine stillen Catch-All-Schlucker ersetzen.  
Wo Fehler bewusst abgefangen werden, soll das weiterhin nachvollziehbar bleiben.

---

# 27. Edge Cases und bekannte schwierige Fälle

Dieses Kapitel sammelt Fälle, bei denen Änderungen besonders vorsichtig erfolgen müssen.

## 27.1 Fehlende Baseline bei existierendem Remote-Record
### Symptom
- lokaler Datensatz ist dirty
- Remote-Record existiert
- `lastSyncedEtag` fehlt oder ist nur Whitespace

### Erwartetes Verhalten
- konservativ Konflikt
- kein blindes Update
- kein blindes Delete

### Risiko bei falscher Änderung
- Remote-Änderungen werden überschrieben
- Konflikte werden unsichtbar

---

## 27.2 Delete-vs-Edit
### Symptom
- lokal soft-deleted
- Remote zwischenzeitlich geändert

### Erwartetes Verhalten
- Konflikt
- kein automatischer Remote-Delete

### Risiko bei falscher Änderung
- Datenverlust auf Remote

---

## 27.3 Wiederkehrender Konflikt nach `skip`
### Symptom
- Nutzer überspringt Konflikt
- nächster Sync meldet denselben Konflikt wieder

### Erwartetes Verhalten
- korrekt
- kein Bug

### Risiko bei falscher Änderung
- Konflikt wird unbemerkt „wegoptimiert“

---

## 27.4 Duplicate-UUID nach Create
### Symptom
- Create wirft Unique-/Duplicate-Fehler
- Remote-Record existiert aber bereits

### Erwartetes Verhalten
- Recovery-Lookup
- lokales Re-Attach statt zweitem Create

### Risiko bei falscher Änderung
- doppelte Einträge
- unnötige Fehlzustände
- endlose Pending-Schleifen

---

## 27.5 Timeout nach serverseitigem Create-Erfolg
### Symptom
- Request endet lokal mit Timeout
- Server hat Objekt möglicherweise trotzdem angelegt

### Erwartetes Verhalten
- Recovery-Lookup
- falls Remote vorhanden: `markSynced(...)`

### Risiko bei falscher Änderung
- Doppel-Create
- unnötige Konflikte
- falsche Benutzerwahrnehmung („nichts gespeichert“)

---

## 27.6 Dirty lokal, Remote unverändert
### Symptom
- lokaler Datensatz dirty
- Remote hat denselben Stand wie letzte Baseline

### Erwartetes Verhalten
- Pull überschreibt lokal trotzdem nicht
- kein Konflikt nötig, aber Schutz bleibt

### Risiko bei falscher Änderung
- lokale Änderungen gehen verloren, obwohl gar kein Remote-Konflikt vorlag

---

## 27.7 Pending-Resolution während Pull
### Symptom
- `pendingResolution` gesetzt
- Pull liefert neuere Remote-Version

### Erwartetes Verhalten
- kein Upsert
- keine Entwertung der bewussten Entscheidung

### Risiko bei falscher Änderung
- Nutzerentscheidung wird still überschrieben

---

## 27.8 Remote-Bild gelöscht, lokales Bild noch vorhanden
### Symptom
- lokal existieren noch Bildpfad und `remoteBildPfad`
- Remote liefert kein Bild mehr

### Erwartetes Verhalten
- lokale Bildinfo still bereinigen

### Risiko bei falscher Änderung
- UI zeigt veraltete oder nicht mehr existente Bilder
- Re-Sync-Verhalten wird inkonsistent

---

## 27.9 Konfliktwartephase im Orchestrator
### Symptom
- Sync wirkt lange blockiert
- tatsächlich ist nur Konflikt-UI offen

### Erwartetes Verhalten
- weiter warten
- kein vorschneller Fehlerstatus

### Risiko bei falscher Änderung
- Konfliktbearbeitung führt zu Fake-Timeouts
- UI meldet Fehler, obwohl Nutzer gerade korrekt arbeitet

---

## 27.10 Mehrfachtrigger derselben Konfliktsituation
### Symptom
- gleiche UUID wird mehrfach gemeldet
- mehrfache UI-Öffnung droht

### Erwartetes Verhalten
- Guard greift
- keine Konflikt-Screen-Kaskade

### Risiko bei falscher Änderung
- instabile Navigation
- doppelte Entscheidungen
- schwer nachvollziehbare Race Conditions

---

# 28. Änderungsverbote und rote Linien

Dieses Kapitel benennt Änderungen, die ohne sehr gute fachliche und testseitige Begründung **nicht** vorgenommen werden sollen.

## Verbot 1
Nicht `lastSyncedEtag` aus der Konfliktlogik entfernen, ohne ein gleichwertiges Baseline-Konzept einzuführen.

## Verbot 2
Nicht fehlende Baseline als „harmlos“ behandeln, nur um Konflikte zu reduzieren.

## Verbot 3
Nicht `force_local` oder `force_merge` per Pull überschreiben.

## Verbot 4
Nicht Pull-Konflikte ungeplant direkt per UI-Callback triggern, wenn dadurch Doppeltrigger oder UI-Rennen entstehen.

## Verbot 5
Nicht den Guard gegen parallele `runOnce()`-Aufrufe entfernen.

## Verbot 6
Nicht die konfliktbewusste Timeout-Logik im Orchestrator entfernen.

## Verbot 7
Nicht `bild = null` beim Update entfernen, wenn lokal ein zuvor vorhandenes Remote-Bild bewusst gelöscht wurde.

## Verbot 8
Nicht `remoteBildPfad` als „optional unwichtig“ behandeln.  
Er ist Teil der Sync-Semantik.

## Verbot 9
Nicht still `catch (_) {}`-Blöcke erweitern, ohne die Diagnosefähigkeit mitzudenken.

## Verbot 10
Nicht die UUID-basierte Recovery bei Create-Races entfernen, ohne gleichwertige Idempotenz-/Recovery-Mechanismen einzubauen.

## Verbot 11
Nicht Konflikt-Snapshots abschaffen, wenn kein gleichwertiger Mechanismus für Pull-Konflikte bereitsteht.

## Verbot 12
Nicht Sync-Logs so umbauen, dass Summary-Lines für mobile Diagnose verloren gehen.

---

# 29. Checkliste für Änderungen an der Sync-Logik

Vor jedem Merge von Sync-Änderungen sollte mindestens geprüft werden:

## Fachlich
- Betrifft die Änderung Push, Pull oder beides?
- Ändert sie Konfliktsemantik?
- Ändert sie Baseline-Logik?
- Ändert sie Delete-Verhalten?
- Ändert sie `pendingResolution`?
- Ändert sie `force_local` / `force_merge`?
- Ändert sie Bild-Sync oder Bildbereinigung?

## Technisch
- bleiben Guards gegen doppelte Läufe erhalten?
- bleibt Snapshot-Verhalten konsistent?
- bleibt Recovery bei Create-Races erhalten?
- bleiben Summary-Logs aussagekräftig?
- bleibt Konfliktwartezeit timeout-sicher?

## Testseitig
- bestehende Tests noch gültig?
- neue Edge Cases ergänzt?
- `docs/TESTING.md` bei Bedarf aktualisiert?
- bei Verhaltensänderung auch Doku angepasst?

---

# 30. Erweiterte Kurzfassung

Die Sync-Logik ist absichtlich konservativ.

Wenn Unsicherheit besteht, ist in der Regel besser:
- Konflikt statt stiller Überschreibung
- Skip statt falscher Auto-Heilung
- Snapshot statt Direktnavigation aus Pull
- Recovery statt Doppel-Create
- klare Logs statt stiller Magie

Das Ziel ist nicht „möglichst wenig Konflikte“, sondern:
**möglichst wenig unbemerkter Datenverlust**.

--- 

# 27. Kurzfazit

Die Sync-Architektur der Lager_app ist aktuell eine konfliktbewusste, konservative Offline-First-Synchronisation mit:

- lokalem SQLite-Stand
- PocketBase als Remote-Backend
- serieller Orchestrierung
- Baseline-gestützter Konflikterkennung
- Schutz für bewusste Nutzerentscheidungen
- Snapshot-gestützter Pull-Konfliktbehandlung
- Recovery für Create-Races
- getrenntem Bild-Sync
- strukturiertem Logging

Bei Unsicherheit gilt:
1. aktueller Produktivcode
2. aktuelle Tests
3. dieses Dokument und die übrige Fachdokumentation

---

[Allgemeiner Projektkontext](../prompt.txt) · [Architektur](ARCHITECTURE.md) · [Datenbank](DATABASE.md) · [Testing](TESTING.md) · [Optimizations](OPTIMIZATIONS.md) · [Logger](LOGGER.md)