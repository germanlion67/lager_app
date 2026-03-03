# GitHub Actions Workflows

## Release Workflow

Dieser Workflow automatisiert den Prozess zur Erstellung einer neuen Version der App, einschließlich:
- Erstellen und Pushen eines neuen Versions-Tags
- Testen des Projekts
- Erstellen von Builds für Android und Windows
- Erstellen eines GitHub Releases mit allen Build-Artefakten

### Verwendung

1. Gehe zu **Actions** in GitHub
2. Wähle den Workflow **"Release - Build and Deploy"**
3. Klicke auf **"Run workflow"**
4. Gebe die Versionsnummer ein (z.B. `1.3.4`)
5. Klicke auf **"Run workflow"**

Der Workflow wird dann:
1. Einen Git-Tag `v1.3.4` erstellen und pushen
2. Den Code analysieren und alle Tests ausführen
3. Android APK und App Bundle erstellen
4. Windows Executable erstellen und als ZIP-Archiv verpacken
5. Ein GitHub Release mit allen Artefakten erstellen

### Build-Artefakte

Nach erfolgreichem Durchlauf werden folgende Artefakte erstellt:
- **Android APK**: `app-release.apk` - Für direkte Installation auf Android-Geräten
- **Android App Bundle**: `app-release.aab` - Für Upload im Google Play Store
- **Windows**: `windows-release-[version].zip` - Enthält alle notwendigen Dateien für Windows

### Voraussetzungen

- Der Workflow benötigt die Standard-GitHub-Token-Berechtigungen
- Keine zusätzlichen Secrets oder Konfigurationen erforderlich
- Flutter Version 3.24.0 wird automatisch installiert

### Workflow-Schritte

1. **Create Version Tag**: Erstellt einen Git-Tag mit der angegebenen Version
2. **Run Tests**: Führt `flutter analyze` und `flutter test` aus
3. **Build Android**: Erstellt APK und App Bundle parallel zum Windows-Build
4. **Build Windows**: Erstellt Windows Executable
5. **Create GitHub Release**: Sammelt alle Artefakte und erstellt ein Release

### Fehlerbehebung

Falls der Workflow fehlschlägt:
- Überprüfe die Logs im Actions-Tab
- Stelle sicher, dass alle Tests lokal erfolgreich durchlaufen
- Überprüfe, ob der Tag bereits existiert (Tags können nicht überschrieben werden)
