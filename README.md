# 📦 Lager_app

Eine professionelle, plattformübergreifende Lagerverwaltung für Elektronikbauteile und Kleinteile. Gebaut mit **Flutter** für maximale Portabilität und **PocketBase** als schlankes, performantes Backend.

![Flutter](https://img.shields.io/badge/Flutter-3.41.4-blue?logo=flutter)
![PocketBase](https://img.shields.io/badge/PocketBase-0.36.6-green?logo=pocketbase)
![Docker](https://img.shields.io/badge/Docker-Compose-blue?logo=docker)
![License](https://img.shields.io/badge/License-MIT-yellow)

[![Build and Push Docker Images](https://github.com/germanlion67/lager_app/actions/workflows/docker-build-push.yml/badge.svg)](https://github.com/germanlion67/lager_app/actions/workflows/docker-build-push.yml)
---

## 🚀 Auf einen Blick

Die **Lager_app** ist eine "Offline-First"-Lösung. Sie bietet die Geschwindigkeit einer lokalen App mit der Sicherheit einer zentralen Datenbank.

*   📱 **Mobile (Android)**: Lokale SQLite-Datenbank, automatischer Hintergrund-Sync.
*   🖥️ **Desktop (Linux/Windows)**: Native Performance mit lokaler Datenhaltung.
*   🌐 **Web (Docker)**: Direkter Zugriff auf die Cloud-Daten ohne Installation.

---

## ✨ Kern-Features

*   📦 **Artikelverwaltung**: Erfassung mit Name, Beschreibung, Ort, Fach und automatischer Artikelnummer.
*   📷 **Scanner & Bilder**: QR/Barcode-Scanner (Mobile) und Bildanhänge (Kamera/Galerie).
*   🔄 **Smart-Sync**: Intelligente Synchronisation mit Konfliktlösung und Offline-Modus.
*   📄 **Reporting**: PDF-Berichte, CSV/JSON-Export und ZIP-Backups.
*   🛡️ **Enterprise Security**: Gehärtetes Deployment mit Security-Headern und automatischer Initialisierung.

---

## 🛠️ Schnellstart (Docker)

Für einen schnellen Testlauf (Entwicklung/Test):

```bash
git clone https://github.com/germanlion67/lager_app.git
cd lager_app
cp .env.example .env
docker compose up -d --build
```
*Web-App: [http://localhost:8081](http://localhost:8081) | PocketBase Admin: [http://localhost:8080/_/](http://localhost:8080/_/)*

---

## 📚 Dokumentation

Um die Übersichtlichkeit zu wahren, ist die Dokumentation modular aufgebaut:

### ⚙️ Einrichtung & Betrieb
*   📘 **[INSTALL.md](INSTALL.md)**: Detaillierte Installationsanleitung für alle Plattformen.
*   🚀 **[DEPLOYMENT.md](DEPLOYMENT.md)**: Produktions-Setup, Nginx Proxy Manager & SSL.
*   💾 **[BACKUP.md](docs/PRODUCTION_DEPLOYMENT.md)**: Sicherungsverfahren und Wiederherstellung.

### 🏗️ Entwicklung & Architektur
*   📐 **[ARCHITECTURE.md](docs/ARCHITECTURE.md)**: Projektstruktur, Datenmodell und Design-Entscheidungen.
*   🎨 **[THEMING.md](docs/ARCHITECTURE.md)**: Infos zu AppConfig, AppTheme und Design-Tokens.
*   📝 **[LOGGING.md](docs/logger.md)**: Details zum integrierten Logging-System.

### 📈 Projektstatus
*   ✅ **[CHECKLIST.md](docs/PRIORITAETEN_CHECKLISTE.md)**: Aktueller Stand der Implementierung.
*   🛠️ **[OPTIMIZATIONS.md](docs/MANUELLE_OPTIMIERUNGEN.md)**: Offene Punkte und manuelle Feinschliff-Tasks.

---

## 🤝 Mitwirken & Support

Informationen zu Code-Styles, Pull Requests und Lizenzierung findest du hier:
*   📜 **[CHANGELOG.md](CHANGELOG.md)**: Versionshistorie.
*   ⚖️ **[LICENSE](LICENSE)**: MIT Lizenz.

---

**Entwickelt mit ❤️ von [germanlion67](https://github.com/germanlion67)**
