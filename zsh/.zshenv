# ── XDG Base Directory Specification ──────────────────────────────────────────
# Set environment variables for all shells (interactive & non-interactive / scripts)
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# ── PATH Configuration ────────────────────────────────────────────────────────
export SHELL="/usr/bin/zsh"
export PNPM_HOME="/data/projects/.pnpm-store"

typeset -U path
path=(
    "$HOME/.local/bin"
    "$PNPM_HOME"
    "$HOME/projects/dotfiles/zsh/.zsh/scripts"
    $path
)

# ── Environment Variables & Tool Caches ───────────────────────────────────────
export SCCACHE_DIR="/data/projects/.sccache"
export UV_CACHE_DIR="/data/projects/.uv-cache"
export KUBECONFIG="$HOME/.kube/config"
export FZF_BASE="/usr/share/fzf"
export EDITOR="nvim"
export VISUAL="nvim"

# ── Local Secrets & Environment (Git-Ignored) ──────────────────────────────────
[[ -f "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"
[[ -f "${0:A:h}/.zshenv.local" ]] && source "${0:A:h}/.zshenv.local"
