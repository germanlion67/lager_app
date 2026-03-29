Erstellt Applogo aus Datei assets/images/app_logo.png : dart run flutter_launcher_icons
Erstellt Splash-Screen aus Datei assets/images/app_logo.png : dart run flutter_native_splash:create

--------versionieren--------------------------
1.  pubspec.yaml anpassen
version: 0.3.0+3
Die Build-Nummer (+3) einfach bei jedem Merge um 1 erhöhen — für Android/iOS Stores ist sie Pflicht, für Desktop/Web egal aber schadet nicht.

Dann committen:
git add pubspec.yaml
git commit -m "chore: bump version to 0.3.0+3"
git push origin future-web-docker


2. Tag setzen & alles pushen
git tag -a v0.3.0 -m "v0.3.0 — PDF-Export & ZIP-Backup (Linux/Windows, Phase 1)"

git push origin main
git push origin v0.3.0


3. Kontrolle
git log --oneline -5        # letzten 5 Commits prüfen
git tag                     # Tag sichtbar?
git branch                  # main aktiv?

--------------------------

---------branch mergen---------
1. Nach main wechseln & mergen
git checkout main
git pull origin main                          # sicherstellen dass main aktuell ist

git merge future-web-docker --no-ff \
  -m "release: v0.3.0 — PDF-Export & ZIP-Backup (Linux/Windows, Phase 1)"

2. Tag setzen & alles pushen
git tag -a v0.3.0 -m "v0.3.0 — PDF-Export & ZIP-Backup (Linux/Windows, Phase 1)"

git push origin main
git push origin v0.3.0

4. Kontrolle
git log --oneline -5        # letzten 5 Commits prüfen
git tag                     # Tag sichtbar?
git branch                  # main aktiv?

-----------------------------------

Superuser direkt im Container neu erstellen
docker exec -it pocketbase /pb/pocketbase superuser create admin@example.com changeme123 --dir=/pb_data