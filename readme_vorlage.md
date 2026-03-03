# Project Title

Kurzbeschreibung: Ein Satz, der erklärt, was das Projekt macht und für wen es gedacht ist.

- **Status:** (z.B. stable / beta / WIP)
- **Version:** (z.B. v0.1.0)
- **Lizenz:** (z.B. MIT)
- **Maintainer:** @<username>

(Optional: Badges)
![CI](<badge-url>) ![Docker Pulls](<badge-url>) ![License](<badge-url>)

---

## Projektübersicht

Beschreibe hier in 3–6 Sätzen:
- Problem/Use-Case
- Zielgruppe
- Was das Projekt konkret löst
- Was es **nicht** ist (Scope)

### Kernfunktionalität

- Feature 1 (kurz, konkret)
- Feature 2
- Feature 3

### Vorteile

- **Vorteil 1:** Warum relevant
- **Vorteil 2:** Warum relevant
- **Vorteil 3:** Warum relevant

### Wichtige Hinweise / Risiken

- **Backup/Sicherheit:** Was muss der Nutzer vorher wissen?
- **Breaking Changes:** Was kann schiefgehen?
- **Performance/Costs:** Was kann teuer/langsam sein?

---

## Inhaltsverzeichnis

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Docker](#docker)
  - [Local](#local)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Quick Start](#quick-start)
  - [Command Line](#command-line)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

---

## Features

Beschreibe klar, was das Tool kann. Optional mit Mapping-Tabellen / Inputs & Outputs.

- **Feature:** Beschreibung
- **Feature:** Beschreibung

(Optional: Beispielausgabe / Screenshot / Architektur-Grafik)

---

## Requirements

- **Runtime:** (z.B. Python 3.11+ / Node 20+)
- **Dependencies:** (z.B. ExifTool, ffmpeg, Postgres)
- **Optional:** (z.B. Docker)

---

## Installation

### Docker

(Optional: Hinweis, wo das Image liegt)
- Docker Hub: `<link>`
- GHCR: `<link>`

```bash
docker pull <image>:latest
```

(Optional: Beispiel `docker run`)
```bash
docker run --rm \
  -e EXAMPLE_VAR=foo \
  -v "$(pwd)/data:/app/data" \
  <image>:latest
```

### Local

```bash
git clone https://github.com/<owner>/<repo>.git
cd <repo>
```

(Optional: Abhängigkeiten installieren)
```bash
# Beispiel Python
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

## Configuration

Erkläre, wie konfiguriert wird (Env Vars, Config-File, CLI Flags).  
Optional: unterstützte Config-Formate (INI/.env/JSON).

### Environment Variables

| Variable | Required | Description | Default |
|---|---:|---|---|
| `EXAMPLE_API_URL` | ✅ | Base URL für API | - |
| `EXAMPLE_API_KEY` | ✅ | Auth Key/Token | - |
| `LOG_LEVEL` | ❌ | `DEBUG/INFO/WARN/ERROR` | `INFO` |

(Optional: `.env` Beispiel)
```env
EXAMPLE_API_URL=http://localhost:8080
EXAMPLE_API_KEY=change-me
LOG_LEVEL=INFO
```

---

## Usage

### Quick Start

1. Schritt 1
2. Schritt 2
3. Schritt 3

```bash
# Minimal-Beispiel
<command> --help
```

### Command Line

```bash
# Beispiel: Standardlauf
<command> --all

# Beispiel: Dry run
<command> --dry-run

# Beispiel: Nur Teilfunktion
<command> --feature-x
```

(Optional: Flags dokumentieren)
**Häufige Flags:**
- `--all` – alles aktivieren
- `--dry-run` – nur Vorschau, keine Writes
- `--config <file>` – Config laden

---

## Troubleshooting

### Common Issues

**Problem:** kurze Beschreibung  
**Cause:** mögliche Ursache  
**Fix:** konkrete Schritte

(Optional: Logging/Debug Hinweise)
- Logs: `./logs/app.log`
- Debug: `LOG_LEVEL=DEBUG`

---

## Development

### Project Structure

```text
src/
tests/
docs/
```

### Tests

```bash
# Beispiel
pytest -v
```

### Lint / Format

```bash
# Beispiel
ruff check .
black .
```

---

## Contributing

- Issues/Feature Requests: `<link>`
- PRs willkommen: bitte `CONTRIBUTING.md` lesen
- Code Style / Tests: (kurz nennen)

(Optional: Code of Conduct)
- `CODE_OF_CONDUCT.md`

---

## License

Dieses Projekt ist lizenziert unter der **<LICENSE>**.  
Siehe [LICENSE](LICENSE).
