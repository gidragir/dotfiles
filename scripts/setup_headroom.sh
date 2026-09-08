#!/usr/bin/env bash
# =============================================================================
# Script   : setup_headroom.sh
# Purpose  : Automated idempotent setup of Headroom (proxy, systemd user service,
#            MCP plugins for Antigravity and AnythingLLM, and zsh environment).
# Usage    : bash scripts/setup_headroom.sh
# =============================================================================

set -euo pipefail

error_handler() {
    local exit_code="$1"
    local line_no="$2"
    echo -e "\n\033[0;31m[ERROR] Failed at line ${line_no} with exit code ${exit_code}.\033[0m" >&2
}
trap 'error_handler $? $LINENO' ERR

# Prevent running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "\033[0;31m[ERROR] Do not run this script as root / sudo!\033[0m" >&2
    exit 1
fi

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

echo -e "\033[0;34m[1/6] Ensuring uv and Python environment are ready...\033[0m"
if ! command -v uv &>/dev/null; then
    if command -v mise &>/dev/null; then
        echo "Installing uv via mise..."
        mise install uv
    else
        echo -e "\033[0;31m[ERROR] 'uv' package manager not found. Please install uv or mise first.\033[0m" >&2
        exit 1
    fi
fi

echo -e "\033[0;34m[2/6] Installing/Updating Headroom CLI via uv tool...\033[0m"
# Install with proxy, code (tree-sitter), and mcp extras (omits 3.5GB heavy torch/cuda weights)
if uv tool list 2>/dev/null | grep -q "headroom-ai"; then
    echo "Headroom is already installed. Checking for updates..."
    uv tool upgrade headroom-ai || true
else
    echo "Installing headroom-ai[proxy,code,mcp] into isolated uv environment..."
    uv tool install "headroom-ai[proxy,code,mcp]"
fi

echo -e "\033[0;34m[3/6] Configuring Antigravity MCP Plugin and Global Config...\033[0m"
AGENTS_PLUGIN_DIR="${DOTFILES_ROOT}/.agents/plugins/headroom"
mkdir -p "${AGENTS_PLUGIN_DIR}"

cat > "${AGENTS_PLUGIN_DIR}/plugin.json" << 'EOF'
{
  "name": "headroom",
  "description": "Context optimization and token compression via Headroom CCR and proxy"
}
EOF

cat > "${AGENTS_PLUGIN_DIR}/mcp_config.json" << 'EOF'
{
  "mcpServers": {
    "headroom": {
      "command": "/home/gidragir/.local/bin/headroom",
      "args": [
        "mcp",
        "serve"
      ],
      "env": {
        "PATH": "/home/gidragir/.local/bin:/usr/local/bin:/usr/bin",
        "HEADROOM_PROXY_URL": "http://127.0.0.1:8787"
      }
    }
  }
}
EOF

# Register in global Antigravity MCP config (~/.gemini/config/mcp_config.json)
python3 -c '
import json, os
config_path = os.path.expanduser("~/.gemini/config/mcp_config.json")
os.makedirs(os.path.dirname(config_path), exist_ok=True)
try:
    with open(config_path, "r") as f:
        data = json.load(f)
except Exception:
    data = {"mcpServers": {}}

data.setdefault("mcpServers", {})
data["mcpServers"]["headroom"] = {
    "command": os.path.expanduser("~/.local/bin/headroom"),
    "args": ["mcp", "serve"],
    "env": {
        "PATH": os.path.expanduser("~/.local/bin") + ":/usr/local/bin:/usr/bin",
        "HEADROOM_PROXY_URL": "http://127.0.0.1:8787"
    }
}

with open(config_path, "w") as f:
    json.dump(data, f, indent=2)
'

echo -e "\033[0;34m[4/6] Applying Dotfiles (Stow)... \033[0m"
cd "${DOTFILES_ROOT}"
stow -R -t "${HOME}" zsh anythingllm

echo -e "\033[0;34m[5/6] Configuring Headroom systemd user service...\033[0m"
PROTECT_TOOLS="search_files,read_file,write_file,host-cli-search_files,host-cli-read_file,host-cli-write_file,execute_command"
if systemctl --user is-active --quiet headroom-default.service 2>/dev/null; then
    echo "Headroom systemd user service is already active. Ensuring protection flags..."
    python3 -c '
import json, os
manifest_path = os.path.expanduser("~/.headroom/deploy/default/manifest.json")
if os.path.exists(manifest_path):
    with open(manifest_path, "r") as f:
        data = json.load(f)
    protect = "search_files,read_file,write_file,host-cli-search_files,host-cli-read_file,host-cli-write_file,execute_command"
    data.setdefault("base_env", {})
    data["base_env"]["HEADROOM_PROTECT_TOOL_RESULTS"] = protect
    data["base_env"]["HEADROOM_NO_CCR"] = "1"
    args = data.get("proxy_args", [])
    if "--protect-tool-results" not in args:
        args.extend(["--protect-tool-results", protect])
    if "--no-ccr" not in args:
        args.append("--no-ccr")
    data["proxy_args"] = args
    with open(manifest_path, "w") as f:
        json.dump(data, f, indent=2)
'
else
    echo "Deploying persistent Headroom user service..."
    headroom install apply \
        --scope user \
        --preset persistent-service \
        --backend anyllm \
        --anyllm-provider openai \
        --env OPENAI_TARGET_API_URL=http://127.0.0.1:11434/v1 \
        --env HEADROOM_PROTECT_TOOL_RESULTS="${PROTECT_TOOLS}" \
        --env HEADROOM_NO_CCR=1 \
        --code-aware \
        --port 8787
fi
systemctl --user restart headroom-default.service

echo -e "\033[0;34m[6/6] Verifying Headroom health & routing...\033[0m"
export ANTHROPIC_BASE_URL="http://127.0.0.1:8787"
export OPENAI_BASE_URL="http://127.0.0.1:8787/v1"

headroom doctor || true

echo -e "\n\033[0;32m✓ Headroom setup completed successfully!\033[0m"
echo -e "• Proxy URL:        http://127.0.0.1:8787"
echo -e "• Systemd status:   systemctl --user status headroom-default.service"
echo -e "• Web Dashboard:    headroom dashboard"
echo -e "• Antigravity MCP:  .agents/plugins/headroom/mcp_config.json"
echo -e "• AnythingLLM MCP:  anythingllm_mcp_servers.json\n"
