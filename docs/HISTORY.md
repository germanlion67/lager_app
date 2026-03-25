# 📜 Projekthistorie & Meilensteine

Dieses Dokument dient als Archiv für alle bisherigen Phasen, Analysen und Zusammenfassungen der **Lager_app**. Es bewahrt das Wissen aus den ursprünglichen Planungs- und Umsetzungsdokumenten.

---

## 📋 Dokumente zum Artikel  - 25.03.2026
### 🗄️ Datenbank (Lokal & Server)
- Neue Tabelle `artikel_dokumente` in der lokalen SQLite-Datenbank mit Feldern für:
 - `id, artikel_uuid` (Fremdschlüssel zum Artikel), `uuid, remote_path`
 - `dateiname, dateityp, dateipfad` (lokal), `remoteDokumentPfad`
 - `beschreibung, erstelltAm, updated_at, deleted, etag`
- PocketBase Collection `artikel_dokumente` als serverseitiges Gegenstück mit File-Field für den Upload
### 📱 Flutter App
- `DokumentModel`: Dart-Klasse für ein einzelnes Dokument
- `DokumentRepository`: CRUD-Operationen gegen die lokale SQLite
- `DokumentSyncService`: Push/Pull-Logik analog zur Bild-Synchronisation
- UI – Dokumente-Tab im Artikel-Detail:
 - Liste aller Dokumente zum Artikel
 - Upload-Button (Dateiauswahl via `file_picker`)
 - Download & Öffnen via `open_file`
 - Löschen mit Soft-Delete
### 🔄 Synchronisation
- Dokumente werden getrennt von Textdaten und Bildern synchronisiert
- Gleiche ETag/UUID-Strategie wie bei Artikeln
- Hard-Delete auf dem Server wenn lokal `deleted = 1`


## 📅 März 2026: Die "Kritische Phase" (Härtung & Optimierung)

In diesem Monat wurde die App von einem Prototyp zu einem produktionsreifen System transformiert. Die Schwerpunkte lagen auf Sicherheit, automatisierter Bereitstellung und Performance.

### Meilensteine Phase 3 & 4
*   **Datenbank-Tuning**: Einführung von 5 strategischen Indizes in PocketBase zur Beschleunigung der Suche bei >10.000 Artikeln.
*   **Artikelnummer-System**: Implementierung einer eindeutigen, für Menschen lesbaren Artikelnummer (Startwert 1000).
*   **Security Hardening**: 
    *   Umstellung auf `expose` statt `ports` in Docker für interne Netzwerk-Isolierung.
    *   Konfiguration von Caddy mit strikten Security-Headern (CSP, HSTS).
    *   Automatisierte PocketBase-Initialisierung (Admin-User & Rules via ENV).
*   **CI/CD**: Erstellung von stabilen GitHub Actions Workflows für plattformübergreifende Releases (Android, Windows, Docker).

---

## 🔍 Zusammenfassung der technischen Analysen (Archiv)

### Analyse der README & Struktur (März 2026)
*   **Problem**: Die Dokumentation war stark fragmentiert und enthielt viele Redundanzen zwischen Root-Verzeichnis und `docs/`.
*   **Lösung**: Modularisierung der Dokumentation in `README.md` (Übersicht), `INSTALL.md` (Setup) und spezialisierte `docs/*.md`.
*   **Ergebnis**: Eine saubere "Single Source of Truth"-Struktur.

### Synchronisations-Architektur (Phase 2 Review)
*   **Konzept**: Offline-First mit Delta-Synchronisation.
*   **Implementierung**: Nutzung von `updated_at` (Unix-Timestamp) und `deleted` (Soft-Delete) zur Minimierung des Datenverkehrs.
*   **Erkenntnis**: Das "Last-Write-Wins"-Verfahren ist für Einzelnutzer ideal, benötigt aber einen Konflikt-Screen für Multi-User-Szenarien.

---

## 🚀 Pull Request Historie (Zusammenfassung)

### PR #33: Dokumentations-Konsolidierung
*   Finalisierung der modularen Dokumentationsstruktur.
*   Verschlankung der `README.md` auf < 200 Zeilen.
*   Archivierung historischer Zusammenfassungen in diese Datei (`HISTORY.md`).

### PR #32: Zentralisierte Konfiguration
*   Einführung von `AppConfig`, `AppTheme` und `AppImages`.
*   Eliminierung von ca. 200+ hartcodierten Werten (Farben, Abstände, Radien).
*   Vollständiger Dark-Mode Support via Material 3.

### PR #30 & #31: Docker & Backup
*   Korrektur des Docker-Build-Contexts auf Repository-Root (erforderlich für geteilte `packages/`).
*   Dokumentation von 3 Backup-Methoden (Admin-UI, tar-Archive, Cron-Jobs).

### PR #29: Datenbank-Indizes & Logging
*   Implementierung des `AppLogService` zur Ablösung von `debugPrint`.
*   Hinzufügen von Indizes für `artikelnummer`, `name` und `uuid`.

---

## 📝 Historische Architektur-Entscheidungen

1.  **Caddy statt Nginx (Container)**: Caddy wurde gewählt, da es HTTPS/HSTS und SPA-Routing mit minimaler Konfiguration (4 Zeilen) ermöglicht.
2.  **Docker-Context auf Root**: Um lokale Pakete (Monorepo-Stil) im Docker-Build nutzen zu können, wurde der Kontext auf die oberste Ebene gehoben.
3.  **Soft-Delete**: Datensätze werden nie physikalisch gelöscht, um Clients über Löschvorgänge während des nächsten Sync-Vorgangs informieren zu können.

---

*Dieses Dokument wird bei Abschluss größerer Meilensteine aktualisiert, um den Projektverlauf nachvollziehbar zu halten.*