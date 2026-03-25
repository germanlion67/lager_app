# GitHub Actions Workflows

Diese Dokumentation beschreibt die automatisierten Abläufe im Repository `lager_app`.Die CI/CD-Struktur konzentriert sich auf die Erstellung von Docker-Images, Plattform-spezifischen Binaries und die kontinuierliche Wartung.

## Workflow-Übersicht

| Workflow | Trigger (Wann?) | Hauptaufgabe |
| :--- | :--- | :--- |
| **`docker-build-push.yml`** | `push` auf `main`, Tags (`v*`), `pull_request` | Baut Docker-Images (Web & PocketBase) und pusht sie in die GHCR. |
| **`release.yml`** | Manuell (`workflow_dispatch`) | Erstellt Git-Tags, baut APKs, Windows- & Linux-Binaries und erstellt ein GitHub Release. |
| **`flutter-maintenance.yml`** | Wöchentlich (Mo, 04:00) oder manuell | Führt `analyze` und `test` aus, prüft auf veraltete Pakete (`pub outdated`). |

---

## Release Workflow

Dieser Workflow automatisiert den Prozess zur Erstellung einer neuen Version der App für Endnutzer, einschließlich Testing und Artefakt-Erstellung.

### Verwendung

1. Gehe zu **Actions** in GitHub.
2. Wähle den Workflow **"Release - Build and Deploy"**.
3. Klicke auf **"Run workflow"**.
4. Gib die Versionsnummer ein (z. B. `1.3.4`).
5. Klicke auf **"Run workflow"**.

**Der Workflow führt folgende Schritte aus:**
1. **Create Version Tag**: Erstellt einen Git-Tag `v1.3.4` und pusht diesen.
2. **Run Tests**: Analysiert den Code (`analyze`) und führt Unit-Tests aus.
3. **Build Android**: Erstellt APK und App Bundle parallel zu den Desktop-Builds.
4. **Build Windows**: Erstellt die Windows Executable und verpackt sie als ZIP.
5. **Build Linux**: Erstellt das Linux-Binary-Paket (TAR.GZ).
6. **Create GitHub Release**: Sammelt alle Artefakte und erstellt ein offizielles Release mit Download-Links.

### Build-Artefakte

Nach erfolgreichem Durchlauf stehen im Release folgende Dateien bereit:
- **Android APK**: `app-release.apk` – Für die direkte Installation auf Geräten.
- **Android App Bundle**: `app-release.aab` – Für den Google Play Store.
- **Windows**: `windows-release-[version].zip` – Enthält die ausführbare `.exe`.
- **Linux**: `linux-release-[version].tar.gz` – Bundle für Linux-Desktop.

---

## Docker & Container Registry

Der Workflow **`docker-build-push.yml`** sorgt dafür, dass Web-Version und Backend (PocketBase) immer als aktuelle Docker-Images verfügbar sind.

- **Registry:** `ghcr.io/germanlion67/lager_app_web` und `ghcr.io/germanlion67/lager_app_pocketbase`
- **Tags:** 
  - `latest`: Aktueller Stand des `main`-Branches.
  - `sha-[commit]`: Spezifische Versionen für Rollbacks.
  - `v[version]`: Entspricht den offiziellen Releases.
- **Qualitätssicherung:** Bei Pull Requests wird ein Test-Deployment mit Docker Compose simuliert, um sicherzustellen, dass die Container korrekt starten (Health-Checks).

---

## Wartung (Maintenance)

Um die langfristige Stabilität zu gewährleisten, läuft montags automatisch der **Flutter Maintenance** Workflow:
- **System-Check:** Führt `flutter doctor` aus.
- **Abhängigkeits-Reports:** Erstellt Berichte über veraltete Flutter-Pakete (`build/reports/outdated-*.txt`).
- **Statische Analyse:** Stellt sicher, dass neuer Code den Linting-Regeln entspricht.
- **Automatisierte Tests:** Führt die Test-Suite aus, um Regressionen zu vermeiden.

### Fehlerbehebung

Falls ein Workflow fehlschlägt:
- **Logs prüfen:** Untersuche die Fehlermeldungen direkt im GitHub Actions-Tab.
- **Tag existiert bereits:** Git-Tags können nicht überschrieben werden. Lösche den Tag ggf. manuell oder wähle eine neue Version.
- **Tests lokal ausführen:** Stelle sicher, dass `flutter test` und `flutter analyze` lokal keine Fehler werfen.
- **Berechtigungen:** Für Docker-Builds muss das GitHub-Token Schreibrechte für "Packages" besitzen.
