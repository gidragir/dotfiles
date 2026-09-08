import { execSync } from "child_process";

export interface SkillHandlerParams {
  repo_path?: string;
  auto_commit?: boolean;
}

interface FileGroup {
  name: string;
  commitMsg: string;
  files: string[];
}

export const runtime = {
  handler: async function ({ repo_path, auto_commit }: SkillHandlerParams): Promise<string> {
    const targetDir = repo_path || "/data/projects/dotfiles";

    try {
      const getStatus = (): string =>
        execSync("git status --short", {
          cwd: targetDir,
          shell: "/usr/bin/zsh",
          encoding: "utf8",
          maxBuffer: 5 * 1024 * 1024,
        });

      const rawStatus = getStatus();
      if (!rawStatus.trim()) {
        return `Working tree in ${targetDir} is clean. No uncommitted changes detected.`;
      }

      // If auto_commit is requested, automatically commit all changes in atomic groups
      if (auto_commit === true) {
        const lines = rawStatus.split("\n").filter((l) => l.trim().length > 0);
        const allFiles: string[] = [];

        for (const line of lines) {
          // Format: XY path or XY "path" -> extract path
          const trimmed = line.slice(3).trim();
          const cleanPath = trimmed.replace(/^"|"$/g, "");
          if (cleanPath) {
            allFiles.push(cleanPath);
          }
        }

        if (allFiles.length === 0) {
          return `Working tree in ${targetDir} is clean. No uncommitted files found.`;
        }

        // Categorize files into logical atomic groups
        const groups: Record<string, FileGroup> = {
          desktop: {
            name: "Desktop & Shell",
            commitMsg: "feat(desktop): update shell scripts, Niri binds, and desktop configs",
            files: [],
          },
          anythingllm: {
            name: "AnythingLLM",
            commitMsg: "feat(anythingllm): update workspace configurations, prompts, and plugins",
            files: [],
          },
          infra: {
            name: "Infrastructure & Setup",
            commitMsg: "chore(infra): update setup automation and Ansible playbooks",
            files: [],
          },
          agents: {
            name: "Agents & MCP",
            commitMsg: "chore(agents): update Antigravity plugins and MCP configs",
            files: [],
          },
          docs: {
            name: "Documentation",
            commitMsg: "docs: update runbooks, agent guides, and documentation",
            files: [],
          },
          other: {
            name: "General Updates",
            commitMsg: "chore: update repository files",
            files: [],
          },
        };

        for (const file of allFiles) {
          if (file.startsWith("zsh/") || file.startsWith("niri/") || file.startsWith("noctalia/")) {
            groups.desktop.files.push(file);
          } else if (file.startsWith("anythingllm/")) {
            groups.anythingllm.files.push(file);
          } else if (file.startsWith("playbooks/") || file.startsWith("scripts/")) {
            groups.infra.files.push(file);
          } else if (file.startsWith(".agents/") || file.startsWith("antigravity/")) {
            groups.agents.files.push(file);
          } else if (file.startsWith("docs/") || file.endsWith(".md")) {
            groups.docs.files.push(file);
          } else {
            groups.other.files.push(file);
          }
        }

        const executedCommits: string[] = [];

        for (const [key, group] of Object.entries(groups)) {
          if (group.files.length === 0) continue;

          // Stage files with proper quoting
          const quotedFiles = group.files.map((f) => `"${f}"`).join(" ");
          execSync(`git add ${quotedFiles}`, {
            cwd: targetDir,
            shell: "/usr/bin/zsh",
            encoding: "utf8",
          });

          // Check if there are staged changes
          const stagedDiff = execSync("git diff --cached --name-only", {
            cwd: targetDir,
            shell: "/usr/bin/zsh",
            encoding: "utf8",
          });

          if (stagedDiff.trim()) {
            try {
              execSync(`git commit -m "${group.commitMsg}"`, {
                cwd: targetDir,
                shell: "/usr/bin/zsh",
                encoding: "utf8",
              });

              const commitHash = execSync("git rev-parse --short HEAD", {
                cwd: targetDir,
                shell: "/usr/bin/zsh",
                encoding: "utf8",
              }).trim();

              executedCommits.push(`- ${commitHash} ${group.commitMsg} (${group.files.length} files)`);
            } catch (commitErr: unknown) {
              const msg = commitErr instanceof Error ? commitErr.message : String(commitErr);
              executedCommits.push(`- [WARNING] Failed commit for ${group.name}: ${msg}`);
            }
          }
        }

        // Final check
        const remainingStatus = getStatus().trim();
        if (remainingStatus) {
          // If any files remain, commit them in a cleanup commit
          try {
            execSync("git add -A && git commit -m \"chore: commit remaining untracked files\"", {
              cwd: targetDir,
              shell: "/usr/bin/zsh",
              encoding: "utf8",
            });
            const cleanupHash = execSync("git rev-parse --short HEAD", {
              cwd: targetDir,
              shell: "/usr/bin/zsh",
              encoding: "utf8",
            }).trim();
            executedCommits.push(`- ${cleanupHash} chore: commit remaining untracked files`);
          } catch (_) {
            // Ignore if nothing staged
          }
        }

        const finalStatus = getStatus().trim();
        return [
          `✅ Atomic commits completed successfully in ${targetDir}:`,
          ...executedCommits,
          "",
          finalStatus
            ? `Remaining uncommitted changes:\n${finalStatus}`
            : "Working tree is now completely clean! Zero uncommitted changes.",
        ].join("\n");
      }

      // Default behavior: return status and diff for analysis
      const diffStat = execSync("git diff --stat", {
        cwd: targetDir,
        shell: "/usr/bin/zsh",
        encoding: "utf8",
        maxBuffer: 5 * 1024 * 1024,
      });

      return [
        `Repository: ${targetDir}`,
        "",
        "=== GIT STATUS ===",
        rawStatus,
        "=== DIFF STAT ===",
        diffStat,
        "Instructions for Agent: Group the above changes into atomic commits following Conventional Commits (type(scope): subject) in English. To execute automatically, call atomic-commits with auto_commit=true.",
      ].join("\n");
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      return `Error inspecting git repository at ${targetDir}: ${message}`;
    }
  },
};
