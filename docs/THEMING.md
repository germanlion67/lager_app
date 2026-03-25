# 🎨 Design-System & Theming

Dieses Dokument beschreibt die Implementierung von Material 3, das Design-Token-System und die zentrale Konfiguration der **Lager_app**.

---

## 🏗️ Architektur der UI-Steuerung

Um hartcodierte Werte ("Magic Numbers") im Code zu vermeiden, nutzt die App eine dreistufige Abstraktion im Verzeichnis `app/lib/config/`:

### 1. `AppConfig` (Technische Konstanten)
Hält alle nicht-visuellen und strukturellen Vorgaben bereit.
*   **Abstände**: `spacingSmall` (8.0), `spacingMedium` (16.0), `spacingLarge` (24.0).
*   **Radien**: `cardBorderRadius` (12.0), `inputBorderRadius` (8.0).
*   **Timeouts**: Standard-Dauer für Snackbars und API-Requests.
*   **Bildgrößen**: Standard-Dimensionen für Vorschaubilder (`pbThumbGroesse`).

### 2. `AppTheme` (Visuelle Identität)
Implementiert das Material 3 Farbschema und die Typografie.
*   **Support**: Volle Unterstützung für `ThemeMode.system` (automatischer Wechsel zwischen Hell- und Dunkelmodus).
*   **Farbpaletten**: Nutzung von `ColorScheme.fromSeed` für harmonische Primär- und Akzentfarben.
*   **Schriftarten**: Integration von **Google Fonts (Roboto)** als Hausschrift.
*   **Komponenten-Themes**: Globale Definition für `AppBar`, `Card`, `FloatingActionButton` und `ListTile`.

### 3. `AppImages` (Asset-Management)
Verwaltet Pfade zu statischen Dateien und Feature-Flags für die UI.
*   **Platzhalter**: Pfade zu Standard-Bildern, falls kein Artikelbild vorhanden ist.
*   **Hintergrund-Stack**: Flag `hintergrundAktiv` zur Steuerung von optionalen Overlay-Grafiken in der Liste.

---

## 🛠️ Best Practices für Entwickler

Vermeide direkte Zuweisungen von Farben oder Maßen. Nutze stattdessen immer den Kontext oder die Config-Klassen.

### Richtig (Nutzt das Theme):
```dart
Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
  ),
  color: Theme.of(context).colorScheme.surface,
  child: Padding(
    padding: EdgeInsets.all(AppConfig.spacingMedium),
    child: Text(
      "Beispiel",
      style: Theme.of(context).textTheme.titleMedium,
    ),
  ),
)
```

### Falsch (Hardcoded):
```dart
Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12.0), // ❌ Festwert
  ),
  color: Colors.white, // ❌ Festwert (bricht Dark Mode)
  child: Padding(
    padding: EdgeInsets.all(15.0), // ❌ Festwert
    child: Text("Beispiel"),
  ),
)
```

---

## 🌓 Dark Mode Unterstützung

Die App erkennt die Systemeinstellungen des Geräts.
*   **Hell**: Nutzt helle Hintergründe mit `primary`-Farben als Akzent.
*   **Dunkel**: Nutzt tiefgraue/schwarze Oberflächen (`surface`) mit entsättigten Farben, um die Augen zu schonen.

Die Farbwahl erfolgt automatisch über:
`Theme.of(context).colorScheme.onSurface` (Textfarbe passt sich dem Hintergrund an).

---

[Zurück zur README](../README.md) | [Zum Projekt-Status](CHECKLIST.md)