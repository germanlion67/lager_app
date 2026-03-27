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

---

## Enthaltene Features

- **WSLg Fixes**  
  Cursor-Fix, Schriftdarstellung

- **History**  
  10.000 Einträge, Timestamps, Auto-Save

- **Shell**  
  Tippfehler-Korrektur, `globstar`

- **Prompt**  
  Git-Branch-Anzeige, Farben

- **Farben**  
  `ls`, `grep`, GCC farbig

---

## Verfügbare Aliase

### Flutter

| Alias | Befehl |
|---|---|
| `frun` | `flutter run -d chrome` |
| `fbuild` | `flutter build web` |
| `fclean` | `flutter clean && flutter pub get` |
| `ftest` | `flutter test` |
| `fpub` | `flutter pub get` |

### Git

| Alias | Befehl |
|---|---|
| `gs` | `git status` |
| `gl` | `git log --oneline -20` |
| `gd` | `git diff` |
| `gp` | `git push` |
| `gpull` | `git pull` |

### Docker

| Alias | Befehl |
|---|---|
| `dcu` | `docker compose up -d` |
| `dcd` | `docker compose down` |
| `dcl` | `docker compose logs -f` |
| `dcr` | `docker compose restart` |
| `dps` | `docker ps` *(formatiert)* |

### Projekt

| Alias | Funktion |
|---|---|
| `lager` | `cd ~/lager_app/app` |
| `lager-root` | `cd ~/lager_app` |
| `lager-run` | Ins Projekt wechseln + `flutter run -d chrome` |
| `lager-build` | Ins Projekt wechseln + `flutter build web` |

---

`SETUP_DOC`