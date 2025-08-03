#!/bin/bash

set -euo pipefail

bld='\033[1m'
red='\033[0;31m'
grn='\033[0;32m'
ylw='\033[0;33m'
blu='\033[0;34m'
mag='\033[0;35m'
cyn='\033[0;36m'
rst='\033[0m'

_confirm() {
    while true; do
        echo
        echo -e -n "$bld$1$rst [y/N]: "
        read -r yn
        case $yn in
            [Yy]* ) ${@:2}; return 0;;
            [Nn]*|'' ) return 0;;
            *) echo "Invalid response. Please answer y or n.";;
        esac
    done
}

_status() {
    echo -e "\n$cyn$bld== $@ ==$rst\n"
}

_task() {
    echo -e "${bld}[*] $@$rst"
}

_done() {
    echo -e "$bld[$grn✓$rst$bld] $@$rst"
}

_warn() {
    echo -e "${ylw}warning: $@"
}

same_hash() {
    if [ ! -f "$1" -o ! -f "$2" ]; then
        echo "false"
        return
    fi

    hash1="$(sha256sum "$1" | awk '{print $1}')"
    hash2="$(sha256sum "$2" | awk '{print $1}')"

    if [ "$hash1" = "$hash2" ]; then
        echo "true"
    else
        echo "false"
    fi
}

_status "System management"
_task "Updating system"
sudo apt update -y && sudo apt upgrade -y

_task "Installing packages"
sudo apt install -y git tree tmux ripgrep fzf bat ninja-build gettext cmake build-essential kali-wallpapers-all seclists

_status "Language toolchains"
# rust
if command -v rustc &> /dev/null; then
    _done "Rust already installed"
    rustc --version
else
    _task "Execute rustup installer"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# golang
if command -v go &> /dev/null; then
    _done "Golang already installed"
    go version
else
    _task "Removing previous go installation"
    sudo rm -rf /opt/go
    _task "Downloading latest golang release"
    GOLANG_LATEST="$(curl -fsSL 'https://go.dev/dl/?mode=json' | grep 'linux-amd64' | head -n1 | awk '{print $2}' | sed 's/"\(.*\)",/\1/')"
    curl -fsSL -o golang.tar.gz "https://go.dev/dl/$GOLANG_LATEST"
    _task "Installing golang"
    sudo tar -C /opt -xzf golang.tar.gz
    _task "Removing install files"
    rm golang.tar.gz
fi

# install neovim
_status "Neovim"
if command -v nvim &> /dev/null; then
    _done "Already installed neovim"
else
    _task "Removing previous installation"
    sudo rm -rf /opt/nvim

    _task "Downloading latest neovim release"
    curl -fsSLO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz

    _task "Installing neovim"
    sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    sudo mv /opt/nvim-linux-x86_64 /opt/nvim
    rm -f ~/.local/bin/nvim
    ln -s /opt/nvim/bin/nvim ~/.local/bin/nvim

    _task "Removing install files"
    rm nvim-linux-x86_64.tar.gz
fi

_status "Application configuration"
if [ -d ~/.config/nvim ]; then
    _task "Updating neovim config"
    git -C ~/.config/nvim pull
else
    _status "Setting up neovim config"
    mkdir -p ~/.config
    git clone https://github.com/bwpge/nvim-config.git ~/.config/nvim
fi

# set wallpaper
_status "Customizations"
MONITOR_NAME="$(xrandr --listmonitors | grep '^\s*[[:digit:]]' | awk '{print $4}')"
XFCONF_PROP="$(xfconf-query -c xfce4-desktop -l | grep "last-image" | grep "monitor$MONITOR_NAME" | head -n1)"
if [ -z "$XFCONF_PROP" ]; then
    _warn "could not determine xfconf-query property to set monitor background"
fi
if [[ "$(xfconf-query --channel xfce4-desktop --property "$XFCONF_PROP")" == *"kali-neon.png" ]]; then
    _done "Background already set"
else
    _task "Setting background property"
    xfconf-query -c xfce4-desktop -p "$XFCONF_PROP" -s /usr/share/backgrounds/kali-16x9/kali-neon.png
fi

_task "Applying xfconf settings"
xfconf-query -c xfce4-panel -n -p /panels/panel-1/border-width -s 1
xfconf-query -c xfwm4 -n -p /general/mousewheel_rollup -s false
xfconf-query -c keyboards -n -p /Default/KeyRepeat/Rate -t int -s 40

# set terminal theme
QTERM_CONF_FILE="$HOME/.config/qterminal.org/qterminal.ini"
QTERM_THEME_FILE="/usr/share/qtermwidget6/color-schemes/Kali-Custom.colorscheme"
if [ -f "$QTERM_CONF_FILE" ]; then
    if [ "$(same_hash "$QTERM_THEME_FILE" "Kali-Custom.colorscheme")" = "true" ]; then
        _done "Already created terminal color scheme"
    else
        _task "Creating terminal color scheme"
        sudo cp "Kali-Custom.colorscheme" "$QTERM_THEME_FILE"
    fi

    _task "Updating qterminal config"
    sed -i 's/ApplicationTransparency=[[:digit:]]\+/ApplicationTransparency=0/' "$QTERM_CONF_FILE"
    sed -i 's/^colorScheme=.*$/colorScheme=Kali-Custom/' "$QTERM_CONF_FILE"
fi

_status "Configure zsh"
ZSHRC="$HOME/.zshrc"
if [ -z "$(grep '$HOME/.cargo/env' "$ZSHRC")" ]; then
    _task "Add cargo env source"
    echo -e "\n. \"\$HOME/.cargo/env\"" >> "$ZSHRC"
else
    _done "Already configured cargo"
fi
if [ -z "$(grep 'export PATH=$PATH:/opt/go/bin' "$ZSHRC")" ]; then
    _task "Add golang to PATH"
    echo -e "\nexport PATH=\$PATH:/opt/go/bin" >> "$ZSHRC"
else
    _done "Already configured golang"
fi
if [ -z "$(grep 'source <(fzf --zsh)' "$ZSHRC")" ]; then
    _task "Add fzf key bindings"
    echo -e "\n# fzf key bindings\nsource <(fzf --zsh)" >> "$ZSHRC"
else
    _done "Already configured fzf"
fi

_status "Final steps"
ROCKYOU_FILE="/usr/share/wordlists/rockyou.txt"
ROCKYOU_GZ="$ROCKYOU_FILE.gz"
if [ ! -f "$ROCKYOU_FILE" ]; then
    _task "Extract rockyou.txt"
    sudo gunzip -k "$ROCKYOU_GZ"
else
    _done "Already extracted rockyou.txt"
fi

_task "Cleaning apt"
sudo apt autoremove -y
sudo apt clean -y

_restart_term() {
    _p="$(pgrep qterminal | tr '\n' ' ')"
    _w="$(pwd)"
    qterminal -w "$_w" &
    sleep 1
    kill "$_p"
}

if [ ! -z "$(pgrep qterminal 2>/dev/null)" ]; then
    _confirm "Do you want to restart the terminal?" _restart_term
fi
