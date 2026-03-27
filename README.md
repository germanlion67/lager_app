# 📦 Lager_app

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

> ℹ️ **Ab v0.7.0:** Die Server-URL ist zur Laufzeit konfigurierbar.  
> Beim ersten Start wird ein Einrichtungsbildschirm angezeigt — kein `--dart-define` mehr zwingend nötig.

---

## ✨ Kern-Features

- 📦 **Artikelverwaltung:** Erfassung mit Name, Beschreibung, Ort, Fach und automatischer Artikelnummer
- 📷 **Scanner & Bilder:** QR-/Barcode-Scanner (Mobile) und Bildanhänge (Kamera/Galerie)
- 📎 **Dokumentenverwaltung:** Dokumente (PDF, DOCX, XLSX u. a.) direkt zum Artikel hochladen, synchronisieren und öffnen
- 🔄 **Smart-Sync:** Intelligente Synchronisation mit Konfliktlösung und Offline-Modus — für Artikel, Bilder und Dokumente
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

---

## 🛠️ Schnellstart (Flutter nativ)

Für die lokale Entwicklung ohne Docker:

```bash
# Backend starten
cd server && ./pocketbase serve --http=0.0.0.0:8080

# App starten (in einem zweiten Terminal)
cd app && flutter pub get && flutter run
```

Beim ersten Start erscheint ein Einrichtungsbildschirm, in dem die Server-URL eingegeben wird, z. B.:

- `http://localhost:8080`
- `http://192.168.x.x:8080`

Die URL wird lokal gespeichert und muss nicht erneut eingegeben werden.

> 💡 **Tipp:** Alternativ kann die URL weiterhin per Build-Argument vorkonfiguriert werden:

```bash
flutter run --dart-define=POCKETBASE_URL=http://localhost:8080
```

---

## 📚 Dokumentation

Um die Übersichtlichkeit zu wahren, ist die Dokumentation modular aufgebaut.

### ⚙️ Einrichtung & Betrieb
- 📘 **[INSTALL.md](INSTALL.md):** Detaillierte Installationsanleitung für alle Plattformen
- 🚀 **[DEPLOYMENT.md](DEPLOYMENT.md):** Produktions-Setup, Nginx Proxy Manager & SSL
- 💾 **[BACKUP.md](BACKUP.md):** Sicherungsverfahren und Wiederherstellung

### 🏗️ Entwicklung & Architektur
- 📐 **[ARCHITECTURE.md](ARCHITECTURE.md):** Projektstruktur, Datenmodell und Design-Entscheidungen
- 🗄️ **[DATABASE.md](DATABASE.md):** Datenbank-Design, Sync-Logik, Bild- und Dokumenten-Synchronisation
- 🎨 **[THEMING.md](THEMING.md):** Infos zu AppConfig, AppTheme und Design-Tokens
- 📝 **[LOGGING.md](LOGGING.md):** Details zum integrierten Logging-System

### 📈 Projektstatus
- ✅ **[CHECKLIST.md](CHECKLIST.md):** Aktueller Stand der Implementierung
- 🛠️ **[OPTIMIZATIONS.md](OPTIMIZATIONS.md):** Offene Punkte und manuelle Feinschliff-Tasks

### 🤝 Mitwirken & Support
Informationen zu Code-Styles, Pull Requests und Lizenzierung findest du hier:

- 📜 **[CHANGELOG.md](CHANGELOG.md):** Versionshistorie
- 📜 **[HISTORY.md](HISTORY.md):** Projekthistorie und Meilensteine
- ⚖️ **[LICENSE](LICENSE):** MIT-Lizenz

---

Entwickelt mit ❤️ von **germanlion67**