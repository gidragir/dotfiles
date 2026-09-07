import { execSync } from "child_process";

export interface SkillHandlerParams {
  repo_path?: string;
}

export const runtime = {
  handler: async function ({ repo_path }: SkillHandlerParams): Promise<string> {
    const targetDir = repo_path || "/data/projects/dotfiles";
    try {
      const status = execSync("git status --short", {
        cwd: targetDir,
        shell: "/usr/bin/zsh",
        encoding: "utf8",
        maxBuffer: 5 * 1024 * 1024,
      });

      if (!status.trim()) {
        return `Working tree in ${targetDir} is clean. No uncommitted changes detected.`;
      }

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
        status,
        "=== DIFF STAT ===",
        diffStat,
        "Instructions for Agent: Group the above changes into atomic commits following Conventional Commits (type(scope): subject) in English, and output ready-to-run \"git add\" and \"git commit -m\" commands.",
      ].join("\n");
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      return `Error inspecting git repository at ${targetDir}: ${message}`;
    }
  },
};
