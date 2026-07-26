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