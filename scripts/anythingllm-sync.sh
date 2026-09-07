#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="${DOTFILES_ROOT}/anythingllm/.config/anythingllm-desktop/storage/plugins"

if ! command -v bun &>/dev/null; then
    export PATH="$HOME/.local/share/mise/installs/bun/latest/bin:$PATH"
fi

if [ -f "${PLUGINS_DIR}/sync-prompts.ts" ]; then
    echo "🔄 Synchronizing AnythingLLM system settings, allowed folders, and workspace prompts..."
    cd "${PLUGINS_DIR}"
    bun run sync-prompts.ts
else
    echo "❌ sync-prompts.ts not found at ${PLUGINS_DIR}"
    exit 1
fi
