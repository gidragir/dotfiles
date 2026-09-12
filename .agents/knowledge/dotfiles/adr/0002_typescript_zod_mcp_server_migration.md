# ADR 0002: TypeScript Zod MCP Server Migration

- **Status:** Accepted
- **Date:** 2026-09-12

## Context
Single 571-line JS file was becoming unmaintainable with new memory tools.

## Decision
Migrated to modular TypeScript with Zod validation, Registry pattern, and Bun build.

## Consequences
Clean typesafe architecture, zero breaking changes for AnythingLLM.
