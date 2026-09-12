# Subsystem: Personal AI Stack & Architecture (L1)

## Resource Constraints & Hardware
- GPU: ASUS NVIDIA GeForce RTX 4070 Ti Super (16 GB vRAM).
- Budget: ~2.5 GB desktop (Niri Wayland) + ~9.2 GB 14B model (Q4_K_M) + ~3.0 GB KV Cache (16k FlashAttention q8_0) + ~1.2 GB bge-m3 embedder = ~15.5 GB total.
- Rule: `OLLAMA_MAX_LOADED_MODELS=1` in `ollama/.config/ollama/config.env`. No multi-model batching (vLLM forbidden to prevent Niri OOM).

## Three Operational Circuits
1. Terminal Circuit (Ghostty + Zsh):
   - `OpenCommit` via Ollama (:11434, `qwen2.5-coder:14b`).
   - Alias: `gcai` (`git add -p && opencommit`).
   - Knowledge search CLI: `khoj-ctl` and `khoj-tags`.
2. Active Development Circuit (Antigravity IDE):
   - Headroom Proxy (:8787): AST-pruning, deduplication, semantic caching in PostgreSQL (`headroom_cache`).
   - Host CLI MCP server (`bash-mcp-server.mjs`).
   - Khoj MCP server (stdio via docker exec).
3. Knowledge & Notes Circuit (Obsidian + Khoj + AnythingLLM):
   - Obsidian: `/data/obsidian` (Markdown notes, frontmatter tags).
   - Khoj AI (:42110): Docker container, live indexing, tag search, web search agent.
   - PostgreSQL 16 + pgvector (:5432): Shared vector DB for Khoj embeddings and Headroom cache.
   - AnythingLLM Desktop: Interactive brainstorming UI, workspaces for Socratic dialogue and research.

## Network Topology & Ports
- `11434`: Ollama HTTP API.
- `8787`: Headroom Proxy HTTP API.
- `5432`: PostgreSQL (pgvector).
- `42110`: Khoj AI Web & API.

## Recent Configurations & Hotkeys
- **AnythingLLM Desktop**:
  - **Prompts**:
    - `assistant-chats.md`: Updated to communicate in Russian or English using only Cyrillic and Latin scripts.
    - `main-workspace.md`: Simplified system topology and environment facts, focusing on language and reasoning protocols.
    - `onlychats.md`: Clarified language and reasoning protocols, ensuring factual and verifiable analysis.
  - **Storage Plugins**:
    - `bash-mcp-server.mjs`: Expanded to include more detailed server logic and error handling.
    - `build.ts`: Added build scripts for MCP Server and Agent Skills Handlers, ensuring efficient compilation and deployment.

- **Hotkeys**:
  - `Ctrl+Shift+P`: Open the command palette in Ghostty.
  - `Alt+Shift+D`: Toggle dark mode in Obsidian.
  - `F5`: Refresh the Khoj AI web interface.
  - `Ctrl+Alt+T`: Open a new terminal window in Ghostty.
  - `Ctrl+Alt+K`: Open the Khoj AI web interface.
  - `Ctrl+Alt+L`: Open the AnythingLLM Desktop application.

These updates ensure a seamless and efficient workflow across the AI stack, leveraging the latest configurations and hotkeys for optimal performance.
