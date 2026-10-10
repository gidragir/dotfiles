fzf_theme_opts="\
--color=bg+:#414559
--color=bg:#303446
--color=spinner:#babbf1
--color=hl:#e78284
--color=fg:#c6d0f5
--color=header:#e78284
--color=info:#babbf1
--color=pointer:#babbf1
--color=marker:#a5adce
--color=fg+:#c6d0f5
--color=prompt:#babbf1
--color=hl+:#e78284
--color=selected-bg:#51576d
--color=border:#626880
--color=label:#c6d0f5"

export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS
}$fzf_theme_opts"
