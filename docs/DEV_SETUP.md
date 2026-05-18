# Entwicklungsumgebung – Setup & bekannte Probleme

## Voraussetzungen

- WSL2 (Ubuntu)
- Flutter 3.41+
- Docker & Docker Compose
- Chrome auf dem **Windows-Host**

---

---

## 1. Shell-Konfiguration (`.bashrc`)

Die Datei `~/.bashrc` wird von Bash **automatisch geladen**, sobald ein neues
interaktives Terminal in WSL2 geöffnet wird — also bei jedem neuen
VS Code Terminal, jeder neuen WSL2-Session oder jedem `bash`-Aufruf.

Sie muss **nicht manuell gestartet** werden. Änderungen an der Datei
werden erst in der nächsten Session wirksam, oder sofort durch:

```bash
source ~/.bashrc
```

Die `.bashrc` dieses Projekts richtet automatisch ein:

- Flutter- und Android-SDK-Pfade
- Docker-Autostart (falls nicht aktiv)
- Git-Aliase inkl. VS Code Helper Bypass (`git-push`, `git-pat-reset`)
- Flutter-Aliase inkl. Browser-Umschaltung
- Projekt-Aliase (`lager`, `lager-run` etc.)
- Git-Branch im Prompt
- Willkommensnachricht beim Start

> 💡 Die aktuelle `.bashrc` liegt im Projekt unter `docs/.bashrc`
> und kann bei einem Neu-Setup direkt nach `~/.bashrc` kopiert werden.
> Hintergründe zur Konfiguration: [SETUP_BASHRC.md](SETUP_BASHRC.md)

---

## 2. PocketBase-Datenbank starten

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

## 3. Flutter-App starten (Web)

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


> # App-Container bauen und starten
```bash
docker compose up app -d --build
```

# Logs verfolgen
```bash
docker compose logs app -f
```

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

## 4. GitHub Push aus WSL2 (mit VS Code)

> ⚠️ **Bekanntes Problem: VS Code injiziert `GIT_ASKPASS` in die WSL2-Shell.**
>
> VS Code verbindet sich über einen Unix-Socket mit dem Git-Helper. Wenn dieser
> Socket nicht (mehr) erreichbar ist, schlägt jeder `git push` mit folgendem
> Fehler fehl:
>
> `connect ECONNREFUSED /run/user/1000/vscode-git-xxxx.sock`
>
> Außerdem muss der verwendete GitHub PAT den Scope `workflow` besitzen,
> wenn das Repository GitHub Actions (`.github/workflows/`) enthält.

### Voraussetzung — PAT erstellen

Einmalig auf GitHub einen **Personal Access Token (classic)** erstellen:

**GitHub → Settings → Developer Settings → Personal Access Tokens → Tokens (classic) → Generate new token**

Erforderliche Scopes:
- ✅ `repo`
- ✅ `workflow`

> 💡 Unter **Expiration** kann **"No expiration"** gewählt werden, wenn der Token
> sicher aufbewahrt wird und das Repository nur privat genutzt wird.

### ✅ Push-Befehl (VS Code Helper umgehen)

```bash
env -u GIT_ASKPASS \
    -u VSCODE_GIT_ASKPASS_NODE \
    -u VSCODE_GIT_ASKPASS_MAIN \
    -u VSCODE_GIT_ASKPASS_EXTRA_ARGS \
    -u VSCODE_GIT_IPC_HANDLE \
    git -c credential.helper=store \
    push --set-upstream origin <branch-name>
```
Beim ersten Aufruf nach Username und Passwort (= PAT) fragen → danach automatisch gespeichert.

### PAT abgelaufen oder ungültig — neu setzen

```bash
# Schritt 1: Alten PAT aus dem Store entfernen
git credential reject <<EOF
protocol=https
host=github.com
EOF

# Schritt 2: Push erneut ausführen → neuen PAT eingeben
env -u GIT_ASKPASS \
    -u VSCODE_GIT_ASKPASS_NODE \
    -u VSCODE_GIT_ASKPASS_MAIN \
    -u VSCODE_GIT_ASKPASS_EXTRA_ARGS \
    -u VSCODE_GIT_IPC_HANDLE \
    git -c credential.helper=store \
    push
```

--- 

## 5. Zusammenfassung: Typischer Entwicklungs-Workflow

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

## 6. Häufige Fehler

| Problem | Ursache | Lösung |
|---------|---------|--------|
| Push abgelehnt (workflow scope) | PAT hat keinen `workflow` Scope | Neuen PAT mit ✅ `repo` + ✅ `workflow` erstellen |
| `git push` schlägt fehl (ECONNREFUSED) | VS Code Socket tot | `git-push` Alias verwenden (siehe Abschnitt 3) |
| Bilder werden nicht angezeigt | WSL2 kein WebGL, CanvasKit CPU-Fallback | Web-Server-Modus + Windows-Browser |
| pocketbase serve funktioniert nicht | PocketBase läuft nur via Docker | `docker compose up -d` |
| config.js MIME-Type Fehler | Normale Dev-Server-Warnung | Kann ignoriert werden |
| App verbindet nicht zur DB | PocketBase-Container nicht gestartet | `docker compose up -d` prüfen |
| Aliase nicht verfügbar | `.bashrc` nach Änderung nicht neu geladen | `source ~/.bashrc` ausführen |
| Docker startet nicht automatisch | `dockerd` nicht aktiv, sudo fehlt | `sudo service docker start` manuell ausführen |

---

*Letzte Aktualisierung: Mai 2026*