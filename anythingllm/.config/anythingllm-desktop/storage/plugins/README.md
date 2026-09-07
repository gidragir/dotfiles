# 🧩 AnythingLLM Skills & MCP Hub (Dotfiles Extension)

Проект разработки кастомных агентных навыков (Agent Skills) и MCP-серверов для **AnythingLLM Desktop**.

---

## ⚡ Быстрый старт

### Сборка TypeScript:
```bash
# Однократная сборка всех скиллов:
bun run build

# Режим наблюдения при разработке:
bun run watch
```

### Поиск существующих навыков:
```bash
npx -y skills find <запрос>
```

---

## 📁 Структура
- `agent-skills/` — каталог навыков AnythingLLM.
- `agent-skills/_template/` — заготовка для быстрого создания нового скилла.
- `anythingllm_mcp_servers.json` — конфигурация активных MCP серверов (CLI, Filesystem).
- `bash-mcp-server.mjs` — MCP сервер для выполнения shell-команд через Zsh.
- `AGENTS.md` — подробный гайдлайны разработки для AI-ассистентов.
