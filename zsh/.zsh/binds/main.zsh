# ── ИСПРАВЛЕНИЕ ДЛЯ VI-MODE И ЕГО АДАПТАЦИЯ ───────────────────────────────────

# Возврат Alt + . (вставка последнего аргумента из истории) в режиме вставки
bindkey -M viins '^[^.' insert-last-word
bindkey -M viins '\e.' insert-last-word

# Эмуляция Emacs-навигации в режиме вставки (чтобы не нажимать Esc ради начала/конца строки)
bindkey -M viins '^A' beginning-of-line      # Ctrl + A — в начало строки
bindkey -M viins '^E' end-of-line            # Ctrl + E — в конец строки
bindkey -M viins '^F' forward-char           # Ctrl + F — на один символ вперед
bindkey -M viins '^B' backward-char          # Ctrl + B — на один символ назад

# Корректное удаление в режиме вставки
bindkey -M viins '^W' backward-kill-word     # Ctrl + W — удалить слово назад (по пробелам)
bindkey -M viins '^U' backward-kill-line     # Ctrl + U — удалить всё от курсора до начала строки
bindkey -M viins '^K' kill-line              # Ctrl + K — удалить всё от курсора до конца строки
bindkey -M viins '^H' backward-delete-char   # Backspace (исправление возможных багов терминала)
bindkey -M viins '^?' backward-delete-char

# Быстрый Undo (отмена) в режиме вставки
bindkey -M viins '^_' undo                   # Ctrl + / или Ctrl + Shift + -

# Буферизация строки (Alt + Q)
# Очищает текущую недописанную строку, позволяя выполнить что-то другое (например, ls).
# После выполнения чужой команды недописанная строка автоматически возвращается на место.
bindkey -M viins '^Qq' push-line
bindkey -M viins '\eq' push-line
bindkey -M vicmd 'q' push-line

# ── ПОЛЕЗНЫЕ ZLE-ВИДЖЕТЫ ──────────────────────────────────────────────────────

# 1. Добавление/удаление sudo в начало строки по Alt+S
sudo-command-line() {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="${LBUFFER#sudo }"
    else
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line
bindkey -M viins '\es' sudo-command-line
bindkey -M vicmd '\es' sudo-command-line

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

# Быстрый просмотр текущей директории по Ctrl+L (с сохранением введенной команды)
function _ls_current_dir() {
    echo ""
    eza -la --icons 2>/dev/null || ls -lA
    zle reset-prompt
}
zle -N _ls_current_dir
bindkey '^L' _ls_current_dir

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
# Ускоряем отклик клавиши Escape (10ms вместо стандартных 400ms)
export KEYTIMEOUT=1

# Динамическая смена формы курсора (Beam '|' в Insert, Block '█' в Normal mode) + обновление промпта Starship
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
    echo -ne '\e[6 q' # Сброс в beam при выполнении команды
}
zle -N zle-line-finish