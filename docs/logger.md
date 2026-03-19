# 🪵 Lager App – Logger Dokumentation

> **Erstellt:** 2026-03-19  
> **Status:** Aktiv & Verbindlich  
> **Zweck:** Vollständige Dokumentation des Logging-Systems, der Log-Level,
> Verwendungsregeln und Migration von `debugPrint` auf `AppLogService`

---

## 📁 Übersicht: Logging-System

Die App verwendet ein zentrales Logging-System basierend auf dem
`logger`-Package. Alle Log-Ausgaben laufen über eine einzige globale
Instanz, die in `app_log_service.dart` definiert ist.

| Komponente | Pfad | Zweck |
|-----------|------|-------|
| **AppLogService** | `lib/services/app_log_service.dart` | Globale Logger-Instanz + In-App Viewer |
| **MemoryOutput** | *(intern in AppLogService)* | RAM-Puffer für bis zu 500 Log-Events |
| **ConsoleOutput** | *(intern in AppLogService)* | Ausgabe in die Entwicklerkonsole |
| **Log-Viewer Dialog** | *(intern in AppLogService)* | In-App Anzeige via `AppLogService.showLogDialog()` |

---

## 🔧 1. Einbindung in eine neue Datei

### 1.1 Imports

Jede Datei, die loggen soll, benötigt diese zwei Imports:

```dart
import 'package:logger/logger.dart';
import '../services/app_log_service.dart';
```

> **Hinweis:** Der relative Pfad `../services/` muss je nach
> Dateiposition angepasst werden.

| Datei liegt in | Import-Pfad |
|----------------|-------------|
| `lib/services/` | `'../services/app_log_service.dart'` |
| `lib/widgets/` | `'../services/app_log_service.dart'` |
| `lib/screens/` | `'../services/app_log_service.dart'` |
| `lib/utils/` | `'../services/app_log_service.dart'` |
| `lib/repositories/` | `'../services/app_log_service.dart'` |

### 1.2 Logger-Instanz anlegen

Direkt unterhalb der Klassendeklaration (als `static final` bei
Service-Klassen, oder als `final` bei Widgets/Screens):

```dart
// In Service- / Repository-Klassen (static):
class MeineKlasse {
  static final Logger _logger = AppLogService.logger;
  // ...
}

// In StatefulWidget / StatelessWidget:
class _MeinWidgetState extends State<MeinWidget> {
  final Logger _logger = AppLogService.logger;
  // ...
}
```

---

## 📊 2. Log-Level Referenz

### 2.1 Übersicht aller Level

| Level | Methode | Emoji | Farbe | Wann verwenden |
|-------|---------|-------|-------|----------------|
| **Trace** | `_logger.t(...)` | 🔍 | Grau | Sehr detailliert: jeden HTTP-Header, jeden Loop-Durchlauf |
| **Debug** | `_logger.d(...)` | 🐛 | Blau | Normales Debugging: Methodenaufrufe, Zwischenwerte |
| **Info** | `_logger.i(...)` | ℹ️ | Grün | Wichtige Ereignisse: „Artikel gespeichert", „Sync abgeschlossen" |
| **Warning** | `_logger.w(...)` | ⚠️ | Orange | Unerwartet aber kein Absturz: Fallback greift, Datei zu groß |
| **Error** | `_logger.e(...)` | ❌ | Rot | Fehler in `catch`-Blöcken – **immer** mit `error:` + `stackTrace:` |
| **Fatal** | `_logger.f(...)` | 💀 | Lila | Kritisch: App kann nicht weiterlaufen |

### 2.2 Level im Release-Build

```
Debug-Build  → ab Level.debug  (alle Logs sichtbar)
Release-Build → ab Level.warning (trace + debug werden unterdrückt)
```

> **Konsequenz:** `_logger.t()` und `_logger.d()` sind im
> Release-Build **nicht** sichtbar. Wichtige Produktions-Informationen
> müssen mindestens auf `_logger.i()` geloggt werden.

---

## ✏️ 3. Verwendungsregeln

### 3.1 Einfache Nachrichten (ohne Fehler)

```dart
_logger.t('Sehr detaillierter Trace-Eintrag');
_logger.d('Methode aufgerufen: pickImageFile');
_logger.i('Artikel erfolgreich gespeichert: $artikelName');
_logger.w('Fallback zu file_selector, FilePicker nicht verfügbar');
```

### 3.2 Fehler in catch-Blöcken

**Pflicht:** Immer `error:` und `stackTrace:` mitgeben!

```dart
// ✅ Richtig
try {
  await dateiLesen();
} catch (e, st) {
  _logger.e(
    'methodenName: Beschreibung was fehlgeschlagen ist',
    error: e,
    stackTrace: st,
  );
}

// ❌ Falsch — stackTrace fehlt
} catch (e) {
  _logger.e('Fehler:$e');
}
```

### 3.3 Nachrichten-Format

Die Log-Nachricht soll immer folgendem Muster folgen:

```
'methodenName: Was ist passiert'
```

| Beispiel | Bewertung |
|----------|-----------|
| `'pickImageFile: Datei zu groß (5 MB, max 10 MB)'` | ✅ Klar, mit Kontext |
| `'_pickImageByFileSelector: Bildverarbeitung fehlgeschlagen'` | ✅ Methode + Ereignis |
| `'Fehler!'` | ❌ Kein Kontext |
| `'ImagePickerService: ImagePickerService Fehler in pickImageFile: $e'` | ❌ Redundant, `$e` gehört in `error:` |

> **Hinweis:** Den Klassennamen **nicht** in die Nachricht schreiben.
> `PrettyPrinter` zeigt automatisch Datei + Zeilennummer an.

### 3.4 Variablen in Nachrichten

Werte die zur Diagnose helfen, direkt in die Nachricht einbetten:

```dart
// ✅ Hilfreich
_logger.w(
  'pickImageFile: Datei zu groß '
  '(${file.bytes!.length} Bytes, max$_maxFileSizeBytes Bytes)',
);

// ✅ Bei Fehlern: Wert in error:, nicht in Nachricht
_logger.e(
  '_pickImageByPathFallback: Datei nicht lesbar: $eingabePfad',
  error: e,
  stackTrace: st,
);
```

---

## 🔄 4. Migration: `debugPrint` → `_logger`

### 4.1 Schritt-für-Schritt

**Schritt 1:** Alle `debugPrint`-Aufrufe in der Datei finden:

```bash
grep -n "debugPrint\|print(" lib/services/meine_datei.dart
```

**Schritt 2:** Imports ergänzen:

```dart
import 'package:logger/logger.dart';
import '../services/app_log_service.dart';
```

**Schritt 3:** Logger-Instanz anlegen (in der Klasse):

```dart
static final Logger _logger = AppLogService.logger;
```

**Schritt 4:** `debugPrint` durch passendes Level ersetzen
(siehe Mapping-Tabelle unten).

**Schritt 5:** `catch`-Blöcke auf `(e, st)` erweitern:

```dart
// Vorher:
} catch (e) {
  debugPrint('Fehler:$e');

// Nachher:
} catch (e, st) {
  _logger.e('methodenName: Beschreibung', error: e, stackTrace: st);
```

**Schritt 6:** Nicht mehr benötigte Imports entfernen:

```dart
// Kann entfernt werden wenn kein debugPrint mehr vorhanden:
import 'package:flutter/foundation.dart'; // nur wenn ausschließlich für debugPrint
```

### 4.2 Mapping-Tabelle

| Alter `debugPrint`-Kontext | Neues Level | Begründung |
|---------------------------|-------------|------------|
| Normaler Hinweis / Methodenaufruf | `_logger.d(...)` | Debug-Info, im Release nicht nötig |
| Fallback greift | `_logger.w(...)` | Unerwartet, aber kein Absturz |
| Datei zu groß / ungültig | `_logger.w(...)` | Warnung, Nutzer-Eingabeproblem |
| Datei nicht gefunden | `_logger.w(...)` | Warnung mit Pfad-Info |
| Fehler in `catch`-Block | `_logger.e(...)` | Immer mit `error:` + `stackTrace:` |
| App kann nicht weiterlaufen | `_logger.f(...)` | Kritischer Systemfehler |

### 4.3 Vollständiges Vorher/Nachher-Beispiel

```dart
// ─── VORHER ───────────────────────────────────────────────
import 'package:flutter/foundation.dart';

} catch (e) {
  debugPrint('MeinService.methode: Fehler beim Laden: $e');
  return null;
}

if (bytes.length > _maxSize) {
  debugPrint('MeinService: Datei zu groß (${bytes.length} Bytes)');
  return null;
}

// ─── NACHHER ──────────────────────────────────────────────
import 'package:logger/logger.dart';
import '../services/app_log_service.dart';

static final Logger _logger = AppLogService.logger;

} catch (e, st) {
  _logger.e(
    'methode: Fehler beim Laden',
    error: e,
    stackTrace: st,
  );
  return null;
}

if (bytes.length > _maxSize) {
  _logger.w('methode: Datei zu groß (${bytes.length} Bytes, max$_maxSize Bytes)');
  return null;
}
```

---

## 🖥️ 5. In-App Log-Viewer

### 5.1 Öffnen

Der Log-Viewer kann von überall in der App geöffnet werden:

```dart
await AppLogService.showLogDialog(context);
```

### 5.2 Funktionen des Viewers

| Funktion | Beschreibung |
|----------|-------------|
| **Level-Filter** | Chips zum Filtern ab einem bestimmten Level |
| **Neueste zuerst** | Logs werden in umgekehrter Reihenfolge angezeigt |
| **Aufklappbar** | Stack-Trace und weitere Zeilen per Tap sichtbar |
| **Kopieren** | Alle sichtbaren Logs in die Zwischenablage |
| **Löschen** | RAM-Puffer leeren (nur für aktuelle Session) |

### 5.3 Puffer-Verhalten

```
Maximale Einträge: 500 Events im RAM
Persistenz:        Keine — Logs gehen beim App-Neustart verloren
Älteste Logs:      Werden bei vollem Puffer automatisch verworfen
```

> **Empfehlung:** Für Crash-Diagnose relevante Fehler auf `Level.error`
> oder `Level.fatal` loggen — diese sind selten und bleiben länger im
> Puffer erhalten.

---

## 📋 6. Checkliste: Neue Datei auf Logger umstellen

```
□ grep -n "debugPrint\|print(" auf die Datei ausgeführt
□ Import: package:logger/logger.dart hinzugefügt
□ Import: ../services/app_log_service.dart hinzugefügt
□ Logger-Instanz angelegt: static final Logger _logger = AppLogService.logger;
□ Alle debugPrint durch passendes _logger-Level ersetzt
□ Alle catch-Blöcke auf (e, st) erweitert
□ Alle _logger.e() haben error: e, stackTrace: st
□ Nachrichten folgen dem Format: 'methodenName: Beschreibung'
□ Klassennamen nicht in Nachrichten wiederholt
□ Nicht mehr benötigte foundation.dart Imports geprüft/entfernt
□ flutter analyze ausgeführt — keine neuen Warnungen
```

---

## ✅ 7. Bereits migrierte Dateien (Stand: 2026-03-19)

| Datei | Status | Anmerkung |
|-------|--------|-----------|
| `lib/services/image_picker.dart` | ✅ Migriert | Alle 13 `debugPrint` ersetzt |
| `lib/services/app_log_service.dart` | ✅ Quelle | Logger-Definition |

---

*Dokumentation erstellt auf Basis der AppLogService-Implementierung – Lager App Projekt*