# Subsystem: Personal AI Stack & Architecture (L1)

## Resource Constraints & Hardware
- **GPU:** ASUS NVIDIA GeForce RTX 4070 Ti Super (16 GB vRAM).
- **Budget:** ~2.5 GB desktop (Niri Wayland) + ~9.2 GB 14B model (Q4_K_M) + ~3.0 GB KV Cache (64k context q8_0) + ~1.2 GB bge-m3 embedder = ~15.5 GB total.
- **Inference Invariant:** `OLLAMA_MAX_LOADED_MODELS=1` strictly enforced. Batching servers (vLLM) are prohibited to prevent compositor OOM crashes in Niri. 100% GPU offload verified via `ollama ps`.

## Three Operational Circuits

### 1. Terminal Circuit (Ghostty + Zsh)
- **OpenCommit:** Fast AI commit generation via local Ollama (`qwen2.5:14b-ctx64k` / `qwen2.5-coder:14b` on `:11434`).
- **Alias:** `gcai` (`git add -p && opencommit`).
- **Knowledge CLI:** `khoj-ctl` and `khoj-tags` for rapid note lookup and search.

### 2. Active Development Circuit (Antigravity IDE)
- **Headroom Proxy (:8787):** CCR AST-compression, deduplication, and semantic caching in PostgreSQL (`headroom_cache`).
- **Host CLI MCP Server:** TypeScript/Bun server (`services/host-cli/`) providing typesafe tools with Zod validation and defensive error hints.
- **Khoj MCP Server:** stdio RAG search interface via `docker exec -i khoj khoj-mcp`.

### 3. Knowledge, Memory & Multi-Agent Circuit
- **Obsidian Vault:** `/data/obsidian` (Markdown notes, frontmatter tags, bidirectional sync via `rclone-obsidian-sync.timer`).
- **Khoj AI (:42110):** Docker container with live indexing of Obsidian vault and web research capabilities.
- **PostgreSQL 16 + pgvector (:5432):** Shared vector store for Khoj embeddings and Headroom cache.
- **Hindsight Long-Term Memory (:9999):** 3-tier memory engine (`world`/`experience` evidence vs `observation` consolidated layer). CLI management via `manage-hindsight.sh`.
- **Hermes Idea Pipeline:** Multi-agent intake and refinement funnel (`idea-receiver` -> `idea-refiner` -> `coder`/`thinker`) with 18 MCP tools, Noctalia telemetry integration, and zero-terminal safety.

## Network Topology & Ports
| Port | Service | Purpose |
| :--- | :--- | :--- |
| `11434` | Ollama HTTP API | Local SLM inference engine |
| `8787` | Headroom Proxy | Context-compression proxy & CCR |
| `5432` | PostgreSQL (pgvector) | Vector embeddings & Headroom cache |
| `42110` | Khoj AI Web & API | Knowledge base RAG & note indexing |
| `9999` | Hindsight Long-Term Memory | Agent episodic & observational memory |

## Cross-Repo Symlink Integrity (`ai-dotfiles` vs `dotfiles`)
- **Pre-Cleanup Audit Invariant:** Before deleting broken symlinks or config remnants in `~` or `~/.config`, always inspect `/data/projects/ai-dotfiles`.
- **AnythingLLM Integration:** `~/.config/anythingllm-desktop/` depends on files in `ai-dotfiles/services/anythingllm/` (`prompts`, `sync-prompts.ts`, `anythingllm_mcp_servers.json`, `skills`) and `ai-dotfiles/services/host-cli/dist/bash-mcp-server.mjs`. Legacy broken links pointing to historical `local-ai-stack` MUST be relinked to `ai-dotfiles`, NOT deleted.
- **Hermes PYTHONPATH Invariant:** `~/.config/environment.d/pythonpath.conf` exports `PYTHONPATH=~/.local/lib/python3.11/site-packages` for `/opt/hermes-agent/venv/bin/python` (Python 3.11.16). Used by `hermes-dashboard.service` and `hermes-gateway.service`. Must never be deleted.
- **User Service Re-linking:** When user systemd units move or break, run `systemctl --user reenable <unit>` to recreate `default.target.wants` symlinks cleanly.

## Diagnostic Commands
```bash
# Verify AI stack status (Ollama, Headroom, Khoj, Postgres):
mise run ai:status

# Inspect Ollama active model and GPU allocation:
ollama ps

# Verify Hindsight service status:
manage-hindsight.sh status
```

