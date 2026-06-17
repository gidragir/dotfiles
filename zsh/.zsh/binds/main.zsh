# Для режима вставки vi
bindkey -M viins '^[^.' insert-last-word
bindkey -M viins '\e.' insert-last-word

# Для командного режима vi (опционально, по нажатию "." в обычном режиме)
bindkey -M vicmd '.' insert-last-word