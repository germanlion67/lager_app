# Immich & Nextcloud Integration - Bildablage

Diese Anleitung beschreibt die Integration von Immich und Nextcloud für eine optimale Bildablage und -verwaltung.

## Übersicht der Umgebung

| Service | Hosting | URL |
|---------|---------|-----|
| **Nextcloud** | Ionos (Cloud) | https://cloud.ncschrod.de |
| **Immich** | Lokal (Docker/Portainer) | http://192.168.2.209:2283 oder https://immich.schrod.eu |

---

## Wichtige Fragen zur Klärung

Bevor die Integration eingerichtet wird, sollten folgende Fragen beantwortet werden:

### 1. Primärer Verwendungszweck
- **Option A**: Immich als Hauptfotoverwaltung, Nextcloud als Backup/Sharing
- **Option B**: Nextcloud als Hauptspeicher, Immich für KI-gestützte Suche und Gesichtserkennung
- **Option C**: Bidirektionale Synchronisation beider Systeme

### 2. Synchronisationsrichtung
- Sollen Fotos von Immich → Nextcloud kopiert werden?
- Sollen Fotos von Nextcloud → Immich importiert werden?
- Beide Richtungen?

### 3. Automatisierung
- Automatische Synchronisation gewünscht?
- Manuelle Import/Export-Workflows?
- Zeitgesteuerte Backups?

### 4. Speicherplatz-Überlegungen
- Verfügbarer Speicher bei Ionos (Nextcloud)?
- Verfügbarer lokaler Speicher für Immich?
- Deduplizierung erwünscht?

### 5. Zugriffsszenarien
- Zugriff von unterwegs auf Fotos?
- Teilen von Fotos mit Familie/Freunden?
- Mobile Backup (Smartphone)?

---

## Integrationsmöglichkeiten

### Option 1: Immich External Library (Empfohlen für Lesezugriff)

Immich kann externe Bibliotheken einbinden, um Fotos aus anderen Quellen (z.B. einem gemounteten Nextcloud-Ordner) zu lesen.

#### Vorteile:
- Keine Duplizierung der Daten
- KI-Funktionen von Immich für Nextcloud-Fotos nutzbar
- Zentrale Suche und Gesichtserkennung

#### Nachteile:
- Nur Lesezugriff
- Benötigt Mount-Punkt für Nextcloud

### Option 2: WebDAV-Mount von Nextcloud

Nextcloud-Speicher als Netzlaufwerk einbinden und in Immich als externe Bibliothek nutzen.

### Option 3: Synchronisation via Skript/Rclone

Automatische Synchronisation zwischen beiden Systemen mit rclone.

### Option 4: Nextcloud External Storage für Immich

Nextcloud so konfigurieren, dass es auf den Immich-Speicher zugreift.

---

## Schritt-für-Schritt Anleitung

### Variante A: Nextcloud → Immich (External Library)

Diese Variante ermöglicht es, Fotos aus Nextcloud in Immich zu durchsuchen und mit KI zu analysieren.

#### Schritt 1: WebDAV-Mount auf dem Docker-Host einrichten

```bash
# Auf dem Server, wo Immich läuft (192.168.2.209)
sudo apt-get install davfs2

# Verzeichnis für Mount erstellen
sudo mkdir -p /mnt/nextcloud

# davfs2 Credentials konfigurieren
sudo nano /etc/davfs2/secrets
```

Füge folgende Zeile hinzu:
```
https://cloud.ncschrod.de/remote.php/dav/files/<BENUTZERNAME> /mnt/nextcloud <BENUTZERNAME> <APP_PASSWORT>
```

> **Hinweis**: Ersetze `<BENUTZERNAME>` und `<APP_PASSWORT>` mit deinen Nextcloud-Zugangsdaten.

> ⚠️ **Sicherheitshinweis**: Die Datei `/etc/davfs2/secrets` enthält sensible Zugangsdaten. Stelle sicher, dass die Datei nur für root lesbar ist:
> ```bash
> sudo chmod 600 /etc/davfs2/secrets
> sudo chown root:root /etc/davfs2/secrets
> ```
> Verwende immer ein Nextcloud App-Passwort statt des Hauptpassworts!

#### Schritt 2: Nextcloud mounten

```bash
# Manueller Mount
sudo mount -t davfs https://cloud.ncschrod.de/remote.php/dav/files/<BENUTZERNAME> /mnt/nextcloud

# Für automatischen Mount bei Systemstart, in /etc/fstab eintragen:
https://cloud.ncschrod.de/remote.php/dav/files/<BENUTZERNAME> /mnt/nextcloud davfs user,rw,auto 0 0
```

#### Schritt 3: Mount in Docker Compose verfügbar machen

Die `docker-compose.yml` von Immich anpassen:

```yaml
services:
  immich-server:
    # ... bestehende Konfiguration ...
    volumes:
      - ${UPLOAD_LOCATION}:/usr/src/app/upload
      - /mnt/nextcloud:/mnt/nextcloud:ro  # Nextcloud als Read-Only
```

#### Schritt 4: External Library in Immich einrichten

1. Immich Web-Interface öffnen: http://192.168.2.209:2283
2. Zu **Administration** → **External Libraries** navigieren
3. **Create Library** klicken
4. Library-Pfad eingeben: `/mnt/nextcloud/Photos` (oder entsprechender Ordner)
5. **Scan** starten

---

### Variante B: Immich → Nextcloud (Backup via Rclone)

Diese Variante erstellt automatische Backups von Immich-Fotos nach Nextcloud.

#### Schritt 1: Rclone installieren

```bash
# Auf dem Docker-Host
sudo apt-get install rclone
```

#### Schritt 2: Rclone für Nextcloud konfigurieren

```bash
rclone config
```

Folgende Eingaben machen:
```
n) New remote
name> nextcloud
Storage> webdav
url> https://cloud.ncschrod.de/remote.php/dav/files/<BENUTZERNAME>
vendor> nextcloud
user> <BENUTZERNAME>
password> <APP_PASSWORT>
```

> **Hinweis**: Ersetze `<BENUTZERNAME>` und `<APP_PASSWORT>` mit deinen Nextcloud-Zugangsdaten.

#### Schritt 3: Synchronisationsskript erstellen

```bash
sudo nano /opt/scripts/immich-backup.sh
```

Inhalt:
```bash
#!/bin/bash
# Immich → Nextcloud Backup Script

# ANPASSEN: Pfad zum Immich Upload-Verzeichnis
# Typische Pfade: /srv/immich/upload, /home/user/immich/upload
IMMICH_UPLOAD_DIR="/srv/immich/upload"
NEXTCLOUD_DEST="nextcloud:Fotos/Immich-Backup"
LOG_FILE="/var/log/immich-backup.log"

echo "$(date): Starting backup..." >> $LOG_FILE

rclone sync "$IMMICH_UPLOAD_DIR" "$NEXTCLOUD_DEST" \
    --progress \
    --log-file=$LOG_FILE \
    --log-level INFO

echo "$(date): Backup completed." >> $LOG_FILE
```

```bash
sudo chmod +x /opt/scripts/immich-backup.sh
```

#### Schritt 4: Cronjob für automatisches Backup einrichten

```bash
sudo crontab -e
```

Hinzufügen (täglich um 3:00 Uhr):
```
0 3 * * * /opt/scripts/immich-backup.sh
```

---

### Variante C: Bidirektionale Synchronisation

Für eine bidirektionale Synchronisation wird `rclone bisync` verwendet.

#### Warnung
⚠️ Bidirektionale Synchronisation ist komplex und kann zu Konflikten führen. Nur verwenden, wenn wirklich notwendig!

```bash
# Erste Synchronisation (--resync für Initialisierung)
rclone bisync /pfad/zu/immich/upload nextcloud:Fotos --resync

# Nachfolgende Synchronisationen
rclone bisync /pfad/zu/immich/upload nextcloud:Fotos
```

---

## Empfohlene Konfiguration

Basierend auf der Infrastruktur empfehle ich folgendes Setup:

### Empfehlung: Immich als Primärsystem + Nextcloud-Backup

```
┌─────────────────┐     ┌─────────────────┐
│    Smartphone   │     │    Nextcloud    │
│   (Immich App)  │     │   (Ionos)       │
└────────┬────────┘     └────────▲────────┘
         │                       │
         │ Upload                │ Backup
         │                       │ (Rclone)
         ▼                       │
┌─────────────────────────────────────────┐
│              Immich Server              │
│         (192.168.2.209:2283)            │
│  • KI-Gesichtserkennung                 │
│  • Automatische Klassifizierung         │
│  • Schnelle lokale Suche                │
└─────────────────────────────────────────┘
```

### Vorteile dieser Konfiguration:
1. **Schneller lokaler Zugriff** auf Fotos via Immich
2. **KI-Funktionen** für Suche und Organisation
3. **Cloud-Backup** auf Nextcloud bei Ionos
4. **Zugriff von überall** via Nextcloud oder immich.schrod.eu
5. **Teilen via Nextcloud** für Familie und Freunde

---

## Portainer-Konfiguration

Falls Immich über Portainer verwaltet wird, hier die relevanten Einstellungen:

### Volume-Konfiguration in Portainer

1. Portainer öffnen
2. Zu **Stacks** → **Immich** navigieren
3. Im Stack Editor die Volumes anpassen:

```yaml
volumes:
  - /srv/immich/upload:/usr/src/app/upload
  - /mnt/nextcloud:/mnt/nextcloud:ro  # Optional: Nextcloud-Mount
```

### Umgebungsvariablen

```
UPLOAD_LOCATION=/srv/immich/upload
DB_DATA_LOCATION=/srv/immich/postgres
```

---

## Sicherheitshinweise

### App-Passwörter verwenden
Verwende in Nextcloud immer App-Passwörter statt des Hauptpassworts:
1. Nextcloud → Einstellungen → Sicherheit
2. "Neues App-Passwort erstellen"
3. Dieses Passwort für WebDAV/Rclone verwenden

### HTTPS verwenden
- Nextcloud ist bereits via HTTPS erreichbar ✓
- Immich sollte idealerweise auch via HTTPS erreichbar sein (immich.schrod.eu)

### Firewall-Regeln
- Port 2283 nur im lokalen Netzwerk freigeben
- Für externen Zugriff Reverse-Proxy verwenden

---

## Troubleshooting

### Problem: WebDAV-Mount schlägt fehl
```bash
# Logs prüfen
dmesg | tail -20

# davfs2 Debug-Modus
sudo mount -t davfs -o debug https://cloud.ncschrod.de/remote.php/dav/files/<BENUTZERNAME> /mnt/nextcloud
```

### Problem: Immich External Library scannt nicht
1. Berechtigungen prüfen: `ls -la /mnt/nextcloud`
2. Immich-Container Logs prüfen: `docker logs immich_server`
3. Pfad in Immich verifizieren

### Problem: Rclone Synchronisation langsam
```bash
# Mehrere parallele Transfers
rclone sync source dest --transfers 4 --checkers 8
```

---

## Nützliche Links

- [Immich Dokumentation](https://immich.app/docs/)
- [Nextcloud WebDAV](https://docs.nextcloud.com/server/latest/user_manual/en/files/access_webdav.html)
- [Rclone Dokumentation](https://rclone.org/docs/)
- [davfs2 Manual](http://savannah.nongnu.org/projects/davfs2)

---

## Checkliste zur Einrichtung

- [ ] Verwendungszweck definiert
- [ ] App-Passwort in Nextcloud erstellt
- [ ] Docker-Host vorbereitet
- [ ] Mount oder Rclone konfiguriert
- [ ] Immich External Library eingerichtet (falls gewünscht)
- [ ] Backup-Skript erstellt (falls gewünscht)
- [ ] Cronjob eingerichtet (falls gewünscht)
- [ ] Test-Synchronisation durchgeführt
- [ ] Monitoring eingerichtet

---

*Erstellt für die Integration von Immich (192.168.2.209:2283 / immich.schrod.eu) und Nextcloud (cloud.ncschrod.de)*
