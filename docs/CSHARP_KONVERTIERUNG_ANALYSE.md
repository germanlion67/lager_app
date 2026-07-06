# C#-Konvertierung – Machbarkeitsanalyse & Ablaufplan

## 1) Ausgangslage im aktuellen Repository

Die Anwendung ist ein **Flutter/Dart-Monorepo** mit:

- Frontend + App-Logik in `app/` (Flutter, Offline-First, SQLite lokal)
- plattformabhängigen Teilen über Conditional Imports (`app/lib/..._io.dart`, `..._stub.dart`)
- Backend als **PocketBase** (Container in `server/`, Migrationen in `server/pb_migrations`)
- Web/Deployment via Docker/Caddy (`docker-compose.yml`, `app/Dockerfile`)

Wichtige Hinweise:
- CI ist auf Flutter ausgerichtet (`.github/workflows/ci.yml`: `flutter analyze`, `flutter test`, `flutter build web`)
- Viele mobile/desktop-spezifische Features sind direkt an Flutter-Plugins gekoppelt (`app/pubspec.yaml`)

---

## 2) Kurzfazit zur Konvertierung nach C#

Eine vollständige Konvertierung nach C# ist **grundsätzlich möglich**, aber **kein 1:1-Port** und **kein kleiner Refactor**.  
Sie entspricht einem **technischen Neubau mit fachlicher Übernahme**.

### Was gut möglich ist

1. **Fachlogik übernehmen**
   - Datenmodell (`Artikel`, `Attachment`) und Sync-Regeln sind übertragbar.
2. **Backend weiterverwenden**
   - PocketBase kann zunächst bleiben; C#-Client spricht weiter REST/Datei-API.
3. **Schrittweise Migration**
   - Zuerst C#-Frontend, später optional Backend-Migration auf ASP.NET Core.

### Was nicht direkt übertragbar ist

1. **Flutter UI-Code**
   - Dart Widgets/Screens müssen neu implementiert werden.
2. **Flutter Plugin-Ökosystem**
   - `image_picker`, `mobile_scanner`, `local_auth`, `flutter_local_notifications`, `sqflite`, etc. sind nicht direkt nutzbar.
3. **Dart-Tests**
   - Bestehende Tests (`app/test/`) sind nicht in C# lauffähig und müssen neu aufgebaut werden.

---

## 3) Erwartbare Probleme / Risiken

### 3.1 Technische Risiken

- **Offline-First + Konfliktauflösung**: hoher Aufwand für korrekte Re-Implementierung.
- **Plattformparität**: Android/Web/Linux/Windows müssen in .NET gleichwertig erreicht werden.
- **Datei-/Bild-/Scanner-Workflows**: starke Plattformabhängigkeit, je Ziel-Framework unterschiedlich gut unterstützt.
- **Web-Verhalten**: Flutter-Web-Besonderheiten (Runtime Config) müssen für Blazor/anderes Web-Frontend neu gedacht werden.

### 3.2 Organisatorische Risiken

- Doppelter Pflegeaufwand während Übergangsphase (Flutter + C# parallel)
- Hoher Test-/Abnahmeaufwand wegen regressionskritischer Sync-Fälle
- Größeres Projektrisiko ohne harte Priorisierung der Muss-Features

---

## 4) Was geht / was geht nicht (kompakt)

| Bereich | Geht | Geht nicht / nur mit Neubau |
|---|---|---|
| Domänenmodell | Übernahme der Fachobjekte/Regeln | 1:1 Code-Copy aus Dart |
| UI | Fachliches Verhalten nachbauen | Flutter Widgets direkt nutzen |
| Lokale DB | SQLite in C# möglich | `sqflite`-Code direkt wiederverwenden |
| Auth/Sync | Protokolle/API übernehmbar | Flutter-Servicecode direkt übernehmen |
| Scanner/Biometrie/Notifications | Mit .NET-spezifischen Libraries möglich | Flutter-Plugin-Implementierungen übernehmen |
| Tests | Testfälle fachlich als Vorlage nutzbar | Dart-Tests direkt weiterverwenden |
| Backend | PocketBase weiter nutzbar | PocketBase-internes Verhalten ohne Anpassung in C# reproduzieren |

---

## 5) Empfohlener Ablaufplan

### Phase 0 – Zielbild und Scope fixieren

- Zielplattform festlegen (z. B. .NET MAUI + Blazor Web + optional Desktop)
- Muss-/Kann-Features priorisieren (Sync, Konflikte, Scanner, Attachments, App-Lock)
- Entscheidung dokumentieren: PocketBase behalten oder später ablösen

### Phase 1 – Fachliche Entkopplung vorbereiten

- API-Verträge und Datenformate aus Flutter-Code extrahieren und stabilisieren
- Kritische Sync-Regeln und Konfliktfälle als fachliche Spezifikation festhalten
- Bestehende Testfälle als Anforderungskatalog aufbereiten

### Phase 2 – C#-Basis aufbauen

- C#-Solution mit klarer Schichtung (Domain, Application, Infrastructure, UI)
- PocketBase-Client, Auth, Fehlerbehandlung, Logging implementieren
- Lokale Persistenz (SQLite) und Synchronisationsbasis in C# erstellen

### Phase 3 – Kernfunktionen migrieren

- Artikelverwaltung + Anhänge + Import/Export
- Sync inkl. Konflikterkennung/-auflösung
- Einstellungen/Server-Setup/Runtime-Konfiguration

### Phase 4 – Plattformfeatures und Parität

- Scanner, Kamera, Biometrie, Notifications je Plattform integrieren
- Web/Desktop/Mobile Verhalten angleichen
- Performance-/Stabilitätsvergleich gegen Flutter-Stand

### Phase 5 – Test, Pilot, Cutover

- Vollständige Regression (funktional + offline/sync + Fehlerfälle)
- Pilotbetrieb mit ausgewählten Nutzern
- Go-Live, danach Flutter-Code geordnet zurückbauen

---

## 6) Empfehlung

Empfohlen ist eine **inkrementelle Migration** statt Big-Bang:

1. PocketBase zunächst behalten
2. C#-Client funktional parallel aufbauen
3. Erst bei stabiler Feature-Parität produktiv umstellen

Damit werden Risiko, Downtime und fachliche Regressionen deutlich reduziert.

---

## 7) Entscheidungsgrundlage (Go/No-Go)

Ein Go ist sinnvoll, wenn:
- C# als strategischer Standard gesetzt ist
- ausreichende Kapazität für Neubau + Test vorhanden ist
- eine parallele Übergangsphase organisatorisch tragbar ist

Ein No-Go bzw. Verschiebung ist sinnvoll, wenn:
- schnelle Feature-Weiterentwicklung wichtiger als Plattformwechsel ist
- Team überwiegend Flutter-kompetent und C#-Kapazität knapp ist
- kurzfristig kein Budget für umfangreiche Qualitätssicherung verfügbar ist
