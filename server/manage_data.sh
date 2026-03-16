#!/bin/bash

# Konfiguration
BACKUP_DIR="./backups"
SOURCE_DIR="./pb_data"
mkdir -p "$BACKUP_DIR"

echo "========================================"
echo "   Lager-App: Backup & Restore Tool"
echo "========================================"
echo "1) Voll-Backup erstellen (Daten & Bilder)"
echo "2) Restore durchführen (Aus Liste wählen)"
echo "3) Beenden"
read -p "Bitte wählen [1-3]: " CHOICE

case $CHOICE in
    1)
        # BACKUP LOGIK
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_NAME="lager_full_$TIMESTAMP.tar.gz"
        
        echo "Stoppe Container für konsistentes Backup..."
        docker compose stop
        
        echo "Erstelle Archiv in $BACKUP_DIR..."
        if sudo tar -czpf "$BACKUP_DIR/$BACKUP_NAME" "$SOURCE_DIR"; then
            echo "✅ Backup erfolgreich: $BACKUP_NAME"
        else
            echo "❌ Fehler beim Backup!"
        fi
        
        echo "Starte Container wieder..."
        docker compose start
        ;;

    2)
        # RESTORE LOGIK
        echo "Verfügbare Backups im Ordner $BACKUP_DIR:"
        # Listet alle .tar.gz Dateien auf
        FILES=($(ls $BACKUP_DIR/*.tar.gz 2>/dev/null))
        
        if [ ${#FILES[@]} -eq 0 ]; then
            echo "❌ Keine Backups gefunden!"
            exit 1
        fi

        # Backups zur Auswahl anzeigen
        for i in "${!FILES[@]}"; do
            echo "$i) $(basename ${FILES[$i]})"
        done

        read -p "Welches Backup soll eingespielt werden? (Nummer): " FILE_INDEX

        if [[ -z "${FILES[$FILE_INDEX]}" ]]; then
            echo "❌ Ungültige Auswahl!"
            exit 1
        fi

        SELECTED_BACKUP="${FILES[$FILE_INDEX]}"
        echo "⚠️  WARNUNG: Aktuelle Daten in $SOURCE_DIR werden überschrieben!"
        read -p "Fortfahren? (y/n): " CONFIRM
        
        if [[ $CONFIRM == "y" ]]; then
            echo "Stoppe System..."
            docker compose stop
            
            # Sicherheitskopie des aktuellen Standes
            mv "$SOURCE_DIR" "${SOURCE_DIR}_old_$(date +%s)"
            
            echo "Stelle Daten aus $(basename $SELECTED_BACKUP) wieder her..."
            if sudo tar -xzpf "$SELECTED_BACKUP" -C .; then
                echo "✅ Restore erfolgreich."
            else
                echo "❌ Fehler beim Entpacken!"
            fi
            
            echo "Starte System..."
            docker compose up -d
        else
            echo "Abgebrochen."
        fi
        ;;

    3)
        echo "Beendet."
        exit 0
        ;;

    *)
        echo "Ungültige Auswahl."
        exit 1
        ;;
esac