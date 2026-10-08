# 🤖 AGENTS.md — Руководство для AI-агентов по работе с репозиторием

> **Цель документа:** Обеспечить AI-агентам и разработчикам мгновенную ориентацию в репозитории dotfiles для **CachyOS (Niri)**, а также зафиксировать архитектурные стандарты, практики DevOps/GitOps и правила внесения изменений для максимального удобства и целостности системы (UX/DX Flow).

---

## 📌 1. Обзор проекта и архитектура

Данный репозиторий представляет собой декларативную систему автоматизированного развертывания и управления окружением (Infrastructure-as-Code для локальной рабочей станции):
- **ОС:** CachyOS (оптимизированный Arch Linux под x86-64-v3/v4).
- **Оконный менеджер / Композитор:** Niri (scrollable-tiling Wayland композитор с конфигурацией на KDL).
- **Автоматизация установки:** Bash-бутстрапперы (`setup_system.sh`, `setup_user.sh`) и модульные Ansible-плейбуки (`playbooks/`).
- **Управление конфигурациями:** **Chezmoi** (симлинки из репозитория в `$HOME` через `mode = "symlink"`, шаблоны для host-зависимых файлов).
- **Стек разработки:** Rust (`rustup`, `mold`, `sccache`), TypeScript/Node (`mise`, `pnpm`, `biome`), Python (`uv`), Cloud-Native & DevOps (`k3d`, `kubectl`, `k9s`, `helm`, `argocd`, `sops`, `age`, `distrobox`, `docker`), QEMU/KVM (`libvirt`, `virtio-fs`).
- **Аппаратная архитектура хранения:** Оптимизированный двухдисковый Dual-NVMe сетап с распределением файловых систем (Btrfs zstd, XFS prjquota, ext4 noatime).

---

## 🗂 2. Ментальная карта структуры проекта

```
dotfiles/
├── scripts/                     # Системные скрипты и утилиты хоста
│   ├── setup_system.sh          # [Root] Системный бутстраппер (диски, системные пакеты, SDDM/Limine)
│   ├── setup_user.sh            # [User] Пользовательский бутстраппер (AUR, chezmoi, mise, rust, timers)
│   ├── check.sh                 # Диагностика Docker XFS / prjquota / storage
│   ├── check_setup.sh           # Полная валидация окружения (точки монтирования, кэши, symlinks)
│   ├── patrition_delete.sh      # ⚠️ ДЕСТРУКТИВНЫЙ скрипт очистки /dev/nvme1n1 (не запускать без спроса!)
│   ├── setup_wallpaper_engine.sh# Утилита настройки динамических обоев
│   └── create_win11_vm.sh       # Скрипт развертывания Windows 11 VM в KVM
├── mise.toml                    # Задачи сборки и проверки окружения (mise run ai:status, etc.)
├── lefthook.yml                 # Git хуки качества и линтинга
│
├── playbooks/                   # Модульные Ansible-плейбуки
│   ├── vars/
│   │   └── packages.yml         # 🌟 SINGLE SOURCE OF TRUTH для всех устанавливаемых пакетов
│   ├── packages.yml             # Плейбук установки (теги: system, user, aur, cargo; host_profile)
│   ├── setup_system.yml         # Разметка NVMe 1, создание FS, fstab, Docker, KVM
│   ├── setup_user.yml           # Применение Chezmoi, настройка кэшей, каталогов, user services
│   ├── setup_display_manager.yml# Catppuccin тема для SDDM и Limine, multi-monitor
│   ├── setup_rust.yml           # Изолированный быстрый Rust-тулчейн (mold, sccache, cargo-binstall)
│   ├── setup_gaming.yml         # Gaming-стек CachyOS, Proton/NVIDIA, symlink библиотеки Steam
│   ├── setup_virt.yml           # QEMU/KVM/libvirt, swtpm, UFW правила, Virtio-FS /srv/Shared
│   ├── setup_rclone.yml         # Systemd user unit + timer для bisync Obsidian в Google Drive
│   ├── setup_cooler_control.yml # Профили охлаждения и кривые вентиляторов
│   └── setup_wallpaper_engine.yml # Установка и сервис Wallpaper Engine для Wayland
├── ai-dotfiles/                 # 🧠 [Repo] Единая декларативная AI-инфраструктура (~/projects/ai-dotfiles)
│   ├── infra/playbooks/         # Плейбуки настройки AI-стека (setup_ollama, setup_khoj, setup_hermes)
│   ├── infra/stacks/            # Docker Compose стеки (khoj, hindsight)
│   ├── infra/stow/              # GNU Stow пакеты (hermes, ollama, opencommit)
│   ├── services/hermes/         # Hermes Idea Pipeline (18 MCP инструментов, профили, плагины)
│   ├── services/host-cli/       # Host CLI MCP сервер на TypeScript/Bun
│   └── scripts/                 # Автономные CLI-утилиты (ai-status.sh, khoj-ctl.sh, etc.)
│
├── .agents/                     # 🤖 Antigravity Workspace Customizations
│   ├── agents/                  # Роли и промпты субагентов (researcher, implementer, etc.)
│   ├── knowledge/dotfiles/      # Архитектурная база знаний L0/L1 (ADR, CLI, подсистемы)
│   ├── plugins/                 # Antigravity плагины (headroom, host-cli)
│   ├── rules/                   # Поведенческие правила (CLAUDE.md)
│   └── skills/                  # Специализированные навыки (hardware-troubleshooting, etc.)
│
├── deploy/                      # Локальные стеки деплоя (deploy/khoj/)
├── tests/                       # Тесты инфраструктуры (e2e_virt_manager_test.sh)
│
├── .chezmoiroot                 # Корень source state Chezmoi (home/)
├── home/                        # Исходное состояние Chezmoi для $HOME
│   ├── .chezmoi.toml.tmpl       # Шаблон конфигурации хоста (promptChoiceOnce для chassis)
│   ├── .chezmoiignore           # Изоляция ai-dotfiles и фильтрация desktop/laptop сервисов
│   ├── dot_config/              # ~/.config (niri, nvim, ghostty, sheldon, etc.)
│   ├── dot_cargo/               # ~/.cargo (config.toml)
│   ├── dot_zsh/                 # ~/.zsh (скрипты, алиасы, бинды)
│   ├── dot_zshrc                # ~/.zshrc
│   └── dot_zshenv.tmpl          # Шаблон ~/.zshenv (desktop vs laptop)
└── linked/                      # Директории с runtime-state приложений
    └── noctalia/                # ~/.config/noctalia (монтируется как цельный symlink)
```

---

## ⚙️ 3. Ключевые архитектурные принципы

### 1. GitOps & DevOps (Idempotence & Single Source of Truth)
- **Single Source of Truth для пакетов:** Все пакеты (Pacman, AUR, Cargo, CLI) декларируются **исключительно** в [`playbooks/vars/packages.yml`](file:///home/gidragir/projects/dotfiles/playbooks/vars/packages.yml). Не добавляйте вызовы `pacman -S` или `paru -S` напрямую в таски или скрипты без крайней необходимости.
- **Идемпотентность:** Все плейбуки и bash-скрипты должны быть безопасны для многократного повторного запуска. Не используйте `command:` / `shell:` в Ansible без `creates:`, `changed_when:` или проверок состояния через `stat`.
- **Разделение привилегий:**
  - **System (Root):** Запускается через `sudo`, отвечает за блочные устройства, `/etc/fstab`, системные пакеты, udev, SDDM, system systemd-юниты.
  - **User (Non-Root):** Запускается от обычного пользователя. AUR-хелпер (`paru` через модуль `kewlfft.aur`) **категорически запрещено** запускать из-под root! Пользовательские юниты systemd настраиваются со `scope: user`.

### 2. Модель управления конфигурациями через Chezmoi
Репозиторий dotfiles располагается в `/data/projects/dotfiles` (с симлинком в `~/projects/dotfiles`).
Управление пользовательскими конфигурациями (`$HOME`) переведено с GNU Stow на **Chezmoi** с сохранением zero-latency symlink рабочего процесса:
- **Корень source-state:** Задан через `.chezmoiroot = home`. Все управляемые файлы размещаются внутри `home/` с префиксами `dot_`.
- **Режим live-editing (`mode = "symlink"`):** Статические файлы (`nvim`, `ghostty`, `sheldon`, скрипты) разворачиваются как прямые симлинки на исходники в репозитории. Изменения в Neovim или конфигах мгновенно видны в `rtk git status` без необходимости вызова `chezmoi apply`.
- **Шаблонизация (`.tmpl`):** Хост-зависимые параметры (мониторы Niri `display.kdl.tmpl`, окружение `dot_zshenv.tmpl`) компилируются на основе переменной шасси (`desktop` vs `laptop`).
- **Симлинки целых каталогов (`symlink_`):** Для приложений с runtime-состоянием (Noctalia) директория монтируется целиком через `home/dot_config/symlink_noctalia.tmpl` на `linked/noctalia`.
- **Изоляция AI-стека:** Через `home/.chezmoiignore` жестко исключены пути `ai-dotfiles` (`.hermes/**`, `.config/Hermes/**`, `.opencommit*`, `.gemini/**`), которые на рабочей станции обслуживаются независимо через GNU Stow.

**Команды работы с Chezmoi:**
- Для применения конфигурации:
  ```bash
  chezmoi apply --source /data/projects/dotfiles --force
  ```
- Для проверки дрифта:
  ```bash
  chezmoi verify
  chezmoi diff
  ```

### 3. Dual-NVMe архитектура и стратегия кэширования
Система рассчитана на эффективное использование двух NVMe накопителей:
1. **NVMe 0 (Системный диск):**
   - `/boot/efi` (FAT32, 1G)
   - `/` (Btrfs/Ext4, ~100G)
   - `swap` (8G)
   - `/home` (Пользовательские конфиги и профили)
2. **NVMe 1 (Высокопроизводительный Data-диск):**
   - `/var/lib/docker` (**XFS**, `defaults,noatime,prjquota`): Нативный Docker с аппаратными квотами проектов.
   - `/var/lib/libvirt/images` (**ext4**, `defaults,noatime`): Образы виртуальных машин KVM без деградации CoW.
   - `/data/projects` (**Btrfs**, `compress=zstd:3,discard=async`): Исходный код и централизованные кэши:
     - `/data/projects/.pnpm-store` — жесткие ссылки pnpm работают мгновенно внутри той же ФС.
     - `/data/projects/.uv-cache` — сжатие zstd экономит диск при хранении Python wheels.
     - `/data/projects/.sccache` — общий кэш сборки Rust.
     - `/data/projects/.cargo-cache/` — кэш пакетов и git-репозиториев Cargo.
   - `/data/sync` (**Btrfs**, `compress=zstd:3,discard=async`): Obsidian, Zotero, синхронизируемые документы.

### 4. Shell & Terminal UX Flow (Zsh + Neovim + Vi-mode)
- **Модальный терминал:** Включен полный Vi-режим в Zsh (`bindkey -v`) с индикатором формы курсора (Beam `|` в Insert, Block `█` в Normal) и быстрым переключением (`KEYTIMEOUT=1`).
- **Интеграция с Neovim:** Нажатие `v` в командной строке Zsh открывает текущую команду в Neovim (LazyVim).
- **Интерактивные превью:** `fzf-tab` перехватывает автодополнения Zsh (`cd`, `kill`, `git`, `systemctl`, `export`) и отображает интерактивные превью с помощью `eza`, `bat` и `ps`.
- **Фаст-навигация:** `zoxide` (`cd`), `tv` (Television), `spf` (Superfile TUI, автоматически меняющий рабочую директорию при выходе).
- **Композитор Niri:** Модульная конфигурация в `home/dot_config/niri/cfg/*.kdl`. Оконные правила (`rules.kdl`) изолируют настройки, правила автозапуска лежат в `autostart.kdl`.
- **Централизация скриптов автоматизации:** Все кастомные shell-скрипты, оконные хелперы (например, переключение/вызов окон в Niri), CLI-утилиты и скрипты интеграций хранятся **исключительно** в `home/dot_zsh/scripts/`. Каталог `~/.zsh/scripts` автоматически экспортируется в `$PATH` через `.zshenv`. Категорически запрещено создавать изолированные loose-скрипты в `~/.local/bin/` или вне репозитория dotfiles.

### 5. Персональный AI-стек и трехуровневая архитектура моделей
Единая декларативная AI-инфраструктура хоста вынесена в репозиторий [`ai-dotfiles`](file:///data/projects/dotfiles/ai-dotfiles):
- **Три рабочих контура:**
  1. *Терминальный контур:* OpenCommit напрямую через локальный `ollama` (`qwen2.5:14b-ctx64k` на `:11434`), алиас `gcai` (`git add -p && opencommit`).
  2. *Контур разработки:* Antigravity IDE (Gemini Pro) + Headroom Proxy (`:8787`, CCR AST-сжатие логов/кода, кэш в PostgreSQL) + Host CLI MCP (TypeScript/Bun) + Khoj MCP (`docker exec -i khoj khoj-mcp`).
  3. *Контур знаний и RAG:* Obsidian (`/data/obsidian`) + Khoj Docker (`:42110`, живая индексация) + PostgreSQL 16 с расширением `pgvector` (`:5432`) + Hindsight Long-Term Memory (`:9999`).
- **Аппаратные ограничения vRAM (16 ГБ):** Пакетные серверы типа vLLM запрещены из-за риска OOM десктопа Niri. Используется `ollama.service` (`q8_0` KV-кэш, Flash Attention, `OLLAMA_MAX_LOADED_MODELS=1`).
- **Политика долговременной памяти (Context Poisoning Protection):** Флаг `--memory` в Headroom отключен. Память и заметки запрашиваются **строго через осознанные tool calls** (Khoj MCP, `search_files`, `khoj-ctl.sh`), а не неявной инъекцией в системный промпт прокси.
- **Защитные схемы MCP:** Аргументы инструментов в Host CLI MCP (`services/host-cli/`) валидируются через Zod и приводятся к ожидаемым типам (Defensive Coercion), ошибки возвращаются в виде структурированных хинтов (`available_tools`).

### 6. Аппаратная специфика: Аудио (WirePlumber 0.5) и Подсветка (OpenRGB / HID)
- **WirePlumber 0.5 Routing & Sleep Invariants:**
  - Синтаксис строго SPA-JSON (`wireplumber.conf.d/*.conf`). Lua-скрипты в WirePlumber 0.5 устарели и игнорируются.
  - Автопереключение профилей гарнитуры выключено: `"bluetooth.autoswitch-to-headset-profile" = false` в `10-seamless-routing.conf` (предотвращает принудительное переключение в монофонический HFP/HSP при доступе приложений к микрофону).
  - Запрет засыпания нод: свойство `session.suspend-timeout-seconds = 0` обязательно для правил, матчащих `api.alsa.*` и `api.bluez5.*` в `30-disable-idle-suspend.conf` (устраняет задержки и зависания аудиопотоков).
- **OpenRGB & USB HID Архитектура:**
  - **Systemd Targets:** Пользовательские юниты `openrgb.service` и `openrgb-profile.service` должны привязываться строго к `graphical-session.target`. Привязка к `default.target` / `multi-user.target` создает ordering cycle, при котором systemd аварийно сбрасывает старт сервиса профиля.
  - **Изоляция аргументов в CLI OpenRGB:** Опции `-z` (зоны) внутри одного вызова `openrgb` загрязняют последующие устройства в цепочке `-d`. Категорически запрещено передавать временные размеры зон (`-sz`) или `-z` внутри регулярной смены цвета в `devices.conf` / `devices.sh`. Размеры ARGB-заголовков материнской платы персистентно хранятся в `Configuration.json`.
  - **Zombie-дескрипторы после сна (Hotplug Limit):** Демон `openrgb --server` не имеет udev hotplug-монитора. При сне ПК или USB-ресбросе ядро удаляет старые ноды (`/dev/hidraw2 (deleted)`) и создает новые (`/dev/hidraw3`). Для исключения отправки команд в мертвые дескрипторы используется:
    1. Автоматический self-healing в `devices.sh` (`_heal_stale_openrgb()`, проверяющий `/proc/<pid>/fd/` на `hidraw.*deleted`).
    2. Системный sleep-хук `/usr/lib/systemd/system-sleep/openrgb-resume` (из `playbooks/setup_system.yml`), перезапускающий `openrgb.service` при выходе из сна.

---

## 🚀 4. Инструкция по установке и тестированию

### Системный этап (Root)
Запускается на чистой системе CachyOS:
```bash
sudo bash scripts/setup_system.sh
```
Что делает:
1. Клонирует репозиторий при необходимости в `/data/projects/dotfiles`.
2. Запускает `playbooks/packages.yml --tags system`.
3. Запускает `playbooks/setup_system.yml` (разбивает NVMe 1, настраивает монтирование, группы `docker`, `libvirt`, `kvm`).
4. Запускает `playbooks/setup_display_manager.yml` (темизация SDDM и Limine).
> **Важно:** После выполнения шага обязателен перезаход в сессию (`log out` / `reboot`) для применения групп пользователя.

### Пользовательский этап (User)
Запускается от обычного пользователя (не root):
```bash
bash scripts/setup_user.sh
```
Что делает:
1. Устанавливает коллекцию `kewlfft.aur` в Ansible Galaxy.
2. Ставит официальные и AUR пакеты, а также Cargo-утилиты через `cargo binstall`.
3. Настраивает симлинки проектов и применяет конфигурации Chezmoi.
4. Настраивает структуру кэшей Rust, pnpm, uv.
5. Запускает фоновый таймер rclone для Obsidian (`setup_rclone.yml`).

### Проверка корректности окружения (Health Checks)
После установки или внесения инфраструктурных изменений обязательно запустите диагностические скрипты:
```bash
# 1. Проверка пользовательского окружения, кэшей и монтирования:
bash scripts/check_setup.sh

# 2. Проверка Docker-хранилища, XFS ftype и prjquota:
sudo bash scripts/check.sh

# 3. Комплексная проверка AI-стека (Ollama, Headroom, Khoj, Postgres):
mise run ai:status
```

---

## 🤖 5. Руководство для AI-агентов: Как вносить изменения

### Сценарий A: Добавление или удаление пакетов ПО
1. **Не запускайте `pacman` или `paru` вручную!**
2. Откройте [`playbooks/vars/packages.yml`](file:///home/gidragir/projects/dotfiles/playbooks/vars/packages.yml).
3. Определите нужную секцию:
   - `system_packages`: Низкоуровневые утилиты, драйверы, системные демоны.
   - `user_pacman_packages`: Пользовательские CLI/GUI инструменты из официальных репозиториев Arch/CachyOS.
   - `aur_packages`: Программы, доступные только в AUR (устанавливаются через `paru`).
   - `cargo_packages`: Быстрые бинарники на Rust (устанавливаются через `cargo binstall`).
   - `cli_essential_packages`: Базовые утилиты командной строки (fzf, eza, bat, etc.).
   - `unwanted_packages`: Пакеты, которые должны принудительно удаляться (например, дефолтные браузеры/терминалы).
4. Проверьте установку запуском:
   ```bash
   ansible-playbook playbooks/packages.yml --tags <tag>
   ```

### Сценарий B: Добавление новой конфигурации программы (Chezmoi)
Если вы настраиваете новую программу, например `ripgrep` или `tmux`:
1. Разместите файлы конфигурации внутри `home/` так, чтобы путь относительно `home/` зеркалировал целевой путь в `$HOME` с заменой ведущих точек на `dot_`:
   - `~/.config/mytool/config` → `home/dot_config/mytool/config`.
   - `~/.mytoolrc` → `home/dot_mytoolrc`.
2. Примените конфигурацию:
   ```bash
   chezmoi apply --source /data/projects/dotfiles --force
   ```
3. Проверьте отсутствие дрифта:
   ```bash
   chezmoi verify
   ```
4. Обновите список в [`README.md`](file:///home/gidragir/projects/dotfiles/README.md).

### Сценарий C: Изменение настроек Niri (Wayland композитор)
Конфигурация Niri декомпозирована в [`home/dot_config/niri/cfg/`](file:///home/gidragir/projects/dotfiles/home/dot_config/niri/cfg):
- `keybinds.kdl`: Горячие клавиши (используйте существующие соглашения `Mod+...`).
- `rules.kdl`: Правила для окон (floating, geometry-corner-radius, maximized-to-edges).
- `autostart.kdl`: Фоновые демоны (панели, буфер обмена `cliphist`, обои).
- `display.kdl.tmpl`: Разрешение и частота мониторов (шаблон Chezmoi с ветвлением по шасси `desktop` / `laptop`).
- `env/`: Локальные оверрайды для конкретной рабочей машины (`include optional=true`).

**Безопасное тестирование без выхода из сеанса:**
Для тестирования оконного менеджера и баров используйте готовый скрипт песочницы:
```bash
niri-sandbox    # Запускает вложенную сессию Wayland в окне
```

### Сценарий D: Модификация shell-скриптов и Ansible
- **Строгий режим Bash:** Всегда используйте `set -euo pipefail` в начале bash-скриптов.
- **Обработка ошибок:** Добавляйте `trap 'error_handler $? $LINENO' ERR` для информативного вывода строки с ошибкой.
- **Проверка прав:** Проверяйте `$EUID`:
  - `if [ "$EUID" -ne 0 ]; then exit 1; fi` (для root скриптов).
  - `if [ "$EUID" -eq 0 ]; then exit 1; fi` (для user скриптов).
- **Следование стилю:** Все плейбуки оформляются с подробными комментариями заголовков, тегами (`tags: [...]`) и именованием каждой таски (`name: ...`).

### Сценарий E: Создание скриптов автоматизации и CLI-утилит (Window & System Helpers)
Когда требуется создать вспомогательный скрипт для автоматизации (переключение/вызов окон в Niri, тумблеры режимов, CLI-хелперы, интеграции):
1. **Единый каталог размещения:** Создавайте файл строго внутри `home/dot_zsh/scripts/<script-name>.sh` (или без расширения).
2. **Права на выполнение:** Всегда выставляйте флаг исполняемости:
   ```bash
   chmod +x home/dot_zsh/scripts/<script-name>.sh
   ```
3. **Обновление линков:** Примените Chezmoi:
   ```bash
   chezmoi apply --source /data/projects/dotfiles --force
   ```
4. **Интеграция с Niri / горячими клавишами:** В `home/dot_config/niri/cfg/keybinds.kdl` привязывайте скрипт через:
   ```kdl
   Mod+<Key> { spawn "bash" "-c" "~/.zsh/scripts/<script-name>.sh"; }
   ```
   Либо через `spawn-sh "<script-name>.sh";` (так как `~/.zsh/scripts` находится в `$PATH`).
5. **Запрет на unmanaged loose scripts:** Категорически запрещено создавать локальные скрипты в `~/.local/bin/` или `~` в обход репозитория. Любая автоматизация должна находиться в `home/dot_zsh/scripts/`, управляться Chezmoi и быть закоммичена в Git.

### Сценарий F: Управление и доработка AI-стека (Ollama, Khoj, Hindsight, Hermes)
Архитектура AI-инфраструктуры хоста сосредоточена в [`ai-dotfiles`](file:///data/projects/dotfiles/ai-dotfiles):
1. **Кастомные Modelfiles и модели Ollama:**
   - Все декларативные Modelfiles версионируются в `ai-dotfiles/infra/modelfiles/`.
   - Сборка и оверлеи выполняются через `mise run model:build:<name>`.
2. **Docker Compose стеки (Khoj, Hindsight):**
   - Конфигурации стеков хранятся в `ai-dotfiles/infra/stacks/` (`khoj`, `hindsight`).
   - Управление и статус проверяются через `mise run ai:status`.
3. **MCP-серверы и защитное программирование (Defensive Coercion):**
   - Host CLI MCP сервер реализован на TypeScript/Bun в `ai-dotfiles/services/host-cli/`.
   - Для всех инструментов используется валидация Zod.
   - Ошибки типизации компактных моделей (14B) нормализуются с возвратом структурированных подсказок со списком `available_tools`.
4. **Конфигурация базы знаний Khoj и поиск по Obsidian:**
   - Деплой и манифесты находятся в `deploy/khoj/` и `ai-dotfiles/infra/stacks/khoj/`.
   - Индексация заметок Obsidian (`/data/obsidian`) осуществляется автоматически контейнером Khoj.

### Сценарий G: Оркестрация задач и субагенты (Subagent-Driven Development)
В Antigravity 2.0 используется оркестраторная модель работы с изоляцией контекста. Профиль каждого агента определен в `.agents/agents/*.md`.
1. **Защита основного контекста (Context Protection):**
   - Запрещено выполнять «тяжелый» ресерч (grep по всей кодовой базе, чтение десятков файлов, длинные логи тестов) в основном диалоге.
   - Делегируйте такие задачи субагенту `researcher` (модель `flash`).
2. **Матрица моделей и ролей:**
   - `researcher` (Flash) — поиск путей, файлов, чтение конфигов и выжимка фактов.
   - `implementer` (Inherit/Flash) — написание кода строго под один пункт плана без отвлечений.
   - `code-reviewer` (Pro) — глубокий двухэтапный аудит качества кода, стандартов безопасности и AGENTS.md.
   - `tester-validator` (Flash) — запуск линтеров, сборки и синтаксических проверок.
   - `system-architect` (Pro) — аудит системных рисков (NVMe, fstab, Btrfs, UFW, QEMU, Wayland/Niri).
3. **Методология Subagent-Driven Development:**
   - Перед сложной задачей сформируйте план (`implementation_plan.md`).
   - Для каждого шага: сбор контекста (`researcher`) → реализация (`implementer`) → ревью (`code-reviewer`) → автопроверка (`tester-validator`).
   - Используйте навык `.agents/skills/subagent-driven-development/SKILL.md`.

---

## 🛡️ 6. Гигиена репозитория и безопасность

1. **Никаких секретов в Git:**
   - Категорически запрещено коммитить приватные SSH ключи (`~/.ssh/id_*`), GPG/age ключи, `rclone.conf`, токены API и пароли.
   - Для управления секретами используются `sops` и `age`.
   - Локальные переменные окружения выносятся в `.zshenv.local` или `*.local` (игнорируются в Git).
   - **Конфигурация и секреты проектов (`mise.local.toml`):** Любые локальные переменные, токены и секреты во всех проектах должны определяться исключительно в локальном файле `mise.local.toml` (для менеджера окружения `mise`), который обязательно добавляется в `.gitignore`. Никогда не хардкодить чувствительные данные напрямую в коде, плейбуках или файлах конфигурации.
2. **Артефакты сборки и кэши:**
   - Бинарники Cargo (`~/.cargo/bin/`), кэши сборки (`.global-cache`, `.package-cache*`), роли Ansible (`.ansible/`) занесены в `.gitignore`.
   - Не добавляйте большие бинарные файлы или дампы памяти в репозиторий.
3. **История команд:**
   - Файлы истории shell хранятся по стандарту XDG в `~/.local/state/zsh/history` и никогда не попадают в систему контроля версий.

---

## 💎 7. Золотые правила для AI-агентов (UX & Quality Checklist)

- [ ] **Не ломайте симлинки Chezmoi:** Конфигурации в `~/.config/...` развернуты как симлинки на `/data/projects/dotfiles/home/...` (`mode = "symlink"`). Изменения вносятся либо через Neovim напрямую (симлинк прозрачен), либо в файл исходника репозитория. Никогда не заменяйте симлинк регулярным файлом вручную!
- [ ] **Все скрипты автоматизации строго в dotfiles:** Никаких разовых скриптов в `~/.local/bin/` или вне репозитория! Все пользовательские CLI-утилиты, хелперы для Niri и скрипты автоматизации создаются в `home/dot_zsh/scripts/`, имеют права `+x`, разворачиваются через Chezmoi и коммитятся в Git.
- [ ] **Никаких секретов напрямую — только `mise.local.toml`:** Все чувствительные переменные, токены и приватные настройки выносятся строго в `mise.local.toml` (с добавлением в `.gitignore`), запрещено писать секреты открытым текстом в репозиторий.
- [ ] **Соблюдайте тему оформления:** Единый визуальный стиль системы — **Catppuccin Frappe**. Все новые терминальные утилиты, темы SDDM, Limine, Ghostty и Neovim должны соответствовать этой палитре.
- [ ] **Сохраняйте целостность кэшей:** Не меняйте пути кэшей в `setup_user.yml`, так как они завязаны на Dual-NVMe разметку дисков.
- [ ] **Оптимизация контекста через Headroom:** При анализе объемных терминальных выводов, логов сборки или результатов масштабного поиска (>100 строк) используйте MCP-инструмент `headroom_compress` для сжатия контекста с сохранением оригинала (CCR).
- [ ] **Никакой неявной инъекции памяти в Headroom:** Не включайте флаг `--memory` в Headroom Proxy. Извлечение заметок и памяти должно выполняться исключительно осознанными вызовами инструментов (Khoj MCP, `search_files`) во избежание зависаний SSE и "отравления контекста" (Context Poisoning).
- [ ] **Контроль бюджета vRAM (16 ГБ):** Не запускайте конкурирующие серверы инференса (vLLM) параллельно с Ollama. Модели инференса и эмбеддингов (`bge-m3:latest`) обслуживаются сервисом `ollama.service` с лимитом `OLLAMA_MAX_LOADED_MODELS=1`.
- [ ] **Декларативность моделей AI:** Все локальные модели Ollama объявляются в `ai-dotfiles/infra/playbooks/setup_ollama.yml`.
- [ ] **Защитное программирование MCP:** При реализации или обновлении MCP-инструментов обеспечьте Zod-валидацию аргументов и осмысленные подсказки со списком доступных инструментов (`available_tools`) для самокоррекции моделей 14B.
- [ ] **Осторожность с дисками:** Никогда не запускайте скрипты разметки диска (`playbooks/setup_system.yml`, `scripts/patrition_delete.sh`) без явного указания и подтверждения от пользователя.
- [ ] **Проверяйте работоспособность:** Перед отчетом пользователю о завершении задачи выполните синтаксическую валидацию или `scripts/check_setup.sh`, а для AI-сервисов — `mise run ai:status`.



