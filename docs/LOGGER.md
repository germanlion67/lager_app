# 📝 Logging-System (AppLogService)

Dieses Dokument beschreibt das zentrale Logging-Framework der **Lager_app**, das eine konsistente Fehlerdiagnose über alle Plattformen (Mobile, Desktop, Web) hinweg ermöglicht.

---

## 🎯 Warum ein zentraler Logger?

In der Vergangenheit wurden Log-Ausgaben verstreut mit `debugPrint()` oder `print()` getätigt. Das neue System bietet folgende Vorteile:
1.  **Struktur**: Jede Nachricht hat ein Level (Info, Warning, Error).
2.  **In-App Viewer**: Logs können direkt in der App auf einem speziellen Screen eingesehen werden (ideal für Mobile-Tests ohne USB-Kabel).
3.  **Produktions-Sicherheit**: Automatische Filterung sensibler Daten im Release-Build.
4.  **Plattform-Neutralität**: Einheitliche Ausgabe im Browser-Terminal, Android-Logcat und Linux-Stdout.

---

## 🛠️ Verwendung im Code

Der Zugriff erfolgt global über den `AppLogService.logger`. Nutze immer das passende Level für die jeweilige Information.

### 1. Information (Normaler Ablauf)
```dart
AppLogService.logger.info("Synchronisation erfolgreich abgeschlossen.");
```

### 2. Warnung (Unerwartet, aber kein Crash)
```dart
AppLogService.logger.warning("Keine Internetverbindung. Sync verschoben.");
```

### 3. Fehler (Kritische Probleme)
Übergib bei Fehlern immer das `error`-Objekt und optional den `stackTrace`.
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

| Level | Verwendung | Sichtbarkeit (Prod) |
|---|---|---|
| `trace` | Sehr detaillierte Ablauf-Schritte | Ausgeblendet |
| `debug` | Variablen-Inhalte, SQL-Queries | Ausgeblendet |
| `info` | Meilensteine (App-Start, Login, Sync) | Eingeschränkt |
| `warning` | Behebbare Fehler (Timeout, Validierung) | Sichtbar |
| `error` | Exceptions, Abstürze, DB-Korruption | **Immer Sichtbar** |

---

## 🌓 Visualisierung & Themes

Das Logging-System ist vollständig in das **Design-System** integriert. Die Farben der Log-Einträge passen sich dem `AppTheme` an:
*   **Rot**: Fehler (`error`)
*   **Gelb**: Warnungen (`warning`)
*   **Blau/Grau**: Informationen (`info`)

---

## 🧹 Migrations-Guide

Alle verbleibenden `debugPrint`-Statements müssen schrittweise ersetzt werden. Eine Liste der betroffenen Dateien findest du im Dokument:
👉 **[OPTIMIZATIONS.md](OPTIMIZATIONS.md)**

---

## Neue Log-Events (v0.8.0 — Kaltstart-Fix)

| Logger | Level | Nachricht | Kontext |
|---|---|---|---|
| ArtikelList | INFO | `[ArtikelList] Sync abgeschlossen → Liste neu laden` | Nach `SyncStatus.success` |
| ArtikelList | WARN | `[ArtikelList] Sync fehlgeschlagen` | Nach `SyncStatus.error` |
| PocketBaseSync | INFO | `PocketBaseSync: downloadMissingImages start` | Beginn Bild-Download-Phase |
| PocketBaseSync | INFO | `PocketBaseSync: downloadMissingImages end (downloaded: X, skipped: Y, failed: Z)` | Ende mit Statistik |
| PocketBaseSync | DEBUG | `PocketBaseSync: Downloading image for {uuid}: {url}` | Pro heruntergeladenem Bild |
| PocketBaseSync | DEBUG | `PocketBaseSync: Bild gespeichert für {uuid}: {path}` | Erfolgreicher Download |
| PocketBaseSync | WARN | `PocketBaseSync: Image download HTTP {code} für {uuid}` | HTTP-Fehler beim Download |
| PocketBaseSync | WARN | `PocketBaseSync: Image download failed for {uuid}: {error}` | Allgemeiner Download-Fehler |
| ArtikelDbService | DEBUG | `✅ Bildpfad für Artikel UUID {uuid} silent aktualisiert` | `setBildPfadByUuidSilent()` |
| Main | INFO | `[Main] Starte initialen Sync nach Setup...` | Nach URL-Konfiguration |
| Main | INFO | `[Main] Initialer Sync abgeschlossen` | Sync fertig, UI-Wechsel |
| Main | INFO | `[Main] Kein Sync nötig → direkt zur App` | Web oder nicht eingeloggt |

--- 


[Zurück zur README](../README.md) | [Zum Projekt-Status](CHECKLIST.md)