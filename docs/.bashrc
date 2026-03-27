# ============================================================
# .bashrc — Komplette Entwicklungsumgebung für WSL2
# Lager-App Flutter/Docker/PocketBase
# Version: 1.0 | Erstellt: 27.03.2026
# ============================================================

# Nicht-interaktive Shells sofort beenden
case $- in
    *i*) ;;
      *) return;;
esac

# ============================================================
# 1. WSL2/WSLg FIXES
# ============================================================

# Behebt fehlenden Mauszeiger in GUI-Apps unter WSLg
export LIBGL_ALWAYS_SOFTWARE=1

# Bessere Schriftdarstellung in GUI-Apps
export GDK_DPI_SCALE=1

# ============================================================
# 2. HISTORY KONFIGURATION
# ============================================================

# Keine Duplikate, keine Leerzeichen-Einträge
HISTCONTROL=ignoreboth:erasedups

# History an Datei anhängen statt überschreiben
shopt -s histappend

# Große History
HISTSIZE=10000
HISTFILESIZE=20000

# Timestamp in History
HISTTIMEFORMAT="%d/%m/%y %T "

# History sofort speichern (nicht erst bei Session-Ende)
PROMPT_COMMAND="history -a;${PROMPT_COMMAND:-}"

# ============================================================
# 3. SHELL OPTIONEN
# ============================================================

# Fenstergröße nach jedem Befehl aktualisieren
shopt -s checkwinsize

# ** matcht rekursiv in Pfaden
shopt -s globstar 2>/dev/null

# Tippfehler bei cd korrigieren
shopt -s cdspell 2>/dev/null

# ============================================================
# 4. CHROOT ERKENNUNG
# ============================================================

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# ============================================================
# 5. PROMPT MIT GIT-BRANCH
# ============================================================

# Git-Branch für Prompt auslesen
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Farbiger Prompt: user@host:~/pfad (branch)$
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\$ '

# Terminal-Titel setzen (für xterm/VSCode)
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
esac

# ============================================================
# 6. FARBEN
# ============================================================

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# ============================================================
# 7. ALLGEMEINE ALIASE
# ============================================================

# Dateien & Verzeichnisse
alias ls='ls --color=auto'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Speicher & System
alias df='df -h'
alias du='du -sh'
alias free='free -h'

# Sicherheits-Aliase (Bestätigung vor Überschreiben)
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Verzeichnis erstellen und direkt wechseln
mkcd() { mkdir -p "$1" && cd "$1"; }

# ============================================================
# 8. GIT SHORTCUTS
# ============================================================

alias gs='git status'
alias gl='git log --oneline -20'
alias gd='git diff'
alias gp='git push'
alias gpull='git pull'
alias gc='git commit -m'
alias ga='git add'
alias gaa='git add .'
alias gbr='git branch -a'
alias glog='git log --oneline --graph --decorate -20'

# ============================================================
# 9. DOCKER SHORTCUTS
# ============================================================

alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias dcr='docker compose restart'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dprune='docker system prune -f'

# Docker automatisch starten falls nicht aktiv
if ! pgrep dockerd > /dev/null; then
    sudo service docker start > /dev/null 2>&1
fi

# ============================================================
# 10. FLUTTER KONFIGURATION
# ============================================================

# Flutter Pfad
export PATH=$PATH:/usr/local/flutter/bin
export PATH="$PATH":"$HOME/.pub-cache/bin"

# Standard-Browser für Flutter
export CHROME_EXECUTABLE=/usr/bin/chromium

# Browser-Aliase für schnellen Wechsel
# Verwendung: flutter-edge && flutter run -d chrome
alias flutter-chromium='export CHROME_EXECUTABLE=/usr/bin/chromium && echo "✔ Browser: WSL2 Chromium"'
alias flutter-chrome='export CHROME_EXECUTABLE="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" && echo "✔ Browser: Windows Chrome"'
alias flutter-edge='export CHROME_EXECUTABLE="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" && echo "✔ Browser: Windows Edge"'

# Flutter Shortcuts
alias frun='flutter run -d chrome'
alias fbuild='flutter build web'
alias fclean='flutter clean && flutter pub get'
alias ftest='flutter test'
alias fpub='flutter pub get'
alias fanalyze='flutter analyze'

# ============================================================
# 11. ANDROID SDK
# ============================================================

export ANDROID_HOME=$HOME/android-sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/build-tools/34.0.0

# ============================================================
# 12. PROJEKT-SHORTCUTS
# ============================================================

alias lager='cd ~/lager_app/app'
alias lager-root='cd ~/lager_app'
alias lager-run='cd ~/lager_app/app && flutter run -d chrome'
alias lager-build='cd ~/lager_app/app && flutter build web'

# ============================================================
# 13. DBUS / KEYRING (für Flutter/PocketBase Auth)
# ============================================================

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi
eval $(echo "" | gnome-keyring-daemon --start --components=secrets 2>/dev/null)
export DBUS_SESSION_BUS_ADDRESS

# ============================================================
# 14. BASH COMPLETION
# ============================================================

if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Externe Alias-Datei laden (optional)
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# ============================================================
# 15. WILLKOMMENSNACHRICHT
# ============================================================

echo "──────────────────────────────────────"
echo " 🚀 Lager-App Entwicklungsumgebung"
echo " Flutter Browser: $(basename $CHROME_EXECUTABLE)"
echo " Shortcuts: lager, frun, fclean, gs"
echo " Browser:   flutter-chromium | -chrome | -edge"
echo " Docker:    dcu, dcd, dcl, dps"
echo "──────────────────────────────────────"
BASHRC_FILE