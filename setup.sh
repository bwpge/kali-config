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

confirmed=0
noconfirm=0
ZSHRC="$HOME/.zshrc"

opts="$@"
if [ "$opts" = "-y" -o "$opts" = "--yes" ]; then
    noconfirm=1
fi

_confirm() {
    confirmed=0
    if [ "$noconfirm" = 1 ]; then
        confirmed=1
        return 0
    fi

    while true; do
        echo -e -n "$bld$1$rst [Y/n]: "
        read -r yn
        case $yn in
            [Yy]|'' ) confirmed=1; return 0;;
            [Nn] ) return 0;;
            *) echo "Invalid response. Please answer y or n.";;
        esac
    done
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


_confirm "Do you want to update?"
do_update="$confirmed"

_confirm "Do you want to install extra packages?"
do_install_pkgs="$confirmed"

do_install_rust=0
do_install_go=0
_confirm "Do you want to install language toolchains?"
if [ "$confirmed" = 1 ]; then
    _confirm "-> Install rust?"
    do_install_rust="$confirmed"

    _confirm "-> Install go?"
    do_install_go="$confirmed"
fi

_confirm "Do you want to install neovim?"
do_install_nvim="$confirmed"

_confirm "Do you want to update dotfiles?"
do_dotfiles="$confirmed"

_confirm "Do you want to customize desktop applications and settings?"
do_customize="$confirmed"

_confirm "Do you want to manage wordlists?"
do_wordlists="$confirmed"

_confirm "Do you want to clean apt packages?"
do_cleanup="$confirmed"


echo
did_change=0


if [ $do_update = 1 ]; then
    did_change=1
    _task "Updating system"
    sudo apt update -y && sudo apt upgrade -y
fi

if [ $do_install_pkgs = 1 ]; then
    did_change=1
    _task "Installing packages"
    sudo apt install -y git jq tree tmux ripgrep fzf bat ninja-build gettext cmake build-essential

    if [ -z "$(grep 'source <(fzf --zsh)' "$ZSHRC")" ]; then
        _task "Add fzf key bindings"
        echo -e "\n# fzf key bindings\nsource <(fzf --zsh)" >> "$ZSHRC"
    else
        _done "Already configured fzf keybindings"
    fi
fi

if [ $do_install_rust = 1 ]; then
    if command -v rustc &> /dev/null; then
        _done "Rust already installed"
        rustc --version
    else
        did_change=1
        _task "Execute rustup installer"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

        if [ -z "$(grep '$HOME/.cargo/env' "$ZSHRC")" ]; then
            _task "Add cargo env source to .zshrc"
            echo -e "\n. \"\$HOME/.cargo/env\"" >> "$ZSHRC"
        else
            _done "Already configured cargo in .zshrc"
        fi
    fi
fi

if [ $do_install_go = 1 ]; then
    if command -v go &> /dev/null; then
        _done "Golang already installed"
        go version
    else
        did_change=1
        _task "Removing previous go installation"
        sudo rm -rf /opt/go
        _task "Downloading latest golang release"
        GOLANG_LATEST="$(curl -fsSL 'https://go.dev/dl/?mode=json' | grep 'linux-amd64' | head -n1 | awk '{print $2}' | sed 's/"\(.*\)",/\1/')"
        curl -fsSL -o golang.tar.gz "https://go.dev/dl/$GOLANG_LATEST"
        _task "Installing golang"
        sudo tar -C /opt -xzf golang.tar.gz
        _task "Removing install files"
        rm golang.tar.gz

        if [ -z "$(grep 'export PATH=$PATH:/opt/go/bin' "$ZSHRC")" ]; then
            _task "Add golang to PATH"
            echo -e "\nexport PATH=\$PATH:/opt/go/bin" >> "$ZSHRC"
        else
            _done "Already configured golang in .zshrc"
        fi
    fi
fi

if [ $do_install_nvim = 1 ]; then
    if command -v nvim &> /dev/null; then
        _done "Already installed neovim"
    else
        did_change=1
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
fi

if [ $do_dotfiles = 1 ]; then
    did_change=1
    if [ -d ~/.config/nvim ]; then
        _task "Updating neovim config"
        git -C ~/.config/nvim pull
    else
        _task "Setting up neovim config"
        mkdir -p ~/.config
        git clone https://github.com/bwpge/nvim-config.git ~/.config/nvim
    fi
fi

if [ $do_customize = 1 ]; then
    did_change=1
    _task "Installing wallpapers"
    sudo apt install kali-wallpapers-all

    # set wallpaper
    MONITOR_NAME="$(xrandr --listmonitors | grep '^\s*[[:digit:]]' | awk '{print $4}')"
    XFCONF_PROP="/backdrop/screen0/monitor$MONITOR_NAME/workspace0/last-image"
    _task "Setting background image"
    xfconf-query -c xfce4-desktop -n -p "$XFCONF_PROP" -s "/usr/share/backgrounds/kali-16x9/kali-neon.png"

    _task "Applying xfconf settings"
    xfconf-query -c xfce4-panel -n -p /panels/panel-1/border-width -t int -s 1
    xfconf-query -c xfwm4 -n -p /general/mousewheel_rollup -t bool -s false
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
            sudo chmod 644 /usr/share/qtermwidget6/color-schemes/Kali-Custom.colorscheme
        fi

        _task "Updating qterminal config"
        sed -i 's/ApplicationTransparency=[[:digit:]]\+/ApplicationTransparency=0/' "$QTERM_CONF_FILE"
        sed -i 's/^colorScheme=.*$/colorScheme=Kali-Custom/' "$QTERM_CONF_FILE"
    fi
fi

if [ $do_wordlists = 1 ]; then
    did_change=1
    _task "Installing seclists"
    sudo apt install seclists

    ROCKYOU_FILE="/usr/share/wordlists/rockyou.txt"
    ROCKYOU_GZ="$ROCKYOU_FILE.gz"
    if [ ! -f "$ROCKYOU_FILE" ]; then
        _task "Extract rockyou.txt"
        sudo gunzip -k "$ROCKYOU_GZ"
    else
        _done "Already extracted rockyou.txt"
    fi
fi

if [ $do_cleanup = 1 ]; then
    did_change=1
    _task "Cleaning apt packages"
    sudo apt autoremove -y
    sudo apt clean -y
fi

# restart qterminal
if [ $did_change = 1 ]; then
    if [ ! -z "$(pgrep qterminal 2>/dev/null)" ]; then
        echo
        _confirm "Do you want to restart the terminal?"
        if [ $confirmed = 1 ]; then

            # countdown to restart
            seconds=5
            for ((i=seconds; i>0; i--)); do
                echo -ne "\r${ylw}Restarting the terminal in $i seconds...${rst} "
                sleep 1
            done
            echo

            _p="$(pgrep qterminal | tr '\n' ' ')"
            _w="$(pwd)"
            qterminal -w "$_w" &
            sleep 1
            kill "$_p"
        fi
    fi
fi
