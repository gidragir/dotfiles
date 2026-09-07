# 🤖 AGENTS.md — AnythingLLM Skills & MCP Development (AIDD Guide)

> **Назначение документа:** Инструкция и стандарты для AI-ассистентов и разработчиков по созданию, сборке, тестированию и отладке расширений для **AnythingLLM Desktop** (Agent Skills и MCP серверы) на базе TypeScript и Bun.

---

## 🏗 1. Архитектура и стек разработки

- **Стек:** TypeScript, Bun (`bun build`), Node.js (runtime хоста), CommonJS target.
- **Два типа расширений:**
  1. **Agent Skills (`agent-skills/<skill-id>/`):**
     - Встроенные плагины AnythingLLM, которые можно включать/отключать per-workspace в интерфейсе.
     - Обязаны содержать `plugin.json` (манифест `skill-1.0.0`) и `handler.js` (скомпилированный CommonJS модуль, экспортирующий `{ runtime: { handler: async (args) => string } }`).
     - Разработка ведется строго в `handler.ts`, сборка — через `bun run build`.
  2. **MCP Серверы (`anythingllm_mcp_servers.json`):**
     - Внешние серверы по протоколу Model Context Protocol (MCP) через Stdio.
     - `bash-mcp-server.mjs`: Сервер прямого доступа к CLI хоста через `/usr/bin/zsh`.
     - `filesystem`: Официальный сервер MCP для чтения/записи разрешенных директорий (`/data/projects`, `/data/obsidian`).

---

## 🗂 2. Структура проекта

```
anythingllm/.config/anythingllm-desktop/storage/plugins/
├── AGENTS.md                     # Этот документ (AIDD стандарты и правила)
├── README.md                     # Документация и справочник CLI команд
├── package.json                  # Скрипты сборки Bun, зависимости
├── tsconfig.json                 # Настройки TypeScript компилятора
├── anythingllm_mcp_servers.json  # Декларация активных MCP серверов
├── bash-mcp-server.mjs           # MCP-сервер выполнения CLI команд на хосте
│
├── agent-skills/                 # Каталог кастомных навыков AnythingLLM
│   ├── _template/                # 🌟 Шаблон для быстрого создания нового скилла
│   │   ├── plugin.json
│   │   └── handler.ts
│   └── atomic-commits/           # Скилл анализа Git и генерации Conventional Commits
│       ├── plugin.json           # Спецификация навыка AnythingLLM
│       ├── handler.ts            # Исходник на TypeScript
│       └── handler.js            # Автономный скомпилированный бандл (CommonJS)
```

---

## ⚙️ 3. Правила разработки нового Agent Skill

### Шаг 1: Создание структуры
Создайте директорию в `agent-skills/<skill-name>`:
```bash
mkdir -p agent-skills/my-new-skill
```

### Шаг 2: Манифест `plugin.json`
Манифест строго следует схеме `skill-1.0.0`:
```json
{
  "active": true,
  "hubId": "my-new-skill",
  "name": "Human Readable Name",
  "schema": "skill-1.0.0",
  "version": "1.0.0",
  "description": "Краткое и четкое описание того, что делает инструмент.",
  "author": "gidragir",
  "author_url": "https://github.com/gidragir/dotfiles",
  "license": "MIT",
  "setup_args": {},
  "examples": [
    {
      "prompt": "Пример пользовательского запроса",
      "call": "{\"param1\": \"val\"}"
    }
  ],
  "entrypoint": {
    "file": "handler.js",
    "params": {
      "param1": {
        "description": "Описание параметра",
        "type": "string"
      }
    }
  },
  "imported": true
}
```

### Шаг 3: Написание кода в `handler.ts`
Стандартная сигнатура:
```typescript
export interface SkillParams {
  param1?: string;
}

export const runtime = {
  handler: async function (params: SkillParams): Promise<string> {
    try {
      // Логика инструмента
      return "Результат для LLM";
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      return `Error: ${message}`;
    }
  },
};
```

### Шаг 4: Сборка через Bun
Сборка обязательна для генерации `handler.js`:
```bash
bun run build
```
Правила сборщика:
- `--target node`
- `--format cjs` (AnythingLLM backend жестко ожидает CommonJS при `require()`).

---

## 🔍 4. Поиск готовых скиллов (`npx skills`)

Для вдохновения или быстрого заимствования паттернов используйте CLI каталог:
```bash
# Поиск скиллов по ключевым словам
npx -y skills find <query>

# Поиск по автору
npx -y skills find --owner vercel-labs
```

---

## 🧪 5. Тестирование и валидация

Перед тем как проверять скилл в UI AnythingLLM, запустите локальный тест в CLI:
```bash
# Проверка экспорта и загрузки в Node.js:
node -e 'const h = require("./agent-skills/<skill-name>/handler.js"); console.log(h.runtime.handler);'

# Тестовый вызов функции:
node -e 'require("./agent-skills/<skill-name>/handler.js").runtime.handler({}).then(console.log);'
```

---

## 💎 6. Золотые правила для AI-агентов (AIDD Checklist)

1. **Никогда не редактируйте `handler.js` вручную:** Всегда редактируйте `handler.ts` и запускайте `bun run build`.
2. **Строго CommonJS выход:** В `package.json` должен оставаться `"type": "commonjs"`. Для ES-модулей в этой папке используйте только расширение `.mjs` (например, `bash-mcp-server.mjs`).
3. **Безопасность путей:** При выполнении shell-команд всегда оборачивайте пути в кавычки и используйте безопасный fallback (например, по умолчанию `/data/projects/dotfiles`).
4. **Не ломайте симлинки Stow:** Репозиторий находится в `/data/projects/dotfiles`. Все изменения выполняются здесь, а в `~/.config/anythingllm-desktop/storage/plugins` они попадают через stow.
