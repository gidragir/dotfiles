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
  handler: async function({ repo_path }) {
    const targetDir = repo_path || "/data/projects/dotfiles";
    try {
      const status = import_child_process.execSync("git status --short", {
        cwd: targetDir,
        shell: "/usr/bin/zsh",
        encoding: "utf8",
        maxBuffer: 5 * 1024 * 1024
      });
      if (!status.trim()) {
        return `Working tree in ${targetDir} is clean. No uncommitted changes detected.`;
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
        status,
        "=== DIFF STAT ===",
        diffStat,
        'Instructions for Agent: Group the above changes into atomic commits following Conventional Commits (type(scope): subject) in English, and output ready-to-run "git add" and "git commit -m" commands.'
      ].join(`
`);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return `Error inspecting git repository at ${targetDir}: ${message}`;
    }
  }
};
