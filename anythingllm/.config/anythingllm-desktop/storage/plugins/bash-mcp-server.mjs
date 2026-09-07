#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { exec } from "child_process";

const server = new Server(
  {
    name: "host-cli-server",
    version: "1.1.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

function runCommand(command, cwd) {
  return new Promise((resolve) => {
    exec(
      command,
      {
        shell: "/usr/bin/zsh",
        cwd: cwd || "/data/projects/dotfiles",
        maxBuffer: 10 * 1024 * 1024,
        env: process.env,
      },
      (error, stdout, stderr) => {
        let output = "";
        if (stdout) output += stdout;
        if (stderr) output += (output ? "\n[stderr]\n" : "") + stderr;
        if (error && !output) output = error.message;

        resolve({
          content: [
            {
              type: "text",
              text: output || "(Command executed with no output)",
            },
          ],
        });
      }
    );
  });
}

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "git_status",
        description:
          "Runs 'git status' on the target git repository to inspect modified, deleted, or untracked files.",
        inputSchema: {
          type: "object",
          properties: {
            repo_path: {
              type: "string",
              description:
                "Directory of the git repository (default: /data/projects/dotfiles)",
            },
          },
        },
      },
      {
        name: "git_diff",
        description:
          "Runs 'git diff' to inspect uncommitted code or config changes.",
        inputSchema: {
          type: "object",
          properties: {
            repo_path: {
              type: "string",
              description:
                "Directory of the git repository (default: /data/projects/dotfiles)",
            },
            staged: {
              type: "boolean",
              description: "If true, shows diff of staged changes (--cached)",
            },
          },
        },
      },
      {
        name: "execute_command",
        description:
          "Executes any CLI shell command (git, zsh, docker, etc.) directly on the host system.",
        inputSchema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "The CLI command to execute on the host",
            },
            cwd: {
              type: "string",
              description:
                "Working directory (defaults to /data/projects/dotfiles)",
            },
          },
          required: ["command"],
        },
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const tool = request.params.name;
  const args = request.params.arguments || {};

  if (tool === "git_status") {
    const cwd = args.repo_path || "/data/projects/dotfiles";
    return runCommand("git status", cwd);
  }

  if (tool === "git_diff") {
    const cwd = args.repo_path || "/data/projects/dotfiles";
    const flag = args.staged ? "--cached" : "";
    return runCommand(`git diff ${flag}`, cwd);
  }

  if (tool === "execute_command") {
    const cwd = args.cwd || "/data/projects/dotfiles";
    return runCommand(args.command, cwd);
  }

  throw new Error(`Unknown tool: ${tool}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
