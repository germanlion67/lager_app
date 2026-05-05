# Entwicklungsumgebung – Setup & bekannte Probleme

## Voraussetzungen

- WSL2 (Ubuntu)
- Flutter 3.41+
- Docker & Docker Compose
- Chrome auf dem **Windows-Host**

---

## 1. PocketBase-Datenbank starten

> ⚠️ **NICHT** wie in der alten Doku beschrieben mit
> `cd server && ./pocketbase serve --http=0.0.0.0:8080` starten!
> PocketBase läuft ausschließlich über Docker.

```bash
cd ~/lager_app
docker compose up -d
```

PocketBase ist dann erreichbar unter: `http://localhost:8080`

Admin-UI: `http://localhost:8080/_/`

> **Hinweis:** Das tatsächlich verfügbare PocketBase-Schema ergibt sich aus dem
> aktuellen Container-/Migrationsstand. Serverseitige Migrationen liegen unter
> `server/pb_migrations/`. Maßgeblich sind der laufende Stand und die aktuelle Doku,
> nicht ältere Session-Prompts.

### Datenbank stoppen

```bash
docker compose down
```

### Logs prüfen

```bash
docker compose logs -f pocketbase
```

---

## 2. Flutter-App starten (Web)

> ⚠️ **Bekanntes Problem: WSL2 hat kein WebGL / keine GPU-Beschleunigung.**
>
> `flutter run -d chrome` öffnet Chrome innerhalb von WSL2.
> CanvasKit fällt dort auf CPU-only Rendering zurück, was dazu führt,
> dass **Bilder (Image.memory) nicht angezeigt werden** – obwohl die
> Bilddaten korrekt geladen sind.
>
> **Fehlerbild:** Leerer Bereich wo das Bild sein sollte, keine Fehlermeldung.
> In der Konsole steht:
>
> `WARNING: Falling back to CPU-only rendering. Reason: webGLVersion is -1`

### ✅ Lösung: Web-Server-Modus + Windows-Browser

Statt `flutter run -d chrome` den Web-Server-Modus verwenden:

```bash
cd ~/lager_app/app
flutter run -d web-server --web-port 8888 --web-hostname 0.0.0.0
```

Dann im **Windows-Browser** (Chrome) öffnen:

```
http://localhost:8888
```

Windows-Chrome hat echtes WebGL → CanvasKit rendert korrekt → Bilder funktionieren.

### Hot-Reload

Hot-Reload funktioniert im Web-Server-Modus:

- Im Terminal `r` drücken für Hot-Reload
- `R` für Hot-Restart
- `q` zum Beenden

---

## Plattformhinweis: Web vs. Native

Die Web-Variante unterscheidet sich bewusst von Mobile/Desktop:

- keine produktive lokale SQLite-Sync-Persistenz wie auf Native
- andere Datei-/Bildpfade
- andere Laufzeit- und Browser-Bedingungen
- Konfiguration häufig über Browser-/Runtime-Mechanismen

Für lokale Web-Entwicklung ist deshalb wichtig, Web-spezifische Effekte
(z. B. Browser, CanvasKit, CORS, Runtime-Konfiguration) nicht mit den nativen
SQLite-/Sync-Pfaden gleichzusetzen.

--- 

## 3. Zusammenfassung: Typischer Entwicklungs-Workflow

```bash
# Terminal 1: Datenbank
cd ~/lager_app
docker compose up -d

# Terminal 2: Flutter-App
cd ~/lager_app/app
flutter run -d web-server --web-port 8888 --web-hostname 0.0.0.0

# Windows-Browser: http://localhost:8888
```

---

## 4. Häufige Fehler

| Problem | Ursache | Lösung |
|---------|---------|--------|
| Bilder werden nicht angezeigt | WSL2 kein WebGL, CanvasKit CPU-Fallback | Web-Server-Modus + Windows-Browser |
| pocketbase serve funktioniert nicht | PocketBase läuft nur via Docker | `docker compose up -d` |
| config.js MIME-Type Fehler | Normale Dev-Server-Warnung | Kann ignoriert werden |
| App verbindet nicht zur DB | PocketBase-Container nicht gestartet | `docker compose up -d` prüfen |

---

*Letzte Aktualisierung: März 2026*