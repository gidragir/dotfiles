# ADR 0001: Начальная архитектура и топология dotfiles

- **Статус:** Принято
- **Дата:** 2026-11-08
- **Стек:** Generic / Multi-language

## Контекст
Инициализация кодовой базы `dotfiles`. Для обеспечения надежной автономной навигации ИИ-ассистентов зафиксирована трехуровневая модель контекста (OpenViking L0-L2).

## Архитектурные границы подсистем
- **Docs** (`docs`): Модуль и компоненты директории `docs` (5 файлов)
- **Niri** (`niri`): Модуль и компоненты директории `niri` (15 файлов)
- **Noctalia** (`noctalia`): Модуль и компоненты директории `noctalia` (3 файлов)
- **Noctalia Plugins** (`noctalia_plugins`): Модуль и компоненты директории `noctalia/plugins` (15 файлов)
- **Noctalia Plugins Audio Outputs** (`noctalia_plugins_audio-outputs`): Модуль и компоненты директории `noctalia/plugins/audio-outputs` (4 файлов)
- **Noctalia Plugins Audio Outputs Tests** (`noctalia_plugins_audio-outputs_tests`): Тесты для `noctalia_plugins_audio-outputs`
- **Noctalia Plugins Obsidian** (`noctalia_plugins_obsidian`): Модуль и компоненты директории `noctalia/plugins/obsidian` (6 файлов)
- **Playbooks** (`playbooks`): Модуль и компоненты директории `playbooks` (11 файлов)
- **Playbooks Vars** (`playbooks_vars`): Модуль и компоненты директории `playbooks/vars` (1 файлов)
- **Scripts** (`scripts`): Модуль и компоненты директории `scripts` (8 файлов)
- **Tests** (`tests`): Тесты проекта
- **Wallpaper Engine** (`wallpaper-engine`): Модуль и компоненты директории `wallpaper-engine` (1 файлов)
- **Zsh** (`zsh`): Модуль и компоненты директории `zsh` (14 файлов)


## Решение
1. `L0_index.json` и `L0_index.md` служат единой точкой входа (Mental Map) с минимальным потреблением токенов.
2. Каждая подсистема изолирована в карточке L1 (`subsystems/*.md`) с перечислением точек входа и сигнатур.
3. Справочник команд L2 (`cli/commands.md`) фиксирует фактические команды сборки и верификации.

## Последствия
- Устраняется необходимость рекурсивного сканирования всего репозитория при каждом промпте.
- Агенты обращаются к точечным карточкам L1 по мере необходимости.
