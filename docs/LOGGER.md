# 📝 Logging-System (AppLogService)

Dieses Dokument beschreibt das zentrale Logging-Framework der **Lager_app**, für konsistente Fehlerdiagnose über alle Plattformen (Mobile, Desktop, Web).

---

## 🎯 Warum ein zentraler Logger?

| Vorteil               | Beschreibung                                                              |
| :--------------------- | :------------------------------------------------------------------------ |
| Struktur               | Jede Nachricht hat ein Level (Info, Warning, Error)                       |
| In-App Viewer          | Logs direkt in der App einsehbar — ideal für Mobile-Tests ohne USB-Kabel  |
| Produktions-Sicherheit | Automatische Filterung sensibler Daten im Release-Build                   |
| Plattform-Neutralität  | Einheitliche Ausgabe in Browser-Terminal, Android-Logcat und Linux-Stdout |

---

## 🛠️ Verwendung im Code

Zugriff global über den `AppLogService.logger`. Immer das passende Level verwenden.

### 1. Information (Normaler Ablauf)
```dart
AppLogService.logger.info("Synchronisation erfolgreich abgeschlossen.");
```

### 2. Warnung (Unerwartet, aber kein Crash)
```dart
AppLogService.logger.warning("Keine Internetverbindung. Sync verschoben.");
```

### 3. Fehler (Kritische Probleme)
Immer `error`-Objekt und `stackTrace` übergeben.
```dart
try {
  await api.fetchData();
} catch (e, stack) {
  AppLogService.logger.error(
    "Fehler beim API-Abruf",
    error: e,
    stackTrace: stack,
  );
}
```

---

## 🖥️ Log-Level Definitionen

| Level   | Verwendung                                   | Sichtbarkeit (Prod) |
| :------ | :------------------------------------------- | :------------------ |
| `trace` | Sehr detaillierte Ablauf-Schritte            | Ausgeblendet        |
| `debug` | Variablen-Inhalte, SQL-Queries               | Ausgeblendet        |
| `info`  | Meilensteine (App-Start, Login, Sync)        | Eingeschränkt       |
| `warning` | Behebbare Fehler (Timeout, Validierung)      | Sichtbar            |
| `error` | Exceptions, Abstürze, DB-Korruption          | Immer sichtbar      |

## 📋 Definierte Log-Events (Referenz)
| Logger          | Level   | Nachricht                                                                 | Kontext                                     |
| :-------------- | :------ | :------------------------------------------------------------------------ | :------------------------------------------ |
| `ArtikelList`   | `INFO`  | `[ArtikelList] Sync abgeschlossen → Liste neu laden`                      | Nach `SyncStatus.success`                   |
| `ArtikelList`   | `WARN`  | `[ArtikelList] Sync fehlgeschlagen`                                       | Nach `SyncStatus.error`                     |
| `PocketBaseSync` | `INFO`  | `PocketBaseSync: downloadMissingImages start`                             | Beginn Bild-Download-Phase                  |
| `PocketBaseSync` | `INFO`  | `PocketBaseSync: downloadMissingImages end (downloaded: X, skipped: Y, failed: Z)` | Ende mit Statistik                          |
| `PocketBaseSync` | `DEBUG` | `PocketBaseSync: Downloading image for {uuid}: {url}`                     | Pro heruntergeladenem Bild                  |
| `PocketBaseSync` | `DEBUG` | `PocketBaseSync: Bild gespeichert für {uuid}: {path}`                     | Erfolgreicher Download                      |
| `PocketBaseSync` | `WARN`  | `PocketBaseSync: Image download HTTP {code} für {uuid}`                   | HTTP-Fehler beim Download                   |
| `PocketBaseSync` | `WARN`  | `PocketBaseSync: Image download failed for {uuid}: {error}`               | Allgemeiner Download-Fehler                 |
| `ArtikelDbService` | `DEBUG` | `✅ Bildpfad für Artikel UUID {uuid} silent aktualisiert`                 | `setBildPfadByUuidSilent()`                 |
| `Main`          | `INFO`  | `[Main] Starte initialen Sync nach Setup...`                              | Nach URL-Konfiguration                      |
| `Main`          | `INFO`  | `[Main] Initialer Sync abgeschlossen`                                     | Sync fertig, UI-Wechsel                     |
| `Main`          | `INFO`  | `[Main] Kein Sync nötig → direkt zur App`                                 | Web oder nicht eingeloggt                   |

💡 Neue Log-Events hier eintragen damit die Nachrichtenformate konsistent bleiben.

---

## 🌓 Visualisierung

Log-Einträge passen sich dem `AppTheme` an:
| Farbe       | Level     |
| :---------- | :-------- |
| 🔴 Rot      | `error`   |
| 🟡 Gelb     | `warning` |
| 🔵 Blau/Grau | `info`    |
---

## 🧹 Migrations-Guide

Verbleibenden `debugPrint`-Statements werden schrittweise ersetzt.
Betroffenen Dateien: 👉 siehe Projekt-Status

--- 

[Zurück zur README](../README.md) | [ARCHITECTURE.md](ARCHITECTURE.md) | [Zum Projekt-Status](OPTIMIZATIONS.md)