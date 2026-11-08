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
alias dotfiles-sync="ansible-playbook /data/projects/dotfiles/playbooks/setup_user.yml --tags chezmoi"
alias dotfiles-sync-cli="sudo -v && ansible-playbook /data/projects/dotfiles/playbooks/setup_user.yml --tags chezmoi && ansible-playbook /data/projects/dotfiles/playbooks/packages.yml --tags cli"

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