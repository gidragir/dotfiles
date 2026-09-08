# Headroom Context Optimization

## Triggers & Thresholds
- Call `headroom_compress` when input text or file content exceeds 500 lines.
- Call `headroom_compress` when command output, system logs, or git diffs exceed 100 lines.
- Call `headroom_compress` for large search results or reference documentation before reasoning over them.

## Safety & Code Editing Constraints
- Must NEVER use Headroom compression on files targeted for line-by-line editing via `replace_file_content` or `multi_replace_file_content`.
- Always inspect the raw file content directly when preparing code replacements to ensure exact whitespace and string matching.
- Limit Headroom compression to research, planning, summarization, and read-only analysis tasks.

## Retrieval & Monitoring Protocol
- Call `headroom_retrieve` with the chunk hash when verbatim details or uncompressed context are required.
- Call `headroom_stats` to verify token savings and compression efficiency when evaluating session context.
