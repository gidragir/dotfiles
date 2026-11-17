# AGENTS.md — Репозиторий `dotfiles` (CachyOS + Niri)

Декларативная инфраструктура рабочей станции на **CachyOS Linux** (Niri Wayland, Catppuccin Frappe, Yggdrasil `ygg`, `mise`).
Корень репозитория: `/data/projects/dotfiles` (симлинк `~/projects/dotfiles`).

---

## 1. Навигация и аудит контекста (`context-init`)

- Карта подсистем и код модулей извлекаются через MCP `context-init` (`context_get_subsystems`, `context_get_subsystem`, `context_pack(id, compress=true)`, `context_check`).
- Без MCP (субагенты, скрипты): `rtk context-init pack <subsystem_id> --compress` и `rtk context-init check --compact`.
- После структурных изменений файлов запустите `rtk context-init update` и закоммитьте `.context-init/knowledge/`.
- Актуальный список задач автоматизации смотрите через `mise tasks` (источник — [`mise.toml`](file:///home/gidragir/projects/dotfiles/mise.toml)).

---

## 2. Управление конфигурациями (Yggdrasil `ygg`)

- **Декларативность:** Симлинки в `$HOME` и аппаратные скоупы (`pc`, `asus`) задаются в [`links.toml`](file:///home/gidragir/projects/dotfiles/links.toml), пакеты (`pacman`, `paru`, `cargo`) — в [`packages.toml`](file:///home/gidragir/projects/dotfiles/packages.toml), хуки жизненного цикла — в [`setup.nu`](file:///home/gidragir/projects/dotfiles/setup.nu).
- **Anti-Overwrite Invariant (Ansible):** Запрещено использовать `ansible.builtin.copy`, `template` или `ini_file` поверх путей, управляемых `links.toml`. Ansible отвечает только за системный уровень и вызывает `ygg apply`.
- **Гранулярность симлинков:** Для гибридных директорий с runtime-состоянием (`OpenRGB/`, `noctalia/`) линкуйте файлы поштучно. Монолитный симлинк директории допустим только для 100% декларативных каталогов (`niri`, `rofi`, `waypaper`, `wireplumber`).
- **Pre-flight проверка:** Перед добавлением пути в `links.toml` убедитесь, что источник физически существует (`test -e <source>`).
- **Изоляция `ai-dotfiles`:** Глоб `zsh/scripts/*` не должен затирать симлинки AI-стека (`ai-status.sh`, `hermes-*`, `khoj-*`), разворачиваемые из `/data/projects/ai-dotfiles`. Файл `~/.config/environment.d/pythonpath.conf` не удалять.
- **Команды:** `ygg status`, `ygg apply -n` (dry-run), `ygg apply`. Для песочного тестирования и аудита модулей используйте скилл `ygg-verify`.

---

## 3. Скрипты, Niri и системные утилиты

- **Единое место скриптов:** Пользовательские CLI-утилиты и оконные хелперы Niri создаются строго в [`zsh/scripts/`](file:///home/gidragir/projects/dotfiles/zsh/scripts) (`chmod +x`, разворачиваются через `ygg apply` в `~/.zsh/scripts/`, который уже в `$PATH`). Не создавайте loose-скрипты в `~/.local/bin/` или `~`.
- **Изоляция системных Python-утилит:** Утилиты с `#!/usr/bin/env python3` (`virt-manager` и др.), зависящие от системного `gi`, оборачиваются в `zsh/scripts/<tool>` со сбросом `VIRTUAL_ENV`/`PYTHONHOME` и вызовом `exec /usr/bin/python3 /usr/bin/<tool> "$@"`.
- **Niri:** Модульные конфиги лежат в [`niri/cfg/`](file:///home/gidragir/projects/dotfiles/niri/cfg), хостовые экраны — в `niri/displays/`. Для безопасной проверки без выхода из сеанса используйте `niri-sandbox`.
- **Системные скрипты хоста:** Диагностика и VM/дисковые утилиты лежат в [`scripts/`](file:///home/gidragir/projects/dotfiles/scripts).

---

## 4. Контекстные указатели (Disclosed Reference)

Подгружайте профильные документы и скиллы **только** при работе с соответствующей подсистемой:

| Подсистема / задача | Куда обращаться | Обязательная проверка |
| :--- | :--- | :--- |
| Правки `noctalia/` (`config.toml`, `hosts/*.toml`, Luau-плагины) | [`docs/noctalia-invariants.md`](file:///home/gidragir/projects/dotfiles/docs/noctalia-invariants.md) | `noctalia config validate`, `noctalia plugins lint <path>` |
| Правки `playbooks/` или bash-скриптов (`scripts/`, `zsh/scripts/`) | [`docs/playbooks-invariants.md`](file:///home/gidragir/projects/dotfiles/docs/playbooks-invariants.md) | Идемпотентность, `set -euo pipefail`, `REPO_ROOT` |
| Аудио (WirePlumber 0.5, BlueZ) или подсветка (OpenRGB, HID) | Скилл `hardware-troubleshooting` ([SKILL.md](file:///home/gidragir/projects/dotfiles/.agents/skills/hardware-troubleshooting/SKILL.md)) | SPA-JSON в `wireplumber/`, проверка дескрипторов OpenRGB |
| Аудит/песочница модулей Yggdrasil | Скилл `ygg-verify` | `ygg apply --sandbox ... --skip-packages` |
| Сложные многошаговые задачи | Скилл `subagent-driven-development` и `.agents/agents/*.md` | `mise run test:e2e` / `ygg apply -n` |

---

## 5. Безопасность, Workspace и Ограничения

- **Workspace-кастомизации:** Используйте только `.agents/` (не `.agent/`). При перемещении/удалении файлов синхронизируйте [`README.md`](file:///home/gidragir/projects/dotfiles/README.md) и [`AGENTS.md`](file:///home/gidragir/projects/dotfiles/AGENTS.md).
- **Секреты и кэши:** Секреты хранятся через `sops`/`age`, локальные оверрайды — в `.zshenv.local` и `mise.local.toml` (в `.gitignore`). Не меняйте пути Dual-NVMe кэшей (`.pnpm-store`, `.uv-cache`, `.sccache`, `.cargo-cache`).
- **Деструктивные операции:** Не запускайте `playbooks/archive/setup_system.yml`, `scripts/patrition_delete.sh` и `mise run disk:wipe` без явного подтверждения пользователя.
- **Размер файла:** Держите корневой `AGENTS.md` $\le 22\,000$ байт во избежание усечения `<user_rules>`.


## 🗺 Архитектурная карта и навигация (OpenViking L0-L2)

Проект `dotfiles` описан трехуровневой базой знаний context-init (L0-L2), которая лежит в `.context-init/knowledge/` и коммитится вместе с кодом. Людям можно читать её напрямую; агентам — предпочитать MCP/`pack` ниже: это компактнее и учитывает бюджет токенов. После структурных изменений запустите `context-init update` и закоммитьте изменения базы в том же PR.

### ⚡ MCP-First Protocol (context-init)

Во все вызовы передавайте `"path": "<repo_root>"`.

1. `context_get_subsystems` — карта подсистем проекта (L0).
2. `context_get_subsystem(subsystem_id)` — компактная L1-карточка подсистемы.
3. `context_pack(subsystem_id, mode="toc")` — символы со строками; `context_pack(subsystem_id, compress=true)` — AST-сжатый код (`style="compact"` по умолчанию).
4. `context_pack(subsystem_id, files=["<file>"], compress=false)` — точный код нужных файлов.
5. `context_check` — проверка архитектурного дрейфа перед сдачей задачи.

Ответ с `truncated: true` — повторите вызов с `cursor` из футера или сузьте `files`.

Без доступа к MCP (субагенты, скрипты): `rtk context-init pack <subsystem_id> --compress --max-lines 200` (`--toc`, `--files <f> --no-compress`, `--cursor "cur_..."`) и `rtk context-init check --compact`.

### 📦 Доступные подсистемы:
- `docs` (Docs) — Модуль и компоненты директории `docs` (7 файлов)
- `niri` (Niri) — Модуль и компоненты директории `niri` (15 файлов)
- `noctalia` (Noctalia) — Модуль и компоненты директории `noctalia` (5 файлов)
- `noctalia_plugins` (Noctalia Plugins) — Модуль и компоненты директории `noctalia/plugins` (15 файлов)
- `noctalia_plugins_audio-outputs` (Noctalia Plugins Audio Outputs) — Модуль и компоненты директории `noctalia/plugins/audio-outputs` (4 файлов)
- `noctalia_plugins_audio-outputs_tests` (Noctalia Plugins Audio Outputs Tests) — Тесты для `noctalia_plugins_audio-outputs`
- `noctalia_plugins_obsidian` (Noctalia Plugins Obsidian) — Модуль и компоненты директории `noctalia/plugins/obsidian` (6 файлов)
- `playbooks` (Playbooks) — Модуль и компоненты директории `playbooks` (7 файлов)
- `playbooks_archive` (Playbooks Archive) — Модуль и компоненты директории `playbooks/archive` (5 файлов)
- `scripts` (Scripts) — Модуль и компоненты директории `scripts` (4 файлов)
- `tests` (Tests) — Тесты проекта
- `umbriel` (Umbriel) — Модуль и компоненты директории `umbriel` (1 файлов)
- `wallpaper-engine` (Wallpaper Engine) — Модуль и компоненты директории `wallpaper-engine` (1 файлов)
- `zsh` (Zsh) — Модуль и компоненты директории `zsh` (14 файлов)
