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

git add .   Staged:     neue Dateien, geänderte Dateien, gelöschte Dateien (im aktuellen Verzeichnisbereich)
git add -u  Staged nur: Änderungen an bereits bekannten Dateien inklusive Löschungen
git add -A  Staged:     alles, also neue, geänderte und gelöschte Dateien
--------------------------------------


Superuser direkt im Container neu erstellen
docker exec -it pocketbase /pb/pocketbase superuser create admin@example.com changeme123 --dir=/pb_data

Test User 
(user@lager.app / changeme123)

--------------------updaten-----------------
Ohne nennenswertes Laufzeit-Risiko kannst du sicher machen:

flutter pub outdated
flutter pub get
flutter analyze
flutter test
Mit moderatem Risiko:

flutter pub upgrade
Mit höherem Risiko:

flutter pub upgrade --major-versions
flutter upgrade
--------------------