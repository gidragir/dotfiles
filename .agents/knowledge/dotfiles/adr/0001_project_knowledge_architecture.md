# ADR 0001: OpenViking-Inspired Hierarchical Project Knowledge Architecture

- **Status:** Accepted
- **Date:** 2026-09-12
- **Context:** During extensive configuration work on CachyOS dotfiles, LLM models (especially 14B local models and cloud agents) need fast, reliable access to architectural decisions, subsystem boundaries, and CLI parameters without flooding the limited context window (16k tokens) or hallucinating commands.
- **Decision:**
  1. Adopt a 3-tier hierarchical structure:
     - L0: Global abstract map in `L0_index.json` (~200 tokens).
     - L1: Per-subsystem architecture cards in `subsystems/*.md`.
     - L2: CLI syntax and detailed specs in `cli/*.md` and ADR files.
  2. Implement explicit MCP tool calls (`project_knowledge`, `save_decision`, `cli_help`) rather than implicit memory prompt injection.
  3. Refactor the MCP server to modular TypeScript with Zod validation and compile it via `bun build` to `bash-mcp-server.mjs`.
- **Consequences:**
  - Token consumption drops by up to 80% when querying system knowledge.
  - Zero risk of context poisoning.
  - High extensibility for adding new subsystems and tools.
