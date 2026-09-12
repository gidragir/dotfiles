# 🧠 Персональный AI-Стек: Архитектура, Топология и Эксплуатация (AI Stack Guide)

> **Назначение документа:** Единый источник технической правды (Single Source of Truth) по архитектуре, сетевой топологии, управлению памятью и инструментам персонального AI-стека на рабочей станции CachyOS (Niri Wayland).

---

## 🏛 1. Аппаратный контекст и бюджет ресурсов

Система оптимизирована под конкретную аппаратную конфигурацию:
- **GPU:** ASUS NVIDIA GeForce RTX 4070 Ti Super (**16 ГБ vRAM**, Ada Lovelace).
- **RAM:** 32 ГБ DDR5.
- **Хранилище:** Dual-NVMe (NVMe 0: System/Home, NVMe 1: `/data/projects` Btrfs zstd, `/data/models/ollama`, `/var/lib/docker` XFS prjquota).

### Распределение 16 ГБ vRAM под нагрузкой:
```
┌─────────────────────────────────────────────────────────────┐
│ Всего vRAM: 16.0 ГБ                                         │
├──────────────────────────────┬──────────────────────────────┤
│ Рабочий стол (Niri, Ghostty, │ ~2.0 - 2.5 ГБ                │
│ Vivaldi Wayland/GPU)         │                              │
├──────────────────────────────┼──────────────────────────────┤
│ Модель Qwen2.5-Coder-14B     │ ~9.2 ГБ                      │
│ (Q4_K_M квантование)         │                              │
├──────────────────────────────┼──────────────────────────────┤
│ Контекст KV-кэша (16k токенов│ ~2.5 - 3.2 ГБ                │
│ FlashAttention + q8_0)       │                              │
├──────────────────────────────┼──────────────────────────────┤
│ Embedder bge-m3:latest (GPU) │ ~1.1 - 1.2 ГБ (динамически)  │
├──────────────────────────────┼──────────────────────────────┤
│ ИТОГО активный аллок:        │ ~14.8 - 15.6 ГБ (из 16.0 ГБ) │
└──────────────────────────────┴──────────────────────────────┘
```

> [!WARNING]
> **Бюджет vRAM предельно плотный:** Тяжелые фреймворки серверного батчинга (vLLM, Aphrodite) категорически исключены, так как они аллоцируют 90% vRAM на старте и вызывают аварийное падение Wayland-композитора Niri по OOM. Используется **Ollama** с параметром `OLLAMA_MAX_LOADED_MODELS=1` и автоматической выгрузкой неактивных моделей по `keep_alive`.

---

## 🌐 2. Архитектура трех рабочих контуров

AI-стек разделен на три изолированных контура с минимальным оверхедом и прямыми путями передачи данных:

```
+───────────────────────────────────────────────────────────────────────────────────+
| 1. ТЕРМИНАЛЬНЫЙ КОНТУР (Ghostty + Zsh)                                             |
|    • OpenCommit (CLI) -> прямой вызов Ollama (:11434, qwen2.5-coder:14b)           |
|    • Быстрый алиас `gcai` (git add -p && opencommit) — коммиты за 0.8-1.5 сек      |
|    • Утилиты `khoj-ctl` и `khoj-tags` для быстрого CLI-поиска по базе знаний       |
+───────────────────────────────────────────────────────────────────────────────────+
| 2. КОНТУР АКТИВНОЙ РАЗРАБОТКИ (Antigravity IDE)                                    |
|    • Google Antigravity (Gemini Pro) — проектирование, рефакторинг, фичи          |
|    • Headroom Proxy (:8787) — CCR-сжатие логов/AST кода, семантический кэш         |
|    • Host CLI MCP (`bash-mcp-server.mjs`) — выполнение команд, чтение файлов       |
|    • Khoj MCP (`docker exec -i khoj khoj-mcp`) — бесшовный контекст Obsidian       |
+───────────────────────────────────────────────────────────────────────────────────+
| 3. КОНТУР ЗНАНИЙ И АНАЛИЗА (Obsidian + Khoj + AnythingLLM)                         |
|    • Obsidian: Markdown хранилище заметок в `/data/obsidian`                      |
|    • Khoj (:42110): Docker-контейнер, живая индексация заметок, поиск по тегам    |
|    • PostgreSQL + pgvector (:5432): единая векторная БД для Khoj и кэша Headroom   |
|    • AnythingLLM Desktop: локальный RAG-архив с LanceDB и Ollama `bge-m3`          |
+───────────────────────────────────────────────────────────────────────────────────+
```

---

## 🔌 3. Сетевая топология и матрица портов

| Порт | Сервис | Протокол | Назначение | Доступ |
|---|---|---|---|---|
| **`11434`** | **Ollama** | HTTP / OpenAI v1 | Локальный GPU-инференс моделей (`qwen2.5-coder:14b`, `qwen2.5:14b`, `deepseek-r1:14b`, `bge-m3`) | `0.0.0.0:11434` (доступен хосту и Docker) |
| **`8787`** | **Headroom Proxy** | HTTP / OpenAI v1 | Прокси сжатия контекста (CCR), семантического кэширования и AST-прунинга | `127.0.0.1:8787` |
| **`5432`** | **PostgreSQL + pgvector** | PostgreSQL | Хранение эмбеддингов Khoj и семантического кэша Headroom (`headroom_cache`) | `127.0.0.1:5432` |
| **`42110`** | **Khoj AI** | HTTP / Web UI / MCP | Семантический поиск по заметкам Obsidian, агенты, MCP-сервер | `0.0.0.0:42110` / `host` |

### Схема маршрутизации трафика:
```
[ Ghostty Terminal ]
   │ (gcai / opencommit)
   ▼
[ Ollama: qwen2.5-coder:14b ] (:11434) ◄── Прямой вызов без посредников

[ Antigravity IDE ]
   ├──► [ Headroom Proxy ] (:8787)
   │       ├── 1. Проверка семантического кэша -> [ PostgreSQL pgvector ] (:5432)
   │       ├── 2. AST-сжатие логов/кода
   │       └── 3. Маршрутизация: локальный Ollama (:11434) или внешний Gemini API
   │
   └──► [ Khoj MCP ] (stdio via docker exec)
           └──► [ Obsidian Vault ] (`/data/obsidian`, RO)
```

---

## 🧠 4. Политика долговременной памяти и защита от Context Poisoning

Опыт эксплуатации выявил критическую проблему неявной долговременной памяти (Implicit Memory Injection):
- **Проблема:** Включение флага `--memory` в Headroom или бесконтрольное скармливание всех сессий в векторные базы приводило к инъекции инструкций вида `ALWAYS call memory_search BEFORE searching files`. Это вызывало зависание SSE-стриминга, распыление внимания компактных моделей и воспроизведение старых исправленных ошибок («отравление контекста»).
- **Решение и стандарт:**
  1. **Никакой неявной инъекции памяти в системные промпты.** Headroom используется **строго** для синтаксического AST-сжатия кода, дедупликации и семантического кэширования в PostgreSQL (`DATABASE_URL=postgresql://headroom:headroom_password@127.0.0.1:5432/headroom_cache`). Флаг `--memory` отключен.
  2. **Память — это осознанный инструмент (Tool Call):** Извлечение исторического контекста или заметок выполняется **только явно** через вызовы инструментов:
     - Поиск по базе знаний Obsidian: через `khoj-ctl search`, Khoj MCP или `search_files`.
     - Архитектурные правила проекта: зафиксированы в `AGENTS.md` и читаются по требованию.

---

## 🛠 5. Утилиты управления и автоматизация (CLI Flow)

### 1. `khoj-ctl` — Управление базой знаний Khoj
Скрипт расположен в `zsh/.zsh/scripts/khoj-ctl` (доступен в `$PATH`):
```bash
khoj-ctl status             # Статус Ollama, Headroom, Postgres, Khoj и индексации
khoj-ctl search "<query>"   # Семантический поиск по заметкам Obsidian
khoj-ctl tags [tag]         # Поиск и фильтрация заметок по тегам Obsidian (#tag)
khoj-ctl chat "<query>"     # Диалог с Khoj (поддерживает флаги -m <model>, -a <agent>)
khoj-ctl sync               # Принудительная переиндексация заметок Obsidian
khoj-ctl logs [-f] [N]      # Просмотр логов контейнера Khoj
khoj-ctl restart            # Перезапуск контейнера Khoj с проверкой healthcheck
```

### 2. `khoj-tags` — Быстрый парсер тегов Obsidian
Скрипт `zsh/.zsh/scripts/khoj-tags` выполняет быстрый рипгреп тегов и фронтматтера в `/data/obsidian`.

### 3. `gcai` — Атомарные коммиты через локальную LLM
В `zsh/.zsh/alias/git.zsh` настроен алиас:
```zsh
alias gcai="git add -p && opencommit"
```
OpenCommit настроен на прямое взаимодействие с локальной моделью:
```ini
OCO_AI_PROVIDER=ollama
OCO_OPENAI_BASE_PATH=http://127.0.0.1:11434/v1
OCO_MODEL=qwen2.5-coder:14b
```

### 4. Mise задачи (`mise run ...`)
В `mise.toml` определены шорткаты:
```bash
mise run ai:status       # Быстрая проверка доступности Ollama, Headroom, Khoj и Postgres
mise run khoj:test       # Тестовый пинг эндпоинта генерации Khoj с метриками токенов
mise run khoj:logs       # Последние 50 строк логов Khoj
mise run khoj:restart    # Перезапуск контейнера Khoj
mise run eval:prompts    # Запуск тестов промптов через Promptfoo
mise run eval:view       # Просмотр результатов тестирования Promptfoo в браузере
mise run sync:prompts    # Синхронизация системных промптов в SQLite AnythingLLM
```

---

## 📋 6. Развертывание и Ansible автоматизация

Весь стек развертывается декларативно:

### Автономная настройка Ollama (GitOps): `playbooks/setup_ollama.yml`
Ollama оформлена как независимый GNU Stow-пакет `ollama/` и не линкуется базовым `setup_user.yml` (исключена из установки на машинах без дискретной GPU).
- **Конфигурация:** `~/.config/ollama/config.env` (Flash Attention, q8_0 KV-кэш, `0.0.0.0:11434`, `/data/models/ollama`).
- **Служба:** `~/.config/systemd/user/ollama.service` с `EnvironmentFile=-%h/.config/ollama/config.env`.
- **Развертывание:**
  ```bash
  # Автономная установка и линковка Ollama:
  ansible-playbook playbooks/setup_ollama.yml
  # или через bash:
  bash scripts/setup_ollama.sh
  ```

### Основной плейбук AI-стека: `playbooks/setup_ai_stack.yml`
```bash
ansible-playbook playbooks/setup_ai_stack.yml
```
Выполняемые шаги:
1. Вызов автономного плейбука `setup_ollama.yml` (Stow пакета `ollama`, запуск `ollama.service`, pull моделей).
2. Подъем Docker Compose `deploy/khoj` (Postgres 16 с pgvector + Khoj). Подробная спецификация структуры и файлов: [`deploy/khoj/README.md`](../deploy/khoj/README.md).
3. Автоматическая первоначальная настройка и триггер индексации Khoj (`deploy/khoj/src/scripts/setup.sh`).
4. Конфигурация Headroom Proxy с подключением к Postgres pgvector и Ollama.
5. Установка и настройка OpenCommit через `pnpm`.
6. Проверка активности службы `headroom-default.service`.

---

## 🛡 7. Защитное программирование и архитектура MCP-серверов

Сервер хост-инструментов переведен на модульный **TypeScript** с валидацией через **Zod** (`anythingllm/.../storage/plugins/src/`) и компилируется в `bash-mcp-server.mjs` через `bun run build`:
1. **Паттерны проектирования:**
   - **Registry Pattern (`ToolRegistry`):** Централизованная регистрация и диспетчеризация инструментов, обработка алиасов (`host-cli`, `host_cli`, `cli`, `bash`) и возврат структурированных подсказок (`available_tools`) при неизвестных вызовах без падений.
   - **Command Pattern (`ToolHandler`):** Каждый инструмент изолирован в своем модуле (`filesystem/`, `system/`, `knowledge/`), реализуя интерфейс с типизированной схемой.
   - **OpenViking Hierarchical Knowledge (`KnowledgeEngine`):** Трехуровневая модель контекста dotfiles в `.agents/knowledge/dotfiles/`:
     - **L0 (Abstract):** `project_knowledge(level="L0")` — мгновенная ментальная карта модулей, stow-пакетов и ключевых правил (~200 токенов).
     - **L1 (Subsystems):** `project_knowledge(level="L1", target="<id>")` — архитектурные контракты подсистем (`wm_niri`, `ai_stack`, `storage_nvme`, `playbooks`, `dev_runtimes`, `shell_ux`).
     - **L2 (Specs & CLI Help):** `cli_help(command_name="...")` — извлечение или фоновый сбор точного синтаксиса `--help` утилит хоста (`niri`, `mise`, `stow`, `khoj-ctl`, etc.).
     - **ADR Logging:** `save_decision(...)` — фиксация архитектурных решений и баг-логов в `.agents/knowledge/dotfiles/adr/`.
2. **Defensive Coercion через Zod:**
   - Модели класса 14B при формировании аргументов защищены кастомными препроцессорами Zod (`coercedNumber`, `coercedBoolean`, `coercedString`), преобразующими строки вида `"50"` в числа, `"true"` в булевы флаги, и подставляющими безопасные дефолты.
3. **Сборка и тесты:**
   - `mise run build:mcp` — мгновенная компиляция через `bun`.
   - `bun test` — 100% покрытие схем Zod, коэрсинга, движка OpenViking и реестра инструментов.

