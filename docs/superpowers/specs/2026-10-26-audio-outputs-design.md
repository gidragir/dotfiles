# Дизайн-документ: Плагин Noctalia `gidragir/audio-outputs`

> **Дата:** 2026-10-26  
> **Статус:** Черновик (на согласовании)  
> **Целевая система:** CachyOS Linux, Niri Wayland, Noctalia Shell v5.3.0, PipeWire 1.6 + WirePlumber 0.5  
> **Целевой каталог:** `linked/noctalia/plugins/audio-outputs/`

---

## 1. Контекст и намерение (Intent & Why)

На хосте с видеокартой NVIDIA RTX 4070 Ti Super подключены два приёмника: монитор LG ULTRAWIDE (порт `hdmi-output-0`, профиль `output:hdmi-stereo`) и телевизор Panasonic-TV (порт `hdmi-output-1`, профиль `output:hdmi-stereo-extra1`).
В PipeWire/ALSA Card Profile (ACP) одновременно создаётся сток только для активного профиля звуковой карты. Соответственно, при активном мониторе сток для ТВ в системе отсутствует, и стандартный виджет (`audio-switcher`) не может на него переключиться.
Существующий плагин `blackbartblues/audio-switcher` помечен как `deprecated = true`, не умеет переключать профили карт и оперирует только уже запущенными стоками.
**Цель:** Создать современный, производительный плагин `gidragir/audio-outputs` для Noctalia Shell, объединяющий существующие стоки PipeWire и неактивные HDMI-профили в единый список для мгновенного переключения аудиовыходов «в один клик» с корректной миграцией аудиопотоков.

---

## 2. Цели, не-цели и анти-цели

### Цели (Goals)
1. **Гибридный список выходов:** Синтез списка доступных устройств из `pactl -f json list sinks` (активные стоки) и `pactl -f json list cards` (неактивные профили карт с валидными приёмниками).
2. **Бесшовное переключение (Use):**
   - Для активного стока (`kind = "sink"`): немедленный вызов `pactl set-default-sink <sink>` и перенос потоков `pactl move-sink-input`.
   - Для неактивного профиля (`kind = "profile"`): вызов `pactl set-card-profile <card> <profile>`, асинхронное отслеживание появления нового стока через `pactl subscribe` (с таймаутом 3.5 с), установка `set-default-sink` и перенос всех активных потоков `sink-input`.
3. **Защита от сброса на Built-in Audio:** Гарантировать, что при смене профиля карты система не останется на резервном встроенном звуке материнской платы.
4. **Интеллектуальная идентификация HDMI:** Извлечение имени монитора/ТВ из `ports[...].properties["device.product.name"]` в pactl JSON с фолбэком на чтение `/proc/asound/card*/eld#*` (`monitor_name`) и описания профиля.
5. **Индикация доступности и персистентный кэш устройств (`knownDevices`):**
   - В `preferences.json` поддерживается реестр `knownDevices`: когда приёмник активен и PipeWire/ELD отдают его имя (`device.product.name`), запись сохраняется навсегда: `{ "cardName:portName": { "name": "Panasonic-TV", "lastSeen": 1719000000 } }`.
   - В выключенном состоянии/режиме ожидания (`availability: not available`) профиль отображается со статусом `Disconnected / Standby` и сохранённым именем, оставаясь доступным для выбора («Use»).
   - Пустые порты GPU (HDMI 3, HDMI 4), которые никогда не имели подключения и не имеют пользовательского алиаса, автоматически скрываются из UI.
   - Настройка `show_disconnected` (по умолчанию `true`) позволяет скрыть все отключенные устройства при необходимости.
6. **Полная интеграция с Noctalia:**
   - Виджет бара (`widget.luau`): иконка, процент громкости, интерактивный тултип, регулировка громкости колесом мыши, клики открытия панели и циклического переключения.
   - Выдвижная панель (`panel.luau`): карточка активного устройства со слайдером громкости, mute, список выходов со строгим соблюдением дизайн-токенов Noctalia (Catppuccin Frappe), кнопки назначения алиасов и кастомных иконок.
   - Поставщик Launcher (`launcher.luau`): быстрый доступ по префиксу `audio`.
   - Сервис-бэкенд (`service.luau`): единственный владелец подпроцессов `pactl`, связь через `noctalia.state` и `onIpc()`.
   - Локализация: полные переводы `en.json` и `ru.json`.

### Не-цели (Non-Goals)
- Управление микрофонами и аудиовходами (YAGNI, микрофон настраивается независимо).
- Bluetooth Handoff / сопряжение Bluetooth через данный плагин (для этого есть штатный Bluetooth-виджет Noctalia).
- Создание комбинированных стоков (объединение колонок и ТВ в один виртуальный сток).

### Анти-цели (Anti-Goals)
- Мусорные профили: запрещено отображать пустые порты HDMI 3/4 видеокарты и дублирующие многоканальные профили (Surround 5.1 / 7.1), если для стерео-выхода уже есть соответствующий stereo-профиль.
- Зависание UI при переключении: запрещено использовать блокирующие вызовы или `sleep` в основном цикле Luau.
- Конфликт с WirePlumber: плагин не должен генерировать статические SPA-конфиги WirePlumber, полагаясь на нативное сохранение состояния через `wpctl` / WirePlumber state.

---

## 3. Ограничения (Constraints)

1. **Версия Noctalia:** 5.3.0 (`plugin_api = 32`). Использование актуальных API-контрактов (`runAsync`, `runStream`, `getColor`, `pluginDataDir`).
2. **Дизайн-система:** Запрещены захардкоженные hex-цвета. Использовать только токены темы Noctalia (`surface_variant`, `outline`, `primary`, `text`, `subtext`). Контейнеры с дочерними элементами — строго `ui.column` / `ui.row`, `ui.box` только как терминальный элемент.
3. **Хранение состояния:** Настройки пользователя (алиасы, скрытые выходы, иконки) сохраняются в `noctalia.pluginDataDir() .. "/preferences.json"` (`version = 1`).
4. **Инварианты репозитория:**
   - Путь размещения: `linked/noctalia/plugins/audio-outputs/`.
   - Регистрация в `linked/noctalia/plugins/catalog.toml`.
   - Конфигурация `config.toml` не должна ломать существующий `audio-switcher` до явного подтверждения.
   - Тесты логики в `tests/*.lua` должны запускаться автономно.

---

## 4. Рассмотренные подходы и выбор

1. **Подход 1 (Выбран): Единый список с интеллектуальной фильтрацией и статусом доступности.**
   - Активные стоки + HDMI-профили с обнаруженными мониторами/алиасами.
   - Поддержка статуса `Disconnected` для выключенного ТВ.
   - Обоснование выбора: решает проблему невидимости ТВ в режиме ожидания, избавляет от визуального мусора пустых портов GPU, обеспечивает максимальную отзывчивость UX.
2. **Подход 2: Строгая фильтрация по `available: true` со сворачиваемым разделом.**
   - Отклонен: требует лишнего клика для включения ТВ, усложняет верстку панели.
3. **Подход 3: Статический маппинг портов в конфиге.**
   - Отклонен: нулевая переносимость и хрупкость при смене конфигурации мониторов.

---

## 5. Архитектура и структура компонентов

### 5.1 Структура каталога `linked/noctalia/plugins/audio-outputs/`
```
audio-outputs/
├── plugin.toml             # Манифест плагина (id: "gidragir/audio-outputs", plugin_api = 32)
├── service.luau            # Фоновый демон (subprocesses, pactl subscribe, state manager)
├── panel.luau              # UI панели (громкость, список выходов, настройки)
├── widget.luau             # UI виджета статус-бара (иконка, процент, тултип, клики)
├── launcher.luau           # Интеграция с лаунчером Noctalia (префикс "audio")
├── lib/
│   └── parser.luau         # Чистый модуль парсинга pactl JSON и построения модели
├── translations/
│   ├── en.json             # Английская локализация
│   └── ru.json             # Русская локализация
├── tests/
│   ├── fixtures/           # JSON дампы pactl list sinks и cards для тестов
│   │   ├── sinks.json
│   │   └── cards.json
│   └── parser_test.lua     # Unit-тесты парсинга, фильтрации и модели
├── README.md               # Документация, ограничения и описание работы
└── LICENSE                 # MIT License
```

### 5.2 Модель данных (Snapshot State)
Ключ состояния: `audio_outputs_snapshot`
```lua
{
  available = true,             -- pactl доступен в системе
  loading = false,             -- первичная загрузка завершена
  busy = false,                -- выполняется операция переключения
  outputs = {                  -- нормализованный список выходов
    {
      id = "sink:alsa_output.pci-0000_01_00.1.hdmi-stereo",
      kind = "sink",            -- "sink" | "profile"
      sinkName = "alsa_output.pci-0000_01_00.1.hdmi-stereo",
      cardName = "alsa_card.pci-0000_01_00.1",
      profileName = "output:hdmi-stereo",
      portName = "hdmi-output-0",
      displayName = "LG ULTRAWIDE",
      rawDescription = "AD103 High Definition Audio Controller Digital Stereo (HDMI)",
      available = true,         -- физическая готовность (jack/ELD detected)
      isDefault = true,         -- текущий сток по умолчанию
      volume = 95,              -- процент громкости
      muted = false,
      icon = "video-display",   -- иконка по умолчанию
    },
    {
      id = "profile:alsa_card.pci-0000_01_00.1:output:hdmi-stereo-extra1",
      kind = "profile",
      sinkName = nil,
      cardName = "alsa_card.pci-0000_01_00.1",
      profileName = "output:hdmi-stereo-extra1",
      portName = "hdmi-output-1",
      displayName = "Panasonic-TV", -- из ELD/порт-проперти или алиаса, фолбэк: "Digital Stereo (HDMI 2)"
      rawDescription = "Digital Stereo (HDMI 2) Output",
      available = false,        -- ТВ в standby
      isDefault = false,
      volume = 100,
      muted = false,
      icon = "tv",
    },
    -- USB Audio, Встроенный звук Realtek и т.д.
  },
  defaultOutputId = "sink:alsa_output.pci-0000_01_00.1.hdmi-stereo",
  outputVolume = 95,
  outputMuted = false,
  error = "",
  updatedAt = 1719000000,
  revision = 42,
}
```

### 5.3 Протокол переключения выходов и машина состояний (FSM Rollback)
1. UI вызывает IPC-команду или записывает команду в `audio_outputs_command`:
   `{ type = "set-output", id = targetId }`.
2. Если `kind == "sink"`:
   - Выполнить `pactl set-default-sink <sinkName>`.
   - Запросить список `pactl -f json list sink-inputs` и для каждого входа выполнить `pactl move-sink-input <id> <sinkName>`.
   - Обновить snapshot и отправить уведомление (если включено в настройках).
3. Если `kind == "profile"`:
   - Сохранить состояние отката: `previousCardProfile`, `previousSinkName`.
   - Запустить `pactl set-card-profile <cardName> <profileName>`.
   - В обработчике `pactl subscribe` отслеживать события `change on card` и `new on sink`.
   - При обнаружении нового стока для данной карты:
     - Выполнить `pactl set-default-sink <newSinkName>`.
     - Перенести потоки через `pactl move-sink-input`.
   - Если за 3.5 секунды сток не обнаружен (`sink_spawn_timeout`):
     - Зафиксировать ошибку `sink_spawn_timeout`.
     - Выполнить процедуру отката FSM:
       1. Восстановить профиль карты: `pactl set-card-profile <cardName> <previousCardProfile>`.
       2. Дождаться восстановления предыдущего стока.
       3. Восстановить `pactl set-default-sink <previousSinkName>`.
       4. Перенести `sink-inputs` обратно на `previousSinkName`.
     - Выставить статус ошибки в snapshot и показать уведомление об ошибке.

### 5.4 IPC-контракт и дебаунс управления громкостью
`service.luau` является единственным владельцем подпроцессов `pactl`. Взаимодействие с `widget.luau` и `panel.luau` осуществляется через `onIpc()` и команды:
- `volume-up` / `volume-down` (шаг 5% по умолчанию).
- `volume-set <0..100>` (событие слайдера `onChange` / `onDragEnd`).
- `mute-toggle`.
- `cycle-output` (переключение на следующий доступный выход).
- `set-output <outputId>`.

Для исключения лавины вызовов `pactl` при быстром скролле колесом мыши или перетаскивании слайдера в `service.luau` переносится механизм дебаунса из образца `audio-switcher`:
- Переменная `desiredValue` накапливает последнее запрошенное значение.
- Вызовы `pactl set-sink-volume` выполняются последовательно через очередь, промежуточные значения объединяются.
- Громкость профилей (`kind == "profile"`): в PipeWire неактивные профили не имеют ассоциированного стока и регулятора громкости, поэтому в схеме данных для них `volume = nil`, а слайдер в карточке панели отображает и регулирует громкость только активного стока. WirePlumber сохраняет настройки громкости для каждого устройства аппаратно через внутренний state.

---

## 6. Что оставлено на усмотрение разработчика (Left to Builder)
- Реализация двухфазного FSM отката при таймауте создания стока (принято решение: полный откат профиля карты, возврат стока и потоков).
- Точные параметры таймаута ожидания стока (в диапазоне 3.0–4.0 с).
- Внутренняя структура фикстур для юнит-тестов (Lua test runner).
- Подбор дефолтных глифов/иконок для разных типов устройств (монитор, ТВ, наушники, динамики, USB).
- Схема дебаунса громкости и Mute через IPC-очередь в `service.luau`.
