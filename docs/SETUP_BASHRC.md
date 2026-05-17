# .bashrc — Setup-Anleitung

## Neuen Entwicklungsrechner einrichten

### 1. Backup der bestehenden `.bashrc`

```bash
cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d)
```

### 2. Neue `.bashrc` installieren

```bash
cp ~/lager_app/docs/.bashrc ~/.bashrc
```

### 3. Aktivieren

```bash
source ~/.bashrc
```

> 💡 Bei jedem neuen Terminal wird die `.bashrc` automatisch geladen.
> Änderungen werden erst in der nächsten Session wirksam — oder sofort
> durch erneutes `source ~/.bashrc`.

---

## Enthaltene Features

- **WSLg Fixes**  
  Cursor-Fix (`LIBGL_ALWAYS_SOFTWARE`), Schriftdarstellung (`GDK_DPI_SCALE`)

- **History**  
  10.000 Einträge, Timestamps, Duplikate werden entfernt, Auto-Save nach jedem Befehl

- **Shell**  
  Tippfehler-Korrektur bei `cd`, rekursive Pfad-Expansion mit `**`

- **Prompt**  
  Git-Branch-Anzeige in Gelb, Farben für User/Host/Pfad, Terminal-Titel in VS Code

- **Farben**  
  `ls`, `grep` farbig

- **Docker**  
  Automatischer Start falls `dockerd` nicht aktiv

- **SSH Agent**  
  Wird aus WSLg Runtime-Dir geladen (`/mnt/wslg/runtime-dir/ssh-agent.sock`)

---

## Verfügbare Befehle

### Browser umschalten

| Befehl | Funktion |
|---|---|
| `flutter-chromium` | WSL2 Chromium (kein Mauszeiger ohne Desktop-Oberfläche) |
| `flutter-chrome` | Windows Chrome (empfohlen — echtes WebGL) |
| `flutter-edge` | Windows Edge (echtes WebGL) |

> ⚠️ Ohne GPU-Beschleunigung (WSL2 Chromium) werden Bilder nicht korrekt
> angezeigt. Für die Entwicklung Windows-Browser verwenden.
> Siehe [DEV_SETUP.md](DEV_SETUP.md) — Abschnitt 2.

Standard beim Start: `CHROME_EXECUTABLE=/usr/bin/chromium`

---

### Flutter

| Befehl | Funktion |
|---|---|
| `flutter-run` | `flutter run -d web-server --web-port 8888 --web-hostname 0.0.0.0` |
| `flutter-build` | `flutter build web` |
| `flutter-clean` | `flutter clean && flutter pub get` |
| `flutter-test` | `flutter test` |
| `flutter-pub` | `flutter pub get` |
| `flutter-analyze` | `flutter analyze` |

> 💡 App danach im Windows-Browser öffnen: `http://localhost:8888`

---

### Git

| Befehl | Funktion |
|---|---|
| `git-status` | `git status` |
| `git-log` | `git log --oneline --graph --decorate -20` |
| `git-diff` | `git diff` |
| `git-add` | `git add` |
| `git-add-all` | `git add .` |
| `git-commit` | `git commit -m` |
| `git-pull` | `git pull` |
| `git-branches` | `git branch -a` |
| `git-push` | Push ohne VS Code Helper (verhindert `ECONNREFUSED`) |
| `git-push-branch <name>` | Ersten Push eines neuen Branches mit `--set-upstream` |
| `git-pat-reset` | Gespeicherten PAT löschen — beim nächsten Push neu eingeben |

> ⚠️ `git-push` statt `git push` verwenden — VS Code injiziert einen
> Socket-Helper der in WSL2 regelmäßig fehlschlägt.
> Siehe [DEV_SETUP.md](DEV_SETUP.md) — Abschnitt 3.

---

### Docker

| Befehl | Funktion |
|---|---|
| `docker-up` | `docker compose up -d` |
| `docker-down` | `docker compose down` |
| `docker-logs` | `docker compose logs -f` |
| `docker-restart` | `docker compose restart` |
| `docker-status` | `docker ps` *(formatiert)* |
| `docker-clean` | `docker system prune -f` |

---

### Projekt

| Befehl | Funktion |
|---|---|
| `lager` | `cd ~/lager_app/app` |
| `lager-root` | `cd ~/lager_app` |
| `lager-run` | Ins Projekt wechseln + Web-Server starten (Port 8888) |
| `lager-build` | Ins Projekt wechseln + `flutter build web` |

---

### Allgemein

| Befehl | Funktion |
|---|---|
| `ll` | `ls -alFh` (ausführliche Liste mit Größen) |
| `la` | `ls -A` (alle Dateien inkl. versteckte) |
| `..` | `cd ..` |
| `...` | `cd ../..` |
| `df` | Speicherplatz (lesbar formatiert) |
| `du` | Verzeichnisgröße (lesbar formatiert) |
| `rm` | Mit Bestätigung (Schutz vor versehentlichem Löschen) |
| `cp` | Mit Bestätigung |
| `mv` | Mit Bestätigung |
| `mkcd <name>` | Verzeichnis erstellen und direkt hineinwechseln |