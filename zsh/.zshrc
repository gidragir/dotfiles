export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'

# ── Colored man pages (less termcap) ─────────────────────────────────────────
export LESS_TERMCAP_md="$(tput bold 2> /dev/null; tput setaf 2 2> /dev/null)"
export LESS_TERMCAP_me="$(tput sgr0 2> /dev/null)"

# ── History Configuration ───────────────────────────────────────────────────
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=50000
SAVEHIST=50000

setopt HIST_IGNORE_ALL_DUPS    # Don't record duplicate commands
setopt HIST_IGNORE_SPACE       # Don't record commands starting with space
setopt HIST_SAVE_NO_DUPS       # Don't write duplicates to history file
setopt HIST_REDUCE_BLANKS      # Remove extra blanks from history items
setopt SHARE_HISTORY           # Share history between all active shells instantly

export HISTORY_IGNORE="(\&|[bf]g|c|clear|history|exit|q|pwd|* --help)"

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

# ── CachyOS / Zsh Plugins ────────────────────────────────────────────────────
# Fish-like autosuggestions
if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  bindkey '^F' autosuggest-accept
fi

# Syntax highlighting (must be loaded before history-substring-search)
if [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# History substring search
if [[ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
fi

# Pkgfile "command not found" handler (Arch / CachyOS)
if [[ -f /usr/share/doc/pkgfile/command-not-found.zsh ]]; then
  source /usr/share/doc/pkgfile/command-not-found.zsh
fi

# ── External Bindings and Aliases ────────────────────────────────────────────
source "$HOME/.zsh/binds/main.zsh"
source "$HOME/.zsh/alias/core.zsh"
source "$HOME/.zsh/alias/git.zsh"
source "$HOME/.zsh/alias/ansible.zsh"
source "$HOME/.zsh/alias/k8s.zsh"

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
