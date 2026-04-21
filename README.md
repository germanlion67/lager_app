# 📦 Lager_app

[![CI](https://img.shields.io/github/actions/workflow/status/germanlion67/lager_app/ci.yml?branch=main&label=CI&logo=github)](https://github.com/germanlion67/lager_app/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/germanlion67/lager_app?label=Version&logo=github)](https://github.com/germanlion67/lager_app/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![PocketBase](https://img.shields.io/badge/PocketBase-0.25-B8DBE4?logo=pocketbase)](https://pocketbase.io)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20Web%20%7C%20Linux%20%7C%20Windows-blue)]()


Eine professionelle, plattformübergreifende Lagerverwaltung für Elektronikbauteile und Kleinteile.  
Gebaut mit **Flutter** für maximale Portabilität und **PocketBase** als schlankes, performantes Backend.

**Technologien:** Flutter · PocketBase · Docker · MIT License

---

## 🚀 Auf einen Blick

Die **Lager_app** ist eine **Offline-First**-Lösung.  
Sie bietet die Geschwindigkeit einer lokalen App mit der Sicherheit einer zentralen Datenbank.

- 📱 **Mobile (Android):** Lokale SQLite-Datenbank, automatischer Hintergrund-Sync
- 🖥️ **Desktop (Linux/Windows):** Native Performance mit lokaler Datenhaltung
- 🌐 **Web (Docker):** Direkter Zugriff auf die Cloud-Daten ohne Installation

> ℹ️ **Ab v0.8.2:** App-Lock mit biometrischer Authentifizierung für mobile Plattformen.
> ℹ️ **Ab v0.8.9:** Smart-Sync für hocheffizienten Daten & Bild-Abgleich

---

## ✨ Kern-Features

- 📦 **Artikelverwaltung:** Erfassung mit Name, Beschreibung, Ort, Fach und automatischer Artikelnummer
- 📷 **Scanner & Bilder:** QR-/Barcode-Scanner (Mobile) und Bildanhänge (Kamera/Galerie)
- 📎 **Dokumentenverwaltung:** Dokumente (PDF, DOCX, XLSX u. a.) direkt zum Artikel hochladen, synchronisieren und öffnen
- 🔄 **Smart-Sync (B-007):** Intelligente Synchronisation mit Konfliktlösung und ETag-basiertem Bild-Abgleich — spart Bandbreite und Zeit.
- 🔐 **App-Lock:** Biometrische Authentifizierung (Fingerabdruck/Face) mit Fallback auf Geräte-PIN — konfigurierbare Sperrzeit bei Inaktivität
- 🔧 **Flexible Server-Konfiguration:** PocketBase-URL zur Laufzeit konfigurierbar — per Setup-Screen, Einstellungen oder Build-Default
- 📄 **Reporting:** PDF-Berichte, CSV-/JSON-Export und ZIP-Backups
- 🛡️ **Enterprise Security:** Gehärtetes Deployment mit Security-Headern und automatischer Initialisierung

---

## 🛠️ Schnellstart (Docker)

Für einen schnellen Testlauf in **Entwicklung/Test**:

```bash
git clone https://github.com/germanlion67/lager_app.git
cd lager_app
cp .env.example .env
docker compose up -d --build
```

**Danach erreichbar:**
- **Web-App:** `http://localhost:8081`
- **PocketBase Admin:** `http://localhost:8080/_/`

**Standard-Zugangsdaten (nur Entwicklung!):**

| Zugang | E-Mail | Passwort |
|---|---|---|
| PocketBase Admin | `admin@example.com` | `changeme123` |
| App Test-User | `user@lager.app` | `changeme123` |

> ⚠️ **Sicherheitshinweis:** Diese Zugangsdaten sind nur für die lokale Entwicklung gedacht.
> Ändere sie **sofort** in Produktionsumgebungen! Siehe [DEPLOYMENT.md](DEPLOYMENT.md).
---

## 🛠️ Schnellstart (Flutter nativ)

Für die lokale Entwicklung mit Flutter:

```bash
# Terminal 1: Backend starten (Docker)
cd lager_app
docker compose up -d

# Terminal 2: App starten
cd lager_app/app
flutter pub get
flutter run -d web-server --web-port 8888 --web-hostname 0.0.0.0
```

Dann im **Windows-Browser** öffnen: `http://localhost:8888`

Beim ersten Start erscheint ein Einrichtungsbildschirm, in dem die Server-URL eingegeben wird, z. B.:

- `http://localhost:8080`
- `http://192.168.x.x:8080`

Die URL wird lokal gespeichert und muss nicht erneut eingegeben werden.

> ⚠️ **WSL2-Nutzer:** `flutter run -d chrome` zeigt keine Bilder an (kein WebGL in WSL2).
> Nutze stattdessen den Web-Server-Modus + Windows-Browser. Siehe [DEV_SETUP.md](DEV_SETUP.md).

> 💡 **Tipp:** Alternativ kann die URL weiterhin per Build-Argument vorkonfiguriert werden:

```bash
flutter run --dart-define=POCKETBASE_URL=http://localhost:8080
```

---

## 📚 Dokumentation

Um die Übersichtlichkeit zu wahren, ist die Dokumentation modular aufgebaut.

### ⚙️ Einrichtung & Betrieb
- 🖥️ **[DEV_SETUP.md](docs/DEV_SETUP.md):** Entwicklungsumgebung (WSL2, bekannte Probleme)
- 📘 **[INSTALL.md](INSTALL.md):** Detaillierte Installationsanleitung für alle Plattformen
- 🚀 **[DEPLOYMENT.md](DEPLOYMENT.md):** Produktions-Setup, Nginx Proxy Manager & SSL
- 💾 **[BACKUP.md](BACKUP.md):** Sicherungsverfahren und Wiederherstellung
- 🔑 **[ANDROID_RELEASE_KEYSTORE.md](ANDROID_RELEASE_KEYSTORE.md):** Einrichtung eines stabilen Android Release-Keystores für GitHub Actions.

### 🏗️ Entwicklung & Architektur
- 📐 **[ARCHITECTURE.md](docs/ARCHITECTURE.md):** Projektstruktur, Datenmodell und Design-Entscheidungen
- 🗄️ **[DATABASE.md](docs/DATABASE.md):** Datenbank-Design, Sync-Logik, Bild- und Dokumenten-Synchronisation
- 🎨 **[THEMING.md](docs/THEMING.md):** Infos zu AppConfig, AppTheme und Design-Tokens
- 📝 **[LOGGING.md](docs/LOGGER.md):** Details zum integrierten Logging-System
- 🧪 **[TESTING.md](docs/TESTING.md):** Alle Tests beschrieben — Ziele, Abdeckung und lokaler Aufruf

### 📈 Projektstatus
- ✅ **[CHECKLIST.md](docs/CHECKLIST.md):** Aktueller Stand der Implementierung
- 🛠️ **[OPTIMIZATIONS.md](docs/OPTIMIZATIONS.md):** Offene Punkte und manuelle Feinschliff-Tasks

### 🤝 Mitwirken & Support
Informationen zu Code-Styles, Pull Requests und Lizenzierung findest du hier:

- 📜 **[CHANGELOG.md](CHANGELOG.md):** Versionshistorie
- 📜 **[HISTORY.md](docs/HISTORY.md):** Projekthistorie und Meilensteine
- ⚖️ **[LICENSE](LICENSE):** MIT-Lizenz

---

Entwickelt mit ❤️ von **germanlion67**
