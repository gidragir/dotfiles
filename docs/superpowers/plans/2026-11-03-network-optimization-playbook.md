# Network Optimization Playbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a modular, standalone Ansible playbook `playbooks/setup_network_optimization.yml` that mitigates host-induced home network degradation (Bufferbloat, boot-time bursts, LLMNR) with full revert capabilities.

**Architecture:** Dual-play structure (System Play for `/etc/` drop-ins and sysctl, User Play for user systemd drop-ins) driven by a `network_optimization_state` variable (`present` / `absent`) and tags (`apply` / `revert`). Preserves all existing core dotfiles playbooks without modification.

**Tech Stack:** Ansible (core modules: `copy`, `file`, `systemd`, `sysctl`, `command`), Systemd Drop-ins, Linux TCP/IP sysctl (`bbr`, `fq_codel`).

**Spec:** [docs/superpowers/specs/2026-11-03-network-optimization-design.md](file:///home/gidragir/projects/dotfiles/docs/superpowers/specs/2026-11-03-network-optimization-design.md)

## Global Constraints

- Must strictly use drop-in files (`.conf` in `.d/` directories); direct modification of `/usr/lib/` or core service files is strictly prohibited.
- Must not touch Docker bridges (`docker0`, `br-*`), local AI services, or Antigravity IDE connection sockets.
- Must remain 100% idempotent and support clean rollback via `ansible-playbook playbooks/setup_network_optimization.yml -e network_optimization_state=absent --tags revert`.
- All commands and executions must follow host invariants: `rtk` prefix, no `find`/`grep`.

## Review Focus

1. **Drop-in override syntax:** Systemd `ExecStart=` reset must precede the replacement `ExecStart=...` in `rclone-obsidian-sync.service.d/override.conf`, otherwise systemd attempts to execute both commands sequentially.
2. **Missing kernel module fallback:** If `tcp_bbr` is somehow missing, sysctl reload must not fail catastrophically; module availability is pre-checked.
3. **Revert cleanliness:** Rolling back (`state=absent`) must completely remove drop-in directories if empty and reload systemd / sysctl back to system defaults.
4. **Privilege separation:** System play requires `become: true`; User play must run unprivileged (`become: false`) so user units reside in user's `$HOME`.
5. **No impact on rclone if unconfigured:** If rclone is not installed or service is absent, drop-in management should be guarded or non-failing.

---

### Task 1: Create Standalone Network Optimization Playbook

**Files:**
- Create: `playbooks/setup_network_optimization.yml`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-11-03-network-optimization-design.md`
- Produces: `playbooks/setup_network_optimization.yml` supporting:
  - `ansible-playbook playbooks/setup_network_optimization.yml --tags apply`
  - `ansible-playbook playbooks/setup_network_optimization.yml --tags revert -e network_optimization_state=absent`

- [ ] **Step 1: Write `playbooks/setup_network_optimization.yml`**
  Implement dual-play Ansible structure:
  - System Play (`become: true`):
    - Manage `/etc/sysctl.d/99-network-bbr.conf` (BBR + FQ-CoDel).
    - Manage `/etc/systemd/system/cachyos-rate-mirrors.timer.d/override.conf` (`Persistent=false`).
    - Manage `/etc/systemd/resolved.conf.d/disable-llmnr.conf` (`LLMNR=no`).
    - Handlers: reload sysctl, daemon-reload systemd, restart systemd-resolved.
  - User Play (`become: false`):
    - Manage `~/.config/systemd/user/rclone-obsidian-sync.service.d/override.conf` (add `--bwlimit 10M` with `ExecStart=` reset).
    - Manage `~/.config/systemd/user/rclone-obsidian-sync.timer.d/override.conf` (`OnBootSec=10m` with `OnBootSec=` reset).
    - Handlers: daemon-reload user systemd.

- [ ] **Step 2: Verify Ansible playbook syntax**
  Run: `rtk ansible-playbook --syntax-check playbooks/setup_network_optimization.yml`
  Expected: PASS (`syntax OK`).

- [ ] **Step 3: Commit playbook**
  ```bash
  rtk git add playbooks/setup_network_optimization.yml
  rtk git commit -m "feat(network): add standalone network optimization and QoS playbook"
  ```

---

### Task 2: Create Automated Syntax and Idempotence Validation Script

**Files:**
- Create: `tests/test_network_optimization.sh`

**Interfaces:**
- Consumes: `playbooks/setup_network_optimization.yml`
- Produces: Exit code 0 on valid syntax, variable checks, and drop-in format validation.

- [ ] **Step 1: Write `tests/test_network_optimization.sh`**
  Implement a test script that:
  - Validates `ansible-playbook --syntax-check playbooks/setup_network_optimization.yml`.
  - Verifies presence of both `apply` and `revert` tags.
  - Verifies presence of `ExecStart=` reset line in the rclone override definition.
  - Verifies `bbr` module presence in `/proc/sys/net/ipv4/tcp_available_congestion_control`.

- [ ] **Step 2: Run verification test**
  Run: `rtk bash tests/test_network_optimization.sh`
  Expected: PASS with 0 exit code.

- [ ] **Step 3: Commit test script**
  ```bash
  rtk git add tests/test_network_optimization.sh
  rtk git commit -m "test(network): add validation script for network optimization playbook"
  ```

---

### Task 3: Document Playbook in AGENTS.md

**Files:**
- Modify: `AGENTS.md` (Section 2 Ментальная карта структуры проекта)

**Interfaces:**
- Consumes: Newly created playbook path
- Produces: Updated architecture tree in `AGENTS.md`

- [ ] **Step 1: Add `setup_network_optimization.yml` to the mental map in `AGENTS.md`**
  Document `setup_network_optimization.yml` under `playbooks/` with a clear description: standalone network bufferbloat and boot burst optimization.

- [ ] **Step 2: Verify AGENTS.md diff**
  Run: `rtk git diff AGENTS.md`
  Expected: Only the new playbook entry added to `playbooks/`.

- [ ] **Step 3: Commit documentation update**
  ```bash
  rtk git add AGENTS.md
  rtk git commit -m "docs: register setup_network_optimization.yml in AGENTS.md"
  ```
