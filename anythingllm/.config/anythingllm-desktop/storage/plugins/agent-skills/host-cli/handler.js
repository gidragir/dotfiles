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

// agent-skills/host-cli/handler.ts
var exports_handler = {};
__export(exports_handler, {
  runtime: () => runtime
});
module.exports = __toCommonJS(exports_handler);
var import_node_child_process = require("node:child_process");
var runtime = {
  handler: async (params) => {
    if (!params?.command) {
      return "Error: No command provided to host-cli.";
    }
    const targetDir = params.cwd || "/data/projects/dotfiles";
    return new Promise((resolve) => {
      import_node_child_process.exec(params.command, {
        shell: "/usr/bin/zsh",
        cwd: targetDir,
        maxBuffer: 10 * 1024 * 1024,
        env: process.env
      }, (error, stdout, stderr) => {
        let output = "";
        if (stdout)
          output += stdout;
        if (stderr)
          output += (output ? `
[stderr]
` : "") + stderr;
        if (error && !output)
          output = error.message;
        resolve(output || "(Command executed with no output)");
      });
    });
  }
};
