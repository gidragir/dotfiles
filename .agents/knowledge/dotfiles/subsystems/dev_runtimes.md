# Subsystem: Development Toolchains & Runtimes (L1)

## Mise Runtime Manager
- Managed via `mise/.config/mise/` -> `~/.config/mise/`.
- Shims path: `~/.local/share/mise/shims`.
- Tool versions managed: Node.js (`v24.x`), Bun (`1.4.x`), pnpm (`11.x`), Python (`uv`).

## Rust Toolchain Optimization
- Compiler: `rustup` stable.
- Fast Linker: `mold` configured globally in `cargo/.cargo/config.toml`.
- Compilation Cache: `sccache` targeting `/data/projects/.sccache`.
- Fast Package Installer: `cargo-binstall` used for quick binary installation without compiling from source.

## JavaScript & TypeScript Toolchains
- Runtime/Bundler: `bun` used for bundling plugins and scripts.
- Package Manager: `pnpm` (store at `/data/projects/.pnpm-store`).
- Linter & Formatter: `biome` for lightning fast type and format checking.

## Python Toolchain
- Package & Environment Manager: `uv` (cache at `/data/projects/.uv-cache` with zstd compression).

## New Tasks in Mise
- **eval:prompts**: Sync workspace prompts from dotfiles into AnythingLLM SQLite database.
- **eval:view**: Open Promptfoo results viewer in browser.
- **ai:status**: Quick status check for Ollama, Headroom, Khoj, and Postgres.
- **khoj:test**: Send a test prompt to Khoj chat endpoint and display response.
- **eval:promptfoo**: Run Promptfoo evaluation suite against local Ollama.
- **eval:promptfoo:view**: Open Promptfoo results viewer in browser.
- **ai:up**: Start Khoj & Postgres stack in local-ai-stack submodule.
- **ai:down**: Stop Khoj & Postgres stack in local-ai-stack submodule.

## Recent Git Changes

### Mise Configuration Updates
- Added new tasks in `mise.toml`:
  - **eval:prompts**: Sync workspace prompts from dotfiles into AnythingLLM SQLite database.
  - **eval:view**: Open Promptfoo results viewer in browser.
  - **ai:status**: Quick status check for Ollama, Headroom, Khoj, and Postgres.
  - **khoj:test**: Send a test prompt to Khoj chat endpoint and display response.
  - **eval:promptfoo**: Run Promptfoo evaluation suite against local Ollama.
  - **eval:promptfoo:view**: Open Promptfoo results viewer in browser.
  - **ai:up**: Start Khoj & Postgres stack in local-ai-stack submodule.
  - **ai:down**: Stop Khoj & Postgres stack in local-ai-stack submodule.
