# 🎨 Design-System & Theming

Dieses Dokument beschreibt die Implementierung von Material 3, das Design-Token-System und die zentrale Konfiguration der **Lager_app**.

**Zuletzt aktualisiert:** 2026-04-01 (O-004 Batch 1)

---

## 🏗️ Architektur der UI-Steuerung

Um hartcodierte Werte ("Magic Numbers") im Code zu vermeiden, nutzt die App eine dreistufige Abstraktion im Verzeichnis `app/lib/config/`:

### 1. `AppConfig` (Technische Konstanten)
Hält alle nicht-visuellen und strukturellen Vorgaben bereit.

#### Spacing
| Token | Wert | Verwendung |
|---|---|---|
| `spacingXSmall` | 4.0 | Kompakte Abstände (Icon↔Label, Badges) |
| `spacingSmall` | 8.0 | Standard-Innenabstand, SizedBox-Gaps |
| `spacingMedium` | 12.0 | Card-Innenabstand, Formular-Gaps |
| `spacingLarge` | 16.0 | Haupt-Padding (Body, Cards, Sections) |
| `spacingXLarge` | 24.0 | Sektions-Trennung |
| `spacingXXLarge` | 32.0 | Große Sektions-Trennung |

#### Border-Radien
| Token | Wert | Verwendung |
|---|---|---|
| `borderRadiusXXSmall` | 2.0 | Minimale Rundung |
| `borderRadiusXSmall` | 4.0 | Kleine Chips, Tags |
| `cardBorderRadiusSmall` | 6.0 | Kleine Cards, Badges |
| `borderRadiusMedium` | 8.0 | Input-Felder, Status-Container |
| `cardBorderRadiusLarge` | 12.0 | Standard-Cards, Stat-Chips |
| `borderRadiusXLarge` | 16.0 | Pill-Shapes, AppBar-Chips |

#### Icon-Größen (neu in v0.7.4+3)
| Token | Wert | Verwendung |
|---|---|---|
| `iconSizeXSmall` | 14.0 | Stat-Chips, kompakte Badges |
| `iconSizeSmall` | 16.0 | Progress-Indikatoren, inline Icons |
| `iconSizeMedium` | 20.0 | Dialog-Titel, Status-Icons |
| `iconSizeLarge` | 24.0 | Card-Header, ListTile-Leading |

#### Stroke-Breiten (neu in v0.7.4+3)
| Token | Wert | Verwendung |
|---|---|---|
| `strokeWidthThin` | 1.0 | Chip/Badge-Borders |
| `strokeWidthMedium` | 2.0 | CircularProgressIndicator |
| `strokeWidthThick` | 3.0 | FAB-Progress |

#### Opacity (neu in v0.7.4+3)
| Token | Wert | Verwendung |
|---|---|---|
| `opacitySubtle` | 0.1 | Stat-Chip Hintergründe |
| `opacityLight` | 0.2 | Container-Overlays, Status-BG |
| `opacityMedium` | 0.3 | Progress-BG, Borders |

#### Layout (neu in v0.7.4+3)
| Token | Wert | Verwendung |
|---|---|---|
| `infoLabelWidth` | 120.0 | Label-Spalte in Info-Zeilen |
| `avatarRadiusSmall` | 20.0 | CircleAvatar in Cards |
| `dialogContentWidth` | 300.0 | AlertDialog Content-Breite |
| `progressIndicatorSize` | 32.0 | Kreisförmiger Progress im FAB |

#### Sonstige
*   **Timeouts**: Standard-Dauer für Snackbars und API-Requests.
*   **Bildgrößen**: Standard-Dimensionen für Vorschaubilder (`pbThumbGroesse`).
*   **Font-Sizes**: `fontSizeXSmall` (10) bis `fontSizeXXLarge` (20).

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
*   ⚠️ **Hinweis**: Enthält noch hardcodierte Farben (`Color(0xFF...)`) für Platzhalter-Hintergründe. Diese sollten in den aufrufenden Widgets durch `colorScheme.surfaceContainerHighest` ersetzt werden (geplant für O-004 Batch 5).

---

## 🛠️ Best Practices für Entwickler

Vermeide direkte Zuweisungen von Farben oder Maßen. Nutze stattdessen immer den Kontext oder die Config-Klassen.

### ✅ Richtig (Nutzt das Theme):
```dart
Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppConfig.cardBorderRadiusLarge),
  ),
  color: Theme.of(context).colorScheme.surface,
  child: Padding(
    padding: EdgeInsets.all(AppConfig.spacingLarge),
    child: Text(
      "Beispiel",
      style: Theme.of(context).textTheme.titleMedium,
    ),
  ),
)
```
### ❌ Falsch (Hardcoded):
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
Hardcode	Semantik	colorScheme-Ersatz
Colors.white	Oberfläche	colorScheme.surface
Colors.black	Text auf Oberfläche	colorScheme.onSurface
Colors.grey / Colors.grey[600]	Sekundärtext	colorScheme.onSurfaceVariant
Colors.grey[300]	Hintergrund/Divider	colorScheme.surfaceContainerHighest
Colors.grey.shade50	Leichter Hintergrund	colorScheme.surfaceContainerLow
Colors.grey.shade200	Border	colorScheme.outlineVariant
Colors.red	Fehler	colorScheme.error
Colors.red.shade50	Fehler-Container	colorScheme.errorContainer
Colors.red.shade800	Text auf Fehler-Container	colorScheme.onErrorContainer
Colors.green	Erfolg	colorScheme.tertiary
Colors.green.shade50	Erfolg-Container	colorScheme.tertiaryContainer
Colors.green.shade700/800	Text auf Erfolg-Container	colorScheme.onTertiaryContainer
Colors.orange	Warnung	colorScheme.secondary
Colors.orange.shade50	Warn-Container	colorScheme.secondaryContainer
Colors.orange.shade700/800	Text auf Warn-Container	colorScheme.onSecondaryContainer
Colors.blue	Primär/Info	colorScheme.primary
Colors.blue.shade50	Info-Container	colorScheme.primaryContainer
Colors.blue.shade700/800	Text auf Info-Container	colorScheme.onPrimaryContainer

🌓 Dark Mode Unterstützung
Die App erkennt die Systemeinstellungen des Geräts.

Hell: Nutzt helle Hintergründe mit primary-Farben als Akzent.
Dunkel: Nutzt tiefgraue/schwarze Oberflächen (surface) mit entsättigten Farben, um die Augen zu schonen.
Die Farbwahl erfolgt automatisch über:
Theme.of(context).colorScheme.onSurface (Textfarbe passt sich dem Hintergrund an).

Wichtig für Entwickler
Niemals Colors.white oder Colors.black direkt verwenden
Immer colorScheme.surface / colorScheme.onSurface nutzen
Status-Container: *Container + on*Container Paare verwenden
Opacity-Werte aus AppConfig.opacity* statt hardcodierter Werte


---

[Zurück zur README](../README.md) | [Zum Projekt-Status](CHECKLIST.md)