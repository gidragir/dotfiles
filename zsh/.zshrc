export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# Disable Powerlevel10k theme loaded by cachyos-config so Starship controls prompt
precmd_functions=(${precmd_functions:#_p9k*})
precmd_functions=(${precmd_functions:#_p10k*})
chpwd_functions=(${chpwd_functions:#_p9k*})
chpwd_functions=(${chpwd_functions:#_p10k*})
unset PROMPT RPROMPT PS1

# ── Vi-mode (Neovim muscle memory in terminal) ────────────────────────────────
bindkey -v

# Open command buffer in LazyVim with 'v' in Normal mode (after Esc)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# ── Interactive Tool Initializations ──────────────────────────────────────────
eval "$(mise activate zsh)"
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

# ── External Bindings and Aliases ────────────────────────────────────────────
source "$HOME/.zsh/binds/main.zsh"
source "$HOME/.zsh/alias/core.zsh"
source "$HOME/.zsh/alias/git.zsh"
source "$HOME/.zsh/alias/ansible.zsh"
source "$HOME/.zsh/alias/k8s.zsh"

# ── Custom Functions & Helpers ────────────────────────────────────────────────
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

# ── Completions ───────────────────────────────────────────────────────────────
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.m+1) ]]; then
  compinit
else
  compinit -C
fi

if (( $+commands[carapace] )); then
  source <(carapace _carapace)
fi

# ── ZLE & Keybindings ─────────────────────────────────────────────────────────
switch-language-buffer() {
    local ru="ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮйцукенгшщзхъфывапролджэячсмитьбю"
    local en='QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>qwertyuiop[]asdfghjkl;'\''zxcvbnm,.'
    BUFFER=$(sed "y/$ru$en/$en$ru/" <<< "$BUFFER")
    CURSOR=$#BUFFER
}
zle -N switch-language-buffer
bindkey '^X^L' switch-language-buffer

bindkey ' ' magic-space

function _ls_current_dir() {
    echo ""                      # Перевод строки, чтобы ls выводился с новой строчки
    ls -lA                       # Команда ls (можно заменить на eza/exa/lsd, если используете их)
    zle reset-prompt             # Перерисовывает текущую строку ввода (ваша напечатанная cd ~/ останется наместе)
}
zle -N _ls_current_dir
bindkey '^L' _ls_current_dir