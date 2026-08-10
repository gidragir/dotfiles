# ── VI-MODE FIXES & ADAPTATIONS ───────────────────────────────────────────────

# Restore Alt + . (insert last history argument) in insert mode
bindkey -M viins '^[^.' insert-last-word
bindkey -M viins '\e.' insert-last-word

# Emulate Emacs navigation in insert mode (avoiding Esc for start/end of line)
bindkey -M viins '^A' beginning-of-line      # Ctrl + A — beginning of line
bindkey -M viins '^E' end-of-line            # Ctrl + E — end of line
bindkey -M viins '^F' forward-char           # Ctrl + F — forward one character
bindkey -M viins '^B' backward-char          # Ctrl + B — backward one character

# Correct deletion and special keys in insert mode (viins)
bindkey -M viins '^[[3~' delete-char             # Delete (character under cursor)
bindkey -M viins '^[3;5~' delete-char
bindkey -M viins '^H' backward-delete-char       # Backspace
bindkey -M viins '^?' backward-delete-char       # Backspace
bindkey -M viins '^[[H' beginning-of-line       # Home
bindkey -M viins '^[[F' end-of-line             # End
bindkey -M viins '^[[1~' beginning-of-line
bindkey -M viins '^[[4~' end-of-line

# Fast Undo in insert mode
bindkey -M viins '^_' undo                   # Ctrl + / or Ctrl + Shift + -

# Line buffering (Alt + Q)
# Clears current unfinished line, allowing you to run another command (e.g. ls).
# The unfinished line is automatically restored after the command executes.
bindkey -M viins '^Qq' push-line
bindkey -M viins '\eq' push-line
bindkey -M vicmd 'q' push-line

# ── USEFUL ZLE WIDGETS ────────────────────────────────────────────────────────

# 1. Toggle sudo at start of line via Alt+S (EN: \es \eS, RU: \eы \eЫ)
sudo-command-line() {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="${LBUFFER#sudo }"
    else
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line
for key in '\es' '\eS' '\eы' '\eЫ'; do
    bindkey -M viins "$key" sudo-command-line 2>/dev/null
    bindkey -M vicmd "$key" sudo-command-line 2>/dev/null
done

spf() {
    os=$(uname -s)

    # Linux
    if [[ "$os" == "Linux" ]]; then
        export SPF_LAST_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/superfile/lastdir"
    fi

    # macOS
    if [[ "$os" == "Darwin" ]]; then
        export SPF_LAST_DIR="$HOME/Library/Application Support/superfile/lastdir"
    fi

    command spf "$@"

    [ ! -f "$SPF_LAST_DIR" ] || {
        . "$SPF_LAST_DIR"
        rm -f -- "$SPF_LAST_DIR" > /dev/null
    }
}

switch-language-buffer() {
    local ru="ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮйцукенгшщзхъфывапролджэячсмитьбю"
    local en='QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>qwertyuiop[]asdfghjkl;'\''zxcvbnm,.'
    BUFFER=$(sed "y/$ru$en/$en$ru/" <<< "$BUFFER")
    CURSOR=$#BUFFER
}
zle -N switch-language-buffer
bindkey '^X^L' switch-language-buffer

bindkey ' ' magic-space

# Interactive file & directory selection via fzf-file-widget (ESC to cancel)
# Works with Ctrl+K, Ctrl+T, Ctrl+X Ctrl+D, F2, and Alt+R / Alt+D (EN & RU layouts)
if type fzf-file-widget >/dev/null 2>&1; then
    for key in '^K' '^T' '^X^D' '^[[12~' '^[OQ' '\er' '\eR' '\eк' '\eК' '\ed' '\eD' '\eв' '\eВ' '\el' '\eL' '\eд' '\eД'; do
        bindkey "$key" fzf-file-widget 2>/dev/null
        bindkey -M viins "$key" fzf-file-widget 2>/dev/null
        bindkey -M vicmd "$key" fzf-file-widget 2>/dev/null
    done
fi

# ── HISTORY SUBSTRING SEARCH BINDINGS ─────────────────────────────────────────
if type history-substring-search-up >/dev/null 2>&1; then
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    bindkey '^[OA' history-substring-search-up
    bindkey '^[OB' history-substring-search-down
    bindkey -M vicmd 'k' history-substring-search-up
    bindkey -M vicmd 'j' history-substring-search-down
fi

# ── VI-MODE CURSOR SHAPE & STARSHIP PROMPT INDICATOR ──────────────────────────
# Fast Escape response (10ms instead of default 400ms)
export KEYTIMEOUT=1

# Dynamic cursor shape (Beam '|' in Insert, Block '█' in Normal mode) + Starship prompt refresh
function zle-keymap-select {
    if [[ ${KEYMAP} == vicmd ]] || [[ $1 == 'block' ]]; then
        echo -ne '\e[2 q' # Block cursor
    elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ $1 == 'beam' ]]; then
        echo -ne '\e[6 q' # Beam cursor
    fi
    zle reset-prompt
}
zle -N zle-keymap-select

function zle-line-init {
    zle-keymap-select 'beam'
}
zle -N zle-line-init

function zle-line-finish {
    echo -ne '\e[6 q' # Reset to beam cursor upon command execution
}
zle -N zle-line-finish