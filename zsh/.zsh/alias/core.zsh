# ── Core & Tool Shortcuts ───────────────────────────────────────────────────
alias ll='eza -l --icons'
alias la='eza -la --icons'
alias tree='eza --tree --icons'
alias tf='terraform'
alias c='clear'

# ── Build & Compilation Speedups ──────────────────────────────────────────────
alias make="make -j\$(nproc)"
alias ninja="ninja -j\$(nproc)"
alias n="ninja"

# ── Arch / CachyOS System & Package Management ──────────────────────────────
alias update="sudo pacman -Syu"
alias rmpkg="sudo pacman -Rsn"
alias cleanch="sudo pacman -Scc"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias cleanup="sudo pacman -Rsn \$(pacman -Qtdq 2>/dev/null) 2>/dev/null || echo 'No orphaned packages to clean'"
alias jctl="journalctl -p 3 -xb"
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias apt="man pacman"
alias apt-get="man pacman"

# ── Utilities ─────────────────────────────────────────────────────────────────
alias please="sudo"
alias tb="nc termbin.com 9999"
alias dotfiles-sync="ansible-playbook /data/projects/dotfiles/playbooks/setup_user.yml --tags stow"

# Extract archives easily (oh-my-zsh extract plugin functionality)
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"    ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"     ;;
            *.tar)       tar xvf "$1"     ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"      ;;
            *.Z)         uncompress "$1" ;;
            *.7z)        7z x "$1"       ;;
            *.tar.xz)    tar xJf "$1"     ;;
            *.tar.zst)   tar --zstd -xvf "$1" ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}
alias x=extract

# ── Sandbox & Containers ──────────────────────────────────────────────────────
# Sandbox: test Wayland GUI tools without polluting main session
alias niri-sandbox='WAYLAND_DISPLAY=wayland-sandbox niri --session'

# Distrobox: quickly spin up a throwaway container for CLI tool testing
sandbox-box() {
    local image="${1:-archlinux}"
    distrobox create --name sandbox --image "$image" --yes 2>/dev/null || true
    distrobox enter sandbox
}
alias sandbox-rm='distrobox rm sandbox --yes'

spf_tv_search() {
    local target
    target=$(tv files)
    
    if [[ -n "$target" ]]; then
        if [[ -d "$target" ]]; then
            spf "$target"
        else
            spf "$(dirname "$target")"
        fi
    fi
}
alias spft=spf_tv_search