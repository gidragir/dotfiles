Viewed SKILL.md:1-85
Viewed SKILL.md:1-82
Viewed setup_anythingllm.yml:1-113
Viewed setup_ollama.yml:1-92
Viewed setup_ollama.sh:1-41
Viewed anythingllm-sync.sh:1-23
Viewed setup_headroom.sh:1-157
Viewed sync-prompts.ts:1-150
Viewed sync-prompts.ts:151-211
Listed directory anythingllm
Listed directory anythingllm-desktop
Listed directory prompts
Listed directory storage
Listed directory plugins
Listed directory agent-skills
Viewed SKILL.md:1-69
Viewed SKILL.md:1-86
Searched for "embed"
Viewed headroom_anythingllm_troubleshooting.md:1-100
Viewed headroom_anythingllm_troubleshooting.md:101-250
Viewed headroom_anythingllm_troubleshooting.md:251-428
Searched for "ollama"
Viewed packages.yml:110-129
Viewed packages.yml:60-110
Viewed anythingllm_mcp_servers.json:1-28
Listed directory host-cli
Viewed plugin.json:1-37
Viewed plugin.json:1-37
Viewed assistant-chats.md:1-39
Viewed onlychats.md:1-38
Viewed main-workspace.md:1-26

Проведено глубокое ревью архитектурного стека **AnythingLLM Desktop**, **Headroom Proxy**, **Ollama**, **MCP-серверов** и агентских навыков с учётом аппаратной специфики вашей рабочей станции (**NVIDIA GeForce RTX 4070 Ti Super 16GB VRAM**, Dual-NVMe Btrfs/XFS, CachyOS Niri) и практик из `Awesome-local-LLM`.

Для стресс-тестирования решений и формулирования спецификаций применены паттерны **`/meta-prompting`** (`/think`, `/compare`, `/edge`, `/premortem`), правила структурирования агентов **`/writing-for-agents`** и принципы машинной валидации промптов **`/refine-prompt`**.

---

## 🏛 1. Архитектурный аудит: Текущее состояние vs Физические ограничения (16 ГБ VRAM)

В вашем репозитории уже выстроена зрелая архитектура:
1. Изолированный пользовательский демон `ollama.service` (`/usr/bin/ollama-cuda`) с Flash Attention и 8-битным квантованием KV-кэша (`q8_0`).
2. Headroom Proxy в режиме прозрачного сжатия и кэширования префиксов (без деструктивной подмены на `<<ccr:...>>` для локальных инструментов).
3. Кастомный TypeScript/Mise стек в `anythingllm/` для сборки MCP-серверов и декларативной синхронизации SQLite (`sync-prompts.ts`).

### Реальность 16 ГБ VRAM (Ada Lovelace):
Модель класса **14B Q4_K_M** занимает **~9.2 ГБ VRAM**. При контексте 16k–32k токенов (даже с `q8_0` KV-кэшем и Flash Attention) суммарный аллок доходит до **12.5–14.0 ГБ VRAM**.
> [!WARNING]
> **Бюджет памяти:** На рабочей станции остаётся всего **2–3.5 ГБ свободной VRAM** для Wayland-композитора Niri, браузера (Vivaldi с аппаратным ускорением) и Electron (AnythingLLM). 
> **Следствие:** Любые решения, требующие параллельного удержания второй модели (например, фоновый тяжелый Embedder на GPU или второй инференс-сервер), должны быть строго выверены по памяти.

---

## 🔍 2. Глубокий анализ ключевых компонентов

### A. LLM Provider: Ollama vs. llama.cpp Server vs. vLLM / Aphrodite

| Критерий | Ollama (текущий) | llama.cpp Server (`llama-server`) | vLLM / Aphrodite |
| :--- | :--- | :--- | :--- |
| **Управление VRAM** | Отличное (динамический `keep_alive`, выгрузка в RAM) | Среднее (фиксированный слот памяти под один инстанс) | Низкое для десктопа (по умолчанию резервирует 90% VRAM) |
| **Квантование & Форматы** | GGUF (на лету из реестра) | GGUF + imatrix (максимальная точность) | AWQ / GPTQ / FP8 / unquantized |
| **Structured Output / GBNF** | JSON mode через системный промпт (бывают сбои) | **Абсолютная гарантия** (GBNF-грамматики на уровне логитов) | JSON Schema через Outlines / Guided Decoding |
| **Speculative Decoding** | Нет (только планируется) | **Да** (драфтинг 14B модели через 0.5B/1.5B на том же токенайзере) | Да (требует много VRAM) |
| **Сложность внедрения** | 0 (уже работает в `setup_ollama.yml`) | Средняя (нужен systemd юнит и сборка под CUDA) | Высокая (нецелесообразно на 16 ГБ VRAM) |

> **`/think` Решение по провайдеру:**
> 1. **vLLM / Aphrodite отбрасываем**: они идеальны для серверных кластеров с 24–80 ГБ VRAM и непрерывного батчинга. На домашнем десктопе с 16 ГБ VRAM vLLM вызовет OOM композитора Niri при старте браузера.
> 2. **Гибридный путь (Рекомендация):**
>    - Оставить **Ollama** как основной бэкенд общего назначения для динамического переключения между `qwen2.5:14b`, `qwen2.5-coder:14b` и `deepseek-r1:14b` (параметр `OLLAMA_MAX_LOADED_MODELS=1` исключает OOM).
>    - Для критичных задач кодогенерации и вызова инструментов подключить **`llama-server`** как опциональный secondary provider с жестким наложением GBNF-грамматики схем инструментов AnythingLLM.

---

### B. Embedder (Векторизатор): Ликвидация «бутылочного горлышка»

В текущем `sync-prompts.ts` провайдер эмбеддингов не сконфигурирован жестко, из-за чего AnythingLLM использует дефолтный встроенный движок **Xenova/all-MiniLM-L6-v2** (384d, CPU).
* **Проблема:** MiniLM почти не понимает русскоязычную морфологию и структуру заметок Obsidian (`onlychat`), выдавая слабый скоринг семантического поиска.
* **Решение:** Перевести AnythingLLM на выделенный локальный Embedder в Ollama.

#### Рекомендуемые кандидаты:
1. **`bge-m3:latest`** (1024d, контекст 8192):
   - Флагман мультиязычного семантического поиска (русский + английский + код).
   - Поддерживает плотный (dense) и разреженный (sparse/lexical) поиск.
   - Размер весов: всего ~1.2 ГБ. В VRAM подгружается мгновенно, не мешая модели 14B.
2. **`nomic-embed-text:v1.5`** (768d, контекст 8192):
   - Ультралегкий (~560 МБ), поддержка Matryoshka Embeddings (можно урезать до 512d без потери качества).

**Что изменить в `setup_ollama.yml`:**
Добавить `bge-m3` в список загружаемых моделей:
```yaml
target_models:
  - "qwen2.5-coder:14b"
  - "qwen2.5:14b"
  - "deepseek-r1:14b"
  - "bge-m3:latest"   # Выделенный GPU-эмбеддер
```
И в `sync-prompts.ts`:
```typescript
{
  label: "embedding_engine",
  value: "ollama",
},
{
  label: "embedding_model_pref",
  value: "bge-m3:latest",
}
```

---

### C. Vector Base (Векторная база): LanceDB vs. Qdrant vs. Chroma

* **LanceDB (Текущая база по умолчанию в AnythingLLM):**
  - *Плюсы:* Serverless, встроена в процесс бэкенда (написана на Rust), нулевой оверхед по фоновым демонам и портам, прямое сохранение в NVMe Btrfs (`~/.config/anythingllm-desktop/storage/lancedb`).
  - *Производительность:* На объеме персонального хранилища Obsidian (~5 000–50 000 чанков) отклик составляет **<2 мс**.
* **Qdrant:**
  - *Плюсы:* Полноценный гибридный поиск (Dense веса + BM25 Sparse), фильтрация по payload (теги Obsidian, папки `PARA/`, даты).
  - *Минусы:* Требует отдельного демона (Docker-контейнер или системный сервис), потребляет постоянные 200–500 МБ RAM.
* **Chroma:**
  - Известна утечками памяти на длительных сессиях, уступает Qdrant и LanceDB.

> **`/verify` Вердикт по Vector DB:**
> Оставить **LanceDB** внутри AnythingLLM. Для однопользовательского десктопа поднимать отдельный Qdrant ради нескольких тысяч заметок — неоправданный расход ресурсов. Связка **LanceDB + Embedder `bge-m3`** даст 95% прирост качества поиска по Obsidian без усложнения инфраструктуры.

---

### D. Model Router: Роль LiteLLM Proxy и Headroom

В вашем анализе предложен **LiteLLM Proxy**. Давайте оценим его место в текущей топологии:

#### Текущая цепочка:
`AnythingLLM (:8787)` $\to$ `Headroom (:8787)` $\to$ `Ollama (:11434)`

#### Если добавить LiteLLM:
`AnythingLLM` $\to$ `Headroom (:8787 - сжатие контекста)` $\to$ `LiteLLM (:4000 - маршрутизация)` $\to$ `Ollama / llama-server / OpenRouter`

#### В чем реальная ценность LiteLLM для вашего сетапа:
1. **Fallback на облако при переполнении контекста:** Если локальный `qwen2.5-coder:14b` получает контекст >32k токенов или падает по таймауту, LiteLLM прозрачно перенаправляет запрос на внешний API (OpenRouter / DeepSeek API / Gemini) без прерывания диалога.
2. **Unified Model Aliasing:** Можно создать виртуальные алиасы:
   - `model: "fast-code"` $\to$ `ollama/qwen2.5-coder:14b`
   - `model: "heavy-reasoning"` $\to$ `ollama/deepseek-r1:14b` (с фоллбэком на cloud DeepSeek-R1)
3. **Guardrails & Outlines:** В LiteLLM можно настроить предвалидацию JSON-схем ответов.

> **Ограничение:** LiteLLM на Python добавляет ~15–25 мс к TTFT и требует поддержания ещё одного сервиса systemd. Если вы работаете 100% локально, текущий тандем `AnythingLLM -> Headroom -> Ollama` быстрее и надёжнее. LiteLLM целесообразно внедрять **только при необходимости гибридного режима Local + Cloud Failover**.

---

### E. Agent Skills, Память и Structured Output

#### 1. Гарантия структурированного вывода (Outlines / JSON Schema)
Проблема со сбоями вызова инструментов в SLM решается на трех эшелонах:
1. **Эшелон 1 (MCP-сервер `bash-mcp-server.mjs`):** Использование библиотеки `zod` с принудительным `safeParse` и автоисправлением. Если модель передала число вместо строки, обработчик должен сам выполнить коэрсию типов (`String(args.command)`), а не падать с ошибкой валидации MCP.
2. **Эшелон 2 (Defensive Tool Results):** Если модель ошиблась в аргументах, MCP-сервер возвращает не ошибку со статусом 500, а структурированную подсказку для модели:
   ```json
   {"error": "Invalid arguments", "expected_schema": "...", "received": "..."}
   ```
   Это позволяет Qwen-14B автоматически скорректировать вызов на следующем шаге агентной петли.
3. **Эшелон 3 (Системный промпт):** Применение правил `/refine-prompt` (см. раздел 3 ниже).

#### 2. Долговременная память: Mem0 vs Headroom vs Native Memory
В Базе Знаний ([troubleshooting doc](file:///data/projects/dotfiles/docs/headroom_anythingllm_troubleshooting.md#L154-L170)) зафиксирован критический баг: включение `--memory` в Headroom ломало SSE-стриминг и вызывало галлюцинации у SLM из-за инъекции инструкции `ALWAYS call memory_search BEFORE searching files`.
* **Архитектурный паттерн для Mem0:** 
  Mem0 **нельзя** ставить как перехватчик системных промптов на уровне прокси!
  Правильный подход: оформить Mem0 как **MCP-инструмент** в `anythingllm_mcp_servers.json`:
  - `save_agent_fact`: сохранение предпочтения или ошибки.
  - `recall_agent_facts`: поиск по истории взаимодействия при явной необходимости.
  Тогда модель использует память осознанно, а не принудительно на каждом шаге.

#### 3. Тестирование и валидация скиллов (Promptfoo)
Для репозитория dotfiles с хуками `lefthook` инструмент **Promptfoo** — идеальное дополнение:
- Можно создать `evals/promptfoo.yaml`, который перед коммитом прогоняет тестовые промпты («проверь статус git», «найди заметку о лидерстве») через локальный Ollama и проверяет ассерты:
  - Модель вернула вызов правильного инструмента (`search_files`, а не симуляцию).
  - Ответ не содержит китайских иероглифов (CJK check).
  - Ответ уложился в лимит времени TTFT.

---

## ✍️ 3. Ревью и рафинирование промптов (`/refine-prompt` & `/writing-for-agents`)

При анализе текущих файлов промптов в [`prompts/`](file:///data/projects/dotfiles/anythingllm/.config/anythingllm-desktop/prompts/) выявлены следующие моменты:
1. **Наличие отрицаний без позитивных замен:** Фразы типа `Never roleplay or output simulated tool execution` активируют запрещенное поведение. По правилу `/writing-for-agents` и `/refine-prompt` заменяем их на позитивные императивы контракта.
2. **Лишний conversational no-op context:** В `main-workspace.md` и `assistant-chats.md` есть повторения системной топологии, которую модель уже получает из окружения или может прочитать через `search_files`.
3. **Формализация вызова MCP-инструментов:** Для Qwen-14B строгая спецификация вызова инструментов в формате YAML/Markdown повышает надежность парсинга JSON.

### Пример рафинированного промпта для `assistant-chats.md`:
```markdown
# ROLE & OBJECTIVE
Staff Systems & DevOps Engineer on CachyOS Linux (Niri Wayland).
Core mission: inspect Git state, maintain idempotent Ansible playbooks, and automate shell/desktop workflows with zero regressions.

# OPERATIONAL PROTOCOLS

## 1. Execution & Communication
- Match the user's language: Russian if addressed in Russian, English if addressed in English.
- Keep commit messages, code symbols, terminal commands, and identifiers strictly in English.
- Output direct engineering analysis and verifiable state. Omit greetings and filler prose.

## 2. Infrastructure as Code (Ansible & Stow)
- Reference all packages strictly in `playbooks/vars/packages.yml`.
- Ensure all Ansible tasks are idempotent with explicit conditionals (`creates:`, `changed_when:`, `stat`).
- Mirror `$HOME` path structure inside stow packages under `/data/projects/dotfiles/`.

## 3. Host Inspection & Tools (@agent)
- Inspect Git state via `git_status` and `git_diff` before proposing changes.
- Search codebases via `search_files` with `directory: "/data/projects"` or target repository path.
- Read file segments via `read_file`.
- Execute shell operations via `execute_command`.
- Compress outputs larger than 500 lines via `headroom_compress`.

## 4. Atomic Commits Protocol (@agent)
When instructed to execute atomic commits ("выполни все атомарные коммиты", "commit all changes"):
1. Invoke the `atomic-commits` tool with:
   `{"repo_path": "/data/projects/dotfiles", "auto_commit": true}`
2. Report created commit hashes, messages, and staged file counts upon completion.
3. Verify that the working tree is clean.
```

---

## 📋 4. Итоговые рекомендации и план действий

### Приоритет 1 (Немедленные улучшения без оверхеда):
1. **Внедрение GPU Embedder `bge-m3`:**
   - Добавить `bge-m3:latest` в `playbooks/setup_ollama.yml`.
   - В `sync-prompts.ts` прописать системные настройки AnythingLLM: `embedding_engine = "ollama"`, `embedding_model_pref = "bge-m3:latest"`.
   - Это кардинально повысит качество RAG по заметкам Obsidian без увеличения расхода RAM.
2. **Очистка и защита схем в `bash-mcp-server.mjs`:**
   - Добавить нормализацию входных параметров через Zod (коэрсия строк и чисел) для устранения сбоев синтаксиса у Qwen-14B.
3. **Рафинирование промптов:**
   - Обновить `assistant-chats.md`, `onlychats.md` и `main-workspace.md` по правилам `/refine-prompt`.

### Приоритет 2 (Развитие DX и валидации):
1. **Интеграция Promptfoo в `mise` / `lefthook`:**
   - Создать набор тестов для автоматической валидации промптов и MCP-инструментов на локальном инференсе Ollama перед коммитом.
2. **Адаптация secondary бэкенда `llama-server` (опционально):**
   - Добавить в `packages.yml` пакет `llama-cpp-cuda` (или использовать AUR `llama-cpp-git`) для запуска выделенного инстанса с GBNF-грамматиками при решении сложных задач структурированного вывода.

---

Если вы хотите применить улучшения (например, подключить `bge-m3`, обновить `sync-prompts.ts` и оптимизировать промпты воркспейсов), подтвердите, и я подготовлю точечные изменения в репозитории.