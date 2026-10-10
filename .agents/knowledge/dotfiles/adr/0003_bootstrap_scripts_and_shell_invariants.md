# ADR 0003: Bootstrap Script Path Resolution & Shell Arithmetic Invariants

- **Status:** Accepted
- **Date:** 2026-10-09
- **Context:**
  Following the relocation of bootstrap scripts to `scripts/` and the transition to pure `ripgrep`/`fd` tooling, several subtle failure modes emerged:
  1. Off-by-one path resolution: scripts expected `${SCRIPT_DIR}/playbooks` to exist, failing when called from `scripts/`.
  2. The bash `((VAR++))` trap: under `set -e`, if `VAR` starts at 0, arithmetic expansion evaluates to 0 (falsy exit code 1), immediately crashing the script.
  3. Flag confusion between GNU grep and ripgrep: passing `-E` to `rg` caused syntax errors because `-E` denotes `--encoding` in ripgrep.
  4. Tag misalignment in Ansible: skipping essential CLI tools due to missing tags (`cli` tag missing from `--tags user,aur,cargo`).
  5. Loose script generation: Ansible playbooks generating unmanaged executables directly into `~/.local/bin/` rather than committing them to Chezmoi in `home/dot_zsh/scripts/`.

- **Decision:**
  1. Standardize repository root resolution across all bootstrap scripts:
     `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`.
  2. Standardize variable incrementation in Bash scripts running with `set -e`:
     Use `VAR=$((VAR + 1))` exclusively instead of `((VAR++))`.
  3. Prohibit `-E` when invoking `ripgrep` (`rg`), as ripgrep supports regex by default.
  4. Ensure all user-facing setup tasks in `playbooks/packages.yml` include both `cli` and `aur` tags (`tags: [cli, aur, packages]`), and user setup invocations pass `--tags user,aur,cargo,cli`.
  5. All user scripts must be committed to `home/dot_zsh/scripts/` and deployed via Chezmoi, symlinking to `~/.local/bin/` if backward compatibility is required.

- **Consequences:**
  - Automated setups and health checks run deterministically whether invoked via `curl` or locally from any directory.
  - No false-positive aborts in bash test scripts.
  - Zero unmanaged loose scripts outside version control.
