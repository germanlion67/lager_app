# 🔦 Lighthouse-Audit-Befunde & Optimierungsmaßnahmen

## 📊 Audit-Übersicht

**Audit-Datum:** 18.05.2026
**Lighthouse-Version:** aktuell (Navigationsmodus)
**Ziel-URL:** `http://localhost:8081`
**Emulation:** Moto G Power (Mobil), simuliertes Netzwerk
**Renderer:** Flutter Web — Skwasm (WASM-Renderer)
**Drittanbieter:** Google CDN (Skwasm), Google Fonts

### Gesamtscores

| Kategorie | Score | Bewertung |
|:--|:--|:--|
| ⚡ Performance | **75 / 100** | 🟡 Verbesserungsbedarf |
| ♿ Barrierefreiheit | **92 / 100** | 🟢 Gut |
| ✅ Best Practices | **81 / 100** | 🟡 Akzeptabel |
| 🔍 SEO | **63 / 100** | 🔴 Kritisch |

> **Vergleich zum Voraudit (12.05.2026):**
> Performance: 62 → 75 (+13, durch H-004.1–H-004.4 und WASM-Build)
> SEO: 91 → 63 (−28, Regression durch `is-crawlable`-Befund — siehe H-005.1)
> Best Practices: 81 → 81 (stabil)
> Barrierefreiheit: 92 → 92 (stabil, Flutter-bedingte Decke)

---

## ⚡ Performance — Detailbefunde

### Kernmetriken

| Metrik | Wert | Ziel | Status |
|:--|:--|:--|:--|
| First Contentful Paint (FCP) | **0,95 s** | < 1,8 s | ✅ |
| Largest Contentful Paint (LCP) | **1,57 s** | < 2,5 s | ✅ |
| Total Blocking Time (TBT) | **705 ms** | < 200 ms | ❌ |
| Cumulative Layout Shift (CLS) | **0** | < 0,1 | ✅ Perfekt |
| Speed Index (SI) | **7,81 s** | < 3,4 s | ❌ |
| Time to Interactive (TTI) | **16,72 s** | < 3,8 s | ❌ |
| Server Response Time (TTFB) | **2 ms** | < 600 ms | ✅ |
| Max Potential FID | **265 ms** | < 130 ms | 🟡 |

### Netzwerk-Übersicht

**Gesamtgröße:** 2.979 KB (Transfer)

| Ressource | Typ | Größe (Transfer) | Entität |
|:--|:--|:--|:--|
| `skwasm.wasm` | WASM | ~1.180 KB | Google CDN |
| `skwasm.js` | Script | ~15 KB | Google CDN |
| Roboto + weitere Fonts | Font | ~174 KB | Google Fonts |
| `config.js` | Script | — | Eigene App |
| LCP-Bild (`splash/img/light-2x.png`) | Image | 256×256 px | Eigene App |

### Kritische Befunde (Performance)

#### LH-P-001: Render-blockierendes `config.js`

- **Blockierzeit:** 152 ms (geschätzt)
- **Einsparung:** ~138 ms FCP
- **Ursache:** `<script src="/config.js">` ohne `defer`/`async`
- **Fix:**

```html
<script src="/config.js" defer></script>
```

- **Status:** ❌ Offen → Maßnahme: **H-004** (Prio 2)

#### LH-P-002: Hohe Total Blocking Time (705 ms)

- **Ursache:** Skwasm-WASM-Initialisierung blockiert Hauptthread
- **Hauptverursacher:** `skwasm.js` (Google CDN, 119 ms Hauptthread-Zeit)
- **Fix:** WASM-Ressourcen vorladen (`<link rel="preload">`), Service Worker für
  Caching, langfristig: Build-Optimierung
- **Status:** 🟡 Teilweise adressiert durch WASM-Build (H-004.5) — weiter offen

#### LH-P-003: Schlechter Speed Index (7,81 s)

- **Ursache:** Flutter Skwasm-Renderer muss vollständig initialisiert sein, bevor
  Canvas-Inhalte sichtbar werden — strukturell bedingt
- **Fix:** Splash Screen optimieren, Ladeindikator während WASM-Init anzeigen
- **Status:** ❌ Offen — Flutter-architekturbedingt, kein direkter Fix

#### LH-P-004: Fehlende Cache-Control-Header (21,7 KB verschwendet)

- **Betroffene Ressourcen:** Mehrere statische Assets ohne oder mit kurzen Cache-Headern
- **Fix:**

```nginx
location ~* \.(js|wasm|css|png|webp|woff2)$ {
    add_header Cache-Control "max-age=31536000, immutable";
}
```

- **Status:** ❌ Offen → Maßnahme: **H-004** (Prio 1)

#### LH-P-005: Netzwerkabhängigkeitsbaum — `manifest.json` (107 ms Latenz)

- **Kritische Kette:** `localhost/` → `manifest.json`
- **Fix:**

```html
<link rel="preload" href="/manifest.json" as="fetch" crossorigin>
```

- **Status:** ❌ Offen

### Drittanbieter-Analyse

| Anbieter | Übertragungsgröße | Hauptthread-Zeit | Bewertung |
|:--|:--|:--|:--|
| Google CDN (Skwasm) | ~1.195 KB | 119 ms | 🔴 Größter Verursacher |
| Google Fonts (Roboto) | ~174 KB | 0 ms | 🟡 Lokal hostbar |

### Bewusst akzeptiert (Performance)

| Befund | Begründung |
|:--|:--|
| Speed Index > 3,4 s | Flutter Skwasm strukturell bedingt — kein direkter Fix ohne Renderer-Wechsel |
| TTI 16,72 s | WASM-Initialisierung — WASM-Build (H-004.5) ist effektivster Hebel |
| `main.dart.js` / Skwasm unused code | Flutter-Web-typisch, Tree Shaking auf JS-Ebene begrenzt |
| Fehlende Source Maps | Release-Build-Standard, akzeptabel |
| Google Fonts extern | Funktioniert, Lokalisierung als optionale Optimierung (LH-P-006) |

---

## ♿ Barrierefreiheit — Detailbefunde

### Bewertung: 92 / 100

### Kritische Befunde (Barrierefreiheit)

#### LH-A-001: Kein `<main>`-Landmark (`landmark-one-main`, Gewicht: 3)

- **Ursache:** Flutter Web rendert alles in `<canvas>` — kein semantischer DOM-Baum
- **Fix:** Nicht direkt umsetzbar ohne Renderer-Wechsel
- **Status:** ⚠️ Strukturell bedingt — bewusst akzeptiert

#### LH-A-002: `meta-viewport user-scalable=no` (Gewicht: 10)

- **Ursache:** Flutter setzt `user-scalable=no` automatisch
- **Auswirkung:** Kostet ~8 Barrierefreiheitspunkte
- **Fix:** Für interne App akzeptabel — würde Flutter-Zoom-Verhalten brechen
- **Status:** ⚠️ Bewusst akzeptiert

### Bestandene Prüfungen (Auswahl)

| Prüfung | Status |
|:--|:--|
| `html-has-lang` / `html-lang-valid` | ✅ |
| `meta-viewport` (Viewport vorhanden) | ✅ |
| `aria-hidden-body` | ✅ |
| `aria-roles` / `aria-valid-attr` | ✅ |
| `document-title` | ✅ |
| `aria-allowed-attr` / `aria-required-attr` | ✅ |
| `tabindex` | ✅ |

> **Strukturelle Einschränkung:** Flutter Web mit Canvas-Rendering verhindert
> vollständige Screenreader-Unterstützung. Score 92 ist das realistische Maximum
> für diese Architektur.

---

## ✅ Best Practices — Detailbefunde

### Bewertung: 81 / 100

### Kritische Befunde (Best Practices)

#### LH-B-001: Veraltete APIs — 2 Deprecations (Gewicht: 5)

| API | Seit | Ursache |
|:--|:--|:--|
| `SharedArrayBufferConstructedWithoutIsolation` | Chrome 106 | Flutter/Skwasm |
| `Intl.v8BreakIterator` | — | Flutter Engine |

- **Fix für `SharedArrayBuffer`:** COOP/COEP-Header setzen:

```nginx
add_header Cross-Origin-Opener-Policy "same-origin" always;
add_header Cross-Origin-Embedder-Policy "require-corp" always;
```

> ⚠️ Prüfen ob Flutter Skwasm diese Header verträgt — kann WASM-Ladevorgang beeinflussen.

- **Fix für `Intl.v8BreakIterator`:** Wird mit zukünftigem Flutter-Release behoben
- **Status:** 🟡 COOP/COEP evaluieren — `Intl`-Deprecation akzeptiert

#### LH-B-002: Kein HTTPS (Gewicht: 5)

- **Ursache:** Audit auf `http://localhost:8081` — Entwicklungsumgebung
- **Fix:** In Produktion zwingend HTTPS + HSTS (bereits in H-004.2 adressiert)
- **Status:** ✅ In Produktion behoben (H-004.2)

#### LH-B-003: Fehlende Sicherheits-Header

| Header | Status | Maßnahme |
|:--|:--|:--|
| `Strict-Transport-Security` (HSTS) | ✅ Behoben | H-004.2 |
| `Content-Security-Policy` (CSP) | ⚠️ Akzeptiert | Flutter benötigt `unsafe-inline` |
| `X-Frame-Options` / `frame-ancestors` | ❌ Offen | H-005.3 |
| `Cross-Origin-Opener-Policy` | 🟡 Evaluieren | LH-B-001 |
| `Trusted-Types` | ⚠️ Akzeptiert | Flutter inkompatibel |

#### LH-B-004: Third-Party-Cookies

- **Ursache:** Google CDN / Google Fonts — möglicherweise Cookies gesetzt
- **Status:** 🟡 Prüfen ob tatsächlich Cookies gesetzt werden

### Bewusst akzeptiert (Best Practices)

| Befund | Begründung |
|:--|:--|
| CSP `unsafe-inline` / kein `strict-dynamic` | Flutter Web benötigt Inline-Scripts — Fix würde App brechen |
| `Trusted-Types` fehlt | Flutter Web inkompatibel |
| `Intl.v8BreakIterator` deprecated | Flutter Engine — Fix kommt mit Flutter-Update |

---

## 🔍 SEO — Detailbefunde

### Bewertung: 63 / 100 🔴

> **Wichtiger Hinweis:** Flutter Web rendert in `<canvas>`. Suchmaschinen können
> App-Inhalte strukturell nicht lesen. SEO-Optimierungen betreffen primär technische
> Crawlability, nicht inhaltliche Indexierung.

### Kritische Befunde (SEO)

#### LH-S-001: Seite nicht crawlbar — `is-crawlable` (Gewicht: ~4) 🔴

- **Ursache:** Möglicherweise `<meta name="robots" content="noindex">` oder
  `robots.txt` mit `Disallow: /` (aus H-004.1)
- **Prüfen:**

```bash
curl -s http://localhost:8081/robots.txt
curl -s http://localhost:8081 | grep -i robots
```

- **Fix:** Für interne App mit `Disallow: /` ist das korrekt — für öffentliche
  Sichtbarkeit `Allow: /` setzen
- **Status:** ❌ Offen → Maßnahme: **H-005.1**

#### LH-S-002: Fehlende Meta-Description (Gewicht: 1)

- **Fix:**

```html
<meta name="description"
      content="Lager_app — Interne Lagerverwaltung für Artikel, Sync und Inventar.">
```

- **Status:** ❌ Offen → Maßnahme: **H-005.2**

#### LH-S-003: Fehlender oder unzureichender Dokument-Titel (Gewicht: 1)

- **Fix:**

```html
<title>Lager_app | Lagerverwaltung</title>
```

- **Status:** ❌ Offen → Maßnahme: **H-005.2**

#### LH-S-004: Strukturelles SEO-Problem — Flutter Canvas

- **Ursache:** Alle App-Inhalte in `<canvas>` — nicht indexierbar
- **Fix:** Nicht umsetzbar ohne Architekturwechsel (SSR / HTML-Renderer)
- **Status:** ⚠️ Strukturell akzeptiert — interne App, kein SEO-Bedarf

### Bewusst akzeptiert (SEO)

| Befund | Begründung |
|:--|:--|
| Inhalte nicht indexierbar (Canvas) | Interne App — kein öffentliches SEO-Ziel |
| `robots.txt` mit `Disallow: /` | Für interne App korrekt und gewünscht |
| Kein strukturiertes Markup | Flutter Canvas — nicht umsetzbar |

---

## 🎯 Abgeleitete Maßnahmen

### Neue Maßnahme: H-005 (SEO-Korrekturen)

> In `OPTIMIZATIONS.md` unter **H-005** einzutragen.

**Beschreibung:**
Lighthouse-Audit vom 18.05.2026 zeigt SEO-Score 63 (Regression gegenüber 91).
Hauptursache: `is-crawlable`-Befund und fehlende Meta-Tags. Da es sich um eine
interne App handelt, ist vollständige SEO-Optimierung nicht das Ziel — technische
Korrektheit und bewusste Entscheidungen sollen aber dokumentiert sein.

#### H-005.1: `robots.txt`-Verhalten prüfen und dokumentieren

- Prüfen ob `Disallow: /` (aus H-004.1) den `is-crawlable`-Befund verursacht
- Für interne App: `Disallow: /` ist korrekt → Befund bewusst akzeptieren
- Für öffentliche Sichtbarkeit: `Allow: /` setzen
- **Aufwand:** 10 Minuten
- **Status:** ❌ Offen

#### H-005.2: Meta-Description und Titel ergänzen

- `<meta name="description">` und `<title>` in `index.html` ergänzen
- Auch wenn Inhalte nicht indexierbar sind — technische Korrektheit
- **Aufwand:** 5 Minuten
- **Status:** ❌ Offen

#### H-005.3: `X-Frame-Options`-Header evaluieren

- Clickjacking-Schutz für Produktions-Deployment:

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
```

- **Aufwand:** 5 Minuten
- **Status:** ❌ Offen

**Erwartete Score-Verbesserung nach H-005:**

| Kategorie | Vorher | Nachher (geschätzt) |
|:--|:--|:--|
| SEO | 63 | ~75–80 (strukturelle Decke durch Canvas) |
| Best Practices | 81 | ~83–85 |

---

### Offene Maßnahmen aus H-004 (Aktualisierung)

| Task | Beschreibung | Status |
|:--|:--|:--|
| H-004.5 | WASM-Build evaluieren | 🟡 In Evaluierung |
| LH-P-001 | `config.js` auf `defer` setzen | ❌ Offen |
| LH-P-004 | Cache-Control-Header für statische Assets | ❌ Offen |
| LH-P-005 | `manifest.json` vorladen | ❌ Offen |
| LH-B-001 | COOP/COEP-Header evaluieren | 🟡 Evaluieren |
| LH-B-004 | Third-Party-Cookies prüfen | 🟡 Prüfen |

---

## 📈 Score-Entwicklung

| Datum | Version | Performance | Barrierefreiheit | Best Practices | SEO |
|:--|:--|:--|:--|:--|:--|
| 12.05.2026 | 0.9.9+70 | **62** | **92** | **81** | **91** |
| 18.05.2026 | 0.9.9+73 | **75** | **92** | **81** | **63** |


| Datum | Version | FCP | LCP | TBT | CLS | SI |
|:--|:--|:--|:--|:--|:--|:--|
| 18.05.2026 | 0.9.9+73 | 0,9s | 1,4s | 430ms | 0 | 6,6s |


> **Anmerkung zum SEO-Rückgang:**
> Der Rückgang von 91 → 63 ist auf den `is-crawlable`-Befund zurückzuführen,
> der durch die in H-004.1 gesetzte `robots.txt` mit `Disallow: /` ausgelöst wird.
> Für eine interne App ist das fachlich korrekt — der Score-Rückgang ist bewusst
> akzeptiert.

---

## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|:--|:--|:--|
| 2026-05-18 | 0.9.9+70 | Initiale Erstellung — Lighthouse-Audit Navigationsmodus, Skwasm-Renderer. Scores: Performance 75, Barrierefreiheit 92, Best Practices 81, SEO 63. H-005 als neue Maßnahme abgeleitet. |

