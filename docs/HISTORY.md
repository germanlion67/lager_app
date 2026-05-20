# 📜 Projekthistorie & Meilensteine

Dieses Dokument dient als geordnetes Archiv für alle bisherigen Phasen, Releases, technischen Meilensteine und historisch relevanten Entscheidungen der **Lager_app**.

> **Hinweis:**  
> Diese `HISTORY.md` enthält **nur abgeschlossene, historisch relevante und versionierte Änderungen**.  


Die Einträge sind **primär nach Versionsnummer**, **sekundär nach Datum** sortiert.  
Einträge **ohne eindeutige Versionszuordnung** stehen gesammelt im Archivbereich.

---

## Inhaltsverzeichnis

1. [Versionshistorie](#1-versionshistorie)
2. [O-004 Migrationshistorie aus `THEMING.md`](#2-o-004-migrationshistorie-aus-themingmd)
3. [Archiv: nicht eindeutig versionierte Einträge](#3-archiv-nicht-eindeutig-versionierte-einträge)
4. [Historische Architektur-Entscheidungen](#4-historische-architektur-entscheidungen)

---

## 1. Versionshistorie


## 🔦 Lighthouse-Audit — 18./19.05.2026 | v0.9.9+73–75

**Audit-Datum:** 18.05.2026 (Folgemessungen 19.05.2026)
**Lighthouse-Version:** aktuell (Navigationsmodus)
**Ziel-URL:** `http://localhost:8081`
**Emulation:** Moto G Power (Mobil), simuliertes Netzwerk
**Renderer:** Flutter Web — Skwasm (WASM-Renderer)
**Drittanbieter:** Google CDN (Skwasm), Google Fonts

---

### 📊 Score-Entwicklung

| Datum | Version | Performance | Barrierefreiheit | Best Practices | SEO | Anmerkung |
|:--|:--|:--|:--|:--|:--|:--|
| 12.05.2026 | 0.9.9+70 | **62** | **92** | **81** | **91** | Ausgangslage |
| 18.05.2026 | 0.9.9+73 | **75** | **92** | **81** | **63** | Nach WASM-Build |
| 18.05.2026 | 0.9.9+74 | **88** | **92** | **81** | **63** | Nach Performance-Fixes |
| 19.05.2026 | 0.9.9+75 | **56** | **92** | **77** | **63** | Mit Login (schwankend) |
| 19.05.2026 | 0.9.9+75 | **58** | **92** | **77** | **63** | Mit Login (schwankend) |
| 19.05.2026 | 0.9.9+75 | **55** | **92** | **77** | **63** | Mit Login (schwankend) |
| 19.05.2026 | 0.9.9+75 | **58** | **92** | **81** | **63** | Mit Login |
| 19.05.2026 | 0.9.9+75 | **72** | **92** | **81** | **63** | Ohne Login |
| 19.05.2026 | 0.9.9+75 | **75** | **92** | **81** | **100** | Ohne Login — Zielzustand ✅ |

### 📐 Kernmetriken-Entwicklung

| Datum | Version | FCP | LCP | TBT | CLS | SI | Anmerkung |
|:--|:--|:--|:--|:--|:--|:--|:--|
| 12.05.2026 | 0.9.9+70 | 0,95 s | 1,57 s | 705 ms | — | — | Ausgangslage |
| 18.05.2026 | 0.9.9+73 | 0,9 s | 1,4 s | 430 ms | 0 | 6,6 s | Nach WASM-Build |
| 18.05.2026 | 0.9.9+74 | 0,6 s | 1,0 s | 310 ms | 0 | 6,1 s | Nach Performance-Fixes |
| 19.05.2026 | 0.9.9+75 | 1,7 s | 2,6 s | 14.760 ms | 0,015 | 227,0 s | Mit Login — TBT-Ausreißer |
| 19.05.2026 | 0.9.9+75 | 1,2 s | 2,3 s | 15.380 ms | 0,007 | 173,2 s | Mit Login — TBT-Ausreißer |
| 19.05.2026 | 0.9.9+75 | 0,6 s | 2,9 s | 15.300 ms | 0,007 | 205,1 s | Mit Login — TBT-Ausreißer |
| 19.05.2026 | 0.9.9+75 | 1,2 s | 2,3 s | 17.470 ms | 0,015 | 231,6 s | Mit Login — TBT-Ausreißer |
| 19.05.2026 | 0.9.9+75 | 0,6 s | 1,2 s | 1.030 ms | 0 | 6,7 s | Ohne Login ✅ |
| 19.05.2026 | 0.9.9+75 | 0,8 s | 1,5 s | 780 ms | 0 | 6,6 s | Ohne Login ✅ |

> **Anmerkung zu TBT-Ausreißern mit Login:**
> Die massiv erhöhten TBT-Werte (14.000–17.000 ms) bei eingeloggtem Zustand sind auf
> den initialen Sync-Vorgang nach Login zurückzuführen (PocketBase-Abfragen, SQLite-Writes,
> WASM-Initialisierung parallel). Ohne Login entfällt dieser Overhead — TBT normalisiert
> sich auf ~800–1.000 ms.

---

### ⚡ Performance — Detailbefunde

#### Kritische Befunde

| Kürzel | Befund | Ursache | Status |
|:--|:--|:--|:--|
| LH-P-001 | Render-blockierendes `config.js` (152 ms) | `<script>` ohne `defer` | ✅ Erledigt v0.9.9+74 |
| LH-P-002 | Hohe TBT (705 ms) | Skwasm-WASM-Initialisierung | 🟡 Teilweise — WASM-Build hilft |
| LH-P-003 | Speed Index > 3,4 s | Flutter Skwasm strukturell | ⚠️ Bewusst akzeptiert |
| LH-P-004 | Fehlende Cache-Control-Header | Statische Assets ohne Cache | ✅ Erledigt v0.9.9+74 |
| LH-P-005 | `manifest.json` 107 ms Latenz | Fehlender Preload-Hint | ✅ Erledigt v0.9.9+74 |

#### Netzwerk-Übersicht (Ausgangslage v0.9.9+73)

**Gesamtgröße:** 2.979 KB (Transfer)

| Ressource | Typ | Größe (Transfer) | Entität |
|:--|:--|:--|:--|
| `skwasm.wasm` | WASM | ~1.180 KB | Google CDN |
| `skwasm.js` | Script | ~15 KB | Google CDN |
| Roboto + weitere Fonts | Font | ~174 KB | Google Fonts |
| LCP-Bild (`splash/img/light-2x.png`) | Image | 256×256 px | Eigene App |

#### Drittanbieter-Analyse

| Anbieter | Übertragungsgröße | Hauptthread-Zeit | Bewertung |
|:--|:--|:--|:--|
| Google CDN (Skwasm) | ~1.195 KB | 119 ms | 🔴 Größter Verursacher |
| Google Fonts (Roboto) | ~174 KB | 0 ms | 🟡 Lokal hostbar |

#### Bewusst akzeptiert (Performance)

| Befund | Begründung |
|:--|:--|
| Speed Index > 3,4 s | Flutter Skwasm strukturell — kein Fix ohne Renderer-Wechsel |
| TTI > 3,8 s | WASM-Initialisierung — WASM-Build ist effektivster Hebel |
| Unused Code in Skwasm | Flutter-Web-typisch, Tree Shaking auf JS-Ebene begrenzt |
| Fehlende Source Maps | Release-Build-Standard, akzeptabel |
| Google Fonts extern | Lokalisierung als optionale Optimierung (LH-P-006) |

---

### ♿ Barrierefreiheit — Detailbefunde

**Score: 92 / 100** — strukturelle Decke durch Flutter Canvas-Rendering

| Kürzel | Befund | Gewicht | Status |
|:--|:--|:--|:--|
| LH-A-001 | Kein `<main>`-Landmark | 3 | ⚠️ Strukturell — Flutter Canvas |
| LH-A-002 | `meta-viewport user-scalable=no` | 10 | ⚠️ Bewusst akzeptiert — Flutter setzt automatisch |

> Score 92 ist das realistische Maximum für Flutter Web mit Canvas-Rendering.

---

### ✅ Best Practices — Detailbefunde

**Score: 81 / 100**

| Kürzel | Befund | Status |
|:--|:--|:--|
| LH-B-001 | `SharedArrayBuffer` ohne Isolation / `Intl.v8BreakIterator` deprecated | COOP/COEP ✅ v0.9.9+73 — `Intl` ⚠️ bewusst akzeptiert |
| LH-B-002 | Kein HTTPS (Entwicklungsumgebung) | ✅ In Produktion behoben (H-004.2) |
| LH-B-003 | `X-Frame-Options` fehlt | ❌ Offen → H-005.3 |
| LH-B-004 | Third-Party-Cookies (Google CDN/Fonts) | ✅ Geprüft — keine Cookies gesetzt |

#### Bewusst akzeptiert (Best Practices)

| Befund | Begründung |
|:--|:--|
| CSP `unsafe-inline` | Flutter Web benötigt Inline-Scripts — Fix würde App brechen |
| `Trusted-Types` fehlt | Flutter Web inkompatibel |
| `Intl.v8BreakIterator` deprecated | Flutter Engine — Fix kommt mit Flutter-Update |

---

### 🔍 SEO — Detailbefunde

**Score: 63 → 100** (nach H-005.1 + H-005.2 in v0.9.9+75)

| Kürzel | Befund | Gewicht | Status |
|:--|:--|:--|:--|
| LH-S-001 | `is-crawlable` — `robots.txt Disallow: /` | ~4 | ✅ Behoben v0.9.9+75 (H-005.1) |
| LH-S-002 | Fehlende Meta-Description | 1 | ✅ Behoben v0.9.9+75 (H-005.2) |
| LH-S-003 | Fehlender Dokument-Titel | 1 | ✅ Behoben v0.9.9+75 (H-005.2) |
| LH-S-004 | Flutter Canvas — Inhalte nicht indexierbar | — | ⚠️ Strukturell akzeptiert |

> **Wichtiger Hinweis:** Flutter Web rendert in `<canvas>`. Suchmaschinen können
> App-Inhalte strukturell nicht lesen. SEO-Optimierungen betreffen primär technische
> Crawlability, nicht inhaltliche Indexierung. Für eine interne App ist das akzeptabel.

---

### 🎯 Abgeleitete Maßnahmen (Übersicht)

Alle Maßnahmen sind in `OPTIMIZATION.md` unter **H-004** und **H-005** vollständig dokumentiert.

| Maßnahme | Beschreibung | Status |
|:--|:--|:--|
| H-004.1 | `robots.txt` bereitstellen | ✅ v0.9.9+73 |
| H-004.2 | HSTS-Header setzen | ✅ v0.9.9+73 |
| H-004.3 | Splash-Bild Dimensionen + `fetchpriority` | ✅ v0.9.9+74 |
| H-004.4 | `--tree-shake-icons` im Build | ✅ v0.9.9+74 |
| H-004.5 | WASM-Build (Skwasm) | ✅ v0.9.9+73 |
| H-005.1 | `robots.txt` auf `Allow: /` | ✅ v0.9.9+75 |
| H-005.2 | Meta-Description + Title | ✅ v0.9.9+75 |
| H-005.3 | `X-Frame-Options`-Header | ❌ Offen |

--- 

### O-014: Nextcloud-Code entkoppeln und entfernen — abgeschlossen 2026-05-16 | `0.9.9+70`
**Beschreibung:**
~1.870 Zeilen Nextcloud-Code und die Dependency `webdav_client` sind im Projekt,
obwohl Nextcloud unter „Future (nicht in Planung)" steht. Der Code ist jedoch
nicht isoliert — Nextcloud-Imports existieren in:
- `artikel_import_service.dart` (Nextcloud-Import-Pfad)
- `artikel_export_service.dart` (Nextcloud-Export-Pfad)
- `artikel_list_screen.dart` (vermutlich Menüpunkt/Button)
- `sync_service.dart` (wird von 7 Dateien importiert für `ConflictData`,
  `ConflictResolution`, `SyncService`-Interface, `SyncProgressService`,
  `SyncErrorRecoveryService`)

**Ziel:**
1. `ConflictData`, `ConflictResolution`, `SyncResult` und das Adapter-Interface
   in eigene Datei extrahieren (z. B. `lib/services/conflict_types.dart`)
2. Nextcloud-Referenzen aus Import-/Export-Services entfernen
   (Conditional Imports auf Stubs umleiten oder Nextcloud-Pfade entfernen)
3. Nextcloud-Menüpunkt aus `artikel_list_screen.dart` entfernen
4. Alle Nextcloud-Dateien entfernen
5. `webdav_client` aus `pubspec.yaml` entfernen

**Betroffene Dateien (Entkopplung):**
- `lib/services/sync_service.dart` → Conflict-Types extrahieren, Rest entfernen
- `lib/services/artikel_import_service.dart` → Nextcloud-Pfad entfernen
- `lib/services/artikel_export_service.dart` → Nextcloud-Pfad entfernen
- `lib/screens/artikel_list_screen.dart` → Nextcloud-UI entfernen
- `lib/main.dart` → Import von `sync_service.dart` auf neue Datei umstellen

**Zu löschende Dateien:**
- `lib/services/nextcloud_client.dart`
- `lib/services/nextcloud_webdav_client.dart`
- `lib/services/nextcloud_sync_service.dart`
- `lib/services/nextcloud_connection_service.dart`
- `lib/services/nextcloud_credentials.dart`
- `lib/services/nextcloud_service_interface.dart`
- `lib/services/export_nextcloud.dart`
- `lib/services/export_nextcloud_stub.dart`
- `lib/services/import_nextcloud.dart`
- `lib/screens/nextcloud_settings_screen.dart`
- `lib/widgets/nextcloud_resync_dialog.dart`
- `lib/services/sync_service.dart`

**Aufwand:** ~3–4 Stunden (wegen Entkopplung)
**Risiko:** Mittel — Import-/Export-Pfade und List-Screen betroffen

**Tasks:**
- [ ] `conflict_types.dart` mit ConflictData, ConflictResolution, SyncResult extrahieren
- [ ] Alle 7 Dateien die `sync_service.dart` importieren auf neue Imports umstellen
- [ ] Nextcloud-Pfade aus Import-/Export-Services entfernen
- [ ] Nextcloud-UI aus `artikel_list_screen.dart` entfernen
- [ ] 12 Nextcloud-Dateien + `sync_service.dart` löschen
- [ ] `webdav_client` aus pubspec.yaml entfernen
- [ ] Betroffene Tests anpassen
- [ ] `flutter analyze` + `flutter test` grün
- [ ] PROJECT_STRUCTURE.md aktualisieren

---

### O-020: `_PocketBaseConflictAdapter` aus `main.dart` ausgelagert — abgeschlossen 2026-05-16 | `0.9.9+68`
Neue Datei `lib/services/pocketbase_conflict_adapter.dart`. Klasse ist jetzt public
(`PocketBaseConflictAdapter`) und ohne `main.dart`-Abhängigkeit wiederverwendbar.
`main.dart`: Import ergänzt, `_`-Prefix entfernt, keine Logik geändert.
`artikel_db_service.dart`: Singleton auf `_db` — Aufteilung würde Komplexität erhöhen
ohne Gewinn — kein Handlungsbedarf.

--- 

### O-019: `print()` in `app_config.dart` durch Logger ersetzen — abgeschlossen 2026-05-16 | `0.9.9+67`
**Beschreibung:**
Eine `print()`-Stelle in `app_config.dart:99` (innerhalb `assert`).
Funktional harmlos (nur Debug), aber inkonsistent mit dem sonst
durchgängig genutzten `AppLogService.logger`.

**Aufwand:** 5 Minuten
**Risiko:** Keins

**Tasks:**
- [x] `print()` durch `AppLogService.logger.w()` ersetzen
- [x] `assert`-Wrapper ggf. entfernen (Logger hat eigenen Level-Filter)

--- 

### O-016: Timeouts in AppConfig zentralisieren — abgeschlossen 2026-05-16 | `0.9.9+66`
**Beschreibung:**
Timeout-Werte sind über 6+ Service-Dateien als lokale Konstanten oder
Inline-Literals verstreut. `AppConfig.networkTimeout` (12s) existiert,
wird aber von den meisten Services nicht genutzt.

**Ziel:**
Alle Timeout-Konstanten in `AppConfig` bündeln, ohne die Werte zu ändern:

| Konstante | Wert | Ersetzt |
|-----------|------|---------|
| `networkTimeout` | 12s | Bereits vorhanden |
| `syncPushTimeout` | 30s | `_kPushRequestTimeout` |
| `syncUploadTimeout` | 120s | `_kPushUploadTimeout` |
| `connectivityCheckTimeout` | 3s | Inline in `connectivity_service.dart` |
| `backupStatusTimeout` | 5s | Inline in `backup_status_service.dart` |

Nextcloud-Timeouts werden nicht migriert (entfallen mit O-014).

**Aufwand:** ~1 Stunde
**Risiko:** Sehr niedrig — nur Konstantenverlagerung, keine Wertänderung

**Tasks:**
- [x] Timeout-Konstanten in `AppConfig` ergänzen
- [x] Services auf `AppConfig.*Timeout` umstellen
- [x] Lokale `_k*`-Konstanten entfernen
- [x] `flutter analyze` + `flutter test` grün

--- 
---

### F-011: Responsive/Adaptive Layout für Desktop-Web
**Beschreibung:**
Die App ist für mobile Fenstergrößen konzipiert. Auf Desktop-Monitoren wird die UI
über die volle Breite gestreckt, was die Nutzbarkeit einschränkt. Schrittweise
Umstellung auf responsive/adaptive Layouts in drei Stufen.

**Grundprinzip:** Widgets klein und wiederverwendbar halten. Listenansicht und
Detailansicht als eigenständige Widgets (nicht als eigene Screens mit Navigation)
extrahieren – das ist die wichtigste Vorbereitung für Master-Detail in Stufe 3.

---

**Tasks nach Stufe:**

#### Stufe 1 — Maximalbreite begrenzen (~30 min)

- [x] **F-011.1: Zentrale Maximalbreite einführen**
  App-Inhalt auf max. 600px begrenzen und zentrieren. Verhindert dass die mobile UI
  auf breiten Monitoren gestreckt wird.

  ```dart
  // In main.dart oder im zentralen Scaffold:
  body: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: actualContent, // bisheriger Body
    ),
  ),
  ```

  **Wirkung:** Sofort besser lesbar auf Desktop

#### Stufe 2 — Responsive Anpassungen (~4–8 h)

Ziel: Widgets responsive machen und als eigenständige, wiederverwendbare Komponenten
extrahieren. Alles hier Gebaute wird in Stufe 3 wiederverwendet.

- [x] **F-011.2: Breakpoint-Helfer einführen**
  Zentrale Breakpoint-Definitionen anlegen.

  ```dart
  // lib/core/responsive.dart
  class Breakpoints {
    static const double mobile = 600;
    static const double tablet = 900;
    static const double desktop = 1200;
  }

  bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < Breakpoints.mobile;
  bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.mobile &&
      MediaQuery.of(context).size.width < Breakpoints.desktop;
  bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.desktop;
  ```

- [x] **F-011.3: Artikelliste als eigenständiges Widget extrahieren**
  `ArtikelListWidget` aus dem aktuellen Screen herauslösen. Auf breiten Screens
  als Grid (2–3 Spalten) statt einspaltige Liste darstellen.

  ```dart
  // Beispiel: Grid auf Desktop, Liste auf Mobil
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 3,
        ),
        itemBuilder: (context, index) => ArtikelTile(artikel: items[index]),
        itemCount: items.length,
      );
    }
    return ListView.builder(
      itemBuilder: (context, index) => ArtikelTile(artikel: items[index]),
      itemCount: items.length,
    );
  }
  ```

- [x] **F-011.4: Detailansicht als eigenständiges Widget extrahieren**
  `ArtikelDetailWidget` aus dem Detail-Screen herauslösen. Felder auf breiten
  Screens nebeneinander gruppieren statt untereinander.

  ```dart
  // Beispiel: Wrap für responsive Feldanordnung
  Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      SizedBox(width: fieldWidth, child: nameField),
      SizedBox(width: fieldWidth, child: categoryField),
      SizedBox(width: fieldWidth, child: locationField),
    ],
  )
  ```

- [x] **F-011.5: Navigation responsive machen**
  `BottomNavigationBar` auf Desktop durch `NavigationRail` ersetzen.

  ```dart
  Widget build(BuildContext context) {
    if (isMobile(context)) {
      return Scaffold(
        body: currentPage,
        bottomNavigationBar: BottomNavigationBar(...),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onTabChanged,
            destinations: [...],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: currentPage),
        ],
      ),
    );
  }
  ```

- [x] **F-011.6: Settings-Screen responsive machen**
  Einstellungen auf breiten Screens zweispaltig anordnen.

  **Wirkung Stufe 2 gesamt:** Deutlich bessere Desktop-Nutzbarkeit.
  Alle Widgets sind für Stufe 3 vorbereitet.

#### Stufe 3 — Adaptive Layouts / Master-Detail (~1–2 Tage)

Voraussetzung: Stufe 2 abgeschlossen (Widgets extrahiert und responsive).
Aufwand halbiert sich durch Vorarbeit aus Stufe 2.

- [x] **F-011.7: Master-Detail-Layout für Artikelverwaltung**
  Auf Desktop (≥1024px): Links NavigationRail + Artikelliste (flex 2),
  rechts Detail-Panel mit `ArtikelDetailContent` (flex 3).
  
  **Architektur:**
  - `ArtikelDetailContent` als eigenständiges Widget extrahiert
    (`lib/widgets/artikel_detail_content.dart`) — enthält gesamte Detail-Logik
  - `ArtikelDetailScreen` ist dünner Scaffold-Wrapper für Mobile-Navigation
    mit `ValueNotifier`-basiertem AppBar-Rebuild
  - `embedded`-Parameter steuert ob Content im Scaffold oder inline läuft
  - `onStateChanged`-Callback synchronisiert Wrapper mit Content-State
  - `didUpdateWidget` reinitialisiert bei Artikelwechsel (Desktop)
  - `_ladeAnhangCount()` mit try/catch abgesichert (Test-Kompatibilität)
  - `maxContentWidth` auf 1400 erhöht, `ConstrainedBox` nur Mobile/Tablet
  - Neue `AppConfig`-Konstanten: `masterDetailMinWidth`, `masterListFlex`,
    `masterDetailFlex`, `breakpointTablet`, `breakpointDesktop`
  - `lib/core/responsive.dart`: `ScreenSize` enum + `Responsive.fromConstraints()`

  **Betroffene Dateien:**
  | Datei | Änderung |
  |:--|:--|
  | `lib/widgets/artikel_detail_content.dart` | Neu — extrahiertes Detail-Widget |
  | `lib/screens/artikel_detail_screen.dart` | Scaffold-Wrapper mit ValueNotifier |
  | `lib/screens/artikel_list_screen.dart` | Master-Detail auf Desktop |
  | `lib/config/app_config.dart` | Breakpoints, Flex-Werte, maxContentWidth |
  | `lib/core/responsive.dart` | Breakpoint-Helfer (bereits vorhanden, erweitert) |
  | `lib/main.dart` | ConstrainedBox nur Mobile/Tablet |

  **Tests:** 24 + 15 + 11 = 50 Widget-Tests grün
  ```dart
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      return Row(
        children: [
          SizedBox(
            width: 400,
            child: ArtikelListWidget(
              onArtikelSelected: (a) => setState(() => selected = a),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: selected != null
                ? ArtikelDetailWidget(artikel: selected!)
                : const Center(child: Text('Artikel auswählen')),
          ),
        ],
      );
    }
    // Mobil: Navigation wie bisher
    return ArtikelListWidget(
      onArtikelSelected: (a) => Navigator.push(...),
    );
  }
  ```

- [x] **F-011.8: NavigationRail → Sidebar mit Labels erweitern**
  Auf Desktop die NavigationRail zu einer vollständigen Sidebar mit Icons + Labels
  und ggf. Untermenüs erweitern.

- [x] **F-011.9: Dialoge → Seitenpanels auf Desktop**
  Modale Dialoge (z.B. Artikel-Bearbeitung) auf Desktop als Seitenpanel statt
  Fullscreen-Dialog darstellen.

---

**Aufwand gesamt:**

| Stufe | Aufwand | Kumuliert | Status |
|:--|:--|:--|:--|
| Stufe 1 | ~30 min | 30 min | ✅ |
| Stufe 2 | ~4–8 h | 5–9 h | ✅ |
| Stufe 3 | ~1–2 Tage | 2–3 Tage | 🟡 F-011.7 ✅, F-011.8–F-011.9 offen |

**Risiko:** Niedrig (Stufe 1–2), Mittel (Stufe 3 — Navigationslogik-Umbau)

**Hinweis:** Stufe 2 ist so konzipiert, dass alle Arbeit in Stufe 3 wiederverwendet wird.
Der Aufwand für Stufe 3 halbiert sich durch die Vorarbeit aus Stufe 2.

--- 

### O-017: `catch (e)` durch `catch (e, st)` ersetzen
**Beschreibung:**
Mehrere produktive Services fangen Exceptions ohne StackTrace (`catch (e)` statt
`catch (e, st)`). Dadurch geht bei Fehlerdiagnose die Aufrufkette verloren.

**Betroffene produktive Dateien:**
- `pdf_service_shared.dart` (1×)
- `scan_service_stub.dart` (1×)
- `app_log_io.dart` (4×)
- `artikel_import_service.dart` (2×)

Nextcloud-Dateien (9+ Stellen) entfallen mit O-014.

**Aufwand:** ~30 Minuten
**Risiko:** Sehr niedrig

**Tasks:**
- [x] `catch (e)` → `catch (e, st)` in den 4 produktiven Dateien
- [x] StackTrace an Logger-Aufrufe durchreichen
- [x] `flutter analyze` grün

--- 


### B-018: Artikelnummer wird bei Suche/Scan nicht gefunden
**Beschreibung:**
Bei der Suche nach einer Artikelnummer (z.B. "1029") wird der Artikel nicht gefunden,
obwohl er vorhanden ist. Betrifft sowohl die manuelle Suche als auch den
Web-Fallback-Dialog (Texteingabe statt QR-Scanner).

**Reproduktion:**
1. Scan-Button klicken
2. Auf Web: Texteingabe-Dialog erscheint ("QR-Scanner ist auf dieser Plattform nicht verfügbar")
3. Artikelnummer "1029" eingeben
4. Artikel wird nicht gefunden ❌

**Ursache (vermutet):**
Das Feld `artikelnummer` (o.ä.) ist nicht in der Such-/Filterlogik enthalten.
Die Suche durchsucht vermutlich nur `name`, `beschreibung` oder ähnliche Felder.

**Betrifft:** Alle Plattformen (nicht Web-spezifisch)

**Auswirkung:**
- Kernfunktion der App eingeschränkt — Artikel können nicht über Artikelnummer
  gefunden werden
- Web-Fallback-Dialog (Texteingabe statt Scanner) ist dadurch funktionslos

---

**Tasks:**

- [x] **B-018.1: Suchlogik um Artikelnummer erweitern**
  Im Such-/Filter-Code das Feld `artikelnummer` (oder entsprechendes Model-Feld)
  zur Suche hinzufügen.

  ```dart
  // Vermutlich in der Suchlogik so ähnlich:
  bool matchesSearch(Artikel artikel, String query) {
    return artikel.name.toLowerCase().contains(query.toLowerCase()) ||
           artikel.beschreibung.toLowerCase().contains(query.toLowerCase()) ||
           artikel.artikelnummer.toLowerCase().contains(query.toLowerCase()); // ← fehlt vermutlich
  }
  ```

- [x] **B-018.2: Web-Fallback-Dialog Ergebnis korrekt verarbeiten**
  Prüfen ob der Rückgabewert des Texteingabe-Dialogs korrekt an die Suchlogik
  weitergeleitet wird (gleicher Codepfad wie Scanner-Ergebnis).

- [x] **B-018.3: Testen auf allen Plattformen**
  Nach Fix verifizieren:
  - [x] Android: Scanner findet Artikel 1029
  - [x] Android: Manuelle Suche findet Artikel 1029
  - [x] Web: Texteingabe-Fallback findet Artikel 1029

---

**Aufwand:** ~30–60 min
**Priorität:** 🔴 Hoch (Kernfunktion)
**Risiko:** Niedrig

---


### P-007: UI-Performance `ArtikelListScreen` — Filter-Cache, setState-Reduktion, Widget-Extraktion  
**Beschreibung:**  
Analyse des tatsächlichen Codes (13.05.2026) hat fünf konkrete Performance-Befunde  
in `artikel_list_screen.dart` identifiziert. Alle Befunde liegen ausschließlich im  
UI-Layer — kein Eingriff in Sync-Logik erforderlich.  

**Hintergrund:**  
Nach B-018 (Artikelnummer-Suche) wurde ein zäheres Scroll-Verhalten beobachtet.  
Die eigentliche Ursache ist nicht B-018 selbst, sondern dass `_gefilterteArtikel()`  
bei jedem `build()` neu berechnet wird und `setState()` aus mehreren Quellen  
häufig feuert. B-018 hat den Effekt verstärkt, war aber nicht die Ursache.  

**Identifizierte Befunde:**  

| Kürzel | Befund | Prio |  
|:---|:---|:---|  
| P-007.1 | `_gefilterteArtikel()` bei jedem `build()` neu berechnet — keine Cachierung | 🔴 |  
| P-007.2 | `setState()` bei jedem Keystroke im Suchfeld (vor Debounce) | 🔴 |  
| P-007.3 | `_aktualisiereFilter()` ruft eigenes `setState()` auf — doppelter `build()` bei Pagination | 🟡 |  
| P-007.4 | `_buildArtikelTile()` als State-Methode — Flutter kann Widget-Identität nicht cachen | 🟡 |  
| P-007.5 | Scroll-Guard `_isLoadingMore` zu spät im `_onScroll()`-Pfad | 🟢 |  

**Positiv bestätigt (kein Handlungsbedarf):**  
- `ListView.builder` korrekt verwendet ✅  
- `ArtikelListBild` als eigenes Widget ✅  
- Debounce auf DB-Suche vorhanden ✅  

---  

**Tasks:**  

- [x] **P-007.1: `_gefilterteArtikel()` cachen**  
  Ergebnis nur neu berechnen wenn sich Basis-Liste, `_filterOrt` oder  
  `_filterKategorie` tatsächlich geändert haben. Cache-Invalidierung via  
  `identical()`-Referenzcheck auf die Basis-Liste.  

  ```dart
  List<Artikel> _gefilterteArtikelCache = [];
  String _letzterFilterOrt = '';
  String _letzterFilterKategorie = '';
  List<Artikel>? _letzteFilterBasis;

  List<Artikel> _gefilterteArtikel() {
    final basis = _suchbegriff.isNotEmpty ? _suchErgebnisse : _artikelListe;
    if (identical(basis, _letzteFilterBasis) &&
        _filterOrt == _letzterFilterOrt &&
        _filterKategorie == _letzterFilterKategorie) {
      return _gefilterteArtikelCache;
    }
    _letzteFilterBasis = basis;
    _letzterFilterOrt = _filterOrt;
    _letzterFilterKategorie = _filterKategorie;
    _gefilterteArtikelCache = basis.where((a) {
      if (_filterOrt.isNotEmpty && a.ort != _filterOrt) return false;
      if (_filterKategorie.isNotEmpty &&
          (a.kategorie ?? '') != _filterKategorie) return false;
      return true;
    }).toList();
    return _gefilterteArtikelCache;
  }
  ```  

Wirkung: Sync-Status-Updates, _isLoadingMore-Toggles und andere  
setState()-Aufrufe die Filter/Basis nicht ändern lösen keine Neu-Berechnung aus.  
Regressionsrisiko: Niedrig — Logik identisch, nur gecacht.  

- [x] **P-007.2: setState() aus _onSuchbegriffChanged() entfernen**  
  _suchbegriff erst nach Debounce in _fuehreSucheAus() setzen statt  
  bei jedem Keystroke sofort.  

  ```dart
  void _onSuchbegriffChanged(String value) {
    _debounceTimer?.cancel();
    // setState() entfernt — TextField zeigt Text intern korrekt an
    _debounceTimer = Timer(
      const Duration(milliseconds: 500),
      () => _fuehreSucheAus(value),
    );
  }
  ```  

Wirkung: Bei Eingabe von „1029" feuert setState() 1× statt 4×.  
Regressionsrisiko: Sehr niedrig — TextField steuert Anzeige intern.  

- [x] **P-007.3: _aktualisiereFilter() ohne eigenes setState()**  
  Filter-Werte direkt im bestehenden setState() von _ladeArtikel() und  
  _ladeNaechsteSeite() setzen — kein separater setState()-Aufruf.  

  Wirkung: Pro Pagination-Seite 1 setState() statt 2.  
  Regressionsrisiko: Niedrig.  

- [x] **P-007.4: _buildArtikelTile() als eigenes StatelessWidget extrahieren**  
  Neues _ArtikelTile-Widget mit artikel und onTap als Parameter.  
  Flutter kann Widget-Identität über Rebuilds hinweg tracken — Tiles mit  
  unverändertem artikel-Objekt werden nicht neu gebaut.  

  Hinweis: Artikel.operator== ist über uuid definiert — Flutter-  
  Reconciliation funktioniert korrekt. Bestehende Widget-Tests auf neuen  
  Widget-Namen _ArtikelTile prüfen.  
  Regressionsrisiko: Niedrig — reine Extraktion, keine Logikänderung.  

- [x] **P-007.5: Scroll-Guard früher im _onScroll()-Pfad**  
  _isLoadingMore- und _hasMore-Check vor dem Pixel-Vergleich.  

  ```dart
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || !_hasMore) return; // ← früher Guard
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _ladeNaechsteSeite();
    }
  }
  ```  

Wirkung: Redundante _ladeNaechsteSeite()-Aufrufe zwischen erstem  
Aufruf und nächstem build() verhindert.  
Regressionsrisiko: Keins.

--- 



### F-008: Hintergrund-Sync-Intervall konfigurierbar — abgeschlossen 2026-05-08 | `0.9.5+54`
**Beschreibung:** Das automatische Sync-Intervall war hart auf 15 Minuten eingestellt. Der Nutzer kann jetzt im Einstellungs-Screen ein Intervall wählen.

**Optionen:**
- 1 Minute
- 5 Minuten
- 15 Minuten (Standard)
- Nur manuell (kein Timer, Sync nur via Pull-to-Refresh)

**Architektur:**
Callback-Pattern analog zu `onLogout`:
```
SettingsScreen.onSyncIntervalChanged(int seconds)
  → SettingsController.setSyncInterval()
    → SharedPreferences persistieren
    → Callback an main.dart
      → _startPeriodicSync() mit neuem Intervall
```
Änderungen greifen sofort ohne App-Neustart.

**Persistenz:** `SharedPreferences` Key `sync_interval_seconds` (int, Default 900)

**Betroffene Dateien:**
| Datei | Änderung |
|-------|----------|
| `lib/screens/settings_controller.dart` | Feld `syncIntervalSeconds`, Laden/Speichern, Callback, Formatter |
| `lib/screens/settings_screen.dart` | Neue Sync-Card mit Dropdown, `onSyncIntervalChanged` Parameter |
| `lib/main.dart` | `_syncIntervalSeconds` statt Konstante, `_onSyncIntervalChanged()` Callback, Timer-Neustart |

**Tasks:**
- [x] Settings-UI: Dropdown mit 1, 5, 15 Min, Aus
- [x] Refactor von `_startPeriodicSync()` — liest dynamisches Intervall
- [x] Persistenz in SharedPreferences
- [x] Callback-Kette durch ArtikelListScreen durchgereicht
- [x] SnackBar Auto-Dismiss (3s, ohne Action)
- [x] Gerätetest auf Samsung SM A515F bestanden
- [x] Unit-Tests: Scheduler startet/aktualisiert Timer korrekt
- [x] Widget-Test: UI-Einstellung speichert und reflektiert Wert

--- 

### B-016: `remoteBildPfad` wird beim Bild-Entfernen nicht in PocketBase geleert — abgeschlossen 2026-05-08 | `0.9.5+51`
**Entdeckt bei:** P-004, Test 5 (Bild entfernen)
**Schwere:** Niedrig

**Beschreibung:**
Beim Entfernen eines Bildes (M-013) wurde das `bild`-Feld in PocketBase korrekt auf `null` gesetzt und die Bilddatei gelöscht. Das Textfeld `remoteBildPfad` blieb jedoch mit dem alten Dateinamen stehen.

**Fix:**
Im Push-Update-Pfad von `pocketbase_sync_service.dart` wird jetzt `body['remoteBildPfad'] = ''` zusammen mit `body['bild'] = null` gesendet.

**Betroffene Datei:** `lib/services/pocketbase_sync_service.dart` — 1 Zeile hinzugefügt

**Verifiziert (08.05.2026):**
- PocketBase Admin: `bild` = leer ✅
- PocketBase Admin: `remoteBildPfad` = leer ✅
- Kein Follow-up-PATCH ausgelöst (korrekt) ✅
- `downloadMissingImages` überspringt korrekt ✅

--- 

### B-017: Kurzer BlueScreen bei Kamera-Permission-Entzug zur Laufzeit - Abgeschlossen 2026-05-08 | `0.9.5+54`
**Entdeckt bei:** P-004, Test 7.4 (Permission verweigern)
**Schwere:** Niedrig (herabgestuft von Mittel nach Analyse)
**Status:** Bekanntes Android-Verhalten — kein Fix nötig

**Beschreibung:**
Wird die Kamera-Permission in den Android-Einstellungen entzogen, während die App im Hintergrund ist, beendet Android die Activity sofort (Security-Policy). Dabei kann kurzzeitig ein BlueScreen (Flutter-ErrorWidget) aufblitzen, bevor Android die Activity neu erstellt und Flutter komplett von vorne startet.

**Analyse (07.05.2026):**
Die Logs zeigen keinen Stacktrace und keine unbehandelte Exception. Stattdessen wird der Prozess sauber beendet (PID-Wechsel) und die App startet komplett neu — inklusive Login-Screen. Kein Datenverlust, kein korrupter Zustand. Der „BlueScreen" ist der kurze Moment zwischen Activity-Kill und Neustart, in dem Flutter noch versucht, den alten Widget-Tree zu rendern.

**Verhalten:**
```
Permission in Android-Einstellungen geändert
  → Android beendet Activity (alter PID stirbt)
  → Android erstellt Activity neu (neuer PID)
  → Flutter startet komplett von vorne
  → Login-Screen erscheint (kein gespeicherter Token nach Prozess-Kill)
```

**Bewertung:**
- Kein Flutter-Bug, sondern erwartetes Android-OS-Verhalten
- Kein Datenverlust, kein korrupter DB-Zustand
- App startet nach Neustart sauber
- Nach Neustart mit entzogener Permission erscheint korrekt die Berechtigungsabfrage

**Fix (07.05.2026):** `ErrorWidget.builder` in `main()` überschrieben — zeigt `SizedBox.shrink()` statt rotem ErrorWidget. Fehler werden weiterhin geloggt. Rein kosmetisch, kein funktionaler Einfluss.

--- 

### P-004: Android Kamera-Test — abgeschlossen 2026-05-07 | `0.9.5+50`
**Beschreibung:** Vollständige manuelle Verifikation der Kamerafunktionalität auf Android (SM-A515F).

**Testmatrix**

| Test | Beschreibung | Ergebnis |
|------|-------------|----------|
| 1 | Kamera Happy Path (Aufnahme → Vorschau → Speichern → Sync → PocketBase) | ✅ |
| 2 | Kamera abbrechen (Zurück in Kamera-App) | ✅ |
| 3 | Kamera → Zuschneiden (Crop-Dialog mit Kamerabild) | ✅ |
| 4 | Kamera → Bild ersetzen (bestehendes Bild durch neues Kamerabild) | ✅ |
| 5 | Bild entfernen (M-013) — lokal + PocketBase | ⚠️ B-016 |
| 6 | Kamera bei Neuerfassung (neuer Artikel mit Kamerabild) | ✅ |
| 7.1 | Nicht speichern → Verwerfen-Dialog | ✅ |
| 7.2 | Verwerfen → alter Zustand wiederhergestellt | ✅ |
| 7.3 | Großes Foto (> 10 MB) | ✅ übersprungen — `maxWidth`/`maxHeight` in AppConfig greifen automatisch |
| 7.4 | Kamera-Permission verweigern | ❌ B-017 |
| 7.5 | App-Kill während Kamera-Intent (Low Memory) | ✅ sauberer Neustart, kein korrupter Zustand |

**Android-Konfiguration verifiziert**

| Prüfpunkt | Status |
|-----------|--------|
| `CAMERA`-Permission in AndroidManifest | ✅ |
| `uses-feature camera required="false"` | ✅ |
| `MainActivity` erbt von `FlutterFragmentActivity` | ✅ |
| `image_picker: ^1.2.0` (eigener FileProvider integriert) | ✅ |
| DB-Lifecycle bei Kamera-Intent (close/reopen) | ✅ |
| Thumbnail-Erzeugung nach Kamera-Aufnahme | ✅ |
| Hintergrund-Upload zu PocketBase (fire-and-forget) | ✅ |
| `downloadMissingImages` Round-Trip-Bestätigung | ✅ |

**Offene Befunde:** B-016, B-017


### O-013: Log-Viewer Default-Level in Einstellungen konfigurierbar ✅
**Beschreibung:**
User kann in den App-Einstellungen den Standard-Filter-Level für den
Entwickler-Log-Viewer wählen (Trace, Debug, Info, Warning, Error, Fatal).
Wird in SharedPreferences persistiert. Beim Öffnen des Log-Viewers
wird der gespeicherte Level als Default verwendet statt hardcoded
`Level.error`. Neue "Entwickler"-Card im Settings-Screen.

**Betroffene Dateien:**
- `app/lib/services/app_log_service.dart` — `_selectedLevel` aus SharedPreferences laden/speichern, `_levelToKey()`/`_levelFromKey()` Hilfsfunktionen
- `app/lib/screens/settings_screen.dart` — neue `_buildDeveloperCard()` mit persistiertem Dropdown
- `app/lib/config/app_config.dart` — `logViewerDefaultLevelPrefsKey` + `logViewerDefaultLevelFallback` Konstanten

**Aufwand:** ~94 Zeilen, ~25 Minuten (inkl. Lint-Fix)
**Abhängigkeiten:** Keine. Unabhängig von F-010.
**Status:** ✅ Abgeschlossen — manuell getestet

--- 

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

### O-010: `SettingsScreen` — Logik in testbaren Controller extrahieren — abgeschlossen 2026-04-23 | `0.9.1+29`
**Typ:** Refactoring / Testbarkeit  
**Betrifft:** `lib/screens/settings_screen.dart`, `lib/screens/settings_controller.dart`, `lib/screens/settings_state.dart`

`SettingsScreen` wurde fachlich sauber und minimal-invasiv refactored.
Persistente Settings-Logik, Laufzeit-State und Service-Orchestrierung
wurden in einen neuen `SettingsController` ausgelagert.

**Umsetzung**
- `settings_controller.dart` eingeführt
- `SettingsScreen` auf UI-nahe Verantwortung reduziert:
  - Dialoge
  - SnackBars
  - Navigation / Logout-Handling
  - Rendering
- In den Controller verschoben:
  - Laden und Speichern der Settings
  - Dirty-Tracking
  - PocketBase-URL prüfen / speichern / zurücksetzen
  - DB-Status prüfen
  - App-Lock-Status laden / speichern
- `TextEditingController` bewusst pragmatisch im Controller belassen
  (`artikelNummerController`, `pocketBaseUrlController`)

**Testauswirkung**
- `SettingsController` gezielt testbar gemacht
- zusätzliche Tests für Save-/Reset-/Dirty-State-Verhalten ergänzt
- Reject-/Success-Pfade von `saveSettings()` abgesichert


### F-007: Einstellung — Letzter-Sync-Zeitstempel ein-/ausblenden — abgeschlossen 2026-04-23 | `0.9.1+29`
**Typ:** Feature  
**Betrifft:** `lib/screens/settings_screen.dart`, `lib/screens/artikel_list_screen.dart`, `lib/screens/settings_state.dart`

Toggle in den Einstellungen, der den Sync-Zeitstempel in der
Artikelliste ein- oder ausblendet. Persistenz via SharedPreferences.

- Toggle in den Einstellungen ergänzt
- SharedPreferences-Key: `show_last_sync`
- Reaktive Wirkung ohne App-Neustart via `ValueNotifier<bool>`
- Default fachlich konsistent auf `true` vereinheitlicht
- `showLastSyncNotifier`, Prefs-Key und Default in
  `settings_state.dart` zentralisiert
- `ArtikelListScreen` bezieht den gemeinsamen State nicht mehr aus
  `settings_screen.dart`

F-007 — Hotfix in `v0.9.0+25`:
- `ValueListenableBuilder` in `ArtikelListScreen` ergänzt; Toggle war
  zuvor funktionslos, da der Notifier nie abgehört wurde

F-007 — Architektur-Bereinigung in `v0.9.1+29`:
- `showLastSyncNotifier` aus `settings_screen.dart` herausgelöst
- zentrale, UI-neutrale Datei `settings_state.dart` eingeführt
- gemeinsame State-Abhängigkeit vom Screen entkoppelt

### O-009: Widget-Tests `ArtikelListScreen` — abgeschlossen 2026-04-22 | `0.9.0+25`
- Import-Pfad korrigiert: `artikel.dart` → `artikel_model.dart`
- `erstelltAm` / `aktualisiertAm` als Pflichtfelder im Testartikel ergänzt
- `_pumpScreenWithArtikel()` Helper für Dropdown-Tests via `initialArtikel`
- Suchfeld-Label korrigiert: `'Suche...'` → `'Suche…'` (U+2026)
- Alle 15 Widget-Tests grün ✅
- Gesamtstand: **625 Tests**, 28 Dateien ✅


### F-006: Log-Level-Filter als Dropdown statt Button-Reihe — abgeschlossen 2026-04-22 | `0.9.0+25`
**Typ:** Feature / UX-Verbesserung  
**Betrifft:** Log-Dialog (`AppLogService.showLogDialog()`)

Button-Reihe für Trace/Debug/Info/Warn/Error/Fatal passt auf schmalen
Displays nicht in eine Zeile. Ersetzen durch `DropdownButton<Level>`
mit Default-Wert `Level.error`.

- Log-Dialog-Code lokalisieren (vermutlich `app_log_service.dart` oder separater Dialog)
- Button-Reihe durch `DropdownButton<Level>` ersetzen
- Default: `Level.error`
- Gefilterte Log-Ausgabe weiterhin korrekt aktualisieren
- Auf S20 (360dp) verifizieren


### B-012: Letzter-Sync-Zeitstempel auf schmalen Displays abgeschnitten — abgeschlossen 2026-04-22 | `0.9.0+25`
**Typ:** Bug / Regression (B-007-Commit)  
**Betrifft:** `lib/screens/artikel_list_screen.dart` → AppBar `title`

Das Sync-Label hat kein `overflow`-Handling und konkurriert auf 360dp
mit Action-Icons um Platz. Kein `TextOverflow`, kein `Flexible`-Wrapper.

- `overflow: TextOverflow.ellipsis` am Text ergänzen
- `Text` in `Flexible` wrappen um Layout-Constraints zu respektieren
- Nach B-009-Fix (Dropdown-Entfernung) erneut auf S20 prüfen — Problem könnte sich dadurch bereits teilweise lösen


### B-011: App-Version zeigt veralteten Build-Stand — abgeschlossen 2026-04-22 | `0.9.0+25`
**Typ:** Bug / Build-Prozess  
**Betrifft:** Build-Pipeline, kein Code-Fehler

`_getAppVersion()` in `settings_screen.dart` ist korrekt implementiert
und liest via `PackageInfo.fromPlatform()` aus den nativen
Build-Artefakten. Die angezeigte Version 0.8.8+23 stammt aus der
installierten APK — es wurde kein neuer Build nach dem Version-Bump
auf 0.8.9+24 erstellt oder die falsche APK installiert.

- `flutter build apk --release` mit aktuellem Stand ausführen
- Neue APK auf S20 installieren (vorherige deinstallieren)
- Version in Settings verifizieren → muss 0.8.9+24 zeigen
- Hinweis: `pubspec.yaml` zeigt bereits 0.9.0+25 —
  nach nächstem Release-Build wird 0.9.0+25 erscheinen ✅


### B-010: Snackbar-Feedback in Artikelliste fehlt — abgeschlossen 2026-04-22 | `0.9.0+25`
**Typ:** Bug / Regression (B-007-Commit)  
**Betrifft:** `lib/screens/artikel_list_screen.dart`

Nach Sync-Erfolg/-Fehler gibt es kein Snackbar-Feedback mehr.
Der `SyncStatus`-Listener ruft bei `success` nur `_ladeArtikel()` auf.
Fehler-Pfade zeigen keine Rückmeldung.

- Snackbar bei `SyncStatus.success` ergänzen
- Snackbar bei `SyncStatus.error` ergänzen (Fehlertext aus Provider)
- Snackbar bei manuellem Sync-Start ergänzen
- `ScaffoldMessenger`-Erreichbarkeit nach Dropdown-Entfernung (B-009) verifizieren


### B-009: Artikelliste — Ort-Dropdown hardcodiert und falsch platziert — abgeschlossen 2026-04-22 | `0.9.0+25`
**Typ:** Bug / Regression (B-007-Commit)  
**Betrifft:** `lib/screens/artikel_list_screen.dart` → AppBar `actions`

Der Ort-Filter-Dropdown wurde als Test-Stub mit hardcodierten Werten
(`Lager 1`, `Lager 2`, `Büro`) in die AppBar `actions` eingefügt.
Er liest keine echten Daten aus `_artikelListe` und ist falsch
platziert (AppBar statt Body/Filter-Leiste).

- Dropdown aus AppBar `actions` entfernen
- Echte Ort-Werte dynamisch aus `_artikelListe` ableiten (distinct, alphabetisch sortiert, „Alle“ als erster Eintrag)
- Filter-UI in die Suchleiste im Body integrieren
- Filterlogik mit `_gefilterteArtikel()` verbinden (bereits korrekt)

### B-008: Artikelliste — Beschreibung, Artikelnummer und Fach fehlen — abgeschlossen 2026-04-22 | `0.9.0+25`
**Typ:** Bug / Regression (B-007-Commit)  
**Betrifft:** `lib/screens/artikel_list_screen.dart` → `_buildArtikelTile()`

`_buildArtikelTile()` wurde auf ein minimales `ListTile` reduziert.
Vor B-007 war es ein reichhaltigeres Card-Widget mit allen Feldern.
Wiederherstellen als `Card` mit Artikelnummer, Name, Beschreibung,
Ort, Fach und Menge.

- `_buildArtikelTile()` auf Card-Layout mit allen Feldern erweitern
- Artikelnummer, Beschreibung und Fach wieder einblenden
- Auf S20 (360dp) und Tablet verifizieren

### B-007: Intelligenter Bild-Sync & UI-Optimierung — abgeschlossen 2026-04-21 | `0.8.9+24`
- **Smart Sync**: `PocketBaseSyncService` vergleicht nun Datei-Zeitstempel mit PocketBase-Updates
- **Cleanup**: Automatisches Löschen alter Bildversionen im Dateisystem bei Namensänderung
- **UI-Kontrast**: „Letzter Sync“-Zeitstempel auf `onSurface` (Bold) umgestellt für maximale Lesbarkeit

### P-003: Bild-Caching — abgeschlossen 2026-04-20 | `0.8.6+21`
- Integration von `cached_network_image`
- `ArtikelBildWidget` nutzt persistenten Cache für Remote-Bilder
- Kein Flackern/Neu-Laden beim Scrollen in der Liste
- Cache-Invalidierung bei ETag-Änderung sichergestellt


### B-003 bis B-006: Sync-Stabilität — abgeschlossen 2026-04-17 | `0.8.5+19`
- ETag-basierte Konflikt-Erkennung vor PATCH
- Korrektur der Bild-Download-Skip-Logik
- Navigator-Init via GlobalKey gefixt


### T-008: ETag-Konflikt-Logik und `downloadMissingImages`-Check-Logik — abgeschlossen 2026-04-17 | `0.8.5+19`
- `pocketbase_sync_service_conflict_test.dart` — 11 Tests ✅
- `sync_orchestrator_test.dart` — 9 Tests (erweitert) ✅
- ETag-Grenzwerte, ConflictCallback-Typedef, SyncStatus-Enum abgedeckt ✅
- Gesamtstand: **625 Tests**, 28 Dateien ✅

### B-001: Settings-Änderungen werden ohne Speichern übernommen — abgeschlossen 2026-04-14 | `0.8.3+16`
- Dirty-Tracking, Save-Button und Unsaved-Dialog analysiert
- Ergebnis: Verhalten war bereits korrekt implementiert, kein Fix nötig


### B-002: Biometrische Authentifizierung — System-Dialog & Verfügbarkeitsprüfung — abgeschlossen 2026-04-14 | `0.8.3+16`
- Nativer System-Dialog bestätigt
- Verfügbarkeitsprüfung vor Aktivierung bestätigt
- Toggle wird nur bei erfolgreicher Probe-Authentifizierung persistiert

### F-004 & F-005: UI-Politur — abgeschlossen 2026-04-14 | `0.8.4+17`
- Nextcloud-Status-Icon Farbe angepasst
- Detail-Screen Felder leserlicher (`OutlineInputBorder`)

### N-003 & N-005: Branding — abgeschlossen 2026-04-14 | `0.8.4+17`
- Neues App-Icon und Native Splash Screen für alle Plattformen

### F-001 & F-002: Security — abgeschlossen 2026-04-13 | `0.8.2+13`
- Biometrische Authentifizierung und konfigurierbare Sperrzeit

### T-003 bis T-007: Test-Offensive — abgeschlossen 2026-04-13 | `0.8.1+10`
- Unit-Tests für `NextcloudClient`, `MergeDialog`, `AttachmentService`, `BackupStatusService`
- Performance-Test self-contained; `flutter test` läuft ohne manuelle Vorbereitung

### O-008: Magic-Number-Arithmetik in Spacing-Tokens — abgeschlossen 2026-04-13 | `0.8.1+11`
- Neuer Token `spacingSectionGap`
- 3 Stellen `spacingXLarge - 4` ersetzt
- Reines Rename-/Token-Refactoring


### F-003: Artikeldetailansicht — abgeschlossen 2026-04-13 | `0.8.0+8`
- `Row` mit zwei `Expanded`-Kindern
- Neuer Token `detailFieldSpacing`
- Responsive und Dark-Mode-kompatibel

### O-007: Tests für `ImagePickerService` nach P-001 — abgeschlossen 2026-04-13 | `0.8.0+7`
- 15 Tests, alle grün
- `FakeImagePicker`, Plattform-Checks, Guard-Pfade und Kamera-Flows abgedeckt

### P-005: Dependency-Update — abgeschlossen 2026-04-13 | `0.8.0+5`
- `cupertino_icons`, `shared_preferences`, `mockito`, `connectivity_plus` aktualisiert
- `connectivity_plus`-API-Migration bereits umgesetzt
- `dependency_overrides` bereinigt


### v0.8.6+21 — 2026-04-20

#### P-003: Bild-Caching — erledigt in `v0.8.6+21`
- Integration von `cached_network_image`
- `ArtikelBildWidget` nutzt persistenten Cache für Remote-Bilder
- Kein Flackern/Neu-Laden beim Scrollen in der Liste
- Cache-Invalidierung bei ETag-Änderung sichergestellt


### v0.8.5+19 — 2026-04-20

#### B-003: Bild-Download-Skip-Logik in downloadMissingImages — abgeschlossen in `v0.8.5+19`
- Skip-Bedingung war invertiert — Negation fehlte
- Korrigiert: Skip nur wenn `bildPfad.isNotEmpty && dateiExistiert && dateiHatInhalt`
- Bilder werden jetzt korrekt heruntergeladen wenn lokal nicht vorhanden

#### B-004: Konflikt-Callback-Registrierung nach Navigator-Init via GlobalKey — abgeschlossen in `v0.8.5+19`
- `GlobalKey<NavigatorState>` in `main.dart` eingeführt
- Callback-Registrierung via `addPostFrameCallback` nach erstem Frame
- DB-Reopen nach App-Resume vor Sync-Start sichergestellt

#### B-005: ETag-basierte Konflikt-Erkennung vor PATCH — abgeschlossen in `v0.8.5+19`
- Vor jedem PATCH: Remote-Record laden, `updated`-Timestamp mit lokalem `etag` vergleichen
- Bei Abweichung: `onConflictDetected`-Callback statt blindem Überschreiben
- ETag = PocketBase `updated`-Timestamp (ISO 8601), nicht Record-ID

#### B-006: SyncManagementScreen nutzt SyncOrchestrator statt SyncService — abgeschlossen in `v0.8.5+19`
- `SyncManagementScreen` erhält `SyncOrchestrator`-Instanz als Parameter
- Sync-Start über `orchestrator.runOnce()`
- Status-Updates korrekt über `syncStatus`-Stream

#### T-008: ETag-Konflikt-Logik und downloadMissingImages-Check-Logik — abgeschlossen in `v0.8.5+19`
- `pocketbase_sync_service_conflict_test.dart` — 11 Tests ✅
- `sync_orchestrator_test.dart` — 9 Tests (erweitert) ✅
- ETag-Grenzwerte, ConflictCallback-Typedef, SyncStatus-Enum abgedeckt ✅
- Gesamtstand: **610 Tests**, 28 Dateien ✅


### v0.8.4+17 — 2026-04-14

#### F-004: Nextcloud-Status-Icon Farbe angleichen
- Nextcloud-Online-Icon auf `AppConfig.statusColorConnected` (`Material Green 500`) umgestellt ✅
- Konsistente Farbsemantik:
  - Grün = verbunden
  - Rot = getrennt
  - Grau = unbekannt
- Bestehendes semantisches Token wiederverwendet — kein neuer Token nötig ✅

#### F-005: Detail-Screen Felder leserlicher darstellen
- Readonly-Felder: `OutlineInputBorder` + `filled: true` + `fillColor: surfaceContainerLow` ✅
- Text-Farbe im Readonly-Modus: volle Opazität via `onSurface` statt `disabledColor` ✅
- Edit-Modus visuell klar unterscheidbar: `fillColor: surface` + Unterstrich ✅
- Menge und Artikelnummer als `InputDecorator` mit Label statt inline-Text ✅
- Menge-`+/-`-Buttons nur noch im Edit-Modus sichtbar ✅
- Dark Mode: Kontrast in beiden Modi korrekt ✅
- 3 bestehende Widget-Tests an neues Layout angepasst ✅

#### N-003: App-Icon
- Neues App-Logo (`app_logo.png`) mit Lager-Design erstellt ✅
- `flutter_launcher_icons` für alle Plattformen generiert ✅
- Android: `mipmap-hdpi` bis `mipmap-xxxhdpi` ✅
- iOS: alle `AppIcon`-Größen (`20x20` bis `1024x1024`) ✅
- Web: `favicon.png`, `Icon-192`, `Icon-512`, maskable Icons ✅
- Windows: `app_icon.ico` ✅

#### N-005: Native Splash Screen
- `flutter_native_splash` Konfiguration erweitert ✅
- Light Mode: `#1976d2` mit App-Logo ✅
- Dark Mode: `#121212` mit App-Logo ✅
- Android 12+ Splash-API Support ✅
- Web Splash Screen ✅
- Alle Plattformen: Android, iOS, Web ✅

---

### v0.8.3+16 — 2026-04-14

#### B-001: Settings-Änderungen werden ohne Speichern übernommen
- Analyse des Settings-Verhaltens abgeschlossen ✅
- Dirty-Tracking war bereits korrekt implementiert (`_hasUnsavedChanges`, `_isDirty()`) ✅
- Unsaved-Changes-Dialog bei Zurück-Navigation vorhanden (`_onWillPop()`) ✅
- Save-Button mit Dirty-State-Kopplung vorhanden (`_buildSaveButton()`) ✅
- `onChanged`-Handler ändern nur lokalen State, keine direkten Service-Aufrufe ✅
- Alle Persistierung gebündelt in `_saveSettings()` ✅
- Snackbar-Feedback nach erfolgreichem Speichern vorhanden ✅
- Ergebnis: **Kein Code-Fix nötig**, Verhalten war bereits korrekt implementiert ✅

#### B-002: Biometrische Authentifizierung — System-Dialog & Verfügbarkeitsprüfung

##### B-002.1: Nativer System-Dialog
- `_authenticate()` ruft `auth.authenticate()` korrekt auf ✅
- `AuthenticationOptions(biometricOnly: true)` gesetzt ✅
- Automatischer Start via `addPostFrameCallback` in `initState()` ✅
- Fallback-Button für manuellen Retry vorhanden ✅
- Android: `FlutterFragmentActivity` in `MainActivity.kt` bestätigt ✅

##### B-002.2: Verfügbarkeitsprüfung beim Einschalten
- `canCheckBiometrics` + `isDeviceSupported()` wird vor Aktivierung geprüft ✅
- Bei nicht verfügbarer Biometrie: Toggle zurückgesetzt + Fehlermeldung ✅
- Probe-`authenticate()` bei Aktivierung durchgeführt ✅
- Nur bei erfolgreicher Probe wird `setBiometricsEnabled(true)` persistiert ✅

---

### v0.8.2+13 — 2026-04-13

#### F-001: Biometrische Authentifizierung (Mobile)
- `AppLockService` Singleton mit `SharedPreferences`-Persistenz ✅
- `WidgetsBindingObserver` für App-Lifecycle-Erkennung ✅
- `AppLockScreen` mit `local_auth 3.0.1` API ✅
- Automatischer Start der biometrischen Authentifizierung beim Anzeigen ✅
- Fallback auf Geräte-PIN/Pattern, wenn Biometrie nicht verfügbar ✅
- Integration in `main.dart` via `AppLockService().init()` ✅

#### F-002: Konfigurierbare App-Sperrzeit
- `AppLockService` überwacht App-Lebenszyklus (`didChangeAppLifecycleState`) ✅
- Inaktivitäts-Timer mit konfigurierbarer Dauer (`lockTimeout`) ✅
- Sperrzeit persistent in `SharedPreferences` gespeichert ✅
- App sperrt automatisch bei Hintergrundwechsel nach Timeout-Ablauf ✅

---

### v0.8.1+12 — 2026-04-13

#### T-003: Unit-Tests `NextcloudClient`
- **39 Tests**, alle grün ✅
- `MockClient` aus `package:http/testing.dart` — kein Netzwerk nötig ✅
- Optionaler `http.Client? client`-Parameter im Konstruktor (rückwärtskompatibel) ✅
- Alle 8 HTTP-Stellen auf injizierten `_client` umgestellt ✅

##### Abgedeckte Bereiche
- `RemoteItemMeta`: Equality (`path+etag`), `copyWith`, `toString` ✅
- `testConnection()`: `200`, `404`, `500`, Exception, Auth-Header ✅
- `createFolder()`: `201`, `405`, `500`, Exception ✅
- `listItemsEtags()`: 1 Item, Multi-Item, leer, `403`, Non-JSON-Filter, kein ETag, custom Path ✅
- `downloadItem()`: `200`, `404`, Netzwerkfehler ✅
- `uploadItem()`: `201+ETag`, `If-Match`, `412 Conflict`, `500`, kein ETag ✅
- `deleteItem()`: `204`, `404` idempotent, `500`, Exception ✅
- `uploadAttachment()`: `201+ETag`, Content-Type, Default-CT, `500` ✅
- `downloadAttachment()`: `200+Bytes`, `404` ✅
- URI-Auflösung: Items-Pfad, Attachments-Pfad ✅

##### Ergebnis
- Produktionscode minimal geändert: 1 Feld, 1 Parameter, 8 Aufrufstellen ✅
- Gesamtstand Tests: **551 → 590**

---

### v0.8.1+11 — 2026-04-13

#### T-004: Widget-Tests Merge-Dialog
- **18 Widget-Tests**, alle grün ✅
- Grundstruktur des Dialogs getestet ✅
- Konflikt-Anzeige getestet ✅
- Feld-Auswahl getestet ✅
- Bild-Auswahl getestet ✅
- Zusammenführen getestet ✅
- Dialog-Schließen getestet ✅
- Menge-Fallback getestet ✅
- Gesamtstand Tests: **533 → 551**

#### O-008: Magic-Number-Arithmetik in Spacing-Tokens
- Neuer Token `spacingSectionGap` (`20.0`) in `AppConfig` ✅
- 3 Stellen `spacingXLarge - 4` → `spacingSectionGap` ersetzt ✅
- Datei: `artikel_detail_screen.dart` ✅
- Reines Rename-/Token-Refactoring ohne Verhaltensänderung ✅
- Bestehende Widget-Tests decken die Stellen ab ✅

---

### v0.8.1+10 — 2026-04-13

#### T-005: Unit-Tests `AttachmentService`
- **34 Tests**, alle grün ✅
- Get-/Count-/Upload-/Update-/Delete-Pfade abgedeckt ✅
- Integration: Upload → Get-Roundtrip abgedeckt ✅
- Grenzwert 19 vs. 20 Anhänge getestet ✅
- `PocketBaseService.overrideForTesting` genutzt ✅
- `FakeAttachmentRecordService` und `fakeClientException` verwendet ✅
- Gesamtstand Tests: **499 → 533**

---

### v0.8.0+8 — 2026-04-13

#### F-003: Artikeldetailansicht — Ort & Fach nebeneinander
- `artikel_detail_screen.dart`: Ort- und Fach-`TextField` von vertikaler `Column`-Anordnung in eine `Row` mit zwei `Expanded`-Kindern umgebaut ✅
- Neuer `AppConfig`-Token `detailFieldSpacing` (`12.0 dp`) für den horizontalen Abstand ✅
- `crossAxisAlignment: CrossAxisAlignment.start` verhindert visuelles Springen bei unterschiedlich hohen Fehlertexten ✅
- Responsive: `Expanded` skaliert automatisch von Mobile bis Desktop ✅
- Dark Mode unverändert korrekt ✅
- Kein Hardcoding — neuer Abstand vollständig über Token ✅
- Alle 24 bestehenden Widget-Tests grün ✅
- `flutter analyze`: **0 Issues**

---

### v0.8.0+7 — 2026-04-13

#### T-006: Unit-Tests `BackupStatusService`
- **22 Tests**, alle grün ✅
- Tests seit `v0.8.0` vorhanden, formal abgenommen in `v0.8.0+7` ✅
- `MockClient` (`package:http/testing.dart`) — kein echter HTTP-Request ✅
- `last_backup.json`-Parsing vollständig abgedeckt ✅
- Farblogik:
  - Grün (`≤24 h`)
  - Gelb (`≤72 h`)
  - Rot (`>72 h`) ✅
- Fehlerfall: Server nicht erreichbar → `BackupStatus.unknown` ✅
- Fehlerfall: Malformed JSON → graceful degradation ✅

#### O-007: Tests für `ImagePickerService` nach P-001
- **15 Tests**, alle grün ✅
- `FakeImagePicker extends ImagePicker` überschreibt `pickImage()` vollständig ✅
- `@visibleForTesting overrideImagePicker` + `maxFileSizeBytesOverride` für saubere Injektion ✅
- `debugDefaultTargetPlatformOverride` via `try/finally` in `testWidgets` sauber zurückgesetzt ✅
- `XFile.fromData()` statt `XFile(path, bytes:)` wegen `dart:io`-Verhalten ✅
- `tester.runAsync()` für Pfade mit `readAsBytes()` / `compute()` ✅

##### Abgedeckt
- `PickedImage`-Datenklasse ✅
- `isCameraAvailable` für 5 Plattformen ✅
- `openCropDialog()` Guards ✅
- `pickImageCamera()` alle Pfade ✅

##### Ergebnis
- Gesamtstand Tests: **469 → 484**

---

### v0.8.0+6 — 2026-04-13

#### T-007: Performance-Test self-contained
- `setUpAll()` generiert `test_data/import_500.json` mit 500 Artikeln programmatisch ✅
- 10 minimale PNG-Fixtures (`1×1 Pixel`, `67 Byte`) werden in `setUpAll()` erzeugt ✅
- `tearDownAll()` löscht `test_data/images/`, JSON-Fixture und `test_data/` ✅
- `flutter test` läuft ohne Vorbereitung durch ✅
- `@Tags(['performance'])` bleibt — weiterhin separat ausführbar ✅
- `tool/generate_import_dataset.dart` bleibt als optionales CLI-Tool für größere Datensätze ✅
- Gesamtstand Tests: **468 → 469**

---

### v0.8.0+5 — 2026-04-12

#### T-002: Unit-Tests `PocketBaseSyncService`
- **17 Unit-Tests** abgeschlossen ✅
- Push-/Pull-/Fehler-/UUID-Sanitization-/Image-Skip-Logik abgedeckt ✅
- Manuelle Fakes eingesetzt, kein echter Netzwerkzugriff nötig ✅
- Gesamtstand Tests: **451 → 468**

#### P-005: Dependency-Update
- `cupertino_icons: ^1.0.9` ✅
- `shared_preferences: ^2.5.5` ✅
- `mockito: ^5.6.4` ✅
- `connectivity_plus: ^7.1.1` ✅
- `connectivity_service.dart` bereits auf `List<ConnectivityResult>`-API migriert ✅
- `dependency_overrides` für `connectivity_plus_platform_interface` entfernt ✅

---

### v0.8.0 — 2026-04-10

#### 🎉 K-006: Hauptfeature: Kaltstart-Bugfix

##### Problem
Nach einem Kaltstart (App-Daten gelöscht, neue PocketBase-URL konfiguriert)  
blieb die Artikelliste leer, obwohl der Sync im Hintergrund erfolgreich lief.  
Bilder wurden nicht heruntergeladen und der Benutzer sah keine Rückmeldung.

##### Ursachen
1. **Sync-UI-Entkopplung:** `ArtikelListScreen` wusste nicht, wann der Sync abgeschlossen war  
2. **Fehlender Bild-Download:** PocketBase-Sync übertrug nur Metadaten (`remoteBildPfad`)  
3. **Globaler Image-Cache-Clear:** `imageCache.clear()` verwarf alle gecachten Bilder  
4. **Sofortiger UI-Wechsel nach Setup:** Die UI wechselte zu früh zur leeren Liste

#### ✨ Neue Features
- `SyncStatusProvider`-Interface für lose Kopplung zwischen Sync und UI
- `ArtikelListScreen` reagiert auf `SyncStatus.success`
- `FakeSyncStatusProvider` als Test-Double
- Automatischer Bild-Download via `downloadMissingImages()`
- PocketBase-Bild-Fallback in `_LocalThumbnail` und `ArtikelDetailBild`
- Setup-Flow wartet auf initialen Sync
- Buttons im Setup-Screen während Sync deaktiviert

#### 🔧 Technisch
##### Neue Dateien
- `lib/services/sync_status_provider.dart`
- `lib/screens/list_screen_cache_io.dart`
- `lib/screens/list_screen_cache_stub.dart`
- `test/helpers/fake_sync_status_provider.dart`
- `test/services/sync_status_provider_test.dart`

##### Wichtige Änderungen
- `sync_orchestrator.dart` implementiert `SyncStatusProvider`
- `pocketbase_sync_service.dart` erweitert um Bild-Download
- `artikel_db_service.dart`: `setBildPfadByUuidSilent()`
- `artikel_list_screen.dart`: StreamSubscription + gezieltes Cache-Evict
- `main.dart`: Sync abwarten vor UI-Wechsel
- `server_setup_screen.dart`: Lade-Overlay
- `artikel_bild_widget.dart`: PB-Fallback

#### 📚 Dokumentation
- `CHANGELOG.md` aktualisiert
- `OPTIMIZATIONS.md` aktualisiert
- `TESTING.md` aktualisiert
- `ARCHITECTURE.md` aktualisiert
- `DATABASE.md` aktualisiert
- `LOGGER.md` aktualisiert

#### 🧪 Tests
- `flutter analyze`: **0 Issues**
- `flutter test`: **451 bestanden**, 3 übersprungen
- Testsuite: 347 → **451 Tests** (+104), 15 → **18 Dateien** (+3)

---

### v0.7.8 — 2026-04-09

#### ✨ Verbessert: UI-Ansicht

##### 🖼️ Artikel-Detail-Screen
- Artikelname direkt editierbar
- „Zuschneiden“-Button nach Bildauswahl
- Body aufgeräumt, Aktionen in die AppBar verschoben

##### 🎛️ AppBar-Aktionen
- Bild wählen / Kamera nur im Edit-Modus
- Anhänge immer sichtbar, mit Badge-Zähler
- Ändern / Speichern in der AppBar
- PDF-Export & Löschen konsistent in der AppBar

##### 📝 Artikel-Erfassen-Screen
- `textCapitalization: sentences` für Name, Beschreibung, Ort und Fach
- Menge-Feld markiert beim Antippen den gesamten Inhalt
- Bild-Buttons kompakter als `IconButton`

##### 🔍 Artikel-Liste
- QR-Scanner direkt neben dem Suchfeld
- „Neuer Artikel“ in der AppBar statt `FloatingActionButton.extended`
- DB-Icon grün bei Verbindung via `AppConfig.statusColorConnected`

##### 🔧 Technisch
- Neues semantisches Token `AppConfig.statusColorConnected` (`Color(0xFF4CAF50)`)
- `AnhaengeSektion.build()` gibt `SizedBox.shrink()` zurück
- `FocusNode _mengeFocus` mit automatischer Vollauswahl
- `_nameController` vollständig in den Detail-Screen integriert
- `flutter analyze`: **0 Issues**

---

### v0.7.7+5 — 2026-04-08

#### P-002: Suche Debounce + DB-Suche
- `Timer(300ms)` verhindert Suche bei jedem Tastendruck
- Mobile: SQL `LIKE` via `_db.searchArtikel()`
- Web: clientseitiger Filter über geladene PocketBase-Liste
- Skeleton während laufender Suche
- Footer bei aktiver Suche versteckt
- Leer-Feld → sofortiger Reset zur paginierten Liste

#### O-006: Widget-Tests `ArtikelErfassenScreen`
- 11 Tests: Render, Validierung, Abbrechen-Pfade
- `physicalSize 1080x2400` + `scrollUntilVisible()` für `ListView`
- `pumpAndSettle(5s)` für async `_initArtikelnummer()`

---

### v0.7.7+4 — 2026-04-08

#### M-005: Pagination für Artikelliste
- `ScrollController` mit `_onScroll()`-Listener
- `_ladeArtikel()`: Reset mit `offset = 0`
- `_ladeNaechsteSeite()`: offset-basiertes Nachladen mit Guard gegen Doppel-Requests
- Lade-Footer am Listenende
- Web unverändert: `getFullList()` + `_hasMore = false`
- Neue `AppConfig`-Tokens:
  - `paginationPageSize = 30`
  - `paginationScrollThreshold = 200.0`

#### O-005: Deprecated `DokumenteButton` entfernt
- 5 Dateien gelöscht
- `cached_network_image` bleibt anderweitig aktiv genutzt
- `flutter analyze`: **0 Issues**

---

### v0.7.7+2 — 2026-04-07

#### P-001: Kamera-Vorschau-Delay auf Android behoben
- Crop-Dialog aus dem Capture-Flow entfernt
- `maxWidth = 800`, `maxHeight = 800`, `imageQuality = 85` direkt an `picker.pickImage()`
- `openCropDialog()` als `public static`-Methode
- Optionaler „Zuschneiden“-Button im `ArtikelErfassenScreen`

##### Ergebnis
Kamera → sofortige Vorschau auf Android, Crop bleibt optional.

---

### v0.7.7+1 — 2026-04-06

#### T-001: Widget-Tests abgeschlossen
- Tests für Konfliktlösung — Unit- und Widget-Tests vollständig (**77 Tests**) ✅
- `SyncService.detectConflicts()` — 9 Tests
- `_determineConflictReason()` — 15 Tests
- `ConflictResolutionScreen` — 20 Widget-Tests

##### Technische Besonderheit
- `setSurfaceSize(1024×900)` für Widget-Tests
- Standard-Viewport (`800×600`) war zu klein
- `addTearDown` stellt den Default-Viewport wieder her

##### Ausstehend
- T-001.6–T-001.12 manuell auf zwei verbundenen Geräten

---

### v0.7.7 — 2026-04-05

#### Release: Qualitäts-Release mit Tests & Dokumentation

Dieses Release fasst die `v0.7.6+x`-Zwischenstände zusammen und bringt die Version auf `0.7.7`.

#### M-003: Error Handling — erledigt in `v0.7.6+3`
- Neue `AppException`-Hierarchie (`sealed class`) ✅
- Neuer `AppErrorHandler` mit Klassifizierung, Logging, SnackBars und Dialogen ✅
- `sync_conflict_handler.dart`: rohe `$e`-Strings → `AppErrorHandler` ✅
- Netzwerk- und Timeout-Fehler werden automatisch klassifiziert ✅
- Lint-Fixes behoben ✅

#### M-004: Loading States — erledigt in `v0.7.6+2`
- `AppLoadingOverlay`, `AppLoadingIndicator`, `AppLoadingButton` ✅
- `ArtikelSkeletonTile` + `ArtikelSkeletonList` ✅
- Skeleton statt `CircularProgressIndicator` ✅
- Overlay im Detail-Screen und Sync-Management ✅
- 10 neue `AppConfig`-Tokens ✅

#### M-006: Input Validation — erledigt in `v0.7.6+1`
- Pflichtfelder und Inline-Fehlermeldungen ✅
- Name: 2–100 Zeichen ✅
- Menge: nur positive Ganzzahlen, max. `999.999` ✅
- Artikelnummer automatisch ab `1000`, manuell änderbar ✅
- Duplikat-Checks lokal + PocketBase ✅
- `existsKombination()` und `existsArtikelnummer()` ✅

#### O-002: Unit-Tests für `ArtikelDbService` — erledigt in `v0.7.6+4`
- 75 Tests für `ArtikelDbService` ✅
- 64 Tests für `ArtikelModel` ✅
- 30 Tests für `ImageProcessingUtils` ✅
- 23 Tests für `UuidGenerator` ✅
- In-Memory-Setup via `sqflite_common_ffi` ✅
- Produktionsbug in `getUnsyncedArtikel()` gefunden und gefixt ✅

#### Dokumentation
- `docs/TESTING.md` neu erstellt
- `CHANGELOG.md`, `OPTIMIZATIONS.md`, `HISTORY.md`, `README.md` aktualisiert

---

### v0.7.5+1 — 2026-04-03

#### M-008: Backup-Status im Settings-Screen anzeigen
- `BackupStatusService` liest `last_backup.json` via HTTP vom PocketBase-Server
- `BackupStatusWidget` mit farbcodierter Status-Card
- Loading/Error/Unknown-States
- Detail-Zeilen: Zeitpunkt, Datei, Größe, Backup-Anzahl, Rotation
- Refresh-Button zum manuellen Aktualisieren
- Integration in `settings_screen.dart`
- `backup.sh` kopiert `last_backup.json` nach `pb_public`
- `docker-compose.prod.yml` um `pb_public`-Volume ergänzt

---

### v0.7.5+0 — 2026-04-02

#### M-007: UI für Konfliktlösung
- `ConflictResolutionScreen` mit Side-by-Side-Vergleich ✅
- `ConflictData` + `ConflictResolution`-Enum ✅
- Multi-Konflikt-Navigation mit Fortschrittsanzeige ✅
- Merge-Dialog für manuelle Zusammenführung ✅
- Integration mit `SyncConflictHandler` und `SyncService` ✅
- Entscheidungs-Callbacks (`useLocal`, `useRemote`, `merge`, `skip`) ✅
- Unit- und Widget-Tests erstellt (T-001, 77 Tests) ✅

##### Durchgeführte Arbeiten
- `OPTIMIZATIONS.md` bereinigt: Doppelung M-007 (alt) → K-003 umbenannt
- M-007 als erledigt markiert
- 37 Unit-Tests erstellt (`conflict_resolution_test.dart`)
- Neue Aufgabe T-001 für manuelle Integrationstests erstellt

---

### v0.7.4+7 — 2026-04-02

#### O-004 Batch 5
- Keine neuen `AppConfig`-Tokens nötig
- `list_screen_mobile_actions.dart` — 17 Hardcodes → 0
- `nextcloud_settings_screen.dart` — 21 Hardcodes → 0
- `qr_scan_screen_mobile_scanner.dart` — 12 → 6 (bewusst)
- `image_crop_dialog.dart` — 11 → 5 (bewusst)
- `artikel_erfassen_screen.dart` — 12 → 0
- `list_screen_web_actions.dart` — 8 → 0
- `artikel_bild_widget.dart` — 5 → 2 (bewusst)
- `nextcloud_resync_dialog.dart` — 7 → 0
- Übersprungen:
  - `detail_screen_io.dart`
  - `list_screen_io.dart`
  - `list_screen_mobile_actions_stub.dart`
  - `_dokumente_button.dart`

---

### v0.7.4+6 — 2026-04-02

#### O-004 Batch 4
- `app_config.dart` — 13 neue Tokens
- `attachment_upload_widget.dart` — 28 Hardcodes → 0
- `attachment_list_widget.dart` — 23 Hardcodes → 0
- `server_setup_screen.dart` — 23 Hardcodes → 0
- `login_screen.dart` — 18 Hardcodes → 0

---

### v0.7.4+5 — 2026-04-02

#### O-004 Batch 3
- Keine neuen `AppConfig`-Tokens nötig
- `artikel_detail_screen.dart` — 36 Hardcodes → 0
- `artikel_list_screen.dart` — 31 Hardcodes → 0
- `sync_conflict_handler.dart` — 31 Hardcodes → 0

---

### v0.7.4+4 — 2026-04-01

#### O-004 Batch 2: Sync-Cluster migriert
- **193 Hardcodes** in 4 Dateien eliminiert
- `app_theme.dart` — Component-Themes nutzen `AppConfig`-Tokens
- `conflict_resolution_screen.dart` — größte Einzeldatei (82 Hardcodes)
- `sync_error_widgets.dart` — Severity-Farben über `colorScheme`
- `sync_management_screen.dart` — AppBar und Buttons standardisiert

##### Entscheidungen
- `Colors.purple` → `colorScheme.tertiary`
- `Colors.orange` → `colorScheme.secondary`
- AppBar-Farben entfernt — Standard-Theme greift konsistent
- `_getSeverityColor()` nimmt jetzt `BuildContext`

---

### v0.7.4+3 — 2026-04-01

#### O-004 Batch 1: UI-Hardcoded Werte migrieren
- **109 Hardcodes eliminiert**
- `AppConfig` erweitert
- Dark Mode funktioniert korrekt in allen migrierten Widgets
- Kein visuelles Redesign — gleiche Optik, sauberer Code

##### `sync_progress_widgets.dart`
- 55 Hardcodes → 0
- Farben auf `colorScheme` migriert
- Layout-Werte auf `AppConfig`-Tokens umgestellt

##### `settings_screen.dart`
- 54 Hardcodes → 0
- Status-Container vereinheitlicht
- `_buildStatusContainer()` als Helper extrahiert

##### Dokumentation
- `THEMING.md` aktualisiert
- `OPTIMIZATIONS.md` aktualisiert
- `CHANGELOG.md` aktualisiert

---

### v0.7.4+0 — 2026-03-30

#### H-002: CORS-Konfiguration & Infrastruktur-Bereinigung
- `CORS_ALLOWED_ORIGINS` wird beim PocketBase-Start korrekt als `--origins`-Flag übergeben
- Neues `entrypoint.sh` Script ersetzt die bisherige Inline-Startlogik
- Wildcard (`*`) bleibt für Entwicklung, Produktion nutzt strikte Origins
- CORS nur auf PocketBase-Ebene
- Zwei Subdomains: Frontend + API
- `docker-compose.production.yml` (Traefik) entfernt
- Portainer Stack an Produktions-Setup angeglichen
- `.env.production` korrigiert

---

### v0.7.3 — Datum im Ursprung nicht explizit genannt

#### M-009: Login-Flow & Authentifizierung
- Login-Screen mit E-Mail/Passwort-Validierung und Loading-State ✅
- Auth-Gate in `main.dart` mit Auto-Login (Token-Refresh) ✅
- Logout im Settings-Screen mit Bestätigungs-Dialog ✅
- PocketBase API-Regeln auf Auth umgestellt ✅

---

### v0.7.2 — 2026-03-29

#### M-012: Attachments (Dateianhänge pro Artikel)
- PocketBase Collection `attachments` mit File-Upload und Metadaten
- `AttachmentService` (Singleton) — CRUD gegen PocketBase
- `AttachmentModel` — MIME-Type-Erkennung und Größenformatierung
- `AttachmentUploadWidget` — Upload-Dialog mit Validierung
- `AttachmentListWidget` — Liste mit Download, Bearbeiten, Löschen
- `AnhaengeSektion` im Detail-Screen mit Badge-Counter und BottomSheet

##### Problem bei Inbetriebnahme
Upload schlug mit HTTP 400 fehl:
1. `uuid`-Pflichtfeld fehlte im Upload-Body
2. API-Regeln erforderten Auth, aber es gab noch keinen Login-Flow

##### Fix
- `UuidGenerator.generate()` ergänzt
- API-Regeln vorübergehend auf offen gesetzt

##### Weitere Fixes
- Detailansicht zeigt jetzt `artikel.artikelnummer` statt `artikel.id`
- `updated_at` wird in `toPocketBaseMap()` an PocketBase gesendet

---

### v0.7.1 — 2026-03-27 bis 2026-03-28

#### H-003: Backup-Automatisierung
- Dedizierter Backup-Container mit Cron ✅
- SQLite WAL-Checkpoint vor jedem Backup ✅
- Komprimiertes `tar.gz`-Archiv mit Integritätsprüfung ✅
- Rotation alter Backups (Standard: 7 Tage) ✅
- E-Mail- und Webhook-Benachrichtigung ✅
- Status-JSON (`last_backup.json`) für App-Anzeige ✅
- Restore-Script mit Sicherheitskopie und Healthcheck ✅

#### K-005: WSL2-Entwicklungsumgebung — Bildanzeige-Problem gelöst
**Problem:** `Image.memory` wurde unter WSL2 nicht korrekt angezeigt.  
In der Browser-Konsole erschien:

```text
WARNING: Falling back to CPU-only rendering. Reason: webGLVersion is -1
```

**Lösung:** Web-Server-Modus statt `flutter run -d chrome`:

```bash
flutter run -d web-server --web-port 8888 --web-hostname 0.0.0.0
```

Dann im Windows-Browser mit echtem WebGL öffnen: `http://localhost:8888`

**Dokumentation:**
- `DEV_SETUP.md` neu erstellt
- `INSTALL.md` ergänzt

---

### v0.7.0 — 2026-03-27

#### K-004: Runtime-Konfiguration der PocketBase-URL

##### Problem
Die PocketBase-URL wurde ausschließlich zur Build-Zeit per `--dart-define=POCKETBASE_URL=...` gesetzt.  
Das führte zu mehreren Problemen:
- App crashte beim Start, wenn die URL fehlte oder ungültig war
- URL-Änderung erforderte einen neuen Build
- Placeholder-URLs verursachten Fehler in Release-Builds
- `localhost` funktionierte auf Android nicht

##### Lösung
Dreistufige URL-Prioritätskette mit Setup-Screen als Fallback:

| Priorität | Quelle | Beschreibung |
|---|---|---|
| 1 | `SharedPreferences` / `localStorage` | Vom Benutzer gespeicherte URL |
| 2 | Runtime-Config (Web) / `--dart-define` | Build-Default oder Container-Config |
| 3 | Setup-Screen | Benutzer gibt URL manuell ein |

##### Ergebnis
- App startet immer, auch komplett ohne URL-Konfiguration
- Bestehende Installationen mit gespeicherter URL funktionieren unverändert
- `--dart-define` bleibt optional
- Web-Runtime-Config über `window.ENV_CONFIG` bleibt erhalten

---

### v0.3.0 — frühe Basisarbeiten

#### K-003: Artikelnummer & Indizes
- Eindeutige Artikelnummer (`1000+`) ✅
- 5 Performance-Indizes ✅
- Artikelnummer in Listen- und Detailansicht ✅

#### O-001: Bereinigung von `debugPrint`
- Alle `debugPrint`-Aufrufe durch `AppLogService` ersetzt ✅
- Verbleibende 8 Aufrufe in `app_log_io.dart` sind absichtlich ✅

#### M-002: AppLogService Integration
- Konsistentes Logging im gesamten Projekt ✅

#### N-004: Roboto Font
- Roboto als Standard-Schriftart via `google_fonts` ✅

---

### v0.2.0 — frühe Server- und Schema-Basis

#### K-002: PocketBase Schema & API Rules
- Automatische Initialisierung (Admin-User, Collections, Migrations) ✅
- API Rules konfiguriert ✅

---

## 2. O-004 Migrationshistorie aus `THEMING.md`

> Übernommen am **2026-04-15**.  
> Inhaltlich gehört diese Migration zur Versionsreihe **v0.7.4+3 bis v0.7.4+7**.

### Kumulierter Fortschritt

| Version | Batch | Hardcodes | Status |
|---|---|---|---|
| `v0.7.4+7` | Batch 5 | `~108` | ✅ Erledigt |
| `v0.7.4+6` | Batch 4 | `~92` | ✅ Erledigt |
| `v0.7.4+5` | Batch 3 | `~98` | ✅ Erledigt |
| `v0.7.4+4` | Batch 2 | `193` | ✅ Erledigt |
| `v0.7.4+3` | Batch 1 | `109` | ✅ Erledigt |

### Detailübersicht nach Version

#### v0.7.4+7 — Batch 5

| Datei | Hardcodes | Status |
|---|---|---|
| `list_screen_mobile_actions.dart` | `17 → 0` | ✅ |
| `nextcloud_settings_screen.dart` | `21 → 0` | ✅ |
| `qr_scan_screen_mobile_scanner.dart` | `12 → 6` | ✅ (6 bewusst) |
| `image_crop_dialog.dart` | `11 → 5` | ✅ (5 bewusst) |
| `artikel_erfassen_screen.dart` | `12 → 0` | ✅ |
| `list_screen_web_actions.dart` | `8 → 0` | ✅ |
| `artikel_bild_widget.dart` | `5 → 2` | ✅ (2 bewusst) |
| `nextcloud_resync_dialog.dart` | `7 → 0` | ✅ |
| `detail_screen_io.dart` | `3 → 3` | ⏭️ (kein `BuildContext`) |
| `list_screen_io.dart` | `3 → 3` | ⏭️ (kein `BuildContext`) |
| `list_screen_mobile_actions_stub.dart` | `4 → 4` | ⏭️ (Stub) |
| `_dokumente_button.dart` | `18` | ⏭️ (deprecated) |

#### v0.7.4+6 — Batch 4

| Datei | Hardcodes | Status |
|---|---|---|
| `attachment_upload_widget.dart` | `28 → 0` | ✅ |
| `attachment_list_widget.dart` | `23 → 0` | ✅ |
| `server_setup_screen.dart` | `23 → 0` | ✅ |
| `login_screen.dart` | `18 → 0` | ✅ |

#### v0.7.4+5 — Batch 3

| Datei | Hardcodes | Status |
|---|---|---|
| `artikel_detail_screen.dart` | `36 → 0` | ✅ |
| `artikel_list_screen.dart` | `31 → 0` | ✅ |
| `sync_conflict_handler.dart` | `31 → 0` | ✅ |

#### v0.7.4+4 — Batch 2

| Datei | Hardcodes | Status |
|---|---|---|
| `app_theme.dart` | `10 → 0` | ✅ |
| `conflict_resolution_screen.dart` | `82 → 0` | ✅ |
| `sync_error_widgets.dart` | `59 → 0` | ✅ |
| `sync_management_screen.dart` | `43 → 0` | ✅ |

#### v0.7.4+3 — Batch 1

| Datei | Hardcodes | Status |
|---|---|---|
| `sync_progress_widgets.dart` | `55 → 0` | ✅ |
| `settings_screen.dart` | `54 → 0` | ✅ |

---


## 3. 📊 Historische Phasen-Planung (Archiv)

Dieser Status entspricht dem Stand zum Abschluss der Performance-Phase (v0.8.6).

| Phase | Fortschritt | Status |
|---|---|---|
| Phase 1: Grundlagen | 100% | ✅ Abgeschlossen |
| Phase 2: Deployment & Security | 100% | ✅ Abgeschlossen |
| Phase 3: Performance & Optimierung | 100% | ✅ Abgeschlossen |
| Phase 4: Multi-Plattform & Politur | 100% | ✅ Abgeschlossen |

### Historischer Plattform-Status

| Plattform | Status (Stand v0.8.6) |
|---|---|
| Web (Chrome) | ✅ Voll funktionsfähig |
| Linux Desktop | ✅ Build & PDF-Export stabil |
| Windows Desktop | ✅ Build & Export stabil |
| Android | ✅ Build & Kamera stabil (S20 verifiziert) |
| iOS/macOS | ⏸️ Zurückgestellt (Account fehlt) |

---


## 4. Archiv: nicht eindeutig versionierte Einträge

### 2026-03-25 — 📋 Dokumente zum Artikel

#### 🗄️ Datenbank (lokal & Server)
- Neue Tabelle `artikel_dokumente` in der lokalen SQLite-Datenbank
- PocketBase Collection `artikel_dokumente` als serverseitiges Gegenstück

#### 📱 Flutter App
- `DokumentModel`
- `DokumentRepository`
- `DokumentSyncService`
- Dokumente-Tab im Artikel-Detail

#### 🔄 Synchronisation
- Dokumente getrennt von Textdaten und Bildern
- Gleiche ETag/UUID-Strategie wie bei Artikeln
- Hard-Delete auf dem Server bei lokal `deleted = 1`

---

### März 2026 — Die „kritische Phase“ (Härtung & Optimierung)

In diesem Monat wurde die App von einem Prototyp zu einem produktionsreifen System transformiert.

#### Meilensteine Phase 3 & 4
- Datenbank-Tuning mit 5 strategischen Indizes
- Artikelnummer-System ab 1000
- Security Hardening in Docker
- CI/CD für Android, Windows und Docker

---

### 🔍 Zusammenfassung technischer Analysen

#### Analyse der README & Struktur (März 2026)
- Problem: fragmentierte Dokumentation und Redundanzen
- Lösung: Modularisierung in `README.md`, `INSTALL.md` und `docs/*.md`
- Ergebnis: saubere Single-Source-of-Truth-Struktur

#### Synchronisations-Architektur (Phase 2 Review)
- Konzept: Offline-First mit Delta-Synchronisation
- Implementierung: `updated_at` + `deleted`
- Erkenntnis: Last-Write-Wins reicht für Einzelnutzer, benötigt aber Konflikt-UI für Multi-User

---

### 🚀 Pull-Request-Historie (Zusammenfassung)

#### PR #33: Dokumentations-Konsolidierung
- Modulare Dokumentationsstruktur finalisiert
- `README.md` auf < 200 Zeilen verschlankt
- Historische Zusammenfassungen in `HISTORY.md` archiviert

#### PR #32: Zentralisierte Konfiguration
- Einführung von `AppConfig`, `AppTheme` und `AppImages`
- Eliminierung von 200+ hartcodierten Werten
- Vollständiger Dark-Mode Support via Material 3

#### PR #30 & #31: Docker & Backup
- Docker-Build-Context auf Repository-Root korrigiert
- 3 Backup-Methoden dokumentiert

---

### Ohne explizite Versions- und Datumsangabe

#### K-001: Bundle Identifiers
- Android: `com.germanlion67.lagerverwaltung` ✅
- iOS: `com.germanlion67.lagerverwaltung` ✅

---

## 5. Historische Architektur-Entscheidungen

1. **Caddy statt Nginx (Container)**  
   Caddy wurde gewählt, da es HTTPS/HSTS und SPA-Routing mit minimaler Konfiguration ermöglicht.

2. **Docker-Context auf Root**  
   Um lokale Pakete im Docker-Build nutzen zu können, wurde der Kontext auf die oberste Ebene gehoben.

3. **Soft-Delete**  
   Datensätze werden nie physikalisch gelöscht, damit Clients Löschvorgänge beim nächsten Sync erkennen.

4. **Singleton statt Provider für `PocketBaseService`**  
   Die URL-Konfiguration wird vor `runApp()` benötigt. Ein Provider wäre dafür zu spät verfügbar.

---

*Dieses Dokument wird bei Abschluss größerer versionierter Meilensteine aktualisiert, um den Projektverlauf nachvollziehbar zu halten.*