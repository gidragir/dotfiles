# CLI Reference: khoj-ctl & khoj-tags (L2)

## Purpose
`khoj-ctl` manages the local Khoj AI Docker service and Obsidian knowledge base index.
`khoj-tags` is a high-speed ripgrep tag analyzer.

## Syntax & Subcommands
```bash
# Health & Status
khoj-ctl status                   # Checks Ollama (:11434), Headroom (:8787), Postgres (:5432), Khoj (:42110)

# Knowledge Search & Interaction
khoj-ctl search "<query>"         # Semantic search across Obsidian notes
khoj-ctl tags [tag]               # List or filter notes by Obsidian #tag
khoj-ctl chat "<query>"           # Interactive chat with local Khoj agent (supports -m <model>)

# Service Lifecycle
khoj-ctl sync                     # Trigger background re-indexing of /data/obsidian
khoj-ctl restart                  # Restart khoj container and wait for healthy state
khoj-ctl logs [-f] [N]            # View last N lines of Docker logs (optionally follow)

# Fast tag queries
khoj-tags list                    # Dump all unique tags across vault
khoj-tags find <tag>              # List all files containing specific tag
```
