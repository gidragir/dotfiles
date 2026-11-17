# Noctalia Shell v5 & Luau Plugin Invariants

> Справочник инвариантов для модификации `noctalia/` (`config.toml`, `hosts/*.toml`, плагины Luau).

## 1. Конфигурация и синхронизация состояния

- **Config Stack:** Базовый декларативный конфиг хранится в `noctalia/config.toml` (Git), динамическое runtime-состояние — в `~/.local/state/noctalia/settings.toml`.
- **Раскладка панели:** Структурные элементы панели (острова `start`/`center`/`end`, `[[bar.islands.capsule_group]]`, аккордеоны плеера, виджеты `wallhaven`/`mpvpaper`/`audio_switcher`) декларируются в `noctalia/config.toml` (общие) или `noctalia/hosts/<host>.toml` (хостово-специфичные, например `end` с `openrgb`/`battery`).
- **Multi-File & Host Scope:**
  - `~/.config/noctalia/` — физическая гибридная директория (монолитный симлинк директории запрещён в `links.toml`). Общие файлы (`config.toml`, `colors.json`, `plugins`, `settings.json`) линкуются гранулярно; хостовый профиль `noctalia/hosts/{pc,asus}.toml` линкуется через `[scope.<host>.links]` в `~/.config/noctalia/host.toml`.
  - Порядок слияния: `*.toml` в `~/.config/noctalia/` по алфавиту (`config.toml` → `host.toml` → опциональный нетрекаемый `zzz-local.toml`), затем `~/.local/state/noctalia/settings.toml`.
  - При `deepMerge` таблицы сливаются рекурсивно, а **массивы и скаляры перезаписываются целиком** — списки (`[bar.islands].end`, `[plugins].enabled`) при хостовом делении целиком задаются в `noctalia/hosts/<host>.toml`.
- **Запрет слепого сброса `settings.toml`:** Не удалять `settings.toml` и не вырезать `[bar.islands]` без бэкапа и переноса пользовательских настроек в `config.toml`.
- **Восстановление после смены симлинков:**
  1. Бэкап: `cp ~/.local/state/noctalia/settings.toml ~/.local/state/noctalia/settings.toml.bak`
  2. Проверить доступность `~/.config/noctalia/plugins/`.
  3. Сверить `settings.toml` с `config.toml`, перенести недостающие плагины/группы в `config.toml`.
  4. Перезагрузить демон: `noctalia msg config-reload`.
- **Валидация:** После любых правок TOML выполнять `noctalia config validate`.

## 2. Плагины Luau и UI

- **Plugin Sources:** В `noctalia/config.toml` секция `[[plugins.source]]` с `kind = "path"` использует канонический абсолютный путь `location = "/home/gidragir/.config/noctalia/plugins"` (использование `~` запрещено).
- **Dropdown Panels:** Выпадающие панели бара в `plugin.toml` указывают `placement = "attached"`, `position = "auto"`, `open_near_click = true` (не `floating` и не `center`).
- **Card Containers:** `ui.box` — строго терминальный узел без дочерних элементов. Контейнеры с детьми используют `ui.column` или `ui.row` (`fill = "surface_variant/0.25"`, `radius = 8`, `border = "outline"`, `borderWidth = 1`).
- **Panel Padding:** Корневой контейнер панели задаёт `padding = 14` и `gap = 12`.
- **Валидация плагинов:** После правки манифестов или скриптов выполнять `noctalia plugins lint <path>`.
