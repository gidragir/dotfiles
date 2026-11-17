# Playbooks, Network QoS & Scripting Invariants

> Справочник инвариантов для модификации `playbooks/` и `scripts/`.

## 1. Ansible & GitOps

- **Идемпотентность:** Все плейбуки безопасны для повторного запуска; `command:`/`shell:` только с `creates:`, `changed_when:` или предварительным `stat`.
- **Разделение привилегий:**
  - `system` (root): блочные устройства, `/etc/fstab`, системные пакеты, `udev`, SDDM, `scope: system` юниты.
  - `user` (non-root): AUR (`paru` через `kewlfft.aur`) запрещено запускать от root; пользовательские юниты используют `scope: user`.
- **Оформление и теги:** Плейбуки содержат заголовочные комментарии, именованные таски (`name:`) и теги (`tags: [...]`). Задачи пользовательского окружения включают соответствующие теги (`[cli, aur, packages]`).

## 2. Сетевая архитектура, Bufferbloat и QoS

- **Модульность:** Сетевые тюнинги ядра, шейпинг и QoS изолируются в `playbooks/setup_network_optimization.yml` (запрещено жёстко включать в базовые плейбуки). Плейбук поддерживает теги `apply` и `revert` без навязывания тегов на уровне плеев.
- **Systemd Drop-in Overrides:** При переопределении списковых директив (`ExecStart`, `OnBootSec`) в `override.conf` первым шагом идёт сброс пустым значением (`ExecStart=`, `OnBootSec=`). Исходные юниты в `/usr/lib/systemd/` не правятся — только drop-in в `/etc/systemd/system/*.d/`.
- **TCP BBR и Sysctl:** Назначение `net.ipv4.tcp_congestion_control = bbr` предваряется проверкой `/proc/sys/net/ipv4/tcp_available_congestion_control`. Откат на `cubic` выполняется с guard-проверкой `/proc/sys/net/ipv4/tcp_congestion_control` во избежание ложного `changed`.
- **Изоляция фоновых служб:** Бенчмарки (`cachyos-rate-mirrors.timer`) используют `Persistent=false`; `rclone bisync` запускается с задержкой (`OnBootSec=10m`) и лимитом отдачи (`--bwlimit 10M`).

## 3. Bash-скрипты (`scripts/` и `zsh/scripts/`)

- **Строгий режим и ошибки:** Начало bash-скриптов — `set -euo pipefail` и `trap 'error_handler $? $LINENO' ERR`.
- **Проверка прав (`$EUID`):**
  - Root-скрипты: `if [ "$EUID" -ne 0 ]; then exit 1; fi`
  - User-скрипты: `if [ "$EUID" -eq 0 ]; then exit 1; fi`
- **`set -e` Arithmetic Trap:** Запрещено `((VAR++))` / `((VAR+=1))` как самостоятельные инструкции при `set -e` (при `VAR=0` возвращает false). Использовать `VAR=$((VAR + 1))`.
- **Пути из `scripts/`:** Вычислять `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` для обращения к `playbooks/`, не полагаться на `$SCRIPT_DIR/playbooks`.
