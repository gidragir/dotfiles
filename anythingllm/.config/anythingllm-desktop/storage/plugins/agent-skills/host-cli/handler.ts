import { exec } from "child_process";

export interface HostCliParams {
  command: string;
  cwd?: string;
}

export const runtime = {
  handler: async function (params: HostCliParams): Promise<string> {
    if (!params || !params.command) {
      return "Error: No command provided to host-cli.";
    }

    const targetDir = params.cwd || "/data/projects/dotfiles";

    return new Promise((resolve) => {
      exec(
        params.command,
        {
          shell: "/usr/bin/zsh",
          cwd: targetDir,
          maxBuffer: 10 * 1024 * 1024,
          env: process.env,
        },
        (error, stdout, stderr) => {
          let output = "";
          if (stdout) output += stdout;
          if (stderr) output += (output ? "\n[stderr]\n" : "") + stderr;
          if (error && !output) output = error.message;

          resolve(output || "(Command executed with no output)");
        }
      );
    });
  },
};
