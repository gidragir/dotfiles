#!/usr/bin/env bash
# =============================================================================
# Script   : setup_ollama.sh
# Purpose  : Standalone installer and runner for hardware-accelerated Ollama
#            (NVIDIA CUDA, Flash Attention, Q8_0 KV Cache) & 14B models.
# Usage    : bash scripts/setup_ollama.sh
# =============================================================================

set -euo pipefail

error_handler() {
    local exit_code="$1"
    local line_no="$2"
    echo -e "\n\033[0;31m[ERROR] Failed at line ${line_no} with exit code ${exit_code}.\033[0m" >&2
}
trap 'error_handler $? $LINENO' ERR

if [ "$EUID" -eq 0 ]; then
    echo -e "\033[0;31m[ERROR] Do not run this script directly as root/sudo. Run as normal user.\033[0m" >&2
    exit 1
fi

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${DOTFILES_ROOT}"

echo -e "\033[0;34m[1/3] Ensuring NVIDIA CUDA acceleration package (ollama-cuda)...\033[0m"
if ! pacman -Q ollama-cuda &>/dev/null; then
    echo "Installing user packages from playbooks/packages.yml..."
    ansible-playbook playbooks/packages.yml --tags user
else
    echo "✓ ollama-cuda is already installed."
fi

echo -e "\033[0;34m[2/3] Running Ansible playbook setup_ollama.yml...\033[0m"
ansible-playbook playbooks/setup_ollama.yml

echo -e "\n\033[0;32m✓ Ollama & AnythingLLM setup completed successfully!\033[0m"
echo -e "• Service status:   systemctl --user status ollama.service"
echo -e "• Available models: ollama list"
echo -e "• Headroom proxy:   curl -s -H 'Authorization: Bearer headroom' http://127.0.0.1:8787/v1/models\n"
