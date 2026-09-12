# Secrets & Local Environment Variables Policy (`mise.local.toml`)

## Core Rule: Zero Secrets in Public / Tracked Code
- Never hardcode API keys, passwords, credentials, sensitive endpoints, or personal secrets into tracked project files (code, scripts, playbooks, compose files, markdown, etc.).
- Across all projects, sensitive local settings and secret environment variables must be stored in `mise.local.toml` (and managed/loaded through `mise`).

## Implementation Protocol
1. **Local Variables File**: Use `mise.local.toml` at the project root for local environment overrides and secrets.
2. **Git Hygiene**: Ensure `mise.local.toml` is added to `.gitignore` so secrets are never accidentally committed or exposed in public repositories.
3. **Template / Example**: If introducing configuration variables, provide a committed template (e.g., `mise.toml` or `mise.example.toml`) containing placeholder values or defaults, pointing developers to override sensitive values inside `mise.local.toml`.
