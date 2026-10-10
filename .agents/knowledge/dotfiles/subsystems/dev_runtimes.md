# Subsystem: Development Toolchains & Runtimes (L1)

## Mise Runtime Manager
- Configuration: `home/dot_config/mise/config.toml` -> deployed via Chezmoi to `~/.config/mise/config.toml`.
- Shims path: `~/.local/share/mise/shims`.
- Default runtimes: Node.js (`lts`), Bun (`latest`), pnpm (`latest`), Python (`uv`).

## Rust Toolchain Optimization
- Compiler: `rustup` stable.
- Fast Linker: `mold` + `clang` configured in `home/dot_cargo/config.toml`.
- Compilation Cache: `sccache` targeting `/data/projects/.sccache`.
- Cargo Cache Symlinks: `~/.cargo/registry` and `~/.cargo/git` point to `/data/projects/.cargo-cache/`.
- Fast Binary Installer: `cargo-binstall` used for quick binary installation without compiling from source (`bacon`, `cargo-nextest`, `cargo-machete`, `cargo-ramdisk`).

## JavaScript & TypeScript Toolchains
- Runtime/Bundler: `bun` used for script execution and host CLI MCP server.
- Package Manager: `pnpm` (content-addressable store at `/data/projects/.pnpm-store` allowing instant same-FS hardlinks).
- Linter & Formatter: `biome` for lightning-fast type and format checking.

## Python Toolchain
- Package & Environment Manager: `uv` (cache at `/data/projects/.uv-cache` with Btrfs zstd compression).
- Tool binaries: `uv tool` isolated virtualenvs in `~/.local/share/uv/`.

## Tasks in `mise.toml`
| Task | Description |
| :--- | :--- |
| `ai:status` | Status check for Ollama, Headroom, Khoj, and Postgres |
| `knowledge:l0` | Inspect L0 abstract mental map of the dotfiles repository |
| `dotfiles:status` | Check status of Chezmoi managed configurations |
| `dotfiles:diff` | Inspect diff between dotfiles repository and `$HOME` |
| `dotfiles:verify` | Verify zero drift between dotfiles repository and `$HOME` |
| `dotfiles:apply` | Apply repository configurations to `$HOME` |
| `test:e2e` | Run E2E test suite for Noctalia plugins |
| `test:check` | Run comprehensive host environment health check (`scripts/check_setup.sh`) |
