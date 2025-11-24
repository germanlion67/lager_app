# Schnellstart: Immich-Backup zu Nextcloud

Diese Kurzanleitung richtet ein automatisches Backup von Immich-Fotos zu Nextcloud ein.

## Voraussetzungen

- Zugang zum Docker-Host (192.168.2.209)
- Nextcloud App-Passwort
- SSH-Zugang zum Server

## In 5 Minuten einrichten

### 1. Rclone installieren

```bash
ssh user@192.168.2.209
sudo apt-get update && sudo apt-get install -y rclone
```

### 2. Nextcloud verbinden

```bash
rclone config
```

Eingaben:
- `n` (new remote)
- Name: `nextcloud`
- Storage: `webdav`
- URL: `https://cloud.ncschrod.de/remote.php/dav/files/<BENUTZERNAME>`
- Vendor: `nextcloud`
- User: `<BENUTZERNAME>`
- Password: `<APP_PASSWORT>`

> **Hinweis**: Ersetze `<BENUTZERNAME>` mit deinem Nextcloud-Benutzernamen und `<APP_PASSWORT>` mit einem App-Passwort aus Nextcloud (Einstellungen → Sicherheit → App-Passwörter).

### 3. Verbindung testen

```bash
rclone lsd nextcloud:
```

Sollte deine Nextcloud-Ordner anzeigen.

### 4. Backup-Skript erstellen

```bash
sudo mkdir -p /opt/scripts
sudo tee /opt/scripts/backup-immich.sh << 'EOF'
#!/bin/bash
# ANPASSEN: Pfad zum Immich Upload-Verzeichnis (z.B. /srv/immich/upload)
IMMICH_DIR="/srv/immich/upload"
NEXTCLOUD="nextcloud:Fotos/Immich-Backup"

rclone sync "$IMMICH_DIR" "$NEXTCLOUD" --progress
EOF

sudo chmod +x /opt/scripts/backup-immich.sh
```

### 5. Testen

```bash
sudo /opt/scripts/backup-immich.sh
```

### 6. Automatisieren (Optional)

```bash
# Täglich um 2:00 Uhr
(sudo crontab -l 2>/dev/null; echo "0 2 * * * /opt/scripts/backup-immich.sh") | sudo crontab -
```

## Fertig! ✓

Deine Immich-Fotos werden nun nach Nextcloud gesichert.

---

Für erweiterte Optionen siehe die [vollständige Dokumentation](README.md).
