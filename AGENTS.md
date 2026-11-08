# 🤖 AGENTS.md — Руководство для AI-агентов по работе с репозиторием

> **Цель документа:** Обеспечить AI-агентам и разработчикам мгновенную ориентацию в репозитории dotfiles для **CachyOS (Niri)**, а также зафиксировать архитектурные стандарты, практики DevOps/GitOps и правила внесения изменений для максимального удобства и целостности системы (UX/DX Flow).

---

## 📌 1. Обзор проекта и архитектура

Данный репозиторий представляет собой декларативную систему автоматизированного развертывания и управления окружением (Infrastructure-as-Code для локальной рабочей станции):
- **ОС:** CachyOS (оптимизированный Arch Linux под x86-64-v3/v4).
- **Оконный менеджер / Композитор:** Niri (scrollable-tiling Wayland композитор с конфигурацией на KDL).
- **Автоматизация и управление:** Декларативное управление через Yggdrasil (`ygg apply`) и задачи `mise` (`mise run ...`).
- **Управление конфигурациями:** **Yggdrasil (`ygg`)** (декларативное управление модулями, симлинки напрямую в `$HOME`, разделение по аппаратным скоупам `pc` и `asus`, процедурные хуки `setup.nu`).
- **Стек разработки:** Rust (`rustup`, `mold`, `sccache`), TypeScript/Node (`mise`, `pnpm`, `biome`), Python (`uv`), Cloud-Native & DevOps (`k3d`, `kubectl`, `k9s`, `helm`, `argocd`, `sops`, `age`, `distrobox`, `docker`), QEMU/KVM (`libvirt`, `virtio-fs`).
- **Аппаратная архитектура хранения:** Оптимизированный двухдисковый Dual-NVMe сетап с распределением файловых систем (Btrfs zstd, XFS prjquota, ext4 noatime).

---

## 🗂 2. Ментальная карта структуры проекта

```
dotfiles/
├── ygg.toml                     # Идентификатор модуля и поддерживаемые ОС (cachyos, arch)
├── links.toml                   # Сопоставления симлинков и скоупы ([scope.pc.links], [scope.asus.links])
├── packages.toml                # Декларативные списки пакетов (pacman, paru, cargo, scopes)
├── setup.nu                     # Процедурный хук жизненного цикла (MIME apps, кэши, сервисы)
├── secrets.example.toml         # Шаблон хостовых секретов для ~/.ygg/secrets.toml
├── niri/                        # ~/.config/niri (config.kdl, noctalia.kdl, cfg/*.kdl)
│   └── displays/                # Конфигурации дисплеев (pc.kdl, asus.kdl)
├── noctalia/                    # ~/.config/noctalia (config.toml, plugins/)
├── rofi/                        # ~/.config/rofi (cliphist, main, noctalia.rasi)
├── systemd/                     # ~/.config/systemd/user (openrgb, rclone)
├── vivaldi/                     # ~/.config/vivaldi-stable.conf
│   └── vivaldi-stable.conf
├── wallpaper-engine/            # ~/.config/wallpaper-engine (config.json)
├── waypaper/                    # ~/.config/waypaper (config.ini)
├── wireplumber/                 # ~/.config/wireplumber (SPA-JSON 0.5 правила)
├── zsh/                         # ~/.zsh/
│   ├── alias/                   # Базовые алиасы (core, git, k8s)
│   ├── alias-pc/                # Аппаратные алиасы (cooler.zsh)
│   ├── scripts/                 # Пользовательские скрипты автоматизации
│   └── scripts-pc/              # Аппаратные скрипты (cooler-toggle.sh)
├── scripts/                     # Вспомогательные скрипты хоста (mise run ...)
├── playbooks/                   # Ондеманд-плейбуки (gaming, virt, sddm, net) и архив (playbooks/archive/)
├── tests/                       # Тесты инфраструктуры (e2e_virt_manager_test.sh)
├── mise.toml                    # Задачи сборки и проверки окружения
└── lefthook.yml                 # Git хуки качества и линтинга
```

---

## ⚙️ 3. Ключевые архитектурные принципы

### 1. GitOps & DevOps (Idempotence & Single Source of Truth)
- **Single Source of Truth для пакетов:** Все пакеты (Pacman, AUR, Cargo, CLI) декларируются **исключительно** в [`playbooks/vars/packages.yml`](file:///home/gidragir/projects/dotfiles/playbooks/vars/packages.yml). Не добавляйте вызовы `pacman -S` или `paru -S` напрямую в таски или скрипты без крайней необходимости.
- **Идемпотентность:** Все плейбуки и bash-скрипты должны быть безопасны для многократного повторного запуска. Не используйте `command:` / `shell:` в Ansible без `creates:`, `changed_when:` или проверок состояния через `stat`.
- **Разделение привилегий:**
  - **System (Root):** Запускается через `sudo`, отвечает за блочные устройства, `/etc/fstab`, системные пакеты, udev, SDDM, system systemd-юниты.
  - **User (Non-Root):** Запускается от обычного пользователя. AUR-хелпер (`paru` через модуль `kewlfft.aur`) **категорически запрещено** запускать из-под root! Пользовательские юниты systemd настраиваются со `scope: user`.
- **Инвариант неприкосновенности симлинков Yggdrasil в Ansible (Anti-Overwrite Invariant):**
  - Категорически запрещено использовать `ansible.builtin.copy`, `ansible.builtin.template` или `ansible.builtin.ini_file` для путей, управляемых Yggdrasil через `links.toml` (например, `~/.config/systemd/user/*`, `~/.config/niri/*`, `~/.zsh/alias/*`).
  - Копирование файлов поверх симлинков заменяет их на физические копии хоста, вызывая дрейф и ломая обратную связь с репозиторием.
  - Ansible отвечает строго за низкоуровневые системные задачи (разметка NVMe, fstab, udev, SDDM, systemd-юниты с `scope: system`) и вызывает `ygg apply` для развёртывания пользовательских файлов.

### 2. Модель управления конфигурациями через Yggdrasil (`ygg`)
Репозиторий dotfiles располагается в `/data/projects/dotfiles` (с симлинком в `~/projects/dotfiles`).
Управление конфигурациями рабочей станции переведено на декларативный кроссплатформенный менеджер модулей **Yggdrasil (`ygg`)** на базе Nushell:
- **Структура модуля dotfiles:**
  - `ygg.toml`: Идентификатор модуля, поддерживаемые платформы (`os = ["cachyos", "arch"]`).
  - `links.toml`: Декларация развертывания симлинков (`[links]`) и аппаратных скоупов (`[scope.pc.links]`, `[scope.asus.links]`). Симлинки разворачиваются напрямую из репозитория без шаблонизаторов.
  - `packages.toml`: Декларация пакетов по менеджерам (`pacman`, `paru`, `cargo`) с аппаратным разделением скоупов (`[scope.pc.packages]`, `[scope.asus.packages]`).
  - `setup.nu`: Идемпотентный процедурный хук жизненного цикла (настройка MIME-типов для Neovim в `mimeapps.list`, подготовка кэшей, активация systemd-таймеров и сервисов OpenRGB).
- **Многоуровневое разделение (L-Core vs L-Host):**
  - **L-Core (`omni-dotfiles`):** Базовые CLI/TUI инструменты и общий шелл (`nvim`, `ghostty`, `sheldon`, `bat`, `fzf`, `rtk`, `television`, `superfile`, `zshrc`, `zshenv`, `mise`).
  - **L-Host CachyOS (`dotfiles`):** Графическое окружение и аппаратный стек рабочей станции (`niri`, `noctalia`, `rofi`, `wireplumber`, `hypridle`, `OpenRGB`, `waypaper`, `wallpaper-engine`, `zsh/alias`, `zsh/scripts`, сервисы systemd).
- **Изоляция и аудит зависимостей `ai-dotfiles`:**
  - Развертывание скриптов через глоб `zsh/scripts/*` гарантирует сохранение всех симлинков AI-стека (`ai-status.sh`, `hermes-*.sh`, `khoj-*.sh`), разворачиваемых независимо через GNU Stow из `/data/projects/ai-dotfiles`.
  - Запрещено удалять или затирать симлинки скриптов AI-стека в `~/.zsh/scripts/`.
  - Файл `~/.config/environment.d/pythonpath.conf` является обязательным инвариантом Hermes (`/opt/hermes-agent/venv`, Python 3.11) и не подлежит удалению.
- **Инвариант гранулярности симлинков (Hybrid Directory vs Monolithic Linking):**
  - Если целевая директория приложения на хосте содержит динамическое runtime-состояние (`Configuration.json`, базы данных, профили, кэши, маркеры состояния), **КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО** объявлять в `links.toml` симлинк на всю директорию целиком (например, `"OpenRGB" = "~/.config/OpenRGB"`).
  - В гибридных директориях развертывание обязано быть строго **пофайловым** (например, `"OpenRGB/off.orp" = "~/.config/OpenRGB/off.orp"`). Это сохраняет физическую директорию со всеми локальными данными на хосте и подселяет внутрь версионируемый файл.
  - Монолитный симлинк директории разрешен ТОЛЬКО если вся директория является 100% декларативной (как `niri`, `rofi`, `waypaper`, `wireplumber`).
- **Инвариант предвалидации источников (Zero Broken Links Pre-flight Invariant):**
  - Перед добавлением любого сопоставления в `links.toml` агент **ОБЯЗАН** проверить физическое существование `source` пути внутри каталога модуля (`test -e <module>/<source>`).
  - Запрещено объявлять пути в `links.toml` «на будущее» или с опечатками: Yggdrasil вытеснит существующий каталог хоста в бэкап и оставит битый симлинк.

**Команды работы с Ygg:**
- Проверка статуса синхронизации модулей:
  ```bash
  ygg status
  ```
- Применение конфигурации:
  ```bash
  ygg apply
  ```
- Проверка дрифта и симуляция изменений (Dry-Run):
  ```bash
  ygg apply -n
  ```
- **Протокол тестирования в изолированной песочнице (Zero Host Mutation):**
  - Движок Yggdrasil требует явного задания `YGG_HOME` при использовании `--sandbox` во избежание мутации рабочего `~/.ygg/host.toml` и кэшей хоста.
  - Канонический шаблон тестирования в песочнице (Nushell):
    ```bash
    rtk nu -c '
    let sandbox = (mktemp -d -t verify-sandbox-XXXXXX)
    let ygg_home = $"($sandbox)/.ygg"
    mkdir $"($ygg_home)/modules"
    ^ln -s /data/projects/dotfiles $"($ygg_home)/modules/dotfiles"
    "[[modules]]\nname = \"dotfiles\"\nscopes = [\"pc\"]\n" | save -f $"($ygg_home)/host.toml"

    with-env { YGG_HOME: $ygg_home, YGG_SANDBOX: $sandbox } {
        ^ygg apply --sandbox $sandbox --skip-packages
    }
    rm -rf $sandbox
    '
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
- **Композитор Niri:** Модульная конфигурация в `niri/cfg/*.kdl`. Оконные правила (`rules.kdl`) изолируют настройки, правила автозапуска лежат в `autostart.kdl`.
- **Централизация скриптов автоматизации и паттерн изоляции системных утилит:**
  - Все кастомные shell-скрипты, оконные хелперы (например, переключение/вызов окон в Niri), CLI-утилиты и скрипты интеграций хранятся **исключительно** в `zsh/scripts/`. Каталог `~/.zsh/scripts` автоматически экспортируется в `$PATH` через `.zshenv`. Категорически запрещено создавать изолированные loose-скрипты в `~/.local/bin/` или вне репозитория dotfiles.
  - **Паттерн системных оберток (System Python / Tool Isolation):** Системные GUI/CLI утилиты с шебангом `#!/usr/bin/env python3` (`virt-manager` и др.), зависящие от модулей дистрибутива (`python-gobject`/`gi`), ломаются при перехвате пользовательскими средами `mise`/`pyenv`. Для устранения конфликтов создается декларативная обертка в `zsh/scripts/<tool>`:
    - Сбрасываются переменные виртуальных окружений (`unset VIRTUAL_ENV PYTHONHOME`).
    - Производится вызов строго через системный бинарник: `exec /usr/bin/python3 /usr/bin/<tool> "$@"`.
    - Применяется через `ygg apply`.
    - Запрещено модифицировать пакетные файлы дистрибутива в `/usr/bin/` или ломать глобальный конфигурационный профиль `mise` без прямой необходимости.

### 5. Персональный AI-стек и трехуровневая архитектура моделей
Единая декларативная AI-инфраструктура хоста вынесена в репозиторий [`ai-dotfiles`](file:///data/projects/ai-dotfiles):
- **Три рабочих контура:**
  1. *Терминальный контур:* OpenCommit напрямую через локальный `ollama` (`qwen2.5:14b-ctx64k` на `:11434`), CLI `gcai` (`~/.local/bin/gcai`: `git add -p && opencommit`).
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
  - **Systemd Targets & Ordering Cycles:** Пользовательские юниты `openrgb.service` и `openrgb-profile.service` должны привязываться строго к `graphical-session.target`. При этом `openrgb-profile.service` обязан содержать `After=openrgb.service graphical-session.target` во избежание ordering cycle (`job deleted to break ordering cycle`) при логине.
  - **Восстановление ARGB-зон при апгрейде OpenRGB:** При обновлении версий OpenRGB (например, 1.0 -> 1.1) в `~/.config/OpenRGB/Configuration.json` возможна дубликация контроллера материнской платы с обнулением светодиодов зон 2 и 3 (вентиляторы и кастомная лента). Восстановление требует единовременного задания размеров через CLI (`-z 1 -sz 60 -z 2 -sz 60 -z 3 -sz 60`) и дедупликации `Configuration.json`.
  - **Изоляция аргументов в CLI OpenRGB:** Опции `-z` (зоны) внутри одного вызова `openrgb` загрязняют последующие устройства в цепочке `-d`. Категорически запрещено передавать временные размеры зон (`-sz`) или `-z` внутри регулярной смены цвета в `devices.conf` / `devices.sh`. Размеры ARGB-заголовков материнской платы персистентно хранятся в `Configuration.json`.
  - **Zombie-дескрипторы после сна (Hotplug Limit):** Демон `openrgb --server` не имеет udev hotplug-монитора. При сне ПК или USB-ресбросе ядро удаляет старые ноды (`/dev/hidraw2 (deleted)`) и создает новые (`/dev/hidraw3`). Для исключения отправки команд в мертвые дескрипторы используется:
    1. Автоматический self-healing в `devices.sh` (`_heal_stale_openrgb()`, проверяющий `/proc/<pid>/fd/` на `hidraw.*deleted`).
    2. Системный sleep-хук `/usr/lib/systemd/system-sleep/openrgb-resume` (из `playbooks/setup_system.yml`), перезапускающий `openrgb.service` при выходе из сна.

### 7. Сетевая архитектура, Bufferbloat и инварианты Ansible QoS
- **Принцип модульности сетевых оптимизаций:**
  - Сетевые тюнинги ядра, шейпинг полосы и QoS-политики изолируются в отдельном плейбуке [`playbooks/setup_network_optimization.yml`](file:///home/gidragir/projects/dotfiles/playbooks/setup_network_optimization.yml). Их жесткое включение в базовые бутстрапперы (`setup_system.yml` / `setup_user.yml`) запрещено, так как такие настройки требуются опционально.
  - Плейбук обязан гранулярно поддерживать теги `apply` и `revert` без навязывания тегов на уровне плеев (во избежание ложного наследования).
- **Инварианты Systemd Drop-in Overrides:**
  - При переопределении списковых директив сервисов (`ExecStart`) и таймеров (`OnBootSec`) в drop-in файлах (`override.conf`) первым шагом **всегда** идет сброс директивы пустым значением (`ExecStart=`, `OnBootSec=`), иначе systemd выполнит оба вызова последовательно.
  - Исходные пакетные юниты CachyOS в `/usr/lib/systemd/` не редактируются напрямую — изменения вносятся строго через drop-in в `/etc/systemd/system/*.d/`.
- **Инварианты TCP BBR и Idempotent Sysctl:**
  - Назначение `net.ipv4.tcp_congestion_control = bbr` в плейбуках всегда предваряется проверкой доступности алгоритма через чтение `/proc/sys/net/ipv4/tcp_available_congestion_control`.
  - При откате на CUBIC (`sysctl -w net.ipv4.tcp_congestion_control=cubic`) обязателен guard-контроль текущего состояния из `/proc/sys/net/ipv4/tcp_congestion_control` во избежание ложного `changed` статуса.
- **Изоляция фоновых служб от домашней сети:**
  - Таймеры ресурсоемких системных бенчмарков (`cachyos-rate-mirrors.timer`) обязаны иметь `Persistent=false`, чтобы исключить всплеск параллельных сетевых запросов при загрузке ПК.
  - Периодические задачи облачной синхронизации (`rclone bisync`) обязаны запускаться с задержкой после логина (`OnBootSec=10m`) и иметь жесткий лимит полосы отдачи (`--bwlimit 10M`), предотвращающий насыщение очередей роутера.

---

## 🚀 4. Инструкция по установке и тестированию

### Системный и ондеманд-этап (Mise + Ansible)
Тяжелые опциональные окружения и задачи с правами root вынесены в ондеманд-задачи `mise`:
```bash
# Игровой стек (Steam, Lutris, cachyos-gaming-meta, /data/games):
mise run setup:gaming

# Виртуализация (KVM/QEMU, libvirt, virt-manager, сети):
mise run setup:virt

# Аппаратный контроллер вентиляторов CoolerControl (демон и профили):
mise run setup:cooler-control

# Дисплейный менеджер SDDM (DP-2, Catppuccin) и стилизация Limine:
mise run setup:sddm

# Wallpaper Engine (AUR linux-wallpaperengine-git + Steam Workshop):
mise run setup:wallpaper-engine

# Оптимизация сети (TCP BBR, FQ-CoDel, rate-mirrors):
mise run net:optimize
```
Исторические плейбуки первичной подготовки накопителей и бутстрапа сохранены в `playbooks/archive/` (`setup_system.yml`, `setup_user.yml`, `setup_rust.yml`).

### Развертывание и синхронизация (Yggdrasil)
Конфигурация применяется декларативно:
```bash
# Статус модулей:
ygg status

# Предпросмотр изменений (dry-run):
ygg apply -n

# Применение конфигурации и установка пакетов:
ygg apply
```

### Проверка корректности окружения (Health Checks)
После внесения инфраструктурных изменений запустите диагностические задачи:
```bash
# 1. Проверка Docker-хранилища, XFS ftype и prjquota:
mise run docker:check

# 2. Комплексная проверка AI-стека (Ollama, Headroom, Khoj, Postgres):
mise -C /data/projects/ai-dotfiles run status
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

### Сценарий B: Добавление новой конфигурации программы (Yggdrasil)
Если вы настраиваете новую программу, например `hypridle` или `waypaper`:
1. Разместите файлы конфигурации внутри соответствующего каталога репозитория (например, `mytool/config`).
2. Объявите сопоставление в `links.toml`:
   ```toml
   "mytool" = "~/.config/mytool"
   ```
3. Примените конфигурацию:
   ```bash
   ygg apply
   ```
4. Проверьте отсутствие дрифта:
   ```bash
   ygg status
   ```
5. Обновите список в [`README.md`](file:///home/gidragir/projects/dotfiles/README.md).

### Сценарий C: Изменение настроек Niri (Wayland композитор)
Конфигурация Niri декомпозирована в [`niri/cfg/`](file:///home/gidragir/projects/dotfiles/niri/cfg):
- `keybinds.kdl`: Горячие клавиши (используйте существующие соглашения `Mod+...`).
- `rules.kdl`: Правила для окон (floating, geometry-corner-radius, maximized-to-edges).
- `autostart.kdl`: Фоновые демоны (панели, буфер обмена `cliphist`, обои).
- `display.kdl`: Разрешение и частота мониторов (линкуется через скоупы `pc` или `asus` из `niri/displays/`).
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
1. **Единый каталог размещения:** Создавайте файл строго внутри `zsh/scripts/<script-name>.sh` (или без расширения).
2. **Права на выполнение:** Всегда выставляйте флаг исполняемости:
   ```bash
   chmod +x zsh/scripts/<script-name>.sh
   ```
3. **Обновление линков:** Примените Yggdrasil:
   ```bash
   ygg apply
   ```
4. **Интеграция с Niri / горячими клавишами:** В `niri/cfg/keybinds.kdl` привязывайте скрипт через:
   ```kdl
   Mod+<Key> { spawn "bash" "-c" "~/.zsh/scripts/<script-name>.sh"; }
   ```
   Либо через `spawn-sh "<script-name>.sh";` (так как `~/.zsh/scripts` находится в `$PATH`).
5. **Запрет на unmanaged loose scripts:** Категорически запрещено создавать локальные скрипты в `~/.local/bin/` или `~` в обход репозитория. Любая автоматизация должна находиться в `zsh/scripts/`, управляться Yggdrasil и быть закоммичена в Git.

### Сценарий F: Управление и доработка AI-стека (Ollama, Khoj, Hindsight, Hermes)
Архитектура AI-инфраструктуры хоста сосредоточена в [`ai-dotfiles`](file:///data/projects/ai-dotfiles):
1. **Кастомные Modelfiles и модели Ollama:**
   - Все декларативные Modelfiles версионируются в `ai-dotfiles/infra/modelfiles/`.
   - Сборка и оверлеи выполняются через `mise run model:build:<name>`.
2. **Docker Compose стеки (Khoj, Hindsight):**
   - Конфигурации стеков хранятся в `ai-dotfiles/infra/stacks/` (`khoj`, `hindsight`).
   - Управление и статус проверяются через `mise -C /data/projects/ai-dotfiles run status`.
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

- [ ] **Не ломайте симлинки Yggdrasil:** Конфигурации в `~/.config/...` развернуты как симлинки на репозиторий через `links.toml`. Изменения вносятся либо через Neovim напрямую (симлинк прозрачен), либо в файл исходника репозитория. Никогда не заменяйте симлинк регулярным файлом вручную!
- [ ] **Все скрипты автоматизации строго в dotfiles:** Никаких разовых скриптов в `~/.local/bin/` или вне репозитория! Все пользовательские CLI-утилиты, хелперы для Niri и скрипты автоматизации создаются в `zsh/scripts/`, имеют права `+x`, разворачиваются через Yggdrasil (`ygg apply`) и коммитятся в Git.
- [ ] **Никаких секретов напрямую — только `mise.local.toml`:** Все чувствительные переменные, токены и приватные настройки выносятся строго в `mise.local.toml` (с добавлением в `.gitignore`), запрещено писать секреты открытым текстом в репозиторий.
- [ ] **Соблюдайте тему оформления:** Единый визуальный стиль системы — **Catppuccin Frappe**. Все новые терминальные утилиты, темы SDDM, Limine, Ghostty и Neovim должны соответствовать этой палитре.
- [ ] **Сохраняйте целостность кэшей:** Не меняйте пути кэшей в `setup_user.yml`, так как они завязаны на Dual-NVMe разметку дисков.
- [ ] **Оптимизация контекста через Headroom:** При анализе объемных терминальных выводов, логов сборки или результатов масштабного поиска (>100 строк) используйте MCP-инструмент `headroom_compress` для сжатия контекста с сохранением оригинала (CCR).
- [ ] **Никакой неявной инъекции памяти в Headroom:** Не включайте флаг `--memory` в Headroom Proxy. Извлечение заметок и памяти должно выполняться исключительно осознанными вызовами инструментов (Khoj MCP, `search_files`) во избежание зависаний SSE и "отравления контекста" (Context Poisoning).
- [ ] **Контроль бюджета vRAM (16 ГБ):** Не запускайте конкурирующие серверы инференса (vLLM) параллельно с Ollama. Модели инференса и эмбеддингов (`bge-m3:latest`) обслуживаются сервисом `ollama.service` с лимитом `OLLAMA_MAX_LOADED_MODELS=1`.
- [ ] **Декларативность моделей AI:** Все локальные модели Ollama объявляются в `ai-dotfiles/infra/playbooks/setup_ollama.yml`.
- [ ] **Защитное программирование MCP:** При реализации или обновлении MCP-инструментов обеспечьте Zod-валидацию аргументов и осмысленные подсказки со списком доступных инструментов (`available_tools`) для самокоррекции моделей 14B.
- [ ] **Осторожность с дисками:** Никогда не запускайте скрипты разметки диска (`playbooks/setup_system.yml`, `scripts/patrition_delete.sh`) без явного указания и подтверждения от пользователя.
- [ ] **Проверяйте работоспособность:** Перед отчетом пользователю о завершении задачи выполните синтаксическую валидацию или `mise run test:e2e`, а для AI-сервисов — `mise -C /data/projects/ai-dotfiles run status`.

---

## 📜 8. Инварианты разработки и правила кодинга (Behavioral & Coding Invariants)

### 1. Базовые принципы разработки (Core Behavioral Guidelines)
- **Think First:** Не делайте предположений и не скрывайте неясности. Фиксируйте допущения, задавайте вопросы при неопределенности и предлагайте компромиссы до реализации.
- **Simplicity First:** Минимальный код, решающий задачу. Никаких спекулятивных абстракций, избыточной гибкости и обработки невозможных сценариев. Если код можно написать в 50 строк вместо 200 — перепишите.
- **Surgical Changes:** Точечные изменения. Трогайте только то, что требуется задачей. Не «улучшайте» соседний код, форматирование или комментарии. Удаляйте только тот неиспользуемый код, который возник в результате ваших изменений; не удаляйте ранее существовавший неиспользуемый код без запроса.
- **Goal-Driven Execution:** Формулируйте проверяемые цели. Разбивайте многошаговые задачи на краткий план вида:
  ```text
  1. [Step] → verify: [check]
  2. [Step] → verify: [check]
  3. [Step] → verify: [check]
  ```
  Всегда проверяйте критерии успеха перед отчетом о завершении.

### 2. Antigravity & Workspace Topology Invariants
- **Корень кастомизаций:** Строго использовать `.agents/` для workspace-уровня (навыки, правила, плагины, база знаний). Категорически запрещено создавать или внедрять `.agent/`.
- **Локации скриптов:**
  - Системная диагностика и вспомогательные утилиты хоста: [`scripts/`](file:///home/gidragir/projects/dotfiles/scripts) (например, [`scripts/check.sh`](file:///home/gidragir/projects/dotfiles/scripts/check.sh), [`scripts/create_win11_vm.sh`](file:///home/gidragir/projects/dotfiles/scripts/create_win11_vm.sh)).
  - Пользовательский CLI и оконные хелперы Niri: [`zsh/scripts/`](file:///home/gidragir/projects/dotfiles/zsh/scripts) (управляются через Yggdrasil, развертываются в `~/.zsh/scripts/`).
- **Синхронизация документации (Doc Integrity):** Поддерживать [`README.md`](file:///home/gidragir/projects/dotfiles/README.md) и [`AGENTS.md`](file:///home/gidragir/projects/dotfiles/AGENTS.md) в строгой синхронизации с реальным деревом каталогов при перемещении или удалении файлов.

### 3. Shell, Scripting & CLI Invariants
- **Bash `set -e` Arithmetic Trap:** Категорически запрещено использовать `((VAR++))` или `((VAR+=1))` как самостоятельные инструкции в скриптах с `set -e` (если `VAR=0`, арифметическая оценка возвращает false и аварийно завершает скрипт). Всегда использовать `VAR=$((VAR + 1))`.
- **Безопасность флагов Ripgrep (`rg`):** Не передавать флаг `-E` в `rg` (в `rg` ключ `-E` означает `--encoding`). Утилита `rg` по умолчанию обрабатывает регулярные выражения без дополнительных флагов.
- **Иерархия скриптов и пути к плейбукам:** Скрипты в [`scripts/`](file:///home/gidragir/projects/dotfiles/scripts) обязаны вычислять `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` для обращения к [`playbooks/`](file:///home/gidragir/projects/dotfiles/playbooks), а не полагаться на `$SCRIPT_DIR/playbooks`.
- **Выравнивание тегов плейбуков:** Задачи, необходимые при установке пользовательского окружения, обязаны включать соответствующие теги (`[cli, aur, packages]`).
- **Запрет неуправляемых бинарников:** Не создавать скрипты напрямую в `~/.local/bin/` через плейбуки или шелл-команды. Все скрипты размещаются в [`zsh/scripts/`](file:///home/gidragir/projects/dotfiles/zsh/scripts) под управлением Yggdrasil.

### 4. Noctalia Shell v5 & Luau Plugin Invariants
- **Noctalia Configuration & State Synchronization Invariant:**
  - **Config Stack:** Базовый декларативный конфиг хранится в [`noctalia/config.toml`](file:///home/gidragir/projects/dotfiles/noctalia/config.toml) (версионируется в Git), динамическое runtime-состояние — в `~/.local/state/noctalia/settings.toml`.
  - **Правило синхронизации раскладки:** Все структурные элементы панели (раскладки островов `start`/`center`/`end`, капсульные группы `[[bar.islands.capsule_group]]`, аккордеоны плеера, виджеты `wallhaven`/`mpvpaper`/`audio_switcher`) обязаны быть задекларированы в `noctalia/config.toml`.
  - **Запрет слепого сброса `settings.toml`:** Категорически запрещено удалять `settings.toml` или вырезать из него блок `[bar.islands]` без предварительного бэкапа и переноса пользовательских настроек в `config.toml`. Сброс затирает эргономику пользователя (аккордеоны, порядок виджетов).
  - **Протокол восстановления после смены симлинков:**
    1. Создать резервную копию: `cp ~/.local/state/noctalia/settings.toml ~/.local/state/noctalia/settings.toml.bak`.
    2. Проверить доступность каталога плагинов через симлинк `~/.config/noctalia/plugins/`.
    3. Сверить `settings.toml` с `config.toml`, перенести недостающие плагины/группы в `config.toml`.
    4. Выполнить мягкую перезагрузку демона: `noctalia msg config-reload`.
- **Dropdown Panels:** Выпадающие панели бара ОБЯЗАНЫ указывать `placement = "attached"`, `position = "auto"`, `open_near_click = true` в `plugin.toml`. Запрещено использовать `placement = "floating"` или `position = "center"` для панелей, вызываемых из бара.
- **Card Containers:** `ui.box` является строго терминальным узлом без дочерних элементов (leaf node). Все карточки-контейнеры и секции с дочерними элементами обязаны использовать `ui.column` или `ui.row` (`fill = "surface_variant/0.25"`, `radius = 8`, `border = "outline"`, `borderWidth = 1`).
- **Panel Padding:** Корневой контейнер любой панели обязан указывать `padding = 14` и `gap = 12` для предотвращения прилипания контента к краям окна.
- **Plugin Validation:** Всегда выполнять `noctalia plugins lint <path>` после модификации манифестов плагинов или скриптов.
- **Noctalia Plugin Sources Invariant:**
  - В `noctalia/config.toml` секция `[[plugins.source]]` с `kind = "path"` использует канонический абсолютный путь (`location = "/home/gidragir/.config/noctalia/plugins"`).
  - Раскрытие `~` в этом поле не подтверждено (проверка бинарника `noctalia` по `strings` результата не дала): использовать `~` в `location` запрещено до явной проверки.

## 🗺 Архитектурная карта и навигация (OpenViking L0-L2)

Проект `dotfiles` описан трехуровневой базой знаний context-init (L0-L2), которая лежит в `.context-init/knowledge/` и коммитится вместе с кодом. Людям можно читать её напрямую; агентам — предпочитать MCP/`pack` ниже: это компактнее и учитывает бюджет токенов. После структурных изменений запустите `context-init update` и закоммитьте изменения базы в том же PR.

### ⚡ MCP-First Protocol (context-init)

1. `context_get_subsystems` — карта подсистем проекта (L0).
2. `context_get_subsystem(subsystem_id)` — компактная L1-карточка подсистемы.
3. `context_pack(subsystem_id, compress=true)` — AST-сжатый код подсистемы.
4. `context_check` — проверка архитектурного дрейфа перед сдачей задачи.

Без доступа к MCP (субагенты, скрипты): `rtk context-init pack <subsystem_id> --compress` и `rtk context-init check --compact`.

### 📦 Доступные подсистемы:
- `docs` (Docs) — Модуль и компоненты директории `docs` (5 файлов)
- `niri` (Niri) — Модуль и компоненты директории `niri` (15 файлов)
- `noctalia` (Noctalia) — Модуль и компоненты директории `noctalia` (3 файлов)
- `noctalia_plugins` (Noctalia Plugins) — Модуль и компоненты директории `noctalia/plugins` (15 файлов)
- `noctalia_plugins_audio-outputs` (Noctalia Plugins Audio Outputs) — Модуль и компоненты директории `noctalia/plugins/audio-outputs` (4 файлов)
- `noctalia_plugins_audio-outputs_tests` (Noctalia Plugins Audio Outputs Tests) — Тесты для `noctalia_plugins_audio-outputs`
- `noctalia_plugins_obsidian` (Noctalia Plugins Obsidian) — Модуль и компоненты директории `noctalia/plugins/obsidian` (6 файлов)
- `playbooks` (Playbooks) — Модуль и компоненты директории `playbooks` (7 файлов)
- `playbooks_archive` (Playbooks Archive) — Модуль и компоненты директории `playbooks/archive` (5 файлов)
- `scripts` (Scripts) — Модуль и компоненты директории `scripts` (4 файлов)
- `tests` (Tests) — Тесты проекта
- `wallpaper-engine` (Wallpaper Engine) — Модуль и компоненты директории `wallpaper-engine` (1 файлов)
- `zsh` (Zsh) — Модуль и компоненты директории `zsh` (14 файлов)
