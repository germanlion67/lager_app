# FAQ - Immich & Nextcloud Integration

## Allgemeine Fragen

### Warum Immich UND Nextcloud?

| Feature | Immich | Nextcloud |
|---------|--------|-----------|
| KI-Gesichtserkennung | ✓ | ✗ |
| Automatische Klassifizierung | ✓ | ✗ |
| Ähnliche Fotos finden | ✓ | ✗ |
| Datei-Sharing | Eingeschränkt | ✓ |
| Office-Integration | ✗ | ✓ |
| Mobile App (iOS/Android) | ✓ | ✓ |
| Cloud-Hosting | ✗ (selbst) | ✓ (Ionos) |

**Fazit**: Immich für intelligente Fotoverwaltung, Nextcloud für Backup und Teilen.

---

### Welche Daten werden synchronisiert?

- **Fotos**: JPG, PNG, HEIC, WebP
- **Videos**: MP4, MOV, MKV
- **Metadaten**: EXIF, GPS, Datum
- **Nicht synchronisiert**: Immich-Alben, Gesichtsdaten, KI-Tags

---

### Wie viel Speicherplatz wird benötigt?

Die Daten werden **dupliziert** (Original in Immich + Kopie in Nextcloud).

Beispiel:
- 10.000 Fotos à 5 MB = 50 GB
- Benötigt: 50 GB lokal + 50 GB bei Ionos

**Tipp**: Nur bestimmte Ordner synchronisieren, um Speicher zu sparen.

---

## Technische Fragen

### Wie erstelle ich ein Nextcloud App-Passwort?

1. https://cloud.ncschrod.de öffnen
2. Einloggen
3. Rechts oben auf Profilbild → **Einstellungen**
4. Links: **Sicherheit**
5. Runterscrollen zu "App-Passwörter"
6. Name eingeben (z.B. "Immich-Backup")
7. **Neues App-Passwort erstellen** klicken
8. Passwort kopieren und sicher speichern

---

### Wie finde ich den Immich Upload-Pfad?

```bash
# In Portainer unter Stack "immich" nachschauen
# Oder direkt auf dem Server:
docker inspect immich_server | grep -A5 "Mounts"
```

Typische Pfade:
- `/srv/immich/upload`
- `/home/user/immich/upload`
- `/var/lib/immich/upload`

---

### Kann ich selektiv synchronisieren?

Ja! Mit rclone Filtern:

```bash
# Nur JPG-Dateien
rclone sync source dest --include "*.jpg"

# Nur Fotos ab 2024
rclone sync source dest --include "2024/**"

# Bestimmte Ordner ausschließen
rclone sync source dest --exclude "thumbs/**" --exclude "encoded-video/**"
```

---

### Was passiert bei Konflikten?

**rclone sync** (Standard):
- Quelle gewinnt immer
- Gelöschte Dateien in Quelle → werden auch im Ziel gelöscht

**rclone copy** (sicherer):
- Kopiert nur neue/geänderte Dateien
- Löscht nichts im Ziel

**Empfehlung für Backup**: `rclone copy` verwenden

---

### Wie prüfe ich, ob die Synchronisation funktioniert?

```bash
# Trockenlauf (keine Änderungen)
rclone sync source dest --dry-run

# Mit detaillierter Ausgabe
rclone sync source dest --progress --verbose

# Unterschiede anzeigen
rclone check source dest
```

---

## Problemlösung

### "Permission denied" bei Mount

```bash
# Benutzer zur davfs2-Gruppe hinzufügen
sudo usermod -aG davfs2 $USER

# Neu einloggen
exit
ssh user@server
```

---

### "Connection refused" bei Nextcloud

1. URL prüfen: `https://cloud.ncschrod.de/remote.php/dav/files/<BENUTZERNAME>`
2. Benutzername korrekt?
3. App-Passwort (nicht normales Passwort)?
4. SSL-Zertifikat gültig?

```bash
# Verbindung testen
curl -v https://cloud.ncschrod.de/status.php
```

---

### Synchronisation zu langsam

```bash
# Mehr parallele Transfers
rclone sync source dest --transfers 8 --checkers 16

# Größe der Chunks anpassen (für große Dateien)
rclone sync source dest --multi-thread-streams 4
```

---

### Speicher voll auf Nextcloud

1. In Nextcloud Papierkorb leeren
2. Alte Versionen löschen: Einstellungen → "Versionsverlauf"
3. Speichernutzung prüfen: Einstellungen → Persönlich → Speicher

---

## Best Practices

### ✓ Empfohlen

- App-Passwörter verwenden
- Regelmäßige Backups (täglich/wöchentlich)
- Logs überwachen
- Trockenlauf vor großen Änderungen

### ✗ Vermeiden

- Hauptpasswort für Automatisierung
- Bidirektionale Sync ohne Backup
- Manuelle Änderungen an synchronisierten Ordnern
- Zu häufige Synchronisation (< 1 Stunde)

---

## Kontakt & Support

Bei Fragen oder Problemen:
- Immich Dokumentation: https://immich.app/docs/
- Nextcloud Community: https://help.nextcloud.com/
- GitHub Issues in diesem Repository
