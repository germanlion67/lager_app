# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Arbeitsübersicht über **aktuellen Projektstatus**, **offene Aufgaben**, **Prioritäten** und **technische Optimierungen** der **Lager_app**.

**Version:** 1.0.0+78 | **Zuletzt aktualisiert:** 11.07.2026

> **Hinweis:**  
> Diese `OPTIMIZATIONS.md` ist das **laufende Arbeitsdokument** für Status, Prioritäten und Roadmap.  
> Wenn eine Maßnahme **abgeschlossen, historisch relevant und versioniert** ist, wird sie in `HISTORY.md` überführt.  
> Dadurch bleiben Status-Dokument und Historie sauber getrennt und vermeiden unnötige Dopplungen.

> **Technische Referenz für Sync-Details:**  
> Für Push/Pull, Konflikterkennung, Bild-Sync, Invarianten, Edge Cases und Änderungsverbote gilt primär **`docs/SYNC.md`**.

---

## 🏷️ Kürzel-Register

### Legende
- `B` = Bug / Befund / Verifikation / Analyse
- `F` = Feature / sichtbare Funktion / UX
- `H` = Hosting / Hardening / Infrastruktur / Deployment
- `K` = Kern / Grundlagen / Architektur-Meilenstein
- `M` = Maßnahme / größeres Feature / funktionale Erweiterung
- `N` = Nichtfunktionales / Branding / visuelle Ergänzung
- `O` = Optimierung / Refactoring / Codequalität
- `P` = Performance / Plattform / Laufzeitverbesserung
- `T` = Tests / Testinfrastruktur / Testausbau

### Nächste freie Kürzel
- `B-020`, `F-013`, `H-006`, `K-008`, `M-015`, `N-007`, `O-022`, `P-010`, `T-013`

### Vergaberegel
Ein Kürzel gilt **ab dem ersten dokumentierten Auftreten als dauerhaft reserviert** —  
auch dann, wenn der Punkt später verschoben, umbenannt oder nach `Future` verschoben wird.

Commit-Meldungen  `fix:`- Bugfix,  `feat:`-Neues Future, `docs`- Dokumentation, `style`- Formatierung, `refactor`- Code-Umbau, Future/Fix, `test`- Test hinzugefügt, `chore`- Build, Config, Dependencies
---

## 🔴 Priorität: Hoch

### F-012: Web-Version — UI/UX & Funktionsprobleme (Issue #67)
**Beschreibung:**
Sammlung von Bugs und UX-Problemen die ausschließlich die Web-Version betreffen,
gemeldet in Issue #67. Alle Änderungen ausschließlich hinter `kIsWeb`-Guards oder
in Web-spezifischen Layout-Zweigen — Mobile- und Desktop-Native-Verhalten bleibt
unverändert.

**Betroffene Bereiche:**
- `app/lib/screens/` — Detail-, Erfassen-, Listen-, Settings-Screen
- `app/lib/widgets/` — NavigationRail, Sync-Button, Scanner-Button
- `app/lib/services/` — Auth-Persistenz (Web), Speicherpfad (Web)

---

#### 🔴 Prio 1 — Bugs (blockierend)

- [x] **F-012.1: Speichern schlägt fehl — `ArtikelDbService` im Web nicht verfügbar**
  **Symptom:**
  ```
  Speichern fehlgeschlagen: Unsupported operation: ArtikelDbServive ist im Web
  nicht verfügbar. Nutze PocketBase direkt im Web.
  ```
  **Ursache:** Speichern-Pfad ruft `ArtikelDbService` (SQLite) auf — im Web nicht verfügbar.
  **Lösung:** `kIsWeb`-Guard im Speichern-Pfad ergänzen — Web speichert direkt via
  `PocketBaseService`, Mobile/Desktop weiterhin via lokale DB + Sync.
  **Betroffene Datei(en):** Speichern-Logik in Detail-Screen / Controller
  **Aufwand:** ~1–2 h | **Risiko:** Mittel
  **Erledigt:** `_speichernWeb()` via `PocketBaseService` implementiert, `kIsWeb`-Guard in `_speichern()` ergänzt.

- [x] **F-012.2: Speichern-Button nicht sichtbar beim Bearbeiten**
  **Symptom:** Speichern-Button erscheint erst nach Wechsel zur Listenansicht und zurück.
  **Ursache:** State-Rebuild-Problem — Edit-Modus wird gesetzt, aber Button-Bereich
  wird nicht neu gerendert. Im Master-Detail-Layout (Desktop-Web) propagiert
  `ValueNotifier` möglicherweise nicht korrekt über Widget-Tree-Grenzen.
  **Lösung:** `setState(() { _isEditMode = true; })` sicherstellen; `ValueNotifier`-
  Propagierung im Desktop-Layout prüfen.
  **Betroffene Datei(en):** `artikel_detail_content.dart` (Web-Pfad)
  **Aufwand:** ~30 min | **Risiko:** Niedrig
  **Erledigt:** `onStateChanged`-Callback in `ArtikelDetailContent` ergänzt — Wrapper rebuildet AppBar-Actions bei jedem `setState` des Content-Widgets.

- [x] **F-012.3: Sync-Elemente im Web ausblenden**
  **Symptom:** Sync-Zeitstempel-Toggle hat keine sichtbare Wirkung im Web. Sync-Button und Spinner erscheinen im Web-Layout.
  **Ursache:** `ValueListenableBuilder` für `showLastSyncNotifier` und Sync-Button/-Spinner nicht hinter `kIsWeb`-Guard.
  **Lösung:** Sync-Button/-Spinner und `showLastSyncNotifier`-Block in AppBar hinter `if (!kIsWeb)` Guard. Sync-Destination aus NavigationRail entfernt, Index angepasst.
  **Betroffene Datei(en):** AppBar-Widget, NavigationRail-Widget
  **Aufwand:** ~30 min | **Risiko:** Niedrig
  **Erledigt:** Alle drei Sync-Elemente (Button, Spinner, Zeitstempel) hinter `if (!kIsWeb)` Guard. NavigationRail-Index korrigiert.

- [x] **F-012.4: Detailansicht — Titel und Buttons beim ersten Klick falsch**
  **Symptom:** Beim ersten Klick auf einen Artikel bleibt der Titel auf dem vorherigen
  Artikel stehen. Buttons (Bearbeiten, Anhang, PDF, Löschen) fehlen beim ersten Klick komplett.
  **Ursache:** `_DetailPanelHeader` wird von Flutter recycelt (kein Widget-Neuaufbau bei
  Artikel-Wechsel) — `contentKey.currentState` ist beim ersten Render `null`,
  `didUpdateWidget` greift zu spät. `GlobalKey` wurde als `final` deklariert und für
  verschiedene Artikel wiederverwendet.
  **Lösung:** `ValueKey(uuid)` auf `_DetailPanelHeader` → erzwingt Neuinstanziierung bei
  Artikel-Wechsel. `_detailContentKey` von `final` auf nicht-final geändert, wird bei
  jedem `_onArtikelTap()` neu erzeugt. `super.key` in `_DetailPanelHeader`-Konstruktor ergänzt.
  **Betroffene Datei(en):** `artikel_list_screen.dart`
  **Aufwand:** ~1 h | **Risiko:** Niedrig
  **Erledigt:** 3 Änderungen in `artikel_list_screen.dart` — `super.key` ergänzt, `final`
  entfernt, `GlobalKey()` bei jedem Artikel-Wechsel neu erzeugt.

- [x] **F-012.5: NavigationRail verschwindet beim Wechsel zu Einstellungen**
  **Symptom:** Die linke Button-Leiste mit „Artikel" und „Einstellungen" verschwindet
  beim Wechsel zum Einstellungs-Screen.
  **Ursache:** `SettingsScreen` wird als eigenständige `Navigator.push()`-Route
  geöffnet und ersetzt den gesamten Screen inkl. `NavigationRail`. Im Desktop-Web-
  Layout muss er stattdessen im Content-Bereich rechts gerendert werden.
  **Lösung:** Web-Desktop: Settings als Content im bestehenden Layout rendern
  (Index-basiert), nicht als neue Route pushen. Mobile: unverändert.
  **Betroffene Datei(en):** Haupt-Navigation / Shell-Widget (Web-Pfad)
  **Aufwand:** ~1 h | **Risiko:** Mittel
  **Erledigt:** 
- _PanelMode.settings ergänzt
- _buildNavigationRail(): selectedIndex dynamisch, Desktop öffnet Panel
- _handleMenuAction(): Desktop-Guard, Mobile unverändert
- _buildSettingsPanel(): neues Panel konsistent mit Erfassen/Detail
- SettingsScreen: embedded-Parameter (Default false, kein Breaking Change)

---

#### 🟡 Prio 2 — UX-Verbesserungen

- [x] **F-012.6: Session-Verlust bei Browser-Refresh (F5)**
  **Symptom:** Bei jedem Tab-Refresh werden Zugangsdaten verworfen, Neuanmeldung
  erforderlich.
  **Ursache:** Auth-Token wird nur im Speicher gehalten, nicht in `localStorage`
  persistiert.
  **Lösung:** Web: Auth-Token + Model in `localStorage` persistieren und beim
  App-Start wiederherstellen. Prüfen ob PocketBase Dart SDK `AsyncAuthStore`
  für Web bereits nutzbar ist.
  **Betroffene Datei(en):** Auth-Initialisierung / `pocketbase_service.dart` (Web-Pfad)
  **Aufwand:** ~1–2 h | **Risiko:** Mittel
  **Erledigt:**
  ### F-012.6 ✅ Session-Verlust bei Browser-Refresh
- auth_store_factory.dart: conditional export (Web/Native)
- auth_store_factory_web.dart: package:web localStorage
- auth_store_factory_native.dart: SharedPreferences
- pocketbase_service.dart: _createClient() mit AsyncAuthStore
- initialize() + updateUrl(): _createClient() statt PocketBase()
- logout(): authStore.clear() löscht localStorage automatisch


- [x] **F-012.7: Scanner-Button — kontextabhängige Funktion je nach Plattform**
  **Symptom:** Scanner-Button im Web macht auf Desktop keinen Sinn (kein Kamera-
  Scanner verfügbar).
  **Gewünschtes Verhalten:**
  - Mobil: Kamera-Scanner öffnen (unverändert)
  - Desktop-Web: Texteingabe-Dialog für Artikelnummer-Suche
  - Desktop-Web mit HID-Scanner (Nice-to-have): Scanner-Input direkt verarbeiten
    (HID-Scanner sendet Tastatureingaben — schnelle Zeichenfolge + Enter erkennbar)
  **Lösung Stufe 1:** `kIsWeb`-Guard → Texteingabe-Dialog statt Kamera.
  **Lösung Stufe 2 (optional):** `FocusNode` + Keyboard-Listener für HID-Scanner-
  Erkennung (Geschwindigkeit der Eingabe als Heuristik).
  **Betroffene Datei(en):** Scanner-Button-Widget (Web-Pfad)
  **Aufwand:** ~1–2 h (Stufe 1: ~30 min) | **Risiko:** Niedrig

- [x] **F-012.8: TAB-Navigation beim Erstellen neuer Artikel**
  **Symptom:** Kein Weiterspringen per TAB-Taste zwischen Eingabefeldern im
  Erfassen-Screen.
  **Lösung:** `FocusNode`-Kette für alle Felder + `TextInputAction.next` +
  `onSubmitted`-Handler der jeweils nächsten `FocusNode.requestFocus()` aufruft.
  Gilt primär für Web/Desktop — Mobile-Verhalten unverändert.
  **Betroffene Datei(en):** `artikel_erfassen_screen.dart` (Web-Pfad / Desktop)
  **Aufwand:** ~30 min | **Risiko:** Sehr niedrig

---

#### 🟢 Prio 3 — Nice-to-Have

- [x] **F-012.9: Sync-Button im Web prüfen und ggf. ausblenden**
  **Symptom:** Sync-Button in der Web-Version möglicherweise nicht benötigt, da
  Web direkt gegen PocketBase arbeitet (kein lokaler SQLite-Cache).
  **Lösung:** Nach Klärung von F-012.1 (Speicherpfad) entscheiden ob Sync-Button
  im Web konzeptionell sinnvoll ist. Falls nicht: `if (!kIsWeb) SyncButton()`.
  **Abhängigkeit:** F-012.1 muss zuerst abgeschlossen sein.
  **Betroffene Datei(en):** Sync-Button-Widget
  **Aufwand:** ~10 min | **Risiko:** Sehr niedrig

---

**Aufwand gesamt:** ~7–11 Stunden
**Risiko gesamt:** Mittel (F-012.1, F-012.5, F-012.6) | Niedrig (Rest)
**Abhängigkeiten:**
- F-012.9 → F-012.1 zuerst abschließen
- F-012.2 → F-012.1 zuerst prüfen (gleicher Speicherpfad betroffen)

> ⚠️ **Regel für alle F-012-Änderungen:**
> Ausschließlich Web-Codepfade anfassen — alle Änderungen hinter `kIsWeb`-Guards
> oder in Web-spezifischen Layout-Zweigen.
> Mobile- und Desktop-Native-Verhalten bleibt **unverändert**.


### P-009: TBT & Speed Index reduzieren (JS-Bundle-Optimierung)
**Beschreibung:**
Lighthouse-Timespan-Audit (P-006) zeigt TBT 1.140 ms und Speed Index 6,6 s.
Hauptursache: `main.dart.js` mit 4.093 ms Script Evaluation (18 lange Tasks beim Start).
Alle Build-Flags sind bereits optimal (--wasm, --tree-shake-icons, --no-source-maps).
Die verbleibenden Hebel sind: Brotli-Komprimierung, Preload-Hints und Deferred Loading.

**Ausgangslage (v0.9.9+75):**

| Metrik | Aktuell | Ziel |
|:--|:--|:--|
| Total Blocking Time | 780 ms (ohne Login) | < 400 ms |
| Speed Index | 6,6 s | < 4,0 s |
| Bundle-Größe (Transfer) | ~3.077 KB | < 2.500 KB |

**Tasks nach Priorität:**

#### Prio 1 — Quick Wins (< 30 Minuten gesamt)

- [x] **P-009.1: Brotli + Zstd in Caddy aktivieren** Service Worker entfernen: ✅ ABGESCHLOSSEN
  `docker-entrypoint.sh`: `encode gzip` → `encode { zstd br gzip }`
  Caddy 2.7.6 unterstützt beide nativ — kein Plugin nötig.
  **Erwartung:** Bundle-Transfer ~527 KB kleiner (~17%)
  **Ergebnis:** Die App läuft sauber mit: ✅ WASM-Bundle, ✅ Skia WASM-Renderer, ✅ Kein Service Worker, ✅ Alle Requests HTTP 200 

- [x] **P-009.2: `modulepreload` für `main.dart.js` in `index.html`**: ✅ ABGESCHLOSSEN
  `<link rel="modulepreload" href="main.dart.js">` direkt nach preconnect-Links.
  Startet Download + Parse des JS-Loaders früher.
  **Erwartung:** Speed Index -200 bis -400 ms
  **Ergebnis:** Browser sieht `modulepreload` beim ersten HTML-Parse, `main.dart.mjs` wird sofort heruntergeladen und geparst. Wenn `flutter_bootstrap.js` es dann anfordert → bereits im Cache, kein Warten. 

- [x] **P-009.3: `--pwa-strategy=none` im Dockerfile**: ✅ ABGESCHLOSSEN
  Service Worker generiert ~50 ms extra Evaluierungszeit beim ersten Load.
  Kein dokumentierter Offline-Bedarf für interne App.
  ⚠️ Prüfen: Falls PWA-Installation gewünscht → `offline-first` behalten.

#### Prio 2 — Strukturell (2–4 Stunden)

- [ ] **P-009.4: Deferred Loading für sekundäre Screens**
  Neue Datei: `app/lib/core/deferred_screen_loader.dart`
  Deferred imports für: `ArtikelErfassenScreen`, `SettingsScreen`,
  `SyncManagementScreen`, `ConflictResolutionScreen`
  Navigation über `DeferredScreenLoader`-Wrapper.
  **Erwartung:** TBT von ~780 ms auf ~350 ms (geschätzt ~55% Reduktion)
  **Risiko:** Mittel — Navigation-Tests müssen angepasst werden.
  Funktioniert nur Web/WASM, Android/Desktop unverändert.

#### Prio 3 — CI-Hygiene (30 Minuten)

- [ ] **P-009.5: Web-Build-Verifikation in `ci.yml`**
  Neuer Job `build-web-verify` nach `test`.
  Baut Web mit WASM-Flags und prüft ob `main.dart.wasm` vorhanden ist.
  Verhindert dass Build-Regressions erst beim Docker-Push auffallen.

**Aufwand gesamt:** ~3–5 Stunden
**Risiko:** P-009.1–3 niedrig | P-009.4 mittel | P-009.5 niedrig
**Abhängigkeit:** Keine Blocker. P-009.1–3 unabhängig voneinander umsetzbar.

--- 

## 🟡 Priorität: Mittel

---

### P-006: Lighthouse Timespan-Befunde (Laufzeit-Performance, Thumbnails, API-Latenz)
**Beschreibung:**
Lighthouse-Timespan-Audit vom 12.05.2026 über ~21 Sekunden Nutzerinteraktion (Login → Artikelliste → Sync).
Ergänzt H-004 (Seitenstart) um Laufzeit-Befunde. Performance-Score: 57, Best Practices: 74.

**Timespan-Ergebnisse:**

| Metrik | Wert | Ziel | Status |
|:--|:--|:--|:--|
| Total Blocking Time | 1.140 ms | < 200 ms | ❌ |
| INP (Interaction to Next Paint) | 250 ms | < 200 ms | 🟡 |
| Cumulative Layout Shift | 0 | < 0,1 | ✅ |
| API-Serverlatenz (`api.germanlion67.de`) | 592 ms | < 200 ms | 🟠 |
| Main-Thread-Arbeit | 4,6 s | < 2 s | ❌ |

**INP-Aufschlüsselung (250 ms):**

| Unterabschnitt | Dauer | Bewertung |
|:--|:--|:--|
| Eingabeverzögerung | 14 ms | ✅ |
| Verarbeitungsdauer | 35 ms | ✅ |
| Präsentationsverzögerung | 199 ms | ❌ Flaschenhals (Flutter CanvasKit Rendering) |

**Thumbnail-Größen (60×60 Thumbnails via PocketBase `?thumb=60x60`):**

| Bild | Transfer | Erwartet | Faktor |
|:--|:--|:--|:--|
| `esp32_terminal_adapter` | 80 KB | ~3–5 KB | 16–27× zu groß |
| `usb_a_steckerkabel` | 60 KB | ~3–5 KB | 12–20× zu groß |
| `mh_sensor` | 19 KB | ~2–3 KB | 6–10× zu groß |

**Hauptursache TBT:** `main.dart.js` mit 4.093 ms Script Evaluation (davon 18 lange Tasks, bis 264 ms einzeln).

---

**Tasks nach Priorität:**

#### Prio 1 — Thumbnail-Größe prüfen und optimieren

- [ ] **P-006.1: PocketBase Thumbnail-Generierung prüfen**
  Prüfen ob `?thumb=60x60` tatsächlich auf 60×60 Pixel skaliert oder das Originalbild
  mit hoher Qualität ausliefert. Ggf. JPEG-Qualität in PocketBase-Settings reduzieren
  oder Thumbnails clientseitig mit `CachedNetworkImage` + `memCacheWidth`/`memCacheHeight`
  begrenzen.

  ```bash
  # Prüfe tatsächliche Bildgröße:
  curl -s "https://api.germanlion67.de/api/files/artikel/q6zz1lqszs1ent0/27_esp32_terminal_adapter_pslchsymkr.jpg?thumb=60x60" | identify -
  ```

  **Wirkung:** Thumbnail-Traffic von ~160 KB auf ~10–15 KB reduzierbar (90%+ Einsparung)

- [ ] **P-006.2: Bilder vor Upload verkleinern**
  Prüfen ob `AppConfig.maxWidth`/`maxHeight` für Uploads ausreichend niedrig sind.
  Große Originalbilder führen zu großen Thumbnails.
  **Wirkung:** Kleinere Originale → kleinere Thumbnails

#### Prio 2 — API-Latenz untersuchen

- [ ] **P-006.3: PocketBase Thumbnail-Caching prüfen**
  592 ms durchschnittliche Serverlatenz für Bild-API. Prüfen ob PocketBase Thumbnails
  beim ersten Abruf on-the-fly generiert und danach cachet. Wiederholte Aufrufe sollten
  schneller sein.

  ```bash
  # Erster Abruf (ggf. Generierung):
  time curl -s -o /dev/null "https://api.germanlion67.de/api/files/artikel/q6zz1lqszs1ent0/27_esp32_terminal_adapter_pslchsymkr.jpg?thumb=60x60"
  # Zweiter Abruf (Cache):
  time curl -s -o /dev/null "https://api.germanlion67.de/api/files/artikel/q6zz1lqszs1ent0/27_esp32_terminal_adapter_pslchsymkr.jpg?thumb=60x60"
  ```

  **Wirkung:** Klärung ob Latenz einmalig (Generierung) oder dauerhaft

#### Prio 3 — Bewusst akzeptiert

- **INP Präsentationsverzögerung (199 ms)** — Flutter CanvasKit rendert auf Canvas statt
  nativem DOM. Nicht direkt optimierbar ohne Renderer-Wechsel. WASM-Build (H-004.5)
  könnte hier helfen.
- **18 lange Tasks aus `main.dart.js`** — Flutter-Web-typisch. Gleiche Ursache wie bei
  H-004 (Seitenstart). WASM-Build ist der effektivste Hebel.

---

**Aufwand gesamt:** ~1–2 Stunden (P-006.1–P-006.3)
**Risiko:** Niedrig

--- 

### P-008: PocketBase Thumbnail-Konfiguration optimieren
**Beschreibung:**
Analyse vom 20.05.2026 ergab: Das `bild`-Feld der `artikel`-Collection hat
`"thumbs": []` — PocketBase generiert **keine** Thumbnails.
Der `?thumb=60x60`-Query-Parameter im Code wird ignoriert, PocketBase liefert
stattdessen das Originalbild aus (bis zu 5 MB pro Request).

**Betroffene Stellen im Code:**
- `app/lib/config/app_config.dart` → `pbThumbGroesse = '60x60'` (nur Listenansicht)
- `app/lib/widgets/artikel_bild_widget.dart` → `_getPbUrl()`, `_getPbThumbUrl()`
- `app/lib/screens/artikel_detail_content.dart` → `_buildVollbildContent()`
  (Vollbildviewer mit `maxScale: 5.0` lädt Originalbild ohne Thumbnail-Parameter)

**Empfohlene Thumbnail-Größen (aus Code-Analyse):**

| Größe | Verwendung | Begründung |
|:--|:--|:--|
| `60x60` | Listenansicht (`artikelListBildSize = 50px`) | Entspricht `pbThumbGroesse`; 2× DPI → 100px |
| `400x400` | Detailansicht (`artikelDetailBildHoehe = 200px`, volle Breite) | 2× DPI → 400px |
| `1200x1200` | Vollbildviewer (`maxScale: 5.0`) | 200px × 5× Zoom = 1000px + Reserve |

**Erforderliche Änderungen:**

1. **Neue Migration** `server/pb_migrations/1775100000_updated_artikel_thumbs.js`
   — `thumbs: ["60x60", "400x400", "1200x1200"]` für Feld `file1962578385`

2. **`app_config.dart`** — zwei neue Konstanten:
   `pbThumbGroesseDetail = '400x400'` und `pbThumbGroesseVollbild = '1200x1200'`

3. **`artikel_bild_widget.dart`** — `_getPbUrl()` nutzt `400x400` für
   Detailansicht-Fallback statt Originalbild

4. **`artikel_detail_content.dart`** — `_buildVollbildContent()` nutzt
   `1200x1200` statt Originalbild für `InteractiveViewer`

**Wichtiger Hinweis:**
Bestehende Bilder erhalten neue Thumbnails **nicht automatisch** — PocketBase
generiert Thumbnails nur beim Upload. Neue Uploads ab der Migration sind sofort korrekt.
Für bestehende Bilder ist ein Re-Upload oder manueller Trigger erforderlich.

**Wirkung:** Thumbnail-Traffic von bis zu 5 MB auf ~5–300 KB pro Bild reduzierbar.
Direkte Synergie mit P-006.1 (Thumbnail-Größe prüfen).

**Aufwand:** ~2–3 Stunden | **Risiko:** Niedrig
**Abhängigkeit:** Löst P-006.1 strukturell — P-006.1 kann danach als erledigt markiert werden.

**Nächste freie Kürzel nach Vergabe:** `P-009`

--- 

### M-014: Readonly-User-Rolle — PocketBase API Rules + App-UI-Integration

**Beschreibung:**
Einführung einer serverseitigen Readonly-Rolle für PocketBase-User kombiniert mit
einer UI-seitigen Anpassung der Lager_app (Web). Ziel: Bestimmte User dürfen alle
Artikel lesen, aber keine Änderungen (Create/Update/Delete) vornehmen.
Die Sperre greift serverseitig (PocketBase API Rules) — die App-UI blendet
Aktions-Buttons für Readonly-User zusätzlich aus (saubere UX).

**Hintergrund:**
Aktuell darf jeder authentifizierte User alle CRUD-Operationen ausführen:
`createRule / updateRule / deleteRule = "@request.auth.id != \"\""`.
Es gibt keine Rollenunterscheidung. Ein Readonly-User sieht aktuell alle
Bearbeitungs-Buttons, die dann serverseitig mit einem Fehler abgewiesen werden.

---

#### Teil 1 — PocketBase: Rolle und API Rules (serverseitig)

**Schritt 1: `role`-Feld in `users`-Collection ergänzen**
- PocketBase Admin → Collections → `users` → Edit
- Neues Feld: `role` (Typ: `text`, nicht required, Default: leer)
- Mögliche Werte: `""` / `"user"` → Vollzugriff | `"readonly"` → Nur Lesen

**Schritt 2: API Rules in `artikel`-Collection anpassen**

| Regel | Aktuell | Neu |
|---|---|---|
| `listRule` | `@request.auth.id != ""` | `@request.auth.id != ""` *(unverändert)* |
| `viewRule` | `@request.auth.id != ""` | `@request.auth.id != ""` *(unverändert)* |
| `createRule` | `@request.auth.id != ""` | `@request.auth.id != "" && @request.auth.record.role != "readonly"` |
| `updateRule` | `@request.auth.id != ""` | `@request.auth.id != "" && @request.auth.record.role != "readonly"` |
| `deleteRule` | `@request.auth.id != ""` | `@request.auth.id != "" && @request.auth.record.role != "readonly"` |

> ⚠️ Gleiches Schema für alle weiteren Collections mit Schreibzugriff wiederholen
> (z. B. Anhänge, Dokumente — je nach vorhandenem Collection-Set).

**Schritt 3: Readonly-User anlegen**
- PocketBase Admin → Collections → `users` → New record
- E-Mail + Passwort setzen
- Feld `role` = `"readonly"` eintragen → Speichern ✅

---

#### Teil 2 — App-UI: Readonly-Modus (Flutter / Web)

**Ziel:** App liest `role` des eingeloggten Users nach dem Login aus und
blendet Aktions-Buttons (Speichern, Löschen, Bild ändern, Anhang hinzufügen)
für Readonly-User aus — statt sie mit einem Serverfehler abzuweisen.

**Betroffene Bereiche:**
- `app/lib/services/pocketbase_service.dart` — `role`-Getter aus `authStore.model`
- `app/lib/providers/` oder `app/lib/core/` — neuer `isReadonly`-Accessor
- `app/lib/screens/artikel_detail_content.dart` — Bearbeiten/Löschen/Bild-Buttons
- `app/lib/screens/artikel_erfassen_screen.dart` — Speichern-Button / Zugriff sperren
- `app/lib/widgets/` — Sync-Button, Anhang-Button (falls vorhanden)

**Implementierungsvorschlag:**

```dart
// pocketbase_service.dart — neuer Getter
bool get isReadonlyUser {
  final role = _client.authStore.record?.getStringValue('role') ?? '';
  return role == 'readonly';
}
// In ArtikelDetailContent — Beispiel für Button-Guard
if (!pocketBaseService.isReadonlyUser)
  IconButton(
    icon: const Icon(Icons.edit),
    onPressed: _startEditMode,
  ),
```
Wichtig: Alle UI-Guards ausschließlich additiv — kein Entfernen bestehender
Logik, nur if (!isReadonly) vor betroffenen Widgets.
Serverseitige Sperre (Teil 1) bleibt die primäre Sicherheitsebene.

Tasks:

role-Feld in users-Collection in PocketBase anlegen
API Rules für artikel (und weitere Collections) anpassen
Readonly-User in PocketBase anlegen und testen (serverseitig verifizieren)
isReadonlyUser-Getter in pocketbase_service.dart ergänzen
artikel_detail_content.dart: Bearbeiten/Löschen/Bild-Buttons hinter Readonly-Guard
artikel_erfassen_screen.dart: Speichern-Button / Screen-Zugang für Readonly sperren
Anhang- und Dokument-Buttons prüfen und ggf. ausblenden
Manueller E2E-Test: Readonly-User Web — Lesen ✅, Schreiben ❌ (Buttons ausgeblendet)
Manueller E2E-Test: normaler User — alle Funktionen unverändert ✅
Unit-Test: isReadonlyUser-Getter (role = "readonly", role = "", role = "user")
Aufwand: ~3–5 Stunden | Risiko: Niedrig
Plattform: Primär Web — Mobile/Desktop-Native-Verhalten unverändert (kein kIsWeb-Guard
erforderlich, da Readonly-Logik plattformunabhängig sinnvoll ist)
Abhängigkeiten: Keine Blocker. Unabhängig von F-012 und P-009 umsetzbar.

Commit-Vorschlag: feat: readonly user role — PocketBase API rules + app UI guards (M-014)

--- 


## 🟢 Priorität: Nice-to-Have

### O-021: State Management modernisieren 


--- 

### O-015: Dependency-Hygiene
**Beschreibung:**
`flutter_local_notifications: ^21.0.0` wird nirgends im Code importiert
(0 Treffer bei grep). Die Dependency kann entfernt werden.

Weitere Kandidaten (`webdav_client`) werden mit O-014 adressiert.

**Verifiziert per grep:**
- `flutter_local_notifications` → 0 Treffer in `app/lib/` ✅
- `google_fonts` → genutzt in `app_theme.dart` → behalten ✅
- `provider` → genutzt in 8 Dateien → behalten ✅

**Tasks:**
- [ ] `flutter_local_notifications` aus pubspec.yaml entfernen
- [ ] `flutter pub get` + `flutter test` grün

**Aufwand:** 10 Minuten | **Risiko:** Sehr niedrig

--- 

### F-010: Nutzerfreundliche Aktivitäts-Logs (UserLogService)
**Beschreibung:**  
Neben den bestehenden technischen Entwickler-Logs (AppLogService) soll eine zweite, menschenlesbare Log-Ebene eingeführt werden. Diese zeigt dem Nutzer verständliche Aktivitätsmeldungen wie „Artikel ‚LED Strip 5m' erstellt und synchronisiert", „Synchronisation abgeschlossen — 3 aktualisiert" oder „Verbindung zum Server verloren" statt technischer Debug-Ausgaben mit UUIDs und ETags.

**Abgrenzung zu O-012:**  
O-012 (Entwickler-Summary-Logs) bleibt unverändert bestehen. F-010 ist eine eigenständige, nutzerseitige Funktion.

**Design-Entscheidungen**
- Eigener `UserLogService` mit eigenem Datenmodell (`UserLogEntry`), getrennt von `AppLogService`
- Viewer als eigener Dialog, erreichbar über den Settings-Screen
- Umschaltung zwischen Entwickler-Log und Nutzer-Log per Einstellung im Settings-Screen
- Sprache: Deutsch, aber lokalisierbar vorbereitet (Nachrichtentexte über Hilfsmethoden oder einfache l10n-Abstraktion, kein volles ARB/intl erforderlich)
- Keine Feldänderungs-Diffs — geloggt wird auf Artikelebene (erstellt / geändert / gelöscht / synchronisiert), nicht auf Feldebene
- Persistenz über App-Neustart hinweg (SQLite-Tabelle `user_log`)
- Automatisches Löschen von Einträgen älter als X Tage (konfigurierbar, Default z. B. 14 Tage), Cleanup beim App-Start oder vor dem Anzeigen

**Geplante Nutzer-Log-Quellen**
- `PocketBaseSyncService` — Push-Ergebnisse (CREATE/UPDATE/DELETE ok/fail), Pull-Zusammenfassung, Verbindungsfehler
- `SyncOrchestrator` — Sync gestartet / abgeschlossen / fehlgeschlagen
- `main.dart` — Login / Logout

**Tasks**
- [ ] `UserLogEntry`-Modell mit `timestamp`, `level`, `message`
- [ ] `UserLogService` mit SQLite-Persistenz (`user_log`-Tabelle)
- [ ] Auto-Cleanup: Einträge älter als X Tage beim Start löschen
- [ ] DB-Migration für `user_log`-Tabelle
- [ ] Nutzer-Log-Aufrufe in `PocketBaseSyncService` (neben bestehenden technischen Logs)
- [ ] Nutzer-Log-Aufrufe in `SyncOrchestrator`
- [ ] Nutzer-Log-Aufrufe in `main.dart` (Auth-Events)
- [ ] Viewer-Dialog (`UserLogDialog`) mit Level-Filter und Löschen-Button
- [ ] Settings-Screen: Umschaltung Entwickler-Log / Nutzer-Log
- [ ] Lokalisierbare Nachrichtentexte vorbereiten
- [ ] Unit-Tests für `UserLogService` (CRUD, Cleanup, Kapazitätsgrenze)
- [ ] Widget-Test für Viewer-Dialog
- [ ] `docs/LOGGER.md` um Nutzer-Log-Konzept ergänzen

**Aufwandsschätzung:** ~5–6 Stunden

**Abhängigkeiten:**  
Keine Blocker. Greift nicht in bestehende Sync-Logik ein — nur additive Log-Aufrufe neben den bestehenden technischen Logs.

--- 

## ⏭️ Future (nicht in Planung)

### H-001: iOS/macOS Vorbereitung
Erfordert Apple Developer Account. Zurückgestellt bis Account verfügbar.

### N-006: Nextcloud-Workflow
WebDAV-Anbindung finalisieren und mit Nextcloud 28+ testen.

---

### O-018: Hardcoded deutsche UI-Strings (Lokalisierungsvorbereitung)
**Beschreibung:**
20+ Stellen in Screens enthalten hardcoded deutsche Strings, vor allem
Fehlermeldungen in SnackBars. Aktuell kein funktionales Problem, aber
Hindernis für spätere Lokalisierung.

**Betroffene Screens:**
- `artikel_erfassen_screen.dart`
- `artikel_detail_screen.dart`
- `list_screen_mobile_actions.dart`
- `list_screen_web_actions.dart`
- `settings_screen.dart`

**Empfehlung:** Erst umsetzen wenn Mehrsprachigkeit tatsächlich geplant wird.
Bis dahin als dokumentierte technische Schuld belassen.

**Aufwand:** ~4–6 Stunden | **Risiko:** Niedrig | **Priorität:** Future

--- 

## 📊 Fortschritts-Übersicht

Die Priorisierung in diesem Dokument ist maßgeblich, die Zählwerte sind jedoch nur dann belastbar, wenn sie aktiv mitgepflegt werden.  
Im Zweifel gilt der inhaltliche Status der einzelnen Punkte über den numerischen Summen.

**Aktuell besonders relevante offene Themen**
- P-006: Thumbnail-Größen und API-Latenz untersuchen
- O-015: `flutter_local_notifications` entfernen

---

## ✅ Abgeschlossen

> **Hinweis:** Details zu den abgeschlossenen Punkten stehen in `HISTORY.md`.  
> Hier bleiben sie als kompakter Überblick mit Versionsbezug erhalten.



--- 

### B-019: Bild verschwindet nach Speichern im embedded Modus (Web) — abgeschlossen 2026-07-11 | `1.0.0+78`

`bildEntfernt`-Bedingung in `_speichernWeb()` war im Web-Mode dauerhaft `true` sobald ein Artikel mit Bild gespeichert wurde — weil `_bildPfad` im Web immer `null` ist (kein lokales Dateisystem). Folge: `body['bild'] = ''` wurde an PocketBase gesendet → Bild gelöscht → Platzhalter angezeigt.

**Root Cause:** `_bildPfad == null` kann im Web nicht als Signal für „Bild wurde entfernt" dienen.

**Fix:** `_remoteBildUrl == null` als zusätzliche Bedingung in `bildEntfernt` — die URL ist nur `null` wenn der Nutzer das Bild explizit entfernt hat.

**Weitere Verbesserungen im selben Commit:**
- `_buildBildBereich`: Spinner nur wenn `_remoteBildUrl == null` — verhindert dass Lade-Indikator ein bereits sichtbares Bild überdeckt
- `onStateChanged`-Callback via `addPostFrameCallback` verzögert — verhindert setState-during-build im AppBar-Rebuild

Verifiziert: Web (Windows Chrome via `web-server`) ✅ | `flutter analyze` 0 Issues | `flutter test` 1011/1011 ✅

---

### H-004: Lighthouse-Befunde beheben (Web-Performance, Security-Header, SEO) — abgeschlossen 2026-05-19 | `0.9.9+75`
**Beschreibung:**
Lighthouse-Audit vom 12.05.2026 ergab Score 62 (Performance), 92 (Barrierefreiheit), 81 (Best Practices), 91 (SEO). Die Hauptursache für den niedrigen Performance-Score ist die `main.dart.js` (4 MB unkomprimiert, 2.510 ms Total Blocking Time). Daneben fehlen Security-Header und eine `robots.txt`.

**Audit-Ergebnisse (Mobil-Emulation) — Ausgangslage 12.05.2026:**

| Metrik | Wert | Ziel | Status |
|:--|:--|:--|:--|
| First Contentful Paint | 0,8s | < 1,8s | ✅ |
| Largest Contentful Paint | 0,8s | < 2,5s | ✅ |
| Total Blocking Time | 2.510 ms | < 200 ms | ❌ |
| Cumulative Layout Shift | 0 | < 0,1 | ✅ |
| Speed Index | 9,4s | < 3,4s | ❌ |
| Time to Interactive | 17,0s | < 3,8s | ❌ |
| Server Response Time | 21 ms | < 600 ms | ✅ |

**Gesamtgröße Netzwerk:** 3.077 KiB (17 Requests, alle HTTP/2, Gzip aktiv)

**Größte Ressourcen:**

| Ressource | Transfer | Unkomprimiert | Anteil |
|:--|:--|:--|:--|
| `canvaskit.wasm` (Google CDN) | 1.631 KB | 5.687 KB | Flutter Engine |
| `main.dart.js` | 1.280 KB | 4.085 KB | App-Code |
| Fonts (Roboto + Material + Cupertino) | 139 KB | — | Schriften |

---

**Tasks nach Priorität:**

#### Prio 1 — Quick Fixes (Nginx-Config, je 2 min)

- [x] **H-004.1: `robots.txt` in Nginx bereitstellen**
  Nginx liefert `index.html` als Fallback für `/robots.txt` → 87 SEO-Fehler.

  ```nginx
  location = /robots.txt {
      add_header Content-Type text/plain;
      return 200 "User-agent: *\nDisallow: /\n";
  }
  ```

  **Wirkung:** SEO-Score ↑ 
  **Status:** ✅ Umgesetzt in `app/web/robots.txt` als statische Datei

- [x] **H-004.2: HSTS-Header setzen**
  Kein `Strict-Transport-Security`-Header vorhanden.

  ```nginx
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  ```

  **Wirkung:** Best Practices ↑
  **Status:** ✅ Umgesetzt im Caddyfile

#### Prio 2 — HTML-Anpassungen (index.html, je 1 min)

- [x] **H-004.3: Splash-Bild `width`/`height` und `fetchpriority` setzen**
  LCP-Bild (`splash/img/light-2x.png`) hat keine expliziten Dimensionen und kein Priority-Hint.

  ```html
  <img class="center" aria-hidden="true"
       src="splash/img/light-2x.png" alt=""
       width="256" height="256" fetchpriority="high">
  ```

  **Wirkung:** LCP-Discovery-Score ↑, Unsized-Images-Warnung weg
  **Status:** ✅ Umgesetzt in `app/web/index.html`

#### Prio 3 — Build-Optimierung (CI/CD, 5–30 min)

- [x] **H-004.4: `--tree-shake-icons` im Flutter-Build aktivieren**
  Ungenutzte Material-Icons werden aktuell mitgebaut.

  ```yaml
  # In GitHub Actions Workflow:
  flutter build web --release --tree-shake-icons
  ```

  **Wirkung:** `main.dart.js` etwas kleiner
  **Status:** ✅ Umgesetzt im Web-Build-Befehl

- [x] **H-004.5: WASM-Build evaluieren**
  Dart 3.11.5 unterstützt `flutter build web --wasm`. WebAssembly parst deutlich schneller
  als JavaScript → TBT sinkt signifikant.

  ```bash
  flutter build web --wasm
  ```

  **Risiko:** Experimentell — Browser-Kompatibilität und `dart:js_interop` prüfen.
  **Wirkung:** TBT potenziell von 2.510 ms auf < 500 ms

  **Status:** ✅ Abgeschlossen — `main.dart.wasm` im Build vorhanden.
  COOP/COEP-Header (`Cross-Origin-Opener-Policy`, `Cross-Origin-Embedder-Policy`) als
  Voraussetzung für Skwasm / SharedArrayBuffer im Caddyfile gesetzt.
  TBT-Ziel `< 500 ms` erreicht (430 ms).

  **Nebeneffekt:** Caddyfile und `config.js` werden jetzt dynamisch zur Laufzeit generiert
  (`app/docker-entrypoint.sh`) — `POCKETBASE_URL` wird korrekt in CSP eingesetzt,
  kein Image-Rebuild mehr bei URL-Änderung nötig. Siehe Commit `[0.9.9+73]`.

#### Prio 4 — Bewusst akzeptiert (kein Fix nötig)

- **`Intl.v8BreakIterator` deprecated** — kommt aus Flutter Engine (CanvasKit), wird mit
  zukünftigem Flutter-Release behoben. Kostet 5 Punkte bei Best Practices.
- **`meta-viewport user-scalable=no`** — Flutter setzt das automatisch. Kostet 10 Punkte
  bei Barrierefreiheit. Für interne App akzeptabel.
- **`main.dart.js` 55% unused code** — Flutter-Web-typisch (Tree Shaking auf JS-Ebene
  begrenzt). Durch WASM-Build (H-004.5) ersetzt — `main.dart.js` nicht mehr primärer Pfad.
- **Fehlende Source Maps** — `main.dart.js` ohne Source Map. Für Release-Build akzeptabel.
- **CSP `unsafe-inline` / fehlende `strict-dynamic`** — Flutter Web benötigt Inline-Scripts.
  Einschränkung würde App brechen.
- **Third-Party-Cookies (Google CDN/Fonts)** — geprüft, keine Cookies gesetzt. ✅

---

**Aufwand gesamt:** ~1,5 Stunden (H-004.1–H-004.5 inkl. Runtime-Config-Refactoring)
**Risiko:** Niedrig (H-004.1–H-004.4), Mittel (H-004.5 WASM) → Risiko eingetreten und gelöst

**Tatsächliche Score-Entwicklung:**

| Kategorie | Ausgangslage | Nach H-004.1–4 | Nach H-004.5 | Nach H-005 | Δ gesamt |
|:--|:--|:--|:--|:--|:--|
| Performance | 62 | 75 | 88 | 75 | +13 ✅ |
| Barrierefreiheit | 92 | 92 | 92 | 92 | ±0 |
| Best Practices | 81 | 81 | 81 | 81 | ±0 |
| SEO | 91 | 63 | 63 | **100** | +9 ✅ |


**Tatsächliche Metrik-Entwicklung (Zielzustand ohne Login, v0.9.9+75):**

| Metrik | Ausgangslage | Aktuell | Ziel | Status |
|:--|:--|:--|:--|:--|
| First Contentful Paint | 0,8 s | 0,8 s | < 1,8 s | ✅ |
| Largest Contentful Paint | 0,8 s | 1,5 s | < 2,5 s | ✅ |
| Total Blocking Time | 2.510 ms | 780 ms | < 200 ms | ⚠️ verbessert, Ziel noch offen |
| Cumulative Layout Shift | 0 | 0 | < 0,1 | ✅ |
| Speed Index | 9,4 s | 6,6 s | < 3,4 s | ❌ Flutter-architekturbedingt |
| Server Response Time | 21 ms | 21 ms | < 600 ms | ✅ |

> **Anmerkung Performance mit Login:**  
> TBT-Werte von 14.000–17.000 ms bei eingeloggtem Zustand sind auf den initialen
> Sync-Vorgang zurückzuführen (PocketBase-Abfragen + SQLite-Writes + WASM-Init parallel).
> Ohne Login normalisiert sich TBT auf ~780–1.030 ms. Strukturell bedingt, kein direkter Fix.

**Nächster Schritt:** H-005 abgeschlossen — SEO 100 ✅ (ohne Login, v0.9.9+75). H-005.3 offen.

---

### H-005: SEO-Korrekturen & Sicherheits-Header (Lighthouse-Audit 18./19.05.2026) — abgeschlossen 2026-05-20 | `0.9.9+75`
**Beschreibung:**
Lighthouse-Audit vom 18.05.2026 zeigte SEO-Score 63 (Regression gegenüber 91).
Hauptursache: `is-crawlable`-Befund (`robots.txt Disallow: /`) und fehlende Meta-Tags.
SEO 100 erreicht in v0.9.9+75 (ohne Login gemessen).

**Tasks:**

- [x] **H-005.1: `robots.txt` auf `Allow: /` setzen**
  `Disallow: /` war Hauptursache des `is-crawlable`-Befunds (SEO 63).
  **Status:** ✅ Erledigt in v0.9.9+75

- [x] **H-005.2: Meta-Description und `<title>` in `index.html` ergänzen**
  `<meta name="description">` und `<title>Lager_app | Lagerverwaltung</title>` gesetzt.
  **Status:** ✅ Erledigt in v0.9.9+75

- [x] **H-005.3: `X-Frame-Options`-Header setzen**
  Clickjacking-Schutz für Produktions-Deployment:

```nginx
  add_header X-Frame-Options "SAMEORIGIN" always;
``` 

Aufwand: 5 Minuten | Risiko: Sehr niedrig
Status: ✅ Bereits im Caddyfile gesetzt (Referenz-Doku bestätigt)

Tatsächliche Score-Entwicklung:

| Kategorie | Vorher | Nachher |
|:--|:--|:--|
| SEO | 63 | **100** ✅ (ohne Login, v0.9.9+75) |
| Best Practices | 81 | 81 |

---

### T-012: Testlücken bei produktiven Services schließen
**Beschreibung:**
6 produktiv genutzte Services haben keine Testdatei. Höchste Priorität hat
`pocketbase_service.dart` (492 Zeilen, zentraler Client-Service).

**Priorisierte Testliste:**

| Priorität | Service | Status |
|:--|:--|:--|
| 🔴 Hoch | `pocketbase_service.dart` | ✅ 51 Tests |
| 🟡 Mittel | `connectivity_service.dart` | ✅ 14 Tests |
| 🟡 Mittel | `sync_progress_service.dart` | ✅ 61 Tests |
| 🟡 Mittel | `sync_error_recovery.dart` | ✅ 87 Tests |
| 🟢 Niedrig | `tag_service.dart` | ✅ 43 Tests |
| 🟢 Niedrig | `database_service.dart` | ⏭️ Übersprungen — Shim ohne Logik |

T-012 abgeschlossen — alle relevanten Services abgedeckt.

--- 

## In History überführt

### O-014: Nextcloud-Code entkoppeln und entfernen — abgeschlossen 2026-05-16 | `0.9.9+70`

`ConflictData`, `ConflictResolution` und `SyncResult` aus `sync_service.dart` in neue
Datei `lib/services/conflict_types.dart` extrahiert. Alle abhängigen Dateien auf die
neuen Imports umgestellt.

Nextcloud-Referenzen aus `conflict_resolution_screen.dart`, `sync_conflict_handler.dart`,
`pocketbase_conflict_adapter.dart` und `main.dart` entfernt bzw. auf `conflict_types.dart`
umgestellt.

**Gelöschte Dateien:**
- `lib/services/nextcloud_service_interface.dart`
- `lib/services/nextcloud_sync_service.dart`
- `lib/services/sync_service.dart` (Conflict-Types extrahiert, Rest obsolet)
- `lib/widgets/nextcloud_resync_dialog.dart`

**Neue Datei:**
- `lib/services/conflict_types.dart`

`webdav_client` aus `pubspec.yaml` entfernt.
Tests und Mocks angepasst. `flutter analyze`: 0 Issues. `flutter test`: 755/755 (2 skipped).

--- 

### O-020: `_PocketBaseConflictAdapter` aus `main.dart` ausgelagert — abgeschlossen 2026-05-16 | `0.9.9+68`
Neue Datei `lib/services/pocketbase_conflict_adapter.dart`. Klasse ist jetzt public
(`PocketBaseConflictAdapter`) und ohne `main.dart`-Abhängigkeit wiederverwendbar.
`main.dart`: Import ergänzt, `_`-Prefix entfernt, keine Logik geändert.
`artikel_db_service.dart`: Singleton auf `_db` — Aufteilung würde Komplexität erhöhen
ohne Gewinn — kein Handlungsbedarf.

---

### O-019: `print()` in `app_config.dart` durch Logger ersetzt — abgeschlossen 2026-05-16 | `0.9.9+67`
`AppConfig.validateConfig()`: `print()` + `assert`-Wrapper entfernt, durch `_logger.w()`
ersetzt. Warnung erscheint jetzt auch im Release-Build — Placeholder-URL in Produktion
ist ein echtes Konfigurationsproblem, kein reines Debug-Signal.
`// ignore: avoid_print`-Kommentar entfällt. Konsistent mit bestehendem `_logger`-Einsatz
in `AppConfig.init()`.

---

### O-016: Timeout-Konstanten in AppConfig zentralisiert — abgeschlossen 2026-05-16 | `0.9.9+66`
Vier neue Timeout-Konstanten in `AppConfig` ergänzt: `connectivityCheckTimeout` (3s),
`backupStatusTimeout` (5s), `syncPushTimeout` (30s), `syncUploadTimeout` (120s).
`ConnectivityService._tcpCheck()` und `BackupStatusService.fetchStatus()` auf
`AppConfig.*Timeout` umgestellt. Keine Wertänderungen — reine Konstantenverlagerung.

---

### F-011: Responsive/Adaptive Layout für Desktop-Web — abgeschlossen 2026-05-15 | `0.9.8+62`
Mobile-first UI auf Desktop-Monitore ausgeweitet. Drei Stufen umgesetzt.

**Stufe 1** — Maximalbreite (600px, `ConstrainedBox`) ✅  
**Stufe 2** — Breakpoint-Helfer (`lib/core/responsive.dart`), `ArtikelListWidget` als Grid/Liste, `ArtikelDetailWidget` mit responsiver Feldanordnung, `NavigationRail` statt `BottomNavigationBar`, Settings zweispaltig ✅  
**Stufe 3** — Master-Detail ab ≥1024px: `ArtikelDetailContent` extrahiert, `ArtikelDetailScreen` als dünner Scaffold-Wrapper mit `ValueNotifier`-Rebuild, `embedded`-Parameter, `didUpdateWidget` bei Artikelwechsel, `maxContentWidth` auf 1400, neue `AppConfig`-Konstanten (`masterDetailMinWidth`, `masterListFlex`, `masterDetailFlex`, `breakpointTablet`, `breakpointDesktop`). F-011.8 (Sidebar) + F-011.9 (Seitenpanels) offen. 🟡

**Tests:** 50 Widget-Tests grün (24 Detail + 15 List + 11 Erfassen)  
**Risiko:** Niedrig (Stufe 1–2), Mittel (Stufe 3)

---

### O-017: `catch (e)` durch `catch (e, st)` ersetzen — abgeschlossen 2026-05-13 | `0.9.8+57`
`catch (e)` → `catch (e, st)` in `scan_service_stub.dart`, `artikel_import_service.dart` (2×),
`app_log_io.dart` (4×) ersetzt. StackTrace an Logger-Aufrufe durchgereicht.
`pdf_service_shared.dart` war bereits korrekt. Nextcloud-Stellen entfallen mit O-014.
`flutter analyze` grün.

---



### B-018: Artikelnummer wird bei Suche/Scan nicht gefunden — abgeschlossen 2026-05-13 | `0.9.8+57`
Artikelnummer-Feld in SQLite-Suche, PocketBase-Suche und Scanner-Fallback einbezogen.
Web-Fallback-Dialog (Texteingabe) nutzt jetzt denselben Codepfad wie der Scanner.
Verifiziert: Android Scanner ✅, Android Suche ✅, Web Texteingabe ✅

---

### P-007: UI-Performance `ArtikelListScreen` — abgeschlossen 2026-05-13 | `0.9.8+57`
Fünf Befunde in `artikel_list_screen.dart` behoben:

| Kürzel | Maßnahme |
|:---|:---|
| P-007.1 | `_gefilterteArtikel()` gecacht — Invalidierung via `identical()`-Referenzcheck |
| P-007.2 | `setState()` bei Keystroke entfernt — TextField steuert Anzeige intern |
| P-007.3 | `_aktualisiereFilter()` ohne separates `setState()` — 1 statt 2 Rebuilds pro Pagination |
| P-007.4 | `_ArtikelTile` + `_ArtikelInfoChip` als `StatelessWidget` extrahiert |
| P-007.5 | Scroll-Guard `_isLoadingMore`/`_hasMore` vor Pixel-Vergleich verschoben |

`flutter analyze` + `flutter test` grün.

---

### F-008: Hintergrund-Sync-Intervall konfigurierbar — abgeschlossen 2026-05-08 | `0.9.5+54`
Dropdown in Einstellungen: 1 Min / 5 Min / 15 Min (Standard) / Nur manuell.
Callback-Pattern (`onSyncIntervalChanged`) → `SettingsController` → `SharedPreferences` → `main.dart`.
Änderungen greifen sofort ohne App-Neustart. Verifiziert auf SM-A515F.

---

### B-016: `remoteBildPfad` beim Bild-Entfernen nicht in PocketBase geleert — abgeschlossen 2026-05-08 | `0.9.5+51`
Push-Update-Pfad sendet jetzt `body['remoteBildPfad'] = ''` zusammen mit `body['bild'] = null`.
1 Zeile in `pocketbase_sync_service.dart`. PocketBase Admin verifiziert ✅

---

### B-017: Kurzer BlueScreen bei Kamera-Permission-Entzug — abgeschlossen 2026-05-08 | `0.9.5+54`
Bekanntes Android-OS-Verhalten — kein fachlicher Fix nötig. Android beendet Activity bei
Permission-Entzug sofort (Security-Policy), Flutter startet neu. Kein Datenverlust.
Kosmetischer Fix: `ErrorWidget.builder` überschrieben → `SizedBox.shrink()` statt rotem ErrorWidget.

---

### P-004: Android Kamera-Test — abgeschlossen 2026-05-07 | `0.9.5+50`
Vollständige manuelle Verifikation auf SM-A515F (11 Tests). Happy Path, Abbrechen, Crop,
Bild ersetzen, Neuerfassung, Verwerfen-Dialog, Low-Memory-Kill — alle bestanden ✅
Befunde: B-016 (remoteBildPfad), B-017 (BlueScreen bei Permission-Entzug).

---

### O-013: Log-Viewer Default-Level konfigurierbar — abgeschlossen 2026-05-05 | `0.9.5+50`
Standard-Filter-Level (Trace–Fatal) in App-Einstellungen wählbar, via `SharedPreferences`
persistiert. Neue „Entwickler"-Card im Settings-Screen. ~94 Zeilen, ~25 Minuten.

---

### F-009: Kategorie-Eingabe in der Artikel-UX — abgeschlossen 2026-05-04 | `0.9.4+49`
Kategorie-Feld (Freitext, max 50 Zeichen) in Erfassen- und Detail-Screen. Chip in
Listenansicht. Kategorie-Filter als zweites Dropdown neben Ort-Filter (UND-verknüpft,
dynamisch aus Artikelliste). Keine Modell-/DB-/Sync-Änderungen nötig.
Verifiziert auf A515F + S20, PocketBase E2E bestätigt.

---

### T-001: Konfliktlösung, Sync-Hardening und Integrationsverifikation — abgeschlossen 2026-05-04 | `0.9.4+48`
Umfassende Absicherung der Konflikt- und Sync-Pipeline.

**Technisch abgesichert:** ConflictData/ConflictResolution/SyncResult, `detectConflicts()`,
`_determineConflictReason()`, Snapshot-Persistenz, Remote-Delete-Guards, Duplicate-UUID-Recovery,
`toPocketBaseMap()` (UTC-Timestamps, `artikelnummer`-Guard, keine Sync-Metadaten),
UTC-Konsistenz in `artikel_db_service.dart`, Zeitstempel-Semantik in `DATABASE.md`.

**Manuell verifiziert:** `force_local`, `force_merge`, `useRemote`, `skip`, Mehrfachkonflikte
(sequentiell), Soft-Delete lokal + Remote-Edit, UUID-Kollision als konservativer Konfliktfall
(T-001.18). Orchestrator-Timeout während offener Konflikt-UI nicht mehr reproduzierbar.

**Bewusst nicht umgesetzt:** Monitoring für Duplicate-UUID-Fallbacks, ETag-Vereinfachung,
ConflictCallback-Umbau, zusätzliche Modell-Randfälle, Interface-Entkopplung, Soft-Delete-Refactoring.

**Technische Referenz:** `docs/SYNC.md`

---

### M-013: Bild-Reset („Bild leeren") — abgeschlossen 2026-05-04 | `0.9.4+46`
Kontextsensitiver AppBar-Button (ein Button statt zwei): „Bild hinzufügen" / „Bild ändern".
BottomSheet mit Datei / Kamera / Zuschneiden / Bild entfernen (rot, mit Bestätigungsdialog).
Push sendet `body['bild'] = null`, Pull ruft `clearBildInfoByUuidSilent()` auf.
Lokale Bilddatei + Thumbnail physisch gelöscht, Image-Cache invalidiert.
Crop funktioniert jetzt auch für bestehende lokale Bilder.

**Folgefix `0.9.4+47`:** `artikel.copyWith(...)` an `ArtikelDetailBild` übergeben →
Placeholder sofort sichtbar. `CachedNetworkImage.evictFromCache()` vor `clearBildInfoByUuidSilent()`
→ kein 404-Log in Listenansicht.

---

### O-012: Sync-Logs mobil-lesbar — abgeschlossen 2026-05-04 | `0.9.4+44`
Strukturierte 1-Zeilen-Summary-Lines für Push/Pull/Orchestrator eingeführt, in `docs/LOGGER.md`
dokumentiert. Verbose-Flag bewusst verworfen — Log-Level-Filter (F-006) deckt den Use Case ab.

---

### T-001.18: UUID-Kollision als konservativer Konfliktfall — abgeschlossen 2026-05-03 | `0.9.4+42`
„Lokal offline neu erzeugt, vor erstem Sync gleicher Remote-Datensatz vorhanden" → bewusst
konservativer Konfliktfall (nicht stiller Auto-Recovery). Nach `useLocal`-Auflösung erfolgreicher
Folgesync, keine Dublette, kein Retry-Loop.

---

### T-001 (Ergänzung): Bildpfad-Testlücke + Delete-Konfliktfall — abgeschlossen 2026-05-03 | `0.9.4+41`
`_extractBildName()` und `remoteBildPfad` nach CREATE/UPDATE für `List<String>`, `String`,
`null` und leere Werte regressionssicher abgesichert. Soft-Delete lokal + Remote-Edit
erneut manuell verifiziert inkl. Gegenprobe.

---

### B-015: Orchestrator-Timeout während offener Konflikt-UI — abgeschlossen 2026-05-02 | `0.9.4+41`
Timeout-Behandlung konfliktbewusst: Während aktiver Benutzerauflösung kein Timeout.
Regelmäßige Wait-Logs während offener UI. Echte Netzwerkfehler weiterhin korrekt als
Fehler behandelt. Verhaltenstests in `sync_orchestrator_test.dart` ergänzt.

---

### B-003: `remoteBildPfad` nach CREATE/UPDATE in PocketBase — abgeschlossen 2026-04-30 | `0.9.4+39`
Follow-up-PATCH nach Bild-Upload setzt `remoteBildPfad` in PocketBase.
`downloadMissingImages()` erkennt Bild auf anderen Geräten korrekt (`downloaded=1`).
Verifiziert via Logs + PocketBase-Record (Δ created→updated = 147ms) ✅

---

### B-014 + O-012 (Anteil) — abgeschlossen 2026-04-29 | `0.9.4+37`
HTTP 400 CREATE behoben (`artikelnummer`-Guard + vollständiges PocketBase-Schema).
`markSynced()` Spaltennamen-Fix. Push-Timeouts (30s statt 60s Orchestrator-Timeout).
Summary-Logs für Sync-Phasen eingeführt.

---

### B-013: Image Upload Flow, `remoteBildPfad`, Ghost-File-Cleanup — abgeschlossen 2026-04-28 | `0.9.4+36`
Multipart-Bild-Upload in CREATE/UPDATE (`_buildFiles()`-Helper). `markSynced()` um
`remoteBildPfad` erweitert. `clearBildInfoByUuidSilent()` neu. Pull-Pfad entfernt
lokale Bildinfos bei leerem Remote-Feld. 692 Tests grün (+3 skipped).

---

### K-007: Flutter Update — abgeschlossen 2026-04-22 | `0.9.1+26`
Flutter 3.41.4 → 3.41.7, Dart 3.11.1 → 3.11.5. Package-Major-Updates: `csv`, `device_info_plus`,
`file_picker`, `flutter_local_notifications`, `share_plus`, `build_runner`.
`js`-Package entfernt (→ `dart:js_interop`). CI/CD-Workflows aktualisiert.

---

### T-009: Ergänzende Tests `SettingsController` — abgeschlossen 2026-04-23 | `0.9.2+32`
`saveSettings()`-Fehlerpfad, `showLastSync`-Default, Save-/Reset-/Dirty-State-Pfade abgesichert.
`settings_controller_test.dart` auf 15 Tests erweitert.

---

### O-010: `SettingsScreen` — Logik in testbaren Controller extrahieren — abgeschlossen 2026-04-23 | `0.9.1+29`
Settings-Logik (Laden/Speichern, Dirty-Tracking, PB-URL, DB-Status, App-Lock) in neuen `SettingsController` extrahiert. `SettingsScreen` auf UI-Verantwortung reduziert (Dialoge, SnackBars, Navigation, Rendering). `TextEditingController` bewusst pragmatisch im Controller belassen. Controller gezielt testbar gemacht, Save-/Reset-/Dirty-State- und Reject-/Success-Pfade abgesichert.

---

### F-007: Einstellung — Letzter-Sync-Zeitstempel ein-/ausblenden — abgeschlossen 2026-04-23 | `0.9.1+29`
Toggle in den Einstellungen zum Ein-/Ausblenden des Sync-Zeitstempels in der Artikelliste. Persistenz via `SharedPreferences` (`show_last_sync`), reaktiv via `ValueNotifier<bool>`, Default `true`. Hotfix `v0.9.0+25`: `ValueListenableBuilder` ergänzt (Toggle war zuvor funktionslos). Architektur-Bereinigung `v0.9.1+29`: State in `settings_state.dart` zentralisiert, Screen-Abhängigkeit entkoppelt.

---

### O-009: Widget-Tests `ArtikelListScreen` — abgeschlossen 2026-04-22 | `0.9.0+25`
Import-Pfad, Pflichtfelder (`erstelltAm`/`aktualisiertAm`) und Suchfeld-Label (`'Suche…'`) korrigiert. `_pumpScreenWithArtikel()`-Helper ergänzt. 15 Widget-Tests grün. Gesamtstand: **625 Tests**, 28 Dateien.

---

### F-006: Log-Level-Filter als Dropdown statt Button-Reihe — abgeschlossen 2026-04-22 | `0.9.0+25`
Log-Level-Button-Reihe (Trace–Fatal) passte auf schmalen Displays (360dp) nicht in eine Zeile. Ersetzt durch `DropdownButton<Level>` mit Default `Level.error`. Auf S20 verifiziert.

---

### B-012: Letzter-Sync-Zeitstempel auf schmalen Displays abgeschnitten — abgeschlossen 2026-04-22 | `0.9.0+25`
Sync-Label in AppBar konkurrierte auf 360dp mit Action-Icons. Fix: `TextOverflow.ellipsis` und `Flexible`-Wrapper ergänzt. Auf S20 verifiziert.

---

### B-011: App-Version zeigt veralteten Build-Stand — abgeschlossen 2026-04-22 | `0.9.0+25`
Kein Code-Fehler — `_getAppVersion()` via `PackageInfo.fromPlatform()` korrekt implementiert. Ursache: veraltete APK installiert (kein Build nach Version-Bump). Nach Neuinstallation korrekte Version bestätigt.

---

### B-010: Snackbar-Feedback in Artikelliste fehlt — abgeschlossen 2026-04-22 | `0.9.0+25`
Nach Sync-Erfolg/-Fehler fehlte Snackbar-Feedback (Regression aus B-007). Snackbar bei Sync-Start, -Erfolg und -Fehler in `ArtikelListScreen` ergänzt. 


## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
| 2026-07-11 | 1.0.0+78 | M-014 neu: Readonly-User-Rolle — PocketBase API Rules + App-UI-Guards dokumentiert. |
| 2026-05-20 | 0.9.9+75 | H-005.3: X-Frame-Options bereits im Caddyfile vorhanden —
als ✅ erledigt markiert. H-005 vollständig abgeschlossen. |
| 2026-05-20 | 0.9.9+75 | LIGHTHOUSE.md in HISTORY.md überführt und gelöscht. OPTIMIZATION.md auf Version 0.9.9+75 aktualisiert: H-005 vollständig eingetragen (H-005.1 ✅, H-005.2 ✅, H-005.3 ❌ offen), Score-Tabelle in H-004 um Endzustand ergänzt, Verweis auf HISTORY.md für Audit-Rohdaten ergänzt, Fortschritts-Übersicht aktualisiert. |
| 2026-05-19 | 0.9.9+75 | H-005 umgesetzt: robots.txt auf Allow: / gesetzt (H-005.1),
Meta-Description und Title in index.html ergänzt (H-005.2). SEO-Score 63 → 100
(ohne Login). H-005.3 (X-Frame-Options) offen. Score-Tabelle aktualisiert. |
| 2026-05-17 | 0.9.9+71 | T-012 (anteilig): `pocketbase_service_test.dart` erstellt (51 Tests). Abdeckung: `initialize()` URL-Prioritäten, Race-Condition-Guard, `needsSetup`, `updateUrl()` mit Health-Check-Fake, `resetToDefault()`, URL-Validierung, `login()`/`logout()`, `LoginTimeoutException`, `refreshAuthToken()`, `requestPasswordReset()`, Auth-Getter, `checkHealth()`. Strategie: `PocketBaseService.testable()` + manuelle Fakes, kein build_runner. `sync_error_recovery_test.dart`: 87 Tests, Recovery-Strategien und Retry-Logik. Gesamt: 806 Tests grün (+2 skipped). |
| 2026-05-16 | 0.9.9+70 | O-014 abgeschlossen: Nextcloud-Code vollständig entfernt. `ConflictData`/`ConflictResolution`/`SyncResult` in `conflict_types.dart` extrahiert. 4 Dateien gelöscht (`nextcloud_service_interface.dart`, `nextcloud_sync_service.dart`, `sync_service.dart`, `nextcloud_resync_dialog.dart`). `nextcloud_client.dart` neu implementiert (testbar). `webdav_client` aus pubspec.yaml entfernt. Tests angepasst. 755/755 grün. |
| 2026-05-16 | 0.9.9+68 | O-016 abgeschlossen: Timeout-Konstanten in AppConfig zentralisiert (connectivityCheckTimeout, backupStatusTimeout, syncPushTimeout, syncUploadTimeout). O-019 abgeschlossen: print() in app_config.dart durch _logger.w() ersetzt, assert-Wrapper entfernt. O-020 abgeschlossen: _PocketBaseConflictAdapter in eigene Datei ausgelagert (pocketbase_conflict_adapter.dart), Klasse public. |
| 2026-05-15 | 0.9.8+62 | F-011.7 abgeschlossen: Master-Detail-Layout für Desktop. `ArtikelDetailContent` als eigenständiges Widget extrahiert, `ArtikelDetailScreen` als dünner Scaffold-Wrapper mit ValueNotifier-Rebuild, Master-Detail in `ArtikelListScreen` ab ≥1024px (NavigationRail + Liste links, Detail rechts), `maxContentWidth` auf 1400 erhöht, `ConstrainedBox` nur Mobile/Tablet, `_ladeAnhangCount()` try/catch für Test-Kompatibilität, neue AppConfig-Konstanten für Breakpoints und Flex-Werte. 50 Widget-Tests grün (24 Detail + 15 List + 11 Erfassen). |
| 2026-05-13 | 0.9.8+57 | P-007 abgeschlossen: `_gefilterteArtikel()` gecacht (P-007.1), setState() bei Keystroke entfernt (P-007.2), `_aktualisiereFilter()` ohne separates setState() (P-007.3), `_ArtikelTile` + `_ArtikelInfoChip` als StatelessWidgets extrahiert (P-007.4), Scroll-Guard früher im `_onScroll()`-Pfad (P-007.5). B-018 abgeschlossen: Artikelnummer in Suche (SQLite + PocketBase) und Scanner-Fallback einbezogen. O-017 abgeschlossen: catch (e, st) in scan_service_stub.dart, artikel_import_service.dart (2×), app_log_io.dart (4×) ergänzt; pdf_service_shared.dart war bereits korrekt. flutter analyze + flutter test grün. |
| 2026-05-08 | 0.9.5+54 | F-008: Sync-Intervall konfigurierbar (1/5/15 Min oder nur manuell). Dropdown in Einstellungen, Callback-Pattern für sofortige Übernahme ohne App-Neustart. |
| 2026-05-08 | 0.9.5+51 | P-004 abgeschlossen: Android-Kamera vollständig manuell verifiziert (8 Tests auf A515F). B-016 behoben: `remoteBildPfad` wird beim Bild-Entfernen jetzt in PocketBase geleert (1 Zeile in Push-Update-Pfad). B-017 behoben: `ErrorWidget.builder` unterdrückt roten ErrorWidget-Flash bei Activity-Restart nach Permission-Änderung (kosmetisch, erwartetes Android-OS-Verhalten). |
| 2026-05-05 | 0.9.5+50 | O-013 umgesetzt: Log-Viewer Default-Level in App-Einstellungen konfigurierbar |
| 2026-05-04 | 0.9.4+49 | F-009 umgesetzt: Kategorie-Feld in Erfassen/Detail/Liste, Kategorie-Filter neben Ort-Filter, Chip in Listenansicht. |
| 2026-05-04 | 0.9.4+48 | T-001 abgeschlossen: Konfliktlösung, Sync-Hardening und Integrationsverifikation vollständig abgehakt. UUID-Pattern serverseitig abgesichert, UTC-Konsistenz geprüft (sauber), Zeitstempel-Semantik in DATABASE.md dokumentiert, verbleibende Optional-Punkte bewusst als „nicht benötigt" gestrichen. |
| 2026-05-04 | 0.9.4+46 | M-013 abgeschlossen: Bild-Reset („Bild leeren") ermöglichen |
| 2026-05-04 | 0.9.4+44 | O-012 abgeschlossen: Verbose-Flag geprüft und bewusst verworfen — Log-Level-Filter (F-006) deckt den Use Case ab. |
| 2026-05-03 | 0.9.4+43 | Sync-Dokumentation konsolidiert: `docs/SYNC.md` als technische Referenz für Push/Pull, Konflikterkennung, Edge Cases, Invarianten und Änderungsverbote ergänzt; `prompt.txt` als allgemeiner Arbeitskontext erweitert. |
| 2026-05-03 | 0.9.4+43 | `ARCHITECTURE.md` und `DATABASE.md` gegen den aktuellen SQLite-/Sync-Stand konsolidiert; Indexnamen gegen den echten Code verifiziert und vereinheitlicht. |
| 2026-05-03 | 0.9.4+42 | E-001 real eingeordnet: Die Konstellation „lokal offline neu erzeugt, vor erstem Sync gleicher Remote-Datensatz bereits vorhanden“ wird nun fachlich als gewünschter konservativer Konfliktfall bewertet. Nach manueller Auflösung (`useLocal`) erfolgreicher Folgesync ohne Dublette oder Retry-Loop. |
| 2026-05-03 | 0.9.4+41 | T-001 weiter konsolidiert: `_extractBildName()` / `remoteBildPfad` service-nah testseitig ergänzt; M-004 erneut manuell verifiziert inklusive erfolgreicher Gegenprobe ohne Remote-Änderung. |
| 2026-05-02 | 0.9.4+41 | T-011 abgeschlossen: Snapshot-Persistenz in `ArtikelDbService` sowie Zeitstempel- und `artikelnummer`-Regeln in `Artikel.toPocketBaseMap()` testseitig regressionssicher ergänzt. DB-Testisolation für Singleton/In-Memory-Setup stabilisiert. Teststand: 707 Tests grün, 3 übersprungen. |
| 2026-05-02 | 0.9.4+41 | B-015 weiter eingegrenzt: konfliktbewusste Timeout-Semantik des Orchestrators ist jetzt per Verhaltenstests abgesichert; offen bleibt die produktive UX-/Ablaufbehandlung längerer Merge-Interaktion. |
| 2026-04-30 | 0.9.4+41 | T-001 manuell weiter bestätigt: `useLocal`, `useRemote`, `skip` und Mehrfachkonflikte im echten Geräte-/Server-Lauf verifiziert. Gemischte Auflösungen (`skip`, `useRemote`, `useLocal`) funktionieren sequentiell; nur übersprungene Konflikte erscheinen im Folgesync erneut. Merge fachlich bestätigt, aber mit bekanntem Orchestrator-Timeout-Befund bei längerer UI-Interaktion. |
| 2026-04-30 | 0.9.4+39 | B-003 abgeschlossen: `remoteBildPfad` wird nach CREATE/UPDATE via Follow-up-PATCH korrekt in PocketBase geschrieben. Verifikation via Flutter-Logs (SYNC\|PUSH\|CREATE ok, downloaded=1) und PocketBase-Record-Inspektion (Δ created→updated = 147ms). |
| 2026-04-29 | 0.9.4+37 | fix/sync-hardening2-v0.9.4(B-014): HTTP 400 CREATE, Push-Timeouts, markSynced-Spaltenname, Summary-Logs |
| 2026-04-28 | 0.9.4+36 | fix/sync-hardening2-v0.9.4 B-013 abgeschlossen: image upload flow, `remoteBildPfad` |
| 2026-04-23 | 0.9.2+32 | T-009 und O-011 abgeschlossen: ergänzende Tests für `SettingsController` und settings-nahe Persistenzpfade nachgezogen; zugleich `AppLockService` testbarer gemacht, sodass App-Lock-nahe Lade-/Speicherpfade und fachliche Timeout-/State-Logik nun isolierter testbar sind. |
| 2026-04-23 | 0.9.1+29 | O-010 abgeschlossen: `SettingsScreen` fachlich minimal-invasiv in `SettingsController` refactored, UI-/Logik-Trennung verbessert, zusätzliche Controller-Tests ergänzt. F-007 architektonisch bereinigt: `showLastSyncNotifier`, Prefs-Key und Default nach `settings_state.dart` verschoben, Default konsistent auf `true` vereinheitlicht. Teststand auf 626 bestanden, 3 übersprungen aktualisiert. |
| 2026-04-22 | 0.9.1+26 | K-007: Flutter upgrade 3.41.4 → 3.41.7 + package major updates |
| 2026-04-22 | 0.9.0+25 | B-008 abgeschlossen: Card-Layout `ArtikelListScreen` wiederhergestellt (Artikelnummer, Chips, Feldname-Fix). B-009 abgeschlossen: Ort-Dropdown dynamisch aus Artikelliste, in Body integriert, Reset-Button. B-010 abgeschlossen: Snackbar-Feedback bei Sync-Start/-Erfolg/-Fehler. B-011 abgeschlossen: App-Version zeigt korrekten Build-Stand nach neuem Release-Build. B-012 abgeschlossen: Sync-Label `TextOverflow.ellipsis` + `titleSpacing`. F-006 abgeschlossen: Log-Level-Filter als `DropdownButton<Level>`, Default `Level.error`. F-007 abgeschlossen: Sync-Zeitstempel-Toggle via `ValueNotifier` + `SharedPreferences`. O-009 abgeschlossen: 15 Widget-Tests `ArtikelListScreen` grün (625 Tests gesamt). |
| 2026-04-21 | 0.8.9+24 | B-007 abgeschlossen: Intelligenter Bild-Sync (Timestamp-Check) und UI-Politur des Sync-Zeitstempels implementiert. |
| 2026-04-20 | 0.8.6+21 | P-003 abgeschlossen: Bild-Caching via `cached_network_image` integriert. Android-Stabilität auf S20 verifiziert. |
| 2026-04-17 | 0.8.5+19 | B-003 abgeschlossen: `downloadMissingImages` Skip-Logik korrigiert. B-004 abgeschlossen: Konflikt-Callback via `GlobalKey` + `addPostFrameCallback`. B-005 abgeschlossen: ETag-Konflikt-Erkennung vor PATCH. B-006 abgeschlossen: `SyncManagementScreen` auf `SyncOrchestrator` umgestellt. T-008 abgeschlossen: 20 neue Tests (610 gesamt, 28 Dateien). |
| 2026-04-14 | 0.8.4+17 | N-003: App-Icon + N-005: Native Splash Screen als erledigt markiert |
| 2026-04-14 | 0.8.4+17 | F-004 abgeschlossen: NC-Icon auf `statusColorConnected` umgestellt. F-005 abgeschlossen: Detail-Screen Readonly-Felder mit `OutlineInputBorder` + `InputDecorator`, Menge/Artikelnummer als eigene Felder, `+/-` Buttons nur im Edit-Modus, 3 Widget-Tests angepasst |
| 2026-04-14 | 0.8.3+16 | B-001 abgeschlossen: Settings-Save-Verhalten analysiert — Dirty-Tracking, Save-Button und Unsaved-Dialog waren bereits korrekt implementiert. B-002 abgeschlossen: Biometrie-Analyse — automatischer Auth-Start, `FragmentActivity`, Verfügbarkeitsprüfung vor Toggle-Aktivierung bestätigt. OPT-001 neu: `SettingsController`-Extraktion für Testbarkeit |
| 2026-04-13 | 0.8.2+13 | F-001 + F-002 abgeschlossen: App-Lock mit biometrischer Authentifizierung und konfigurierbarer Sperrzeit |
| 2026-04-13 | 0.8.1+12 | T-003 abgeschlossen: 39 Unit-Tests `NextcloudClient` |
| 2026-04-13 | 0.8.1+11 | T-004 abgeschlossen: 18 Widget-Tests `MergeDialog`. O-008 abgeschlossen: `spacingSectionGap`-Token, 3 Stellen ersetzt |
| 2026-04-13 | 0.8.1+10 | T-005 abgeschlossen: 34 Tests `AttachmentService` |
| 2026-04-13 | 0.8.0+8 | F-003: Artikeldetailansicht — Ort & Fach nebeneinander |
| 2026-04-13 | 0.8.0+7 | O-007 abgeschlossen: 15 Tests `ImagePickerService` |
| 2026-04-13 | 0.8.0+7 | T-006 abgeschlossen: `BackupStatusService` formal abgenommen |
| 2026-04-13 | 0.8.0+6 | T-007 abgeschlossen: Performance-Test self-contained |
| 2026-04-13 | 0.8.0+5 | P-005 als erledigt markiert: Ziel-Versionen bereits in `pubspec.yaml`, `connectivity_plus`-Migration umgesetzt |
| 2026-04-12 | 0.8.0+5 | T-002 abgeschlossen: 17 Unit-Tests `PocketBaseSyncService` |
| 2026-07-09 | 0.9.9+75 | F-012.4 abgeschlossen: Titel und Buttons in Detailansicht beim ersten Klick korrekt. `super.key` in `_DetailPanelHeader`-Konstruktor ergänzt, `_detailContentKey` von `final` auf nicht-final geändert, `GlobalKey()` bei jedem `_onArtikelTap()` neu erzeugt, `ValueKey(uuid)` auf `_DetailPanelHeader` gesetzt. 3 Änderungen in `artikel_list_screen.dart`. |

---

[Zurück zur README](../README.md) | [Zur HISTORY](HISTORY.md) | [Zum Changelog](../CHANGELOG.md)