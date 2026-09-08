# 🤖 AGENTS.md — Руководство для AI-агентов по работе с репозиторием

> **Цель документа:** Обеспечить AI-агентам и разработчикам мгновенную ориентацию в репозитории dotfiles для **CachyOS (Niri)**, а также зафиксировать архитектурные стандарты, практики DevOps/GitOps и правила внесения изменений для максимального удобства и целостности системы (UX/DX Flow).

---

## 📌 1. Обзор проекта и архитектура

Данный репозиторий представляет собой декларативную систему автоматизированного развертывания и управления окружением (Infrastructure-as-Code для локальной рабочей станции):
- **ОС:** CachyOS (оптимизированный Arch Linux под x86-64-v3/v4).
- **Оконный менеджер / Композитор:** Niri (scrollable-tiling Wayland композитор с конфигурацией на KDL).
- **Автоматизация установки:** Bash-бутстрапперы (`setup_system.sh`, `setup_user.sh`) и модульные Ansible-плейбуки (`playbooks/`).
- **Управление конфигурациями:** **GNU Stow** (симлинки из репозитория в `$HOME`).
- **Стек разработки:** Rust (`rustup`, `mold`, `sccache`), TypeScript/Node (`mise`, `pnpm`, `biome`), Python (`uv`), Cloud-Native & DevOps (`k3d`, `kubectl`, `k9s`, `helm`, `argocd`, `sops`, `age`, `distrobox`, `docker`), QEMU/KVM (`libvirt`, `virtio-fs`).
- **Аппаратная архитектура хранения:** Оптимизированный двухдисковый Dual-NVMe сетап с распределением файловых систем (Btrfs zstd, XFS prjquota, ext4 noatime).

---

## 🗂 2. Ментальная карта структуры проекта

```
dotfiles/
├── setup_system.sh              # [Root] Системный бутстраппер (диски, системные пакеты, SDDM/Limine)
├── setup_user.sh                # [User] Пользовательский бутстраппер (AUR, stow, mise, rust, timers)
├── check.sh                     # Диагностика Docker XFS / prjquota / storage
├── check_setup.sh               # Полная валидация окружения (точки монтирования, кэши, symlinks)
├── patrition_delete.sh          # ⚠️ ДЕСТРУКТИВНЫЙ скрипт очистки /dev/nvme1n1 (не запускать без спроса!)
├── setup_wallpaper_engine.sh    # Утилита настройки динамических обоев
├── mise.toml                    # Корневые задачи сборки проекта (mise run build:skills)
├── lefthook.yml                 # Git хуки автоматической компиляции TS-скиллов
│
├── playbooks/                   # Модульные Ansible-плейбуки
│   ├── vars/
│   │   └── packages.yml         # 🌟 SINGLE SOURCE OF TRUTH для всех устанавливаемых пакетов
│   ├── packages.yml             # Плейбук установки (теги: system, user, aur, cargo)
│   ├── setup_system.yml         # Разметка NVMe 1, создание FS, fstab, Docker, KVM
│   ├── setup_user.yml           # Применение Stow, настройка кэшей, каталогов, user services
│   ├── setup_display_manager.yml# Catppuccin тема для SDDM и Limine, multi-monitor
│   ├── setup_rust.yml           # Изолированный быстрый Rust-тулчейн (mold, sccache, cargo-binstall)
│   ├── setup_gaming.yml         # Gaming-стек CachyOS, Proton/NVIDIA, symlink библиотеки Steam
│   ├── setup_virt.yml           # QEMU/KVM/libvirt, swtpm, UFW правила, Virtio-FS /srv/Shared
│   ├── setup_rclone.yml         # Systemd user unit + timer для bisync Obsidian в Google Drive
│   ├── setup_cooler_control.yml # Профили охлаждения и кривые вентиляторов
│   └── setup_anythingllm.yml    # AnythingLLM Desktop, Headroom LLM proxy, MCP серверы, TS-скиллы, Obsidian
│
├── .agents/plugins/headroom/    # Antigravity плагин и MCP конфигурация Headroom

├── docs/                        # Документация и траблшутинг (headroom_anythingllm_troubleshooting.md, virt.md, vivaldi.md)
├── scripts/                     # Вспомогательные скрипты развертывания VM и тем
│
└── [GNU Stow Пакеты]            # Каждый каталог ниже зеркалирует структуру $HOME
    ├── zsh/                     # ~/.zshrc, ~/.zshenv, ~/.zprofile, ~/.zsh/ (alias, binds, scripts: единое место для CLI-скриптов и автоматизаций)
    ├── niri/                    # ~/.config/niri/ (config.kdl + модули в cfg/)
    ├── nvim/                    # ~/.config/nvim/ (LazyVim конфигурация, stylua, lua/)
    ├── ghostty/                 # ~/.config/ghostty/ (терминал с поддержкой Wayland и Catppuccin)
    ├── starship/                # ~/.config/starship.toml (промпт со статусом Vi-mode)
    ├── atuin/                   # ~/.config/atuin/ (умная история команд с синхронизацией)
    ├── sheldon/                 # ~/.config/sheldon/ (быстрый менеджер Zsh плагинов на Rust)
    ├── mise/                    # ~/.config/mise/ (управление версиями runtimes: node, python, etc.)
    ├── cargo/                   # ~/.cargo/config.toml (глобальный cargo config: mold, sccache)
    ├── hypr/                    # ~/.config/hypr/ (hypridle, hyprlock для сессии Wayland)
    ├── k3d/                     # ~/.config/k3d/ (конфигурация локального кластера K8s)
    ├── k9s/                     # ~/.config/k9s/ (конфиги и скин терминального UI для Kubernetes)
    ├── rofi/                    # ~/.config/rofi/ (лаунчер приложений Wayland)
    ├── superfile/               # ~/.config/superfile/ (современный файловый TUI менеджер)
    ├── television/              # ~/.config/television/ (быстрый fuzzy-finder / previewer)
    ├── vivaldi/                 # ~/.config/vivaldi-stable.conf (флаги Wayland/GPU)
    ├── wireplumber/             # ~/.config/wireplumber/ (скрипты маршрутизации аудио)
    ├── anythingllm/             # ~/.config/anythingllm-desktop/ (MCP серверы, TS-скиллы, воркспейсы, промпты)
    ├── antigravity/             # ~/.gemini/config/ (глобальные правила и скиллы Antigravity)
    ├── noctalia/                # ~/.config/noctalia/ (Noctalia Shell: бар, лаунчер, OSD, темы, виджеты)
    └── zellij/                  # ~/.config/zellij/ (терминальный мультиплексор)
```

---

## ⚙️ 3. Ключевые архитектурные принципы

### 1. GitOps & DevOps (Idempotence & Single Source of Truth)
- **Single Source of Truth для пакетов:** Все пакеты (Pacman, AUR, Cargo, CLI) декларируются **исключительно** в [`playbooks/vars/packages.yml`](file:///home/gidragir/projects/dotfiles/playbooks/vars/packages.yml). Не добавляйте вызовы `pacman -S` или `paru -S` напрямую в таски или скрипты без крайней необходимости.
- **Идемпотентность:** Все плейбуки и bash-скрипты должны быть безопасны для многократного повторного запуска. Не используйте `command:` / `shell:` в Ansible без `creates:`, `changed_when:` или проверок состояния через `stat`.
- **Разделение привилегий:**
  - **System (Root):** Запускается через `sudo`, отвечает за блочные устройства, `/etc/fstab`, системные пакеты, udev, SDDM, system systemd-юниты.
  - **User (Non-Root):** Запускается от обычного пользователя. AUR-хелпер (`paru` через модуль `kewlfft.aur`) **категорически запрещено** запускать из-под root! Пользовательские юниты systemd настраиваются со `scope: user`.

### 2. Модель управления конфигурациями через GNU Stow
Репозиторий dotfiles располагается в `/data/projects/dotfiles` (с симлинком в `~/projects/dotfiles`).
Каждая конфигурация приложения оформлена как отдельный пакет Stow, путь внутри которого зеркалит относительный путь от `$HOME`:
- `niri/.config/niri` → раскладывается в `~/.config/niri`
- `zsh/.zshrc` → раскладывается в `~/.zshrc`
- `cargo/.cargo/config.toml` → раскладывается в `~/.cargo/config.toml`

**Правила работы со Stow:**
- Для применения конфигурации:
  ```bash
  cd ~/projects/dotfiles
  stow -t ~ <package-name>
  ```
- Для удаления симлинков:
  ```bash
  stow -D -t ~ <package-name>
  ```
- Для повторной перелинковки (restow):
  ```bash
  stow -R -t ~ <package-name>
  ```
- В `playbooks/setup_user.yml` перед запуском `stow` выполняется превентивное удаление конфликтующих стандартных файлов (которые часто создаются пакетными менеджерами при установке программ), чтобы избежать ошибок `stow: target already exists`.

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
- **Композитор Niri:** Модульная конфигурация в `niri/.config/niri/cfg/*.kdl`. Оконные правила (`rules.kdl`) изолируют настройки, правила автозапуска лежат в `autostart.kdl`.
- **Централизация скриптов автоматизации:** Все кастомные shell-скрипты, оконные хелперы (например, переключение/вызов окон в Niri), CLI-утилиты и скрипты интеграций хранятся **исключительно** в `zsh/.zsh/scripts/`. Каталог `~/.zsh/scripts` автоматически экспортируется в `$PATH` через `.zshenv`. Категорически запрещено создавать изолированные loose-скрипты в `~/.local/bin/` или вне репозитория dotfiles.

---

## 🚀 4. Инструкция по установке и тестированию

### Системный этап (Root)
Запускается на чистой системе CachyOS:
```bash
sudo bash setup_system.sh
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
bash setup_user.sh
```
Что делает:
1. Устанавливает коллекцию `kewlfft.aur` в Ansible Galaxy.
2. Ставит официальные и AUR пакеты, а также Cargo-утилиты через `cargo binstall`.
3. Настраивает симлинки проектов и применяет все пакеты Stow.
4. Настраивает структуру кэшей Rust, pnpm, uv.
5. Запускает фоновый таймер rclone для Obsidian (`setup_rclone.yml`).

### Проверка корректности окружения (Health Checks)
После установки или внесения инфраструктурных изменений обязательно запустите диагностические скрипты:
```bash
# 1. Проверка пользовательского окружения, кэшей и монтирования:
bash check_setup.sh

# 2. Проверка Docker-хранилища, XFS ftype и prjquota:
sudo bash check.sh
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

### Сценарий B: Добавление новой конфигурации программы (Stow Package)
Если вы настраиваете новую программу, например `ripgrep` или `tmux`:
1. Создайте каталог в корне репозитория с именем программы:
   ```bash
   mkdir -p mytool/.config/mytool
   ```
2. Разместите файлы конфигурации внутри так, чтобы путь относительно корня пакета повторял путь внутри домашней директории пользователя:
   `dotfiles/mytool/.config/mytool/config` → `~/.config/mytool/config`.
3. Добавьте удаление конфликтующего дефолтного файла/директории в таску `Remove existing config files to avoid stow conflicts` плейбука [`playbooks/setup_user.yml`](file:///home/gidragir/projects/dotfiles/playbooks/setup_user.yml).
4. Протестируйте линковку:
   ```bash
   stow -nv -t ~ mytool    # Dry-run (проверка на коллизии)
   stow -t ~ mytool       # Применение
   ```
5. Обновите список в [`README.md`](file:///home/gidragir/projects/dotfiles/README.md).

### Сценарий C: Изменение настроек Niri (Wayland композитор)
Конфигурация Niri декомпозирована в [`niri/.config/niri/cfg/`](file:///home/gidragir/projects/dotfiles/niri/.config/niri/cfg):
- `keybinds.kdl`: Горячие клавиши (используйте существующие соглашения `Mod+...`).
- `rules.kdl`: Правила для окон (floating, geometry-corner-radius, maximized-to-edges).
- `autostart.kdl`: Фоновые демоны (панели, буфер обмена `cliphist`, обои).
- `display.kdl`: Разрешение и частота мониторов (DP-2, HDMI-A-1).
- `env/`: Локальные оверрайды для конкретной рабочей машины.

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
1. **Единый каталог размещения:** Создавайте файл строго внутри `zsh/.zsh/scripts/<script-name>.sh` (или без расширения).
2. **Права на выполнение:** Всегда выставляйте флаг исполняемости:
   ```bash
   chmod +x zsh/.zsh/scripts/<script-name>.sh
   ```
3. **Обновление линков:** Примените Stow для пакета `zsh`:
   ```bash
   stow -R -t ~ zsh
   ```
4. **Интеграция с Niri / горячими клавишами:** В `niri/.config/niri/cfg/keybinds.kdl` привязывайте скрипт через:
   ```kdl
   Mod+<Key> { spawn "bash" "-c" "~/.zsh/scripts/<script-name>.sh"; }
   ```
   Либо через `spawn-sh "<script-name>.sh";` (так как `~/.zsh/scripts` находится в `$PATH`).
5. **Запрет на unmanaged loose scripts:** Категорически запрещено создавать локальные скрипты в `~/.local/bin/` или `~` в обход репозитория. Любая автоматизация должна быть частью Stow-пакета `zsh` и закоммичена в Git.

---

## 🛡️ 6. Гигиена репозитория и безопасность

1. **Никаких секретов в Git:**
   - Категорически запрещено коммитить приватные SSH ключи (`~/.ssh/id_*`), GPG/age ключи, `rclone.conf`, токены API и пароли.
   - Для управления секретами используются `sops` и `age`.
   - Локальные переменные окружения выносятся в `.zshenv.local` или `*.local` (игнорируются в Git).
2. **Артефакты сборки и кэши:**
   - Бинарники Cargo (`cargo/.cargo/bin/`), кэши сборки (`.global-cache`, `.package-cache*`), роли Ansible (`.ansible/`) занесены в `.gitignore`.
   - Не добавляйте большие бинарные файлы или дампы памяти в репозиторий.
3. **История команд:**
   - Файлы истории shell хранятся по стандарту XDG в `~/.local/state/zsh/history` и никогда не попадают в систему контроля версий.

---

## 💎 7. Золотые правила для AI-агентов (UX & Quality Checklist)

- [ ] **Не ломайте симлинки Stow:** Никогда не редактируйте файлы напрямую в `~/.config/...`, если это симлинк! Всегда вносите изменения в исходный файл в `/data/projects/dotfiles/...`.
- [ ] **Все скрипты автоматизации строго в dotfiles:** Никаких разовых скриптов в `~/.local/bin/` или вне репозитория! Все пользовательские CLI-утилиты, хелперы для Niri и скрипты автоматизации создаются в `zsh/.zsh/scripts/`, имеют права `+x`, линкуются через Stow и коммитятся в Git.
- [ ] **Соблюдайте тему оформления:** Единый визуальный стиль системы — **Catppuccin Frappe**. Все новые терминальные утилиты, темы SDDM, Limine, Ghostty и Neovim должны соответствовать этой палитре.
- [ ] **Сохраняйте целостность кэшей:** Не меняйте пути кэшей в `setup_user.yml`, так как они завязаны на Dual-NVMe разметку дисков.
- [ ] **Оптимизация контекста через Headroom:** При анализе объемных терминальных выводов, логов сборки или результатов масштабного поиска (>100 строк) используйте MCP-инструмент `headroom_compress` для сжатия контекста с сохранением оригинала (CCR).
- [ ] **Осторожность с дисками:** Никогда не запускайте скрипты разметки диска (`setup_system.yml`, `patrition_delete.sh`) без явного указания и подтверждения от пользователя.
- [ ] **Ведение базы грабель и траблшутинга:** При обнаружении скрытых багов, специфичных нюансов API или интеграций (AnythingLLM, Ollama, Headroom, Niri) обязательно фиксируйте и пополняйте документацию в [`docs/headroom_anythingllm_troubleshooting.md`](file:///data/projects/dotfiles/docs/headroom_anythingllm_troubleshooting.md), чтобы предотвращать повторные ошибки в будущем.
- [ ] **Проверяйте работоспособность:** Перед отчетом пользователю о завершении задачи выполните синтаксическую валидацию или `check_setup.sh`.


