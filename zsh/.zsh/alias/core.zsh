alias ll='eza -l --icons'
alias tf='terraform'

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