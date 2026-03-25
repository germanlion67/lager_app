# 🛠️ Technische Optimierungen & Offene Punkte

Dieses Dokument beschreibt spezifische technische Aufgaben, Refactorings und "Politur-Arbeiten", die für den Abschluss von Phase 3 und 4 notwendig sind.

---

## 🔴 Priorität: Hoch

### O-001: Bereinigung von `debugPrint`
Es befinden sich noch ca. 34 manuelle `debugPrint`-Aufrufe im Code, die durch den zentralen `AppLogService` ersetzt werden müssen, um ein konsistentes Logging (auch in Produktion) zu gewährleisten.

**Betroffene Dateien (Auszug):**
*   `app/lib/screens/artikel_erfassen_screen.dart`
*   `app/lib/services/sync_service.dart`
*   `app/lib/utils/image_processing_utils.dart`

**Ziel-Code:**
```dart
// Statt: debugPrint("Fehler beim Laden: $e");
AppLogService.logger.error("Fehler beim Laden", error: e);
```

### M-007: UI für Konfliktlösung
Der Synchronisations-Prozess erkennt Konflikte, aber die Benutzeroberfläche zur Auswahl zwischen "Lokal behalten" oder "Server übernehmen" ist noch nicht finalisiert.

**Aufgabe:**
*   `conflict_resolution_screen.dart` fertigstellen.
*   Vergleichs-Widget (Vorher/Nachher) für Artikeldaten implementieren.

---

## 🟡 Priorität: Mittel

### O-004: UI-Hardcoded Werte migrieren
Es gibt noch ca. 140 Stellen im Code, an denen Farben, Abstände oder Radien direkt (hardcoded) vergeben sind, statt die `AppConfig` oder das `AppTheme` zu nutzen.

**Fokus-Bereiche:**
*   `sync_progress_widgets.dart`
*   `artikel_list_item_widget.dart`
*   `settings_screen.dart`

**Standard-Werte verwenden:**
*   Abstände: `AppConfig.spacingMedium` (16.0)
*   Ecken: `AppConfig.cardBorderRadius` (12.0)
*   Farben: `Theme.of(context).colorScheme.primary`

### O-002: Unit-Tests für Core-Utilities
Einige kritische Hilfsfunktionen sind noch nicht durch automatisierte Tests abgedeckt.

**Zu testende Komponenten:**
*   `uuid_generator.dart`: Sicherstellen der Eindeutigkeit.
*   `image_processing_utils.dart`: Prüfung der Kompression (Größe vor/nachher).
*   `artikel_model.dart`: Validierung von `fromMap` / `toMap` (besonders für Null-Werte).

---

## 🟢 Priorität: Nice-to-Have

### N-005: Nextcloud-Workflow
Die WebDAV-Anbindung ist funktional, aber der automatische Upload nach einem erfolgreichen Sync ist noch als "experimentell" markiert.

**Aufgabe:**
*   Testlauf mit einer realen Nextcloud-Instanz (Version 28+).
*   Fehlerbehandlung bei fehlendem Speicherplatz oder abgelaufenen App-Passwörtern verbessern.

### H-001: iOS/macOS Vorbereitung
Falls ein Apple Developer Account verfügbar wird, sind folgende Schritte in `app/ios/` notwendig:
1.  `Runner.xcworkspace` in Xcode ��ffnen.
2.  `App Groups` für geteilten Speicher (Sync) konfigurieren.
3.  `Info.plist` Beschreibungen für Kamera und Galerie prüfen.

---

[Zurück zur README](../README.md) | [Zum Projekt-Status](CHECKLIST.md)