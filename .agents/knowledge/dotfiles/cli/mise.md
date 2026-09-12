# CLI Reference: mise (L2)

## Purpose
`mise` is the polyglot tool version manager and task runner for the workstation.

## Core Tasks & Commands
```bash
# Task Runner (mise run ...)
mise run ai:status                # Verify Ollama, Headroom, Khoj, Postgres
mise run khoj:test                # Test Khoj generation endpoint with token stats
mise run khoj:restart             # Safe restart of Khoj container
mise run eval:prompts             # Run promptfoo tests
mise run eval:view                # Open promptfoo web view in browser
mise run sync:prompts             # Sync prompts to AnythingLLM SQLite database

# Tool Version Management
mise install                      # Install tools defined in ~/.config/mise/config.toml
mise use node@24                  # Set runtime version
mise list                         # Show installed tools and active versions
mise doctor                       # Check environment and shims sanity
```
