#!/usr/bin/env nu
use state.nu [expand-target-path]

let is_dry = (($env.YGG_DRY_RUN? | default "false") == "true")
let is_sandbox = (($env.YGG_SANDBOX? | default "") != "")
let scopes = (($env.YGG_SCOPES? | default "[]") | from json)

if not $is_dry {
    # 1. Ensure Rclone cache directory exists (~/.cache/rclone)
    mkdir (expand-target-path "~/.cache/rclone")

    # 2. Ensure Neovim default MIME associations in ~/.config/mimeapps.list
    let mime_path = (expand-target-path "~/.config/mimeapps.list")
    mkdir ($mime_path | path dirname)
    let header = "[Default Applications]"
    let entries = [
        "text/markdown=nvim.desktop",
        "text/plain=nvim.desktop",
        "text/x-markdown=nvim.desktop"
    ]
    let existing = if ($mime_path | path exists) { open --raw $mime_path } else { "" }
    mut updated = $existing
    if not ($updated | str contains $header) {
        $updated = (if ($updated == "") { $header + "\n" } else { $updated + "\n" + $header + "\n" })
    }
    for entry in $entries {
        if not ($updated | str contains $entry) {
            $updated = $updated + $entry + "\n"
        }
    }
    $updated | save -f $mime_path

    # 3. Live-host only actions (skipped in --sandbox)
    if not $is_sandbox {
        if ("/data/projects" | path exists) {
            mkdir "/data/projects/.cargo-cache/registry" "/data/projects/.cargo-cache/git"
            mkdir ("~/.cargo" | path expand)
            ^ln -sfn "/data/projects/.cargo-cache/registry" ("~/.cargo/registry" | path expand)
            ^ln -sfn "/data/projects/.cargo-cache/git" ("~/.cargo/git" | path expand)
        }

        ^systemctl --user daemon-reload | complete | ignore
        if (("~/.config/rclone/rclone.conf" | path expand) | path exists) {
            ^systemctl --user enable --now rclone-obsidian-sync.timer | complete | ignore
        }
        if ("pc" in $scopes) {
            ^systemctl --user enable --now openrgb.service openrgb-profile.service | complete | ignore
        }
    }
}
