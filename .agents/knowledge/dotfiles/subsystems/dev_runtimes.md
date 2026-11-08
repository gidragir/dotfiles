# Subsystem: Development Toolchains & Runtimes (L1)

## Mise Runtime Manager
- Configuration: `omni-dotfiles` -> deployed via Yggdrasil to `~/.config/mise/config.toml`.
- Shims path: `~/.local/share/mise/shims`.
- Default runtimes: Node.js (`lts`), Bun (`latest`), pnpm (`latest`), Python (`uv`).

## Rust Toolchain Optimization
- Compiler: `rustup` stable.
- Fast Linker: `mold` + `clang` configured in `cargo/config.toml` (managed via `omni-dotfiles`).
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
| `dotfiles:status` | Check status of Yggdrasil managed configurations (`ygg status`) |
| `dotfiles:diff` | Inspect diff between dotfiles repository and `$HOME` (`ygg apply --dry-run`) |
| `dotfiles:verify` | Verify zero drift between dotfiles repository and `$HOME` (`ygg apply --dry-run`) |
| `dotfiles:apply` | Apply repository configurations to `$HOME` (`ygg apply`) |
| `apply:all` | Apply omni-dotfiles followed by dotfiles (`ygg apply`) |
| `test:e2e` | Run E2E test suite for Noctalia plugins |
| `test:check` | Run comprehensive host environment health check (`scripts/check_setup.sh`) |
