# ============================================================
# ~/.bashrc — Entwicklungsumgebung WSL2
# Lager-App | Flutter / Docker / PocketBase
# Version: 2.0 | Aktualisiert: Mai 2026
# ============================================================

# Nicht-interaktive Shells sofort beenden
case $- in
    *i*) ;;
      *) return;;
esac

# ============================================================
# 1. HISTORY
# ============================================================

# Keine Duplikate, keine Leerzeichen-Einträge
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT="%d/%m/%y %T "

# History sofort speichern (nicht erst bei Session-Ende)
PROMPT_COMMAND="history -a;${PROMPT_COMMAND:-}"

# ============================================================
# 2. SHELL OPTIONEN
# ============================================================

# Fenstergröße nach jedem Befehl aktualisieren
shopt -s checkwinsize

# ** matcht rekursiv in Pfaden
shopt -s globstar 2>/dev/null

# Tippfehler bei cd automatisch korrigieren
shopt -s cdspell 2>/dev/null

# ============================================================
# 3. CHROOT ERKENNUNG (Ubuntu-Standard, nicht ändern)
# ============================================================

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# ============================================================
# 4. PROMPT MIT GIT-BRANCH
# ============================================================

# Aktuellen Git-Branch für den Prompt auslesen
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

# Format: user@host:~/pfad (branch)$
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\$ '

# Terminal-Titel für VS Code / xterm setzen
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
esac

# ============================================================
# 5. FARBEN
# ============================================================

if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# ============================================================
# 6. WSL2 FIXES
# ============================================================

# Verhindert fehlenden Mauszeiger in WSLg GUI-Apps
export LIBGL_ALWAYS_SOFTWARE=1

# Schriftdarstellung in GUI-Apps
export GDK_DPI_SCALE=1

# SSH Agent aus WSLg verwenden
export SSH_AUTH_SOCK=/mnt/wslg/runtime-dir/ssh-agent.sock

# ============================================================
# 7. PFADE — Flutter / Android SDK
# ============================================================

export PATH=$PATH:/usr/local/flutter/bin
export PATH="$PATH":"$HOME/.pub-cache/bin"

export ANDROID_HOME=$HOME/android-sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/build-tools/34.0.0

# Standard-Browser für Flutter (WSL2 Chromium)
export CHROME_EXECUTABLE=/usr/bin/chromium

# ============================================================
# 8. DBUS / KEYRING (Flutter Auth in WSL2)
# ============================================================

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi
eval $(echo "" | gnome-keyring-daemon --start --components=secrets 2>/dev/null)
export DBUS_SESSION_BUS_ADDRESS

# ============================================================
# 9. DOCKER — automatisch starten falls nicht aktiv
# ============================================================

if ! pgrep dockerd > /dev/null; then
    sudo service docker start > /dev/null 2>&1
fi

# ============================================================
# 10. BASH COMPLETION
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
# 11. ALIASE — Dateien & Navigation
# ============================================================

alias ls='ls --color=auto'
alias ll='ls -alFh'
alias la='ls -A'
alias grep='grep --color=auto'

alias ..='cd ..'
alias ...='cd ../..'

alias df='df -h'
alias du='du -sh'

# Sicherheit: Bestätigung vor Überschreiben/Löschen
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Verzeichnis erstellen und direkt hineinwechseln
mkcd() { mkdir -p "$1" && cd "$1"; }

# ============================================================
# 12. ALIASE — Flutter
# ============================================================

# Browser für Flutter wechseln (in der aktuellen Shell-Session)
alias flutter-chromium='export CHROME_EXECUTABLE=/usr/bin/chromium && echo "✔ Browser: WSL2 Chromium"'
alias flutter-chrome='export CHROME_EXECUTABLE="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" && echo "✔ Browser: Windows Chrome"'
alias flutter-edge='export CHROME_EXECUTABLE="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" && echo "✔ Browser: Windows Edge"'

alias flutter-run='flutter run -d web-server --web-port 8888 --web-hostname 0.0.0.0'
alias flutter-build='flutter build web'
alias flutter-clean='flutter clean && flutter pub get'
alias flutter-test='flutter test'
alias flutter-pub='flutter pub get'
alias flutter-analyze='flutter analyze'

# ============================================================
# 13. ALIASE — Projekt (Lager-App)
# ============================================================

alias lager='cd ~/lager_app/app'
alias lager-root='cd ~/lager_app'
alias lager-run='cd ~/lager_app/app && flutter run -d web-server --web-port 8888 --web-hostname 0.0.0.0'
alias lager-build='cd ~/lager_app/app && flutter build web'

# ============================================================
# 14. ALIASE — Git
# ============================================================

alias git-status='git status'
alias git-log='git log --oneline --graph --decorate -20'
alias git-diff='git diff'
alias git-add='git add'
alias git-add-all='git add .'
alias git-commit='git commit -m'
alias git-pull='git pull'
alias git-branches='git branch -a'

# Push ohne VS Code Helper (verhindert ECONNREFUSED in WSL2)
# Beim ersten Aufruf: GitHub-Username + PAT als Passwort eingeben
alias git-push='env -u GIT_ASKPASS \
    -u VSCODE_GIT_ASKPASS_NODE \
    -u VSCODE_GIT_ASKPASS_MAIN \
    -u VSCODE_GIT_ASKPASS_EXTRA_ARGS \
    -u VSCODE_GIT_IPC_HANDLE \
    git -c credential.helper=store push'

# Neuen Branch erstellen und direkt pushen (mit Upstream setzen)
# Verwendung: git-push-branch mein-branch-name
git-push-branch() {
    env -u GIT_ASKPASS \
        -u VSCODE_GIT_ASKPASS_NODE \
        -u VSCODE_GIT_ASKPASS_MAIN \
        -u VSCODE_GIT_ASKPASS_EXTRA_ARGS \
        -u VSCODE_GIT_IPC_HANDLE \
        git -c credential.helper=store push --set-upstream origin "$1"
}

# PAT zurücksetzen wenn abgelaufen oder ungültig
# Danach git-push erneut aufrufen und neuen PAT eingeben
git-pat-reset() {
    git credential reject <<EOF
protocol=https
host=github.com
EOF
    echo "✔ PAT gelöscht — beim nächsten git-push neu eingeben"
}

# ============================================================
# 15. ALIASE — Docker
# ============================================================

alias docker-up='docker compose up -d'
alias docker-down='docker compose down'
alias docker-logs='docker compose logs -f'
alias docker-restart='docker compose restart'
alias docker-status='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias docker-clean='docker system prune -f'

# ============================================================
# 16. WILLKOMMENSNACHRICHT
# ============================================================

echo "──────────────────────────────────────"
echo " 🚀 Lager-App Entwicklungsumgebung"
echo " Browser:  $(basename $CHROME_EXECUTABLE)"
echo " Flutter:  flutter-run | flutter-clean | flutter-pub"
echo " Browser:  flutter-chromium | flutter-chrome | flutter-edge"
echo " Projekt:  lager | lager-root | lager-run"
echo " Git:      git-status | git-push | git-pat-reset"
echo " Docker:   docker-up | docker-down | docker-logs"
echo "──────────────────────────────────────"