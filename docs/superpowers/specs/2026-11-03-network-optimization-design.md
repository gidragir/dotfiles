# Network Optimization Playbook Design Specification

> **Date:** 2026-11-03  
> **Status:** Approved  
> **Target:** Local workstation host (CachyOS / Niri / Dual-NVMe)  
> **Repository:** `/data/projects/dotfiles`

---

## 1. Intent & The Why

### Problem Statement
При включении рабочей станции наблюдается деградация домашней сети (падение скорости, рост ping, задержки для других клиентских устройств). Анализ сетевого стека хоста выявил следующие причины:
1. **Bufferbloat из-за доминирования исходящего трафика (TX 1.14 GB vs RX 577 MB):** активный стриминг контекста и кода Antigravity IDE в Google Cloud, синк Rclone в Google Drive без лимита полосы пропускания (`--bwlimit`).
2. **Всплеск `cachyos-rate-mirrors.timer` при старте:** параметр `Persistent=true` запускает полномасштабный бенчмарк десятков зеркал сразу после загрузки, если ПК был выключен в плановую дату.
3. **Агрессивное окно CUBIC:** `net.ipv4.tcp_congestion_control = cubic` раздувает буфер домашнего роутера при upload-нагрузках до возникновения потерь пакетов.
4. **Широковещательный шум:** запросы LLMNR (`224.0.0.252:5355`) нагружают Wi-Fi эфир домашнего маршрутизатора.

### Goal
Создать изолированный, модульный Ansible-плейбук `playbooks/setup_network_optimization.yml`, позволяющий декларативно применить оптимизации сетевого стека по требованию, а также полностью откатить их в исходное состояние CachyOS без вмешательства в базовые установочные плейбуки (`setup_system.yml`, `setup_user.yml`).

---

## 2. Goals, Non-Goals & Anti-Goals

### Goals
- **Изоляция сетевого всплеска при старте:** устранить немедленный запуск `cachyos-rate-mirrors` через drop-in `Persistent=false`.
- **Шейпинг облачного синка:** ограничить скорость отдачи `rclone bisync` в Google Drive значением `--bwlimit 10M` и сдвинуть запуск на 10 минут после загрузки (`OnBootSec=10m`).
- **Pacing и устранение Bufferbloat:** активировать `bbr` + `fq_codel` через `/etc/sysctl.d/99-network-bbr.conf`.
- **Чистый эфир:** отключить LLMNR в `systemd-resolved` через drop-in конфигурацию.
- **Поддержка отката:** реализация тега `revert` (или переменной `network_optimization_state: absent`) для возврата к дефолтам.

### Non-Goals
- Изменение конфигурации домашнего роутера (настройка SQM/CAKE на стороне маршрутизатора производится пользователем отдельно).
- Ограничение скорости Antigravity IDE / language_server через cgroups/tc (может нарушить отзывчивость взаимодействия с AI-моделями).

### Anti-Goals
- Запрещено модифицировать сетевые интерфейсы Docker (`docker0`, `br-*`), влиять на локальные порты сервисов (`11434`, `42110`, `8890`, `8787`, `5432`).
- Запрещено вносить деструктивные изменения в файлы пакетов CachyOS напрямую в `/usr/lib/` (строго drop-in в `/etc/`).

---

## 3. Approaches Considered

1. **Встраивание в базовые плейбуки (`setup_system.yml` / `setup_user.yml`):**
   - *Плюсы:* автоматическое применение при общем развертывании.
   - *Минусы:* настройки применяются принудительно, нет гибкости отключения при тестировании сети.
2. **Ad-hoc ручные команды в терминале:**
   - *Плюсы:* не требует написания Ansible-кода.
   - *Минусы:* теряется GitOps-контроль, конфигурация затрется при переустановке или обновлении.
3. **Отдельный модульный Ansible-плейбук (`playbooks/setup_network_optimization.yml`): [ВЫБРАН]**
   - *Плюсы:* полный GitOps, изолированное применение по требованию, встроенный откат (`revert`), сохранение чистоты базовых плейбуков.

---

## 4. Detailed Specification

### Playbook: `playbooks/setup_network_optimization.yml`
Поддерживает переменные:
- `network_optimization_state`: `present` (по умолчанию) | `absent`.
- `rclone_bwlimit`: `"10M"` (по умолчанию).
- `rclone_boot_delay`: `"10m"` (по умолчанию).

#### Секция 1: System Play (`become: true`)
- **TCP BBR:**
  - `present`: создает `/etc/sysctl.d/99-network-bbr.conf` с `net.ipv4.tcp_congestion_control = bbr` и `net.core.default_qdisc = fq_codel`. Вызывает `sysctl --system`.
  - `absent`: удаляет `/etc/sysctl.d/99-network-bbr.conf`, восстанавливает `net.ipv4.tcp_congestion_control = cubic`.
- **CachyOS Rate-Mirrors Drop-in:**
  - `present`: создает `/etc/systemd/system/cachyos-rate-mirrors.timer.d/override.conf` (`[Timer]\nPersistent=false`). Перезагружает `systemd`.
  - `absent`: удаляет директорию drop-in, перезагружает `systemd`.
- **Resolved LLMNR Drop-in:**
  - `present`: создает `/etc/systemd/resolved.conf.d/disable-llmnr.conf` (`[Resolve]\nLLMNR=no`). Перезапускает `systemd-resolved`.
  - `absent`: удаляет файл drop-in, перезапускает `systemd-resolved`.

#### Секция 2: User Play (`become: false`)
- **Rclone Obsidian Sync Service & Timer Drop-ins:**
  - `present`:
    - Создает `~/.config/systemd/user/rclone-obsidian-sync.service.d/override.conf`:
      ```ini
      [Service]
      ExecStart=
      ExecStart=/usr/bin/rclone bisync /data/obsidian gdrive:Obsidian \
          --fast-list \
          --modify-window 2s \
          --resilient \
          --recover \
          --retries 3 \
          --bwlimit {{ rclone_bwlimit }} \
          --log-level INFO \
          --log-file=%h/.cache/rclone/obsidian-sync.log
      ```
    - Создает `~/.config/systemd/user/rclone-obsidian-sync.timer.d/override.conf`:
      ```ini
      [Timer]
      OnBootSec=
      OnBootSec={{ rclone_boot_delay }}
      ```
    - Выполняет `systemctl --user daemon-reload`.
  - `absent`:
    - Удаляет override drop-in директории сервиса и таймера, выполняет `systemctl --user daemon-reload`.
