#!/bin/bash

echo "🚀 Starte Flutter-WSL Setup..."

# 1. System-Abhängigkeiten installieren
echo "📦 Installiere Linux-Libraries..."
sudo apt update
sudo apt install -y libsecret-1-dev pkg-config libjsoncpp-dev \
    libgtk-3-dev liblzma-dev libstdc++-12-dev \
    gnome-keyring dbus-x11

# 2. .bashrc Automatisierung hinzufügen
if ! grep -q "gnome-keyring-daemon" ~/.bashrc; then
    echo "📝 Füge Keyring-Start zur .bashrc hinzu..."
    cat << 'BASHRC' >> ~/.bashrc

# Flutter/Keyring Setup für WSL
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
  eval $(dbus-launch --sh-syntax)
fi
eval $(echo "" | gnome-keyring-daemon --start --components=secrets)
export DBUS_SESSION_BUS_ADDRESS
BASHRC
    echo "✅ .bashrc aktualisiert."
else
    echo "ℹ️ .bashrc war bereits konfiguriert."
fi

# 3. Flutter Konfiguration
echo "⚙️  Optimiere Flutter..."
flutter config --enable-linux-desktop

echo "🎉 Fertig! Bitte starte dein Terminal neu oder tippe: source ~/.bashrc"
echo "Danach kannst du deine App mit 'flutter run -d linux' starten."
