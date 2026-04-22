# 🎨 Design-System & Theming

> Stand: v0.8.9+24 (21.04.2026)
> 
> Dieses Dokument ist die aktive Entwicklungsreferenz für das Design-Token-System, Material 3 und die zentrale UI-Konfiguration der **Lager_app**.

---

## 🏗️ Architektur der UI-Steuerung

Um hartcodierte Werte ("Magic Numbers") im Code zu vermeiden, nutzt die App eine dreistufige Abstraktion im Verzeichnis `app/lib/config/`:


| Datei           | Zweck                                                         |
| :-------------- | :------------------------------------------------------------ |
| `app_config.dart` | Technische Konstanten (Spacing, Radien, Icons, Layout, Timeouts) |
| `app_theme.dart`  | Material 3 Farbschema, Typografie, Komponenten-Themes         |
| `app_images.dart` | Asset-Pfade, Feature-Flags für UI-Elemente                    |

## 📐 AppConfig — Token-Referenz

### Spacing
| Token          | Wert | Verwendung                                   |
| :------------- | :--- | :------------------------------------------- |
| `spacingXSmall`  | 4.0  | Kompakte Abstände (Icon↔Label, Badges)       |
| `spacingSmall`   | 8.0  | Standard-Innenabstand, SizedBox-Gaps         |
| `spacingMedium`  | 12.0 | Card-Innenabstand, Formular-Gaps             |
| `spacingLarge`   | 16.0 | Haupt-Padding (Body, Cards, Sections)        |
| `spacingXLarge`  | 24.0 | Sektions-Trennung, Dialog-Padding            |
| `spacingXXLarge` | 32.0 | Große Sektions-Trennung                      |

### Border-Radien
| Token                 | Wert | Verwendung                                   |
| :-------------------- | :--- | :------------------------------------------- |
| `borderRadiusXXSmall` | 2.0  | Minimale Rundung                             |
| `borderRadiusXSmall`  | 4.0  | Kleine Chips, Tags                           |
| `cardBorderRadiusSmall` | 6.0  | Kleine Cards, Badges                         |
| `borderRadiusMedium`  | 8.0  | Input-Felder, Status-Container               |
| `cardBorderRadiusLarge` | 12.0 | Standard-Cards, Stat-Chips, Component-Themes |
| `borderRadiusXLarge`  | 16.0 | Pill-Shapes, AppBar-Chips, Result-Chips      |

### Icon-Größen
| Token           | Wert | Verwendung                                   |
| :-------------- | :--- | :------------------------------------------- |
| `iconSizeXSmall`  | 14.0 | Stat-Chips, kompakte Badges                  |
| `iconSizeSmall`   | 16.0 | Progress-Indikatoren, Inline-Icons, Merge-Buttons |
| `iconSizeMedium`  | 20.0 | Dialog-Titel, Status-Icons, Radio-Buttons    |
| `iconSizeLarge`   | 24.0 | Card-Header, ListTile-Leading, Severity-Icons |
| `iconSizeXLarge`  | 48.0 | Empty-States, Upload-Area-Header, Fehler-Icons |
| `iconSizeXXLarge` | 64.0 | Setup-Screen Header                          |

### Stroke-Breiten
| Token            | Wert | Verwendung                                   |
| :--------------- | :--- | :------------------------------------------- |
| `strokeWidthThin`  | 1.0  | Chip/Badge-Borders, unselected Radio-Buttons, Thumbnail-Progress |
| `strokeWidthMedium`| 2.0  | CircularProgressIndicator, selected Radio-Buttons |
| `strokeWidthThick` | 3.0  | FAB-Progress, QR-Scan-Rahmen                 |

### Opacity
| Token           | Wert | Verwendung                                   |
| :-------------- | :--- | :------------------------------------------- |
| `opacitySubtle` | 0.1  | Stat-Chip Hintergründe, selected Card-BG, Attachment-Icon-BG |
| `opacityLight`  | 0.2  | Container-Overlays, Status-BG                |
| `opacityMedium` | 0.3  | Progress-BG, Borders, Container-Borders      |

### Layout
| Token               | Wert  | Verwendung                                   |
| :------------------ | :---- | :------------------------------------------- |
| `infoLabelWidth`    | 120.0 | Label-Spalte in Info-Zeilen (Settings)       |
| `infoLabelWidthSmall` | 80.0  | Label-Spalte in kompakten Detail-Zeilen (Conflict) |
| `avatarRadiusSmall` | 20.0  | CircleAvatar in Cards                        |
| `dialogContentWidth`| 300.0 | AlertDialog Content-Breite                   |
| `buttonPaddingVertical` | 12.0  | Vertikale Padding für prominente Buttons     |
| `loginFormMaxWidth` | 400.0 | Maximale Breite Login-Formular               |
| `setupFormMaxWidth` | 480.0 | Maximale Breite Setup-Formular               |
| `loginLogoSize`     | 80.0  | App-Logo auf Login-Screen                    |
| `buttonHeight`      | 48.0  | Höhe prominenter Buttons (Login)             |
| `exampleLabelWidth` | 85.0  | Label-Spalte in Beispiel-Zeilen (Setup)      |

### Progress-Indikatoren
| Token                     | Wert | Verwendung                                   |
| :------------------------ | :--- | :------------------------------------------- |
| `progressIndicatorSize`     | 32.0 | Kreisförmiger Progress im FAB                |
| `progressIndicatorSizeSmall`| 20.0 | Kleiner Progress in Buttons                  |

### Attachment-Dimensionen
| Token                     | Wert | Verwendung                                   |
| :------------------------ | :--- | :------------------------------------------- |
| `attachmentImageWidth`    | 56.0 | Thumbnail-Breite für Bild-Anhänge            |
| `attachmentImageHeight`   | 48.0 | Thumbnail-Höhe für Bild-Anhänge              |
| `attachmentIconSize`      | 28.0 | Icon-Größe in Anhang-Tiles                   |
| `attachmentIconContainerSize` | 48.0 | Container für Anhang-Typ-Icons               |
| `uploadAreaIconSize`      | 40.0 | Icon in Upload-Area und Fehler-Fallback      |

### Sonstige Konstanten
| Gruppe      | Beschreibung                                       |
| :---------- | :------------------------------------------------- |
| Timeouts    | Standard-Dauer für Snackbars und API-Requests      |
| Bildgrößen  | Standard-Dimensionen für Vorschaubilder (`pbThumbGroesse`) |
| Font-Sizes  | `fontSizeXSmall` (10) bis `fontSizeXXLarge` (20)   |
| Opacity     | Nutzung von `opacitySubtle` (0.1) bis `opacityMedium` (0.3) |

--- 

## 🎨 AppTheme — Material 3

Die App nutzt ein dynamisches Material 3 Theme, das über `app_theme.dart` gesteuert wird.

- **ThemeMode**: Volle Unterstützung für `ThemeMode.system` (automatischer Hell-/Dunkel-Wechsel).
- **Farbpalette**: Erzeugt über `ColorScheme.fromSeed` für harmonische Akzente.
- **Schriftarten**: Integration von **Google Fonts (Roboto)** als Hausschrift.
- **Komponenten-Themes**: Globale Definition für `AppBar`, `Card`, `FloatingActionButton` und `ListTile` — alle nutzen konsistent die `AppConfig`-Tokens.
- ✅ **O-004 Update**: Component-Themes nutzen jetzt AppConfig-Tokens statt hardcodierter Werte.

--- 

## 🖼️ AppImages — Asset-Management

- **Platzhalter**: Zentrale Verwaltung von Pfaden für Artikel ohne Bild.
- **Feature-Flags**: Steuerung von UI-Elementen wie `hintergrundAktiv` (Overlay-Grafiken).
- **⚠️ Bewusste Ausnahme**: Enthält hardcodierte Farben (`Color(0xFF...)`) für Platzhalter-Hintergründe, um diese logisch von den Theme-Farben zu trennen.

--- 

## 🕒 AppBar Sync-Zeitstempel (B-007)

Um eine perfekte Lesbarkeit des "Letzter Sync"-Zeitstempels auf unterschiedlichen AppBar-Hintergründen zu gewährleisten, gilt folgende Konvention:

- **Farbe**: `Theme.of(context).colorScheme.onSurface`
  - *Grund*: Garantiert maximalen Kontrast zum Oberflächen-Hintergrund, unabhängig vom AppBar-Zustand.
- **Schriftgewicht**: `FontWeight.bold`
- **Schriftgröße**: `12` (entspricht `fontSizeSmall`)
- **Kontext**: Analog zur Gestaltung von Filtern, um eine konsistente visuelle Hierarchie zu schaffen.

**Beispiel-Implementierung:**
```dart
Text(
  'Sync: $timestamp',
  style: TextStyle(
    color: Theme.of(context).colorScheme.onSurface,
    fontWeight: FontWeight.bold,
    fontSize: 12,
  ),
)
```
Seit `v0.9.0+25` ist der Sync-Zeitstempel gegen Overflow auf schmalen
Displays (360dp) abgesichert:

| Eigenschaft | Wert |
|:------------|:-----|
| `overflow` | `TextOverflow.ellipsis` |
| `maxLines` | `1` |
| `titleSpacing` | `0` (+ manuelles `Padding`) |

**Begründung:** Auf 360dp-Displays konkurriert der Zeitstempel-Text mit
den Action-Icons um Platz. Ohne Ellipsis warf Flutter einen
`RenderFlex`-Overflow-Fehler.

**Konvention:** Alle AppBar-Texte die mit Action-Icons koexistieren
müssen `overflow: TextOverflow.ellipsis` + `maxLines: 1` setzen.

---

## 🎛️ Ort-Dropdown (B-009)

Der Ort-Filter-Dropdown in der `ArtikelListScreen`-Body-Suchleiste folgt
denselben Token-Konventionen wie alle anderen UI-Elemente:

| Eigenschaft | Token / Wert |
|:------------|:-------------|
| Hintergrund | `colorScheme.surface` |
| Text | `colorScheme.onSurface` |
| Border-Radius | `AppConfig.borderRadiusMedium` |
| Reset-Button | `colorScheme.onSurfaceVariant` |
| Padding | `AppConfig.spacingSmall` / `AppConfig.spacingMedium` |

**Verhalten:**
- Nur sichtbar wenn Orte vorhanden (`_orte.isNotEmpty`)
- „Alle Orte" als erster Eintrag
- ×-Reset-Button bei aktivem Filter (`_selectedOrt != null`)
- Werte dynamisch aus `_artikelListe` (distinct, alphabetisch)

## 🛠️ Best Practices für Entwickler

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
      'Beispiel',
      style: Theme.of(context).textTheme.titleMedium,
    ),
  ),
)
```

### ❌ Falsch — Hardcoded

```dart 
Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12.0), // ❌ Festwert
  ),
  color: Colors.white, // ❌ bricht Dark Mode
  child: Padding(
    padding: EdgeInsets.all(15.0), // ❌ Festwert
    child: Text('Beispiel'),
  ),
)
```
### Regeln

- ❌ Niemals `Colors.white` oder `Colors.black` direkt verwenden
- ✅ Immer `colorScheme.surface` / `colorScheme.onSurface` nutzen
- ✅ Status-Container: `*Container + on*Container` Paare verwenden
- ✅ Opacity-Werte aus `AppConfig.opacity*` statt hardcodierter Werte
- ✅ Neue Screens (z.B. `app_lock_screen.dart`) von Beginn an mit Tokens implementieren — kein nachträgliches Migrieren
- ✅ AppBar-Status: Texte wie Sync-Zeitstempel immer in onSurface und bold (B-007).
- ✅ Dropdown-Werte dynamisch aus Daten ableiten — niemals hardcodierte Listen (B-009)

--- 

## 🌓 Dark Mode & Farb-Mapping

Die App erkennt die Systemeinstellungen des Geräts automatisch (`ThemeMode.system`).

| Modus      | Verhalten                                            |
| :--------- | :--------------------------------------------------- |
| Hell       | Helle Hintergründe, primary-Farben als Akzent        |
| Dunkel     | Tiefgraue Oberflächen (surface), entsättigte Farben  |
| Automatisch| `ThemeMode.system` — folgt der Geräteeinstellung     |

Textfarben passen sich automatisch an:
```dart
Theme.of(context).colorScheme.onSurface // passt sich immer dem Hintergrund an
```

--- 

## 🎨 Farb-Zuordnung — Referenz
| Hardcode              | Semantik              | colorScheme-Ersatz                  |
| :-------------------- | :-------------------- | :---------------------------------- |
| `Colors.white`        | Oberfläche            | `colorScheme.surface`               |
| `Colors.black`        | Text auf Oberfläche   | `colorScheme.onSurface`             |
| `Colors.grey` / `Colors.grey[600]` | Sekundärtext          | `colorScheme.onSurfaceVariant`      |
| `Colors.grey[300]`    | Hintergrund / Divider | `colorScheme.surfaceContainerHighest` |
| `Colors.grey.shade50` | Leichter Hintergrund  | `colorScheme.surfaceContainerLow`   |
| `Colors.grey.shade200`| Border                | `colorScheme.outlineVariant`        |
| `Colors.red`          | Fehler                | `colorScheme.error`                 |
| `Colors.red.shade50`  | Fehler-Container      | `colorScheme.errorContainer`        |
| `Colors.red.shade800` | Text auf Fehler-Container | `colorScheme.onErrorContainer`      |
| `Colors.green`        | Erfolg                | `colorScheme.tertiary`              |
| `Colors.green.shade50`| Erfolg-Container      | `colorScheme.tertiaryContainer`     |
| `Colors.green.shade700/800` | Text auf Erfolg-Container | `colorScheme.onTertiaryContainer`   |
| `Colors.orange`       | Warnung               | `colorScheme.secondary`             |
| `Colors.orange.shade50` | Warn-Container        | `colorScheme.secondaryContainer`    |
| `Colors.orange.shade700/800` | Text auf Warn-Container | `colorScheme.onSecondaryContainer`  |
| `Colors.blue`         | Primär / Info         | `colorScheme.primary`               |
| `Colors.blue.shade50` | Info-Container        | `colorScheme.primaryContainer`      |
| `Colors.blue.shade700/800` | Text auf Info-Container | `colorScheme.onPrimaryContainer`    |
| `Colors.purple`       | Merge / Tertiär-Aktion | `colorScheme.tertiary`              |

--- 
[Zurück zur README](../README.md) | [Zur Architektur](ARCHITECTURE.md) | [Zum Projekt-Status](OPTIMIZATIONS.md) | [Projekthistorie] (HISTORY.md)