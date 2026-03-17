Erstellt Applogo aus Datei assets/images/app_logo.png : dart run flutter_launcher_icons
Erstellt Splash-Screen aus Datei assets/images/app_logo.png : dart run flutter_native_splash:create


# Branch mergen
git checkout main
git merge feature/pdf-fix --no-ff -m "release: merge pdf-fix into main"

# Tag setzen
git tag -a v0.3.0 -m "v0.3.0 — PDF-Export & ZIP-Backup (Linux/Windows, Phase 1)"

# Beides pushen
git push origin main
git push origin v0.3.0

pubspec.yaml nicht vergessen
name: lager_app
version: 0.3.0+3   # 0.3.0 = SemVer · +3 = Build-Nummer (für Stores relevant)
Die Build-Nummer (+3) einfach bei jedem Merge um 1 erhöhen — für Android/iOS Stores ist sie Pflicht, für Desktop/Web egal aber schadet nicht. 🙂