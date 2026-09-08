var __defProp = Object.defineProperty;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __hasOwnProp = Object.prototype.hasOwnProperty;
function __accessProp(key) {
  return this[key];
}
var __toCommonJS = (from) => {
  var entry = (__moduleCache ??= new WeakMap).get(from), desc;
  if (entry)
    return entry;
  entry = __defProp({}, "__esModule", { value: true });
  if (from && typeof from === "object" || typeof from === "function") {
    for (var key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(entry, key))
        __defProp(entry, key, {
          get: __accessProp.bind(from, key),
          enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable
        });
  }
  __moduleCache.set(from, entry);
  return entry;
};
var __moduleCache;
var __returnValue = (v) => v;
function __exportSetter(name, newValue) {
  this[name] = __returnValue.bind(null, newValue);
}
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, {
      get: all[name],
      enumerable: true,
      configurable: true,
      set: __exportSetter.bind(all, name)
    });
};

// agent-skills/atomic-commits/handler.ts
var exports_handler = {};
__export(exports_handler, {
  runtime: () => runtime
});
module.exports = __toCommonJS(exports_handler);
var import_child_process = require("child_process");
var runtime = {
  handler: async function({ repo_path, auto_commit }) {
    const targetDir = repo_path || "/data/projects/dotfiles";
    try {
      const getStatus = () => import_child_process.execSync("git status --short", {
        cwd: targetDir,
        shell: "/usr/bin/zsh",
        encoding: "utf8",
        maxBuffer: 5 * 1024 * 1024
      });
      const rawStatus = getStatus();
      if (!rawStatus.trim()) {
        return `Working tree in ${targetDir} is clean. No uncommitted changes detected.`;
      }
      if (auto_commit === true) {
        const lines = rawStatus.split(`
`).filter((l) => l.trim().length > 0);
        const allFiles = [];
        for (const line of lines) {
          const trimmed = line.slice(3).trim();
          const cleanPath = trimmed.replace(/^"|"$/g, "");
          if (cleanPath) {
            allFiles.push(cleanPath);
          }
        }
        if (allFiles.length === 0) {
          return `Working tree in ${targetDir} is clean. No uncommitted files found.`;
        }
        const groups = {
          desktop: {
            name: "Desktop & Shell",
            commitMsg: "feat(desktop): update shell scripts, Niri binds, and desktop configs",
            files: []
          },
          anythingllm: {
            name: "AnythingLLM",
            commitMsg: "feat(anythingllm): update workspace configurations, prompts, and plugins",
            files: []
          },
          infra: {
            name: "Infrastructure & Setup",
            commitMsg: "chore(infra): update setup automation and Ansible playbooks",
            files: []
          },
          agents: {
            name: "Agents & MCP",
            commitMsg: "chore(agents): update Antigravity plugins and MCP configs",
            files: []
          },
          docs: {
            name: "Documentation",
            commitMsg: "docs: update runbooks, agent guides, and documentation",
            files: []
          },
          other: {
            name: "General Updates",
            commitMsg: "chore: update repository files",
            files: []
          }
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
        const executedCommits = [];
        for (const [key, group] of Object.entries(groups)) {
          if (group.files.length === 0)
            continue;
          const quotedFiles = group.files.map((f) => `"${f}"`).join(" ");
          import_child_process.execSync(`git add ${quotedFiles}`, {
            cwd: targetDir,
            shell: "/usr/bin/zsh",
            encoding: "utf8"
          });
          const stagedDiff = import_child_process.execSync("git diff --cached --name-only", {
            cwd: targetDir,
            shell: "/usr/bin/zsh",
            encoding: "utf8"
          });
          if (stagedDiff.trim()) {
            try {
              import_child_process.execSync(`git commit -m "${group.commitMsg}"`, {
                cwd: targetDir,
                shell: "/usr/bin/zsh",
                encoding: "utf8"
              });
              const commitHash = import_child_process.execSync("git rev-parse --short HEAD", {
                cwd: targetDir,
                shell: "/usr/bin/zsh",
                encoding: "utf8"
              }).trim();
              executedCommits.push(`- ${commitHash} ${group.commitMsg} (${group.files.length} files)`);
            } catch (commitErr) {
              const msg = commitErr instanceof Error ? commitErr.message : String(commitErr);
              executedCommits.push(`- [WARNING] Failed commit for ${group.name}: ${msg}`);
            }
          }
        }
        const remainingStatus = getStatus().trim();
        if (remainingStatus) {
          try {
            import_child_process.execSync('git add -A && git commit -m "chore: commit remaining untracked files"', {
              cwd: targetDir,
              shell: "/usr/bin/zsh",
              encoding: "utf8"
            });
            const cleanupHash = import_child_process.execSync("git rev-parse --short HEAD", {
              cwd: targetDir,
              shell: "/usr/bin/zsh",
              encoding: "utf8"
            }).trim();
            executedCommits.push(`- ${cleanupHash} chore: commit remaining untracked files`);
          } catch (_) {}
        }
        const finalStatus = getStatus().trim();
        return [
          `✅ Atomic commits completed successfully in ${targetDir}:`,
          ...executedCommits,
          "",
          finalStatus ? `Remaining uncommitted changes:
${finalStatus}` : "Working tree is now completely clean! Zero uncommitted changes."
        ].join(`
`);
      }
      const diffStat = import_child_process.execSync("git diff --stat", {
        cwd: targetDir,
        shell: "/usr/bin/zsh",
        encoding: "utf8",
        maxBuffer: 5 * 1024 * 1024
      });
      return [
        `Repository: ${targetDir}`,
        "",
        "=== GIT STATUS ===",
        rawStatus,
        "=== DIFF STAT ===",
        diffStat,
        "Instructions for Agent: Group the above changes into atomic commits following Conventional Commits (type(scope): subject) in English. To execute automatically, call atomic-commits with auto_commit=true."
      ].join(`
`);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return `Error inspecting git repository at ${targetDir}: ${message}`;
    }
  }
};
