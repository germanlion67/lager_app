# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Arbeitsübersicht über **aktuellen Projektstatus**, **offene Aufgaben**, **Prioritäten** und **technische Optimierungen** der **Lager_app**.

**Version:** 0.9.8+57 | **Zuletzt aktualisiert:** 13.05.2026

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
- `B-019`, `F-012`, `H-005`, `K-008`, `M-014`, `N-007`, `O-023`, `P-008`, `T-013`

### Vergaberegel
Ein Kürzel gilt **ab dem ersten dokumentierten Auftreten als dauerhaft reserviert** —  
auch dann, wenn der Punkt später verschoben, umbenannt oder nach `Future` verschoben wird.

Commit-Meldungen  `fix:`- Neues Future,  `feat:`-Bugfix, `docs`- Dokumentation, `style`- Formatierung, `refactor`- Code-Umbau, Future/Fix, `test`- Test hinzugefügt, `chore`- Build, Config, Dependencies
---

## 🔴 Priorität: Hoch


## 🟡 Priorität: Mittel

### O-014: Nextcloud-Code entkoppeln und entfernen
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


### T-012: Testlücken bei produktiven Services schließen
**Beschreibung:**
6 produktiv genutzte Services haben keine Testdatei. Höchste Priorität hat
`pocketbase_service.dart` (492 Zeilen, zentraler Client-Service).

**Priorisierte Testliste:**

| Priorität | Service | Testfokus |
|-----------|---------|-----------|
| 🔴 Hoch | `pocketbase_service.dart` | `initialize()` URL-Prioritäten, `updateUrl()` mit Health-Check, `login()`/`logout()`, `refreshAuthToken()`, `needsSetup`-Logik |
| 🟡 Mittel | `connectivity_service.dart` | WiFi-Erkennung, Timeout-Verhalten |
| 🟡 Mittel | `sync_progress_service.dart` | Stream-Events, Progress-Tracking |
| 🟡 Mittel | `sync_error_recovery.dart` | Recovery-Strategien, Retry-Logik |
| 🟢 Niedrig | `tag_service.dart` | CRUD |
| 🟢 Niedrig | `database_service.dart` | Init-Pfade |

**Aufwand:** ~4–6 Stunden (alle), ~2 Stunden (nur pocketbase_service)
**Risiko:** Keins — rein additiv

**Tasks:**
- [ ] `test/services/pocketbase_service_test.dart` erstellen
- [ ] `test/services/connectivity_service_test.dart` erstellen
- [ ] Weitere nach Bedarf

---

### H-004: Lighthouse-Befunde beheben (Web-Performance, Security-Header, SEO)
**Beschreibung:**
Lighthouse-Audit vom 12.05.2026 ergab Score 62 (Performance), 92 (Barrierefreiheit), 81 (Best Practices), 91 (SEO). Die Hauptursache für den niedrigen Performance-Score ist die `main.dart.js` (4 MB unkomprimiert, 2.510 ms Total Blocking Time). Daneben fehlen Security-Header und eine `robots.txt`.

**Audit-Ergebnisse (Mobil-Emulation):**

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

- [ ] **H-004.1: `robots.txt` in Nginx bereitstellen**
  Nginx liefert `index.html` als Fallback für `/robots.txt` → 87 SEO-Fehler.

  ```nginx
  location = /robots.txt {
      add_header Content-Type text/plain;
      return 200 "User-agent: *\nDisallow: /\n";
  }
  ```

  **Wirkung:** SEO-Score 91 → ~100

- [ ] **H-004.2: HSTS-Header setzen**
  Kein `Strict-Transport-Security`-Header vorhanden.

  ```nginx
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
  ```

  **Wirkung:** Best Practices ↑

#### Prio 2 — HTML-Anpassungen (index.html, je 1 min)

- [ ] **H-004.3: Splash-Bild `width`/`height` und `fetchpriority` setzen**
  LCP-Bild (`splash/img/light-2x.png`) hat keine expliziten Dimensionen und kein Priority-Hint.

  ```html
  <img class="center" aria-hidden="true"
       src="splash/img/light-2x.png" alt=""
       width="256" height="256" fetchpriority="high">
  ```

  **Wirkung:** LCP-Discovery-Score ↑, Unsized-Images-Warnung weg

#### Prio 3 — Build-Optimierung (CI/CD, 5–30 min)

- [ ] **H-004.4: `--tree-shake-icons` im Flutter-Build aktivieren**
  Ungenutzte Material-Icons werden aktuell mitgebaut.

  ```yaml
  # In GitHub Actions Workflow:
  flutter build web --release --tree-shake-icons
  ```

  **Wirkung:** `main.dart.js` etwas kleiner

- [ ] **H-004.5: WASM-Build evaluieren**
  Dart 3.11.5 unterstützt `flutter build web --wasm`. WebAssembly parst deutlich schneller
  als JavaScript → TBT sinkt signifikant.

  ```bash
  flutter build web --wasm
  ```

  **Risiko:** Experimentell — Browser-Kompatibilität und `dart:js_interop` prüfen.
  **Wirkung:** TBT potenziell von 2.510 ms auf < 500 ms

#### Prio 4 — Bewusst akzeptiert (kein Fix nötig)

- **`Intl.v8BreakIterator` deprecated** — kommt aus Flutter Engine (CanvasKit), wird mit
  zukünftigem Flutter-Release behoben. Kostet 5 Punkte bei Best Practices.
- **`meta-viewport user-scalable=no`** — Flutter setzt das automatisch. Kostet 10 Punkte
  bei Barrierefreiheit. Für interne App akzeptabel.
- **`main.dart.js` 55% unused code** — Flutter-Web-typisch (Tree Shaking auf JS-Ebene
  begrenzt). WASM-Build (H-004.5) ist der effektivere Hebel.
- **Fehlende Source Maps** — `main.dart.js` ohne Source Map. Für Release-Build akzeptabel.
- **CSP `unsafe-inline` / fehlende `strict-dynamic`** — Flutter Web benötigt Inline-Scripts.
  Einschränkung würde App brechen.

---

**Aufwand gesamt:** ~1 Stunde (H-004.1–H-004.4), WASM-Evaluierung separat ~30 min
**Risiko:** Niedrig (H-004.1–H-003.4), Mittel (H-004.5 WASM)

**Erwartete Score-Verbesserung nach H-004.1–H-003.4:**

| Kategorie | Vorher | Nachher (geschätzt) |
|:--|:--|:--|
| Performance | 62 | ~65–70 |
| Barrierefreiheit | 92 | 92 (Flutter-bedingt) |
| Best Practices | 81 | ~86–90 |
| SEO | 91 | ~100 |

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

- [ ] **F-011.7: Master-Detail-Layout für Artikelverwaltung**
  Auf Desktop: Links Artikelliste, rechts Detailansicht gleichzeitig sichtbar.
  Verwendet die in F-011.3 und F-011.4 extrahierten Widgets.

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

- [ ] **F-011.8: NavigationRail → Sidebar mit Labels erweitern**
  Auf Desktop die NavigationRail zu einer vollständigen Sidebar mit Icons + Labels
  und ggf. Untermenüs erweitern.

- [ ] **F-011.9: Dialoge → Seitenpanels auf Desktop**
  Modale Dialoge (z.B. Artikel-Bearbeitung) auf Desktop als Seitenpanel statt
  Fullscreen-Dialog darstellen.

---

**Aufwand gesamt:**

| Stufe | Aufwand | Kumuliert |
|:--|:--|:--|
| Stufe 1 | ~30 min | 30 min |
| Stufe 2 | ~4–8 h | 5–9 h |
| Stufe 3 | ~1–2 Tage | 2–3 Tage |

**Risiko:** Niedrig (Stufe 1–2), Mittel (Stufe 3 – Navigationslogik-Umbau)

**Hinweis:** Stufe 2 ist so konzipiert, dass alle Arbeit in Stufe 3 wiederverwendet wird.
Der Aufwand für Stufe 3 halbiert sich durch die Vorarbeit aus Stufe 2.

--- 

## 🟢 Priorität: Nice-to-Have


### O-020: main.dart, artikel_detail_screen.dart, artikel_db_service.dart aufteilen

### O-021: State Management modernisieren 

### O-022: AppConfig modularisieren, flutter_local_notifications entfernen

--- 

### O-016: Timeouts in AppConfig zentralisieren
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
- [ ] Timeout-Konstanten in `AppConfig` ergänzen
- [ ] Services auf `AppConfig.*Timeout` umstellen
- [ ] Lokale `_k*`-Konstanten entfernen
- [ ] `flutter analyze` + `flutter test` grün

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

**Aufwand:** 10 Minuten
**Risiko:** Sehr niedrig

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
- Optional später: Artikel-Erfassung, Einstellungsänderungen

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

### O-019: `print()` in `app_config.dart` durch Logger ersetzen
**Beschreibung:**
Eine `print()`-Stelle in `app_config.dart:99` (innerhalb `assert`).
Funktional harmlos (nur Debug), aber inkonsistent mit dem sonst
durchgängig genutzten `AppLogService.logger`.

**Aufwand:** 5 Minuten
**Risiko:** Keins

**Tasks:**
- [ ] `print()` durch `AppLogService.logger.w()` ersetzen
- [ ] `assert`-Wrapper ggf. entfernen (Logger hat eigenen Level-Filter)

--- 

## ⏭️ Future (nicht in Planung)

### H-001: iOS/macOS Vorbereitung
Erfordert Apple Developer Account. Zurückgestellt bis Account verfügbar.

### N-006: Nextcloud-Workflow
WebDAV-Anbindung finalisieren und mit Nextcloud 28+ testen.

---

## 📊 Fortschritts-Übersicht

Die Priorisierung in diesem Dokument ist maßgeblich, die Zählwerte sind jedoch nur dann belastbar, wenn sie aktiv mitgepflegt werden.  
Im Zweifel gilt der inhaltliche Status der einzelnen Punkte über den numerischen Summen.

**Aktuell besonders relevante offene Themen**
- optionaler Realtest für den engeren technischen Duplicate-UUID-Recovery-Fallback
- Android-Kamera-Verifikation
- konfigurierbares Sync-Intervall

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

**Aufwand:** ~4–6 Stunden (vollständige Extraktion in l10n)
**Risiko:** Niedrig
**Priorität:** Future — erst bei Mehrsprachigkeitsbedarf

---

## ✅ Abgeschlossen

> **Hinweis:** Details zu den abgeschlossenen Punkten stehen in `HISTORY.md`.  
> Hier bleiben sie als kompakter Überblick mit Versionsbezug erhalten.

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

## In History überführt

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

---

[Zurück zur README](../README.md) | [Zur HISTORY](../HISTORY.md) | [Zum Changelog](../CHANGELOG.md)