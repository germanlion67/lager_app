# 📝 Logging-System (AppLogService)

Dieses Dokument beschreibt das zentrale Logging-Framework der **Lager_app**, für konsistente Fehlerdiagnose über alle Plattformen (Mobile, Desktop, Web).

---

## 1. 🎯 Warum ein zentraler Logger?

| Vorteil               | Beschreibung                                                              |
| :--------------------- | :------------------------------------------------------------------------ |
| Struktur               | Jede Nachricht hat ein Level (Info, Warning, Error)                       |
| In-App Viewer          | Logs direkt in der App einsehbar — ideal für Mobile-Tests ohne USB-Kabel  |
| Produktions-Sicherheit | Automatische Filterung sensibler Daten im Release-Build                   |
| Plattform-Neutralität  | Einheitliche Ausgabe in Browser-Terminal, Android-Logcat und Linux-Stdout |

---

## 2. 🛠️ Verwendung im Code

Zugriff global über den `AppLogService.logger`. In Dateien bevorzugt so verwenden:
```dart
import 'package:logger/logger.dart';
import '../services/app_log_service.dart';

final Logger _logger = AppLogService.logger;
```
Immer das passende Level verwenden.

### 2.1. Information (Normaler Ablauf)
```dart
_logger.i("Synchronisation erfolgreich abgeschlossen.");
```

### 2.2. Warnung (Unerwartet, aber kein Crash)
```dart
_logger.w("Keine Internetverbindung. Sync verschoben.");
```

### 2.3. Fehler (Kritische Probleme)
Immer `error`-Objekt und `stackTrace` übergeben.
```dart
try {
  await api.fetchData();
} catch (e, stack) {
  _logger.e(
    "Fehler beim API-Abruf",
    error: e,
    stackTrace: stack,
  );
}
```

---

## 3. ⚠️ Wichtig: Logger in Tests

### 3.1 Kein `Logger()` in Tests verwenden!

In **Testdateien** darf **niemals** ein eigener `Logger()` instanziiert werden.
Der Default-`PrettyPrinter` erzeugt Box-Zeichen (`│ └ ┌ ├`), die den
Test-Output verschmutzen und die Lesbarkeit zerstören.

**❌ Falsch:**
```dart
final logger = Logger(); // ← erzeugt Box-Zeichen im Test-Output!
logger.i("Test-Nachricht");
```

**✅ Richtig:**
```dart
import '../services/app_log_service.dart';

final Logger _logger = AppLogService.logger;
_logger.i("Test-Nachricht");
```

`AppLogService.logger` verwendet einen `SimplePrinter` (ohne Box-Zeichen),
der für Tests und Produktion gleichermaßen saubere Ausgaben liefert.

### 3.2 Übersprungene Tests (~3 Skips)

Die Testsuite zeigt dauerhaft `~3` übersprungene Tests. Das sind **legitime Skips**
für Tests mit externen Abhängigkeiten, die in der CI/Test-Umgebung nicht verfügbar sind:

| Datei | Zeile | Grund |
| :---- | ----: | :---- |
| `test/services/nextcloud_listfiles_test.dart` | 369 | Nextcloud-Server nicht verfügbar |
| `test/services/artikel_export_service_test.dart` | 36 | UI-Abhängigkeit (hängt ohne Display) |
| `test/services/artikel_export_service_test.dart` | 43 | Platform-Plugin fehlt in Test-Umgebung |

Diese Skips sind **kein Fehler** und erfordern keine Aktion.

---

## 4. 🖥️ Log-Level Definitionen

| API-Methode | Level-Name | Verwendung | Sichtbarkeit (Prod) |
| :---------- | :--------- | :--------- | :------------------ |
| `t(...)` | `trace` | Sehr detaillierte Ablauf-Schritte | Ausgeblendet |
| `d(...)` | `debug` | Variablen-Inhalte, SQL-Queries | Ausgeblendet |
| `i(...)` | `info` | Meilensteine (App-Start, Login, Sync) | Eingeschränkt |
| `w(...)` | `warning` | Behebbare Fehler (Timeout, Validierung) | Sichtbar |
| `e(...)` | `error` | Exceptions, Abstürze, DB-Korruption | Immer sichtbar |
| `f(...)` | `fatal` | Kritisch, App kann nicht weiterlaufen | Immer sichtbar |

---

## 5. 📋 Definierte Log-Events (Referenz)

> **Hinweis:** Diese Tabelle bildet die tatsächlich im Produktivcode vorhandenen Log-Aufrufe ab.  
> Neue Log-Events hier eintragen, damit die Nachrichtenformate konsistent bleiben.

### 5.1 Sync-Service (`PocketBaseSyncService`)

| Level   | Nachricht                                                                                           | Kontext                                                        |
| :------ | :-------------------------------------------------------------------------------------------------- | :------------------------------------------------------------- |
| `DEBUG` | `PocketBaseSync: Skipping sync on Web platform`                                                     | Web-Guard, kein Sync auf Web                                   |
| `INFO`  | `PocketBaseSync: syncOnce start (collection={name})`                                                | Beginn Sync-Lauf                                               |
| `INFO`  | `PocketBaseSync: syncOnce end (success)`                                                            | Ende Sync-Lauf                                                 |
| `ERROR` | `PocketBaseSync: syncOnce failed`                                                                   | Sync-Lauf fehlgeschlagen (mit `error` + `stackTrace`)          |
| `INFO`  | `PocketBaseSync: pushing {N} pending changes`                                                       | Beginn Push-Phase                                              |
| `INFO`  | SYNC&#124;PUSH&#124;CREATE  ok  uuid={uuid}                                                        | Erfolgreicher Remote-Create                                    |
| `INFO`  | SYNC&#124;PUSH&#124;UPDATE  ok  uuid={uuid}                                                        | Erfolgreicher Remote-Update                                    |
| `INFO`  | SYNC&#124;PUSH&#124;DELETE  ok  uuid={uuid}                                                        | Erfolgreicher Remote-Delete                                    |
| `INFO`  | SYNC&#124;PUSH&#124;DELETE  ok(local-only)  uuid={uuid}                                            | Lokal gelöscht, remote bereits nicht vorhanden                 |
| `DEBUG` | SYNC&#124;PUSH&#124;CREATE  remoteBildPfad gesetzt  uuid={uuid}  bild={name}                       | Follow-up-PATCH nach CREATE mit Bild                           |
| `WARN`  | SYNC&#124;PUSH&#124;CREATE  remoteBildPfad-Update fehlgeschlagen  uuid={uuid}  err={error}         | Follow-up-PATCH fehlgeschlagen                                 |
| `DEBUG` | SYNC&#124;PUSH&#124;UPDATE  remoteBildPfad gesetzt  uuid={uuid}  bild={name}                       | Follow-up-PATCH nach UPDATE mit Bild                           |
| `WARN`  | SYNC&#124;PUSH&#124;UPDATE  remoteBildPfad-Update fehlgeschlagen  uuid={uuid}  err={error}         | Follow-up-PATCH fehlgeschlagen                                 |
| `WARN`  | SYNC&#124;PUSH  fail  uuid={uuid}  msg="{kurztext}"                                                | Push-Fehler (Kurzform), Details folgen als ERROR               |
| `INFO`  | SYNC&#124;PUSH  done  created=N  updated=N  deleted=N  conflicts=N  errors=N  total=N              | Abschluss Push-Phase                                           |
| `WARN`  | `PocketBaseSync: Create ohne Antwort (Timeout/Duplicate-UUID); starte Recovery-Lookup (uuid={uuid})` | Timeout-after-success oder Duplicate-UUID, Recovery startet    |
| `WARN`  | `PocketBaseSync: Recovery-Lookup ohne Ergebnis (uuid={uuid}) — Create fehlgeschlagen`               | Recovery-Lookup ohne Treffer                                   |
| `INFO`  | `PocketBaseSync: Create-Recovery erfolgreich (uuid={uuid}, remoteId={id})`                          | Bestehender Remote-Record gefunden und lokal verknüpft         |
| `DEBUG` | SYNC&#124;PULL  conflict(local-dirty)  uuid={uuid}  remoteBild={name}  → snapshot gespeichert      | Pull erkennt Konflikt, speichert Remote-Snapshot               |
| `INFO`  | SYNC&#124;PULL  done  upserted=N  skipped=N  conflicts=N  deleted=N  errors=N  total=N             | Abschluss Pull-Phase                                           |
| `WARN`  | SYNC&#124;PULL  fail  msg="{kurztext}"                                                              | Pull-Fehler (Kurzform), Details folgen als ERROR               |
| `ERROR` | `PocketBase pull failed`                                                                             | Pull-Fehler (mit `error` + `stackTrace`)                       |
| `ERROR` | `PocketBase push failed (uuid={uuid})`                                                               | Push-Fehler pro Artikel (mit `error` + `stackTrace`)           |
| `INFO`  | `PocketBaseSync: downloadMissingImages start`                                                       | Beginn Bild-Download-Phase                                     |
| `INFO`  | `PocketBaseSync: downloadMissingImages end (downloaded=X, skipped=Y, failed=Z)`                     | Ende Bild-Download mit Statistik                               |
| `ERROR` | `PocketBaseSync: downloadMissingImages failed`                                                      | Bild-Download-Phase fehlgeschlagen (mit `error` + `stackTrace`) |

### 5.2 Sync-Orchestrator (`SyncOrchestrator`)

| Level   | Nachricht                                                                        | Kontext                                          |
| :------ | :------------------------------------------------------------------------------- | :----------------------------------------------- |
| `DEBUG` | `SyncOrchestrator: Skipping sync on Web platform`                                | Web-Guard                                        |
| `DEBUG` | `SyncOrchestrator: Konflikt-Callback registriert`                                | Callback-Setup                                   |
| `WARN`  | `SyncOrchestrator: bereits disposed – überspringe`                               | Disposed-Guard                                   |
| `WARN`  | `SyncOrchestrator: Sync bereits aktiv – überspringe`                             | Parallel-Guard                                   |
| `INFO`  | `SyncOrchestrator: start`                                                        | Beginn Orchestrator-Lauf                         |
| `INFO`  | `SyncOrchestrator: end (success) – {timestamp}`                                  | Erfolgreicher Abschluss                          |
| `WARN`  | SYNC&#124;ORCHESTRATOR  fail  phase={phase}  msg="{kurztext}"                   | Timeout oder Fehler, Phase gibt Kontext          |
| `ERROR` | `SyncOrchestrator: sync failed`                                                  | Fehler (mit `error` + `stackTrace`)              |
| `INFO`  | SYNC&#124;ORCHESTRATOR  wait  phase={phase}  state=conflict_ui  elapsed={s}s    | Konfliktbewusste Wartephase                      |
| `INFO`  | `SyncOrchestrator: Starte periodischen Sync (alle {N} min)`                      | Timer-Start                                      |
| `INFO`  | `SyncOrchestrator: Periodischer Sync gestoppt`                                   | Timer-Stop                                       |
| `INFO`  | `SyncOrchestrator: disposed`                                                     | Dispose                                          |

### 5.3 Weitere Dateien — Übersicht

Die folgenden Dateien enthalten Logger-Aufrufe, die hier nicht einzeln aufgelistet werden.
Für die vollständige Nachricht gilt der jeweilige Produktivcode als Referenz.

| Datei | Log-Aufrufe | Wichtigste Events |
| :---- | ----------: | :---------------- |
| `main.dart` | ~44 | Global Error Handler (`FATAL`), Auth-Flow (Login/Logout/Token-Refresh), Konflikt-UI-Lifecycle (Guards, Open, Close), Sync-Lifecycle (Initial/Periodisch/WLAN-Guard), Server-Setup-Callback, App-Lifecycle (Resume/Pause/DB-Reopen), Dev-Mode-Warnungen |
| `artikel_db_service.dart` | ~50 | Schema-Erstellung und Migration (`INFO`/`WARN`), CRUD-Erfolg/-Fehler pro Operation (`DEBUG`/`ERROR`), Sync-Metadaten (`markSynced`, `markForForceLocal`, `markForForceMerge`), Conflict-Snapshot-Persistenz, Bild-/Thumbnail-Pfad-Updates, Suche und Duplikat-Checks, DB-Reset und Backup-Restore |
| `pocketbase_service.dart` | ~25 | Initialisierung und URL-Auflösung, Client-Erstellung und Health-Check, Login/Logout/Token-Refresh/Passwort-Reset, URL-Update mit Health-Check-Validierung, Placeholder-Warnungen |
| `settings_controller.dart` | ~6 | Fehler-Logs für Laden/Speichern/Reset/DB-Löschen (`ERROR`), PocketBase-Verbindungstest |
| `conflict_resolution_screen.dart` | 2 | Fehler bei Konfliktauflösung und Merge (`ERROR`) |
| `artikel_list_screen.dart` | ~2 | Fehler beim Laden der Artikelliste, Nextcloud-Init-Fehler |
| `app_log_service.dart` | 0 | Kein eigener Logger — stellt den Logger bereit |
| `login_screen.dart` | 0 | Nutzt nur UI-State, kein Logger |
| `connectivity_service.dart` | 0 | Reine Utility, kein Logger |
| `app_lock_service.dart` | 0 | Reine State-/Persistenz-Logik, kein Logger |

### 5.4 `debugPrint`-Verbleib

| Datei | Anzahl | Grund |
| :---- | -----: | :---- |
| `app_log_io.dart` | 5 | Bewusst beibehalten — zirkuläre Abhängigkeit (`Logger → IO → Logger`). Betrifft Filesystem-Zugriff, Log-Rotation und Bootstrap-Status. Kein anderer Produktivcode enthält `debugPrint`. |

---

## 6. 🎛️ Log-Dialog — Level-Filter (F-006)

Der In-App Log-Viewer (`AppLogService.showLogDialog()`) verwendet seit `v0.9.0+25`
einen `DropdownButton<Level>` statt der früheren horizontalen Button-Reihe.

| Eigenschaft | Wert |
| :---------- | :--- |
| Widget | `DropdownButton<Level>` |
| Default | `Level.error` (konfigurierbar in Einstellungen seit O-013) |
| Verfügbare Level | `trace`, `debug`, `info`, `warning`, `error`, `fatal` |
| Farbe | Passt sich dynamisch dem gewählten Level an |
| Leer-State | `check_circle_outline`-Icon + Level-Name im Text |

**Vorteil:** Auf schmalen Displays (360dp) passt der Filter in eine Zeile —
die frühere Button-Reihe benötigte horizontales Scrollen.

---

## 7. 🔮 Geplant: Nutzerfreundliche Aktivitäts-Logs (F-010)

Neben dem bestehenden technischen Entwickler-Log ist eine zweite, menschenlesbare Log-Ebene geplant (`UserLogService`). Diese zeigt dem Nutzer verständliche Aktivitätsmeldungen wie „Artikel ‚LED Strip 5m' erstellt und synchronisiert" statt technischer Debug-Ausgaben mit UUIDs und ETags.

Details und Aufgabenliste: → `docs/OPTIMIZATIONS.md` (F-010)

---

## 8. 🌓 Visualisierung

Log-Einträge passen sich dem `AppTheme` an:

| Farbe       | Level     |
| :---------- | :-------- |
| 🔴 Rot      | `error`   |
| 🟡 Gelb     | `warning` |
| 🔵 Blau/Grau | `info`   |

---

## 9. 🧹 Migrations-Guide

`debugPrint` ist im Produktivcode vollständig durch `AppLogService.logger` ersetzt.
Die 5 verbleibenden `debugPrint`-Aufrufe in `app_log_io.dart` sind bewusst beibehalten
(zirkuläre Abhängigkeit — siehe Tabelle oben).

**Auch in Tests gilt:** Kein `Logger()` direkt instanziieren — immer
`AppLogService.logger` verwenden (siehe [Logger in Tests](#⚠️-wichtig-logger-in-tests)).

---

[Zurück zur README](../README.md) | [ARCHITECTURE.md](ARCHITECTURE.md) | [Zum Projekt-Status](OPTIMIZATIONS.md)