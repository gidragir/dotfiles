# Subsystem: Shell & Modal Terminal UX (L1)

## Architecture & Interaction Patterns
- Terminal Emulator: Ghostty with native Wayland support and Catppuccin Mocha theme.
- Shell: Zsh configured via `zsh/.zshrc`, `zsh/.zshenv`, `zsh/.zprofile`.
- Modal Vi-Mode: `bindkey -v` enabled with cursor shape indicators (Beam `|` for Insert, Block `█` for Normal). Quick escape with `KEYTIMEOUT=1`.
- Neovim Command Edit: Press `v` in Normal mode to open current command buffer in LazyVim.
- Interactive Completions: `fzf-tab` with rich preview popups (`eza` for directories, `bat` for text, `ps` for processes).
- Fast Navigation: `zoxide` (`cd`), Television `tv`, Superfile `spf` (auto-cd on exit).
- Git Aliases: `gcai` for interactive staging and committing with `opencommit`.

## Script Organization Rule
- All custom scripts and window helpers MUST reside in `zsh/.zsh/scripts/`.
- The directory `~/.zsh/scripts` is automatically prepended to `$PATH` via `.zshenv`.
- Key scripts present:
  - `khoj-ctl`: CLI management for Khoj, healthchecks, indexing, search.
  - `khoj-tags`: High-speed ripgrep search for Obsidian tags and frontmatter.
  - `noctalia-dmenu`: Wrapper for Noctalia Dmenu plugin CLI.
  - Window helpers for Niri.

## Recent Updates
- Added `gcai` alias in `zsh/.zsh/alias/git.zsh` for interactive staging and committing with `opencommit`.
- Updated `.zshenv` to include `$PNPM_HOME/bin` in the `$PATH`.
- Removed the symbolic link `noctalia-dmenu` and replaced it with a script that checks for the executable and runs it.
- Updated `anything-ctl` script to include new paths for AI stack directories and corrected the `cmd_sync` function.

## Hotkeys
- `v`: Open current command buffer in LazyVim in Normal mode.
- `KEYTIMEOUT=1`: Quick escape from Vi-Mode.

# Recent Git Changes:

--- Diff for zsh/.zsh/alias/git.zsh ---
diff --git a/zsh/.zsh/alias/git.zsh b/zsh/.zsh/alias/git.zsh
index 3a09b37..c52843b 100644
--- a/zsh/.zsh/alias/git.zsh
+++ b/zsh/.zsh/alias/git.zsh
@@ -4,4 +4,6 @@ git-all() {
 
 git-pack() {
     git add . && git commit -m "${1:-Update}" && git push
-}
\ No newline at end of file
+}
+
+alias gcai="git add -p && opencommit"
\ No newline at end of file
--- Diff for zsh/.zsh/scripts/anything-ctl ---
diff --git a/zsh/.zsh/scripts/anything-ctl b/zsh/.zsh/scripts/anything-ctl
index 18e5b3c..1b66abe 100755
--- a/zsh/.zsh/scripts/anything-ctl
+++ b/zsh/.zsh/scripts/anything-ctl
@@ -24,7 +24,10 @@ DB_PATH = Path.home() / ".config/anythingllm-desktop/storage/anythingllm.db"
 OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
 HEADROOM_URL = os.environ.get("HEADROOM_URL", "http://127.0.0.1:8787")
 DOTFILES_DIR = Path("/data/projects/dotfiles")
-PLUGINS_DIR = DOTFILES_DIR / "anythingllm/.config/anythingllm-desktop/storage/plugins"
+AI_STACK_DIR = Path("/data/projects/local-ai-stack")
+MCP_DIR = AI_STACK_DIR / "mcp/host-cli"
+SYNC_DIR = AI_STACK_DIR / "stacks/anythingllm"
+PLUGINS_DIR = MCP_DIR
 
 # Anomaly detection patterns
 CJK_REGEX = re.compile(r"[\u4e00-\u9fff\uac00-\ud7af\u3040-\u30ff]")
@@ -992,7 +995,7 @@ def cmd_test_search(args):
     directory = args.dir or "/data/obsidian"
     print_header(f"Testing bash-mcp-server search_files: query='{query}' dir='{directory}'")
 
-    mcp_script = PLUGINS_DIR / "bash-mcp-server.mjs"
+    mcp_script = MCP_DIR / "dist/bash-mcp-server.mjs"
     if not mcp_script.exists():
         print_error(f"MCP script not found at {mcp_script}")
         return
@@ -1074,13 +1077,13 @@ def cmd_test_prompt(args):
 
 def cmd_sync(args):
     print_header("Synchronizing AnythingLLM Workspaces & Prompts")
-    sync_script = PLUGINS_DIR / "sync-prompts.ts"
+    sync_script = SYNC_DIR / "sync-prompts.ts"
     if not sync_script.exists()
--- Diff for zsh/.zsh/scripts/noctalia-dmenu ---
diff --git a/zsh/.zsh/scripts/noctalia-dmenu b/zsh/.zsh/scripts/noctalia-dmenu
deleted file mode 120000
index 9b60839..0000000
--- a/zsh/.zsh/scripts/noctalia-dmenu
+++ /dev/null
@@ -1 +0,0 @@
-/home/gidragir/.config/noctalia/plugins/dmenu/noctalia-dmenu
\ No newline at end of file
diff --git a/zsh/.zsh/scripts/noctalia-dmenu b/zsh/.zsh/scripts/noctalia-dmenu
new file mode 100755
index 0000000..17d336f
--- /dev/null
+++ b/zsh/.zsh/scripts/noctalia-dmenu
@@ -0,0 +1,14 @@
+#!/usr/bin/env bash
+# =============================================================================
+# Wrapper for Noctalia Dmenu plugin CLI
+# =============================================================================
+set -euo pipefail
+
+TARGET_BIN="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins/dmenu/noctalia-dmenu"
+
+if [[ ! -x "$TARGET_BIN" ]]; then
+    echo "Error: noctalia-dmenu plugin executable not found at: $TARGET_BIN" >&2
+    exit 1
+fi
+
+exec "$TARGET_BIN" "$@"
--- Diff for zsh/.zshenv ---
diff --git a/zsh/.zshenv b/zsh/.zshenv
index 0c78734..08b9afd 100644
--- a/zsh/.zshenv
+++ b/zsh/.zshenv
@@ -14,6 +14,7 @@ typeset -U path
 path=(
     "$HOME/.local/bin"
     "$PNPM_HOME"
+    "$PNPM_HOME/bin"
     "$HOME/.zsh/scripts"
     "$HOME/projects/dotfiles/zsh/.zsh/scripts"
     $path
