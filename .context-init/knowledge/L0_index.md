# 🗺 Карта архитектуры: dotfiles (L0)

> **Стек:** Generic / Multi-language | **Обновлено:** 2026-11-08
> **Описание:** Automated setup scripts and Ansible playbooks for configuring a **CachyOS (Niri)** installation. Transforms a bare system into an optimized development environment for Rust, TypeScript, Python, Kubernetes, and DevOps...

## 🚪 Точки входа (Root Entrypoints)
- `mise.toml`

## ⚡️ Быстрые команды
```bash
```

## 🧩 Каталог подсистем (L1)

| Подсистема | Роль / Назначение | Точки входа | L1 Карточка |
| :--- | :--- | :--- | :--- |
| **Docs** | Модуль и компоненты директории `docs` (5 файлов) | `-` | [subsystems/docs.md](subsystems/docs.md) |
| **Niri** | Модуль и компоненты директории `niri` (15 файлов) | `-` | [subsystems/niri.md](subsystems/niri.md) |
| **Noctalia** | Модуль и компоненты директории `noctalia` (3 файлов) | `-` | [subsystems/noctalia.md](subsystems/noctalia.md) |
| **Noctalia Plugins** | Модуль и компоненты директории `noctalia/plugins` (15 файлов) | `-` | [subsystems/noctalia_plugins.md](subsystems/noctalia_plugins.md) |
| **Noctalia Plugins Audio Outputs** | Модуль и компоненты директории `noctalia/plugins/audio-outputs` (4 файлов) | `-` | [subsystems/noctalia_plugins_audio-outputs.md](subsystems/noctalia_plugins_audio-outputs.md) |
| **Noctalia Plugins Audio Outputs Tests** | Тесты для `noctalia_plugins_audio-outputs` | `-` | [subsystems/noctalia_plugins_audio-outputs_tests.md](subsystems/noctalia_plugins_audio-outputs_tests.md) |
| **Noctalia Plugins Obsidian** | Модуль и компоненты директории `noctalia/plugins/obsidian` (6 файлов) | `-` | [subsystems/noctalia_plugins_obsidian.md](subsystems/noctalia_plugins_obsidian.md) |
| **Playbooks** | Модуль и компоненты директории `playbooks` (11 файлов) | `-` | [subsystems/playbooks.md](subsystems/playbooks.md) |
| **Playbooks Vars** | Модуль и компоненты директории `playbooks/vars` (1 файлов) | `-` | [subsystems/playbooks_vars.md](subsystems/playbooks_vars.md) |
| **Scripts** | Модуль и компоненты директории `scripts` (8 файлов) | `-` | [subsystems/scripts.md](subsystems/scripts.md) |
| **Tests** | Тесты проекта | `-` | [subsystems/tests.md](subsystems/tests.md) |
| **Wallpaper Engine** | Модуль и компоненты директории `wallpaper-engine` (1 файлов) | `-` | [subsystems/wallpaper-engine.md](subsystems/wallpaper-engine.md) |
| **Zsh** | Модуль и компоненты директории `zsh` (14 файлов) | `-` | [subsystems/zsh.md](subsystems/zsh.md) |

## 📋 Инварианты и правила проекта
- Поддерживать актуальность карт модулей и документации архитектуры.
- Все изменения фиксируются через атомарные и типизированные коммиты.
