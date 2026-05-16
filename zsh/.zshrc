# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# ── DEV ENVIRONMENT (added by setup_user.sh) ─────────────────────────────────

# XDG base dirs (explicit, prevents apps from writing to ~/.)
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# PATH
export PATH="$HOME/.local/bin:$PATH"

# ── Rust / Cargo ─────────────────────────────────────────────────────────────
# Toolchain (rustup, cargo binary) stays in ~/.cargo (default CARGO_HOME)
# Registry/git caches are redirected to NVMe 1 via ~/.cargo/config.toml [env]
export SCCACHE_DIR="/data/projects/.sccache"

# ── Node / pnpm ──────────────────────────────────────────────────────────────
# PNPM_HOME: where pnpm stores its global bins and content-addressable store
export PNPM_HOME="$HOME/.local/share/pnpm-store"
export PATH="$PNPM_HOME:$PATH"

# ── Python / uv ──────────────────────────────────────────────────────────────
# uv follows XDG automatically:
#   cache  → ~/.cache/uv
#   data   → ~/.local/share/uv
# Uncomment below to redirect uv cache to NVMe 1 if it grows large:
# export UV_CACHE_DIR="/data/projects/.uv-cache"

# ── Editors ──────────────────────────────────────────────────────────────────
export EDITOR='nvim'
export VISUAL='nvim'

# ── Vi-mode (Neovim muscle memory in terminal) ────────────────────────────────
bindkey -v

# Open command buffer in LazyVim with 'v' in Normal mode (after Esc)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# ── Sandbox: test Wayland GUI tools without polluting main session ─────────────
alias niri-sandbox='WAYLAND_DISPLAY=wayland-sandbox niri --session'

# Distrobox: quickly spin up a throwaway container for CLI tool testing
sandbox-box() {
    local image="${1:-archlinux}"
    distrobox create --name sandbox --image "$image" --yes 2>/dev/null || true
    distrobox enter sandbox
}
alias sandbox-rm='distrobox rm sandbox --yes'

# ── Tool initializations (at end to avoid overriding above) ──────────────────
eval "$(mise activate zsh)"
eval "$(zoxide init zsh)"

# Starship prompt (must be last)
eval "$(starship init zsh)"

# ─────────────────────────────────────────────────────────────────────────────

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
#[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
