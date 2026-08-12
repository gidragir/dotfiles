export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'

# ── Colored man pages (less termcap) ─────────────────────────────────────────
export LESS_TERMCAP_md="$(tput bold 2> /dev/null; tput setaf 2 2> /dev/null)"
export LESS_TERMCAP_me="$(tput sgr0 2> /dev/null)"

# ── History Configuration ───────────────────────────────────────────────────
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"
HISTSIZE=50000
SAVEHIST=50000

setopt HIST_IGNORE_ALL_DUPS    # Don't record duplicate commands
setopt HIST_IGNORE_SPACE       # Don't record commands starting with space
setopt HIST_SAVE_NO_DUPS       # Don't write duplicates to history file
setopt HIST_REDUCE_BLANKS      # Remove extra blanks from history items
setopt SHARE_HISTORY           # Share history between all active shells instantly
setopt EXTENDED_HISTORY        # Save execution timestamps to history file

export HISTORY_IGNORE="(\&|[bf]g|c|clear|history|exit|q|pwd|* --help)"

# Disable terminal flow control (XON/XOFF) so Ctrl+Q and Ctrl+S reach Zsh
stty -ixon 2>/dev/null

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

# ── Completions & Colors ───────────────────────────────────────────────────────
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.m+1) ]]; then
  compinit
else
  compinit -C
fi

# Highlight completion menu items with LS_COLORS & silence raw stderr messages
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select
zstyle ':completion:*:warnings' format ''
zstyle ':completion:*:errors' format ''
zstyle ':completion:*:messages' format ''

if (( $+commands[carapace] )); then
  source <(carapace _carapace)
fi



# ── FZF Keybindings & Interactive File Picker ─────────────────────────────────
if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
  source /usr/share/fzf/key-bindings.zsh
  export FZF_CTRL_T_COMMAND="fd --hidden --follow --exclude .git 2>/dev/null || find . -mindepth 1"
  export FZF_CTRL_T_OPTS="--height 40% --layout=reverse --border --prompt='📁 Files > ' --preview 'eza --tree --level=2 --icons --color=always {} 2>/dev/null || bat --color=always --line-range :40 {} 2>/dev/null || cat {}'"
fi

# ── Zsh Plugin Manager: Sheldon ──────────────────────────────────────────────
if (( $+commands[sheldon] )); then
  eval "$(sheldon source)"
fi

# fzf-tab options & live previews
if (( $+functions[fzf-tab-complete] )); then
  # Compact inline menu (prevents full-screen takeover and terminal output clearing)
  zstyle ':fzf-tab:*' fzf-flags '--height=40%' '--layout=reverse' '--border'
  zstyle ':fzf-tab:*' show-system-error false

  # Rich Live Previews for fzf-tab (safe execution with error suppression)
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath 2>/dev/null || ls -1 --color=always $realpath 2>/dev/null'
  zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word 2>/dev/null'
  zstyle ':fzf-tab:complete:kill:*' fzf-preview 'ps -p $word -o pid,user,%cpu,%mem,cmd 2>/dev/null'
  zstyle ':fzf-tab:complete:(export|unset):*' fzf-preview 'printenv $word 2>/dev/null'
  zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git diff --color=always $word 2>/dev/null'

  # Fix for screen clearing/shifting bug caused by leaking stderr & clear autosuggestions before completion
  function _fzf_tab_complete_silent() {
    if (( $+functions[_zsh_autosuggest_clear] )); then
      _zsh_autosuggest_clear
    fi
    fzf-tab-complete "$@" 2>/dev/null
  }
  zle -N _fzf_tab_complete_silent
  bindkey '^I' _fzf_tab_complete_silent
  # Continuous trigger for deep path completion (press '/' or Tab to enter directories)
  zstyle ':fzf-tab:*' continuous-trigger '/'
fi

# Zsh Autosuggestions Strategy
if (( $+functions[_zsh_autosuggest_bind_widgets] )); then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
  ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(_fzf_tab_complete_silent)

  if (( $+commands[atuin] )); then
    _zsh_autosuggest_strategy_atuin() {
      [[ -z "$2" ]] && return
      typeset -g "$1"="$(atuin search --cmd-only --limit 1 --search-mode prefix -- "$2" 2>/dev/null)"
    }
    ZSH_AUTOSUGGEST_STRATEGY=(atuin history completion)
  else
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  fi
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

# Television Smart Autocomplete (tv) - takes precedence for Ctrl+T
if (( $+commands[tv] )); then
  eval "$(tv init zsh)"
fi

# Smart Shell History (Atuin) - loaded after tv so Atuin retains Ctrl+R
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh)"
fi

source "$HOME/.zsh/alias/core.zsh"
source "$HOME/.zsh/alias/cooler.zsh"
source "$HOME/.zsh/alias/git.zsh"
source "$HOME/.zsh/alias/ansible.zsh"
source "$HOME/.zsh/alias/k8s.zsh"
