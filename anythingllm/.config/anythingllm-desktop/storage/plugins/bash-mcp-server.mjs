#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { exec, execFile } from "child_process";
import fs from "fs";
import path from "path";

const server = new Server(
  {
    name: "host-cli-server",
    version: "1.3.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Stop words for Russian & English query normalization
const STOP_WORDS = new Set([
  "о", "об", "обо", "в", "во", "и", "на", "с", "со", "про", "что", "как", "по", "для", "это", "этом", "этой", "этого",
  "мой", "моем", "моих", "моя", "мои", "свой", "своих", "своем", "заметка", "заметки", "заметках", "заметку", "заметок",
  "обсудить", "найти", "найди", "изучи", "связанные", "темой", "теме", "тему", "obsidian", "note", "notes", "тобой", "хочу",
  "писал", "думаю", "плане", "быть", "мне", "тебя", "тебе", "меня", "есть", "было", "будет", "несколько", "покажи", "файл",
  "файлы", "папка", "папке", "папках", "где", "about", "find", "search", "show", "vault", "look", "tell"
]);

function stemWord(w) {
  let s = w.toLowerCase();
  // Russian suffixes and case endings
  s = s.replace(/(ство|ства|стве|ством|ствий|ствиям|ствиях)$/i, "");
  s = s.replace(/(ость|ости|остью|остей)$/i, "");
  s = s.replace(/(иями|ями|ами|ей|ов|ев|ом|ем|ам|ям|ах|ях|ое|ее|ие|ые|ую|юю|ей|ой|ий|ый|ом|ем|им|ым)$/i, "");
  s = s.replace(/[аеийоуыэюя]$/i, "");
  // English suffixes
  s = s.replace(/(ship|ships|ing|ed|es|s|tion|tions|ment|ments)$/i, "");
  return s;
}

function extractStems(query) {
  const rawTokens = String(query).split(/[^\p{L}\p{N}]+/u).filter(Boolean);
  const stems = new Set();
  for (const token of rawTokens) {
    const lower = token.toLowerCase();
    if (STOP_WORDS.has(lower)) continue;
    const stemmed = stemWord(lower);
    if (stemmed.length >= 3) {
      stems.add(stemmed);
    }
  }
  if (stems.size === 0 && rawTokens.length > 0) {
    for (const t of rawTokens) {
      if (t.length >= 3) stems.add(t.toLowerCase());
    }
  }
  return Array.from(stems);
}

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

function execCmdPromise(bin, args) {
  return new Promise((resolve) => {
    execFile(
      bin,
      args,
      { maxBuffer: 10 * 1024 * 1024, env: process.env },
      (err, stdout) => {
        resolve(stdout || "");
      }
    );
  });
}

async function searchFilesHandler(args) {
  const query = args.keyword || args.query || "";
  const targetDir = args.directory || "/data/obsidian";
  const maxResults = Number(args.max_results) || 25;

  if (!query || typeof query !== "string") {
    return {
      content: [{ type: "text", text: "Error: No search query or keyword provided." }],
    };
  }

  if (!fs.existsSync(targetDir)) {
    return {
      content: [{ type: "text", text: `Error: Target directory '${targetDir}' does not exist.` }],
    };
  }

  const stems = extractStems(query);
  if (stems.length === 0) {
    return {
      content: [{ type: "text", text: `No searchable terms extracted from query: "${query}"` }],
    };
  }

  const fileScores = new Map();
  const matchedStemsPerFile = new Map();

  for (const stem of stems) {
    // 1. Match paths and filenames via fd
    const fdArgs = [
      "-i",
      "-p",
      "-t",
      "f",
      "--exclude",
      ".git",
      "--exclude",
      ".obsidian",
      "--exclude",
      ".trash",
      stem,
      targetDir,
    ];
    const fdOutput = await execCmdPromise("fd", fdArgs);
    const fdFiles = fdOutput.trim().split("\n").filter(Boolean);

    for (const file of fdFiles) {
      const baseName = path.basename(file).toLowerCase();
      const score = baseName.includes(stem) ? 10 : 5;
      fileScores.set(file, (fileScores.get(file) || 0) + score);

      if (!matchedStemsPerFile.has(file)) matchedStemsPerFile.set(file, new Set());
      matchedStemsPerFile.get(file).add(stem);
    }

    // 2. Match content via rg
    const rgArgs = [
      "-i",
      "-l",
      "--max-count=1",
      "-g",
      "!*.png",
      "-g",
      "!*.jpg",
      "-g",
      "!*.jpeg",
      "-g",
      "!*.webp",
      "-g",
      "!*.pdf",
      "--glob",
      "!.git/*",
      "--glob",
      "!.obsidian/*",
      "--glob",
      "!.trash/*",
      stem,
      targetDir,
    ];
    const rgOutput = await execCmdPromise("rg", rgArgs);
    const rgFiles = rgOutput.trim().split("\n").filter(Boolean);

    for (const file of rgFiles) {
      fileScores.set(file, (fileScores.get(file) || 0) + 2);
      if (!matchedStemsPerFile.has(file)) matchedStemsPerFile.set(file, new Set());
      matchedStemsPerFile.get(file).add(stem);
    }
  }

  if (fileScores.size === 0) {
    return {
      content: [
        {
          type: "text",
          text: `No files found matching query "${query}" (stems: ${stems.join(", ")}) in ${targetDir}.`,
        },
      ],
    };
  }

  // Bonus for matching multiple terms and .md extensions
  for (const [file, score] of fileScores.entries()) {
    const matchedCount = matchedStemsPerFile.get(file)?.size || 1;
    let finalScore = score * matchedCount;
    if (file.endsWith(".md")) finalScore += 5;
    fileScores.set(file, finalScore);
  }

  const sortedFiles = Array.from(fileScores.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, maxResults);

  const formattedResults = [];
  for (const [filePath, score] of sortedFiles) {
    let snippet = "";
    try {
      if (filePath.endsWith(".md") || filePath.endsWith(".txt")) {
        const raw = fs.readFileSync(filePath, "utf8");
        let content = raw.replace(/^---[\s\S]*?---\s*/, "").trim();
        if (!content) {
          snippet = " — (Заметка пустая / заготовка)";
        } else {
          content = content.replace(/\[\[([^|\]]+)\|([^\]]+)\]\]/g, "$2");
          content = content.replace(/\[\[([^\]]+)\]\]/g, "$1");
          content = content.replace(/^[#>\s*_-]+/gm, "");
          content = content.replace(/\s+/g, " ").trim();
          if (content.length > 220) {
            content = content.slice(0, 217) + "...";
          }
          snippet = `\n  Краткое содержание: "${content}"`;
        }
      }
    } catch (_) {}

    const noteName = path.basename(filePath, path.extname(filePath));
    formattedResults.push(`- [[${noteName}]] (${filePath})${snippet}`);
  }

  return {
    content: [
      {
        type: "text",
        text: `Found ${sortedFiles.length} notes/files for query "${query}" (stems: ${stems.join(", ")}):\n\n${formattedResults.join("\n")}`,
      },
    ],
  };
}

async function readFileHandler(args) {
  const filePath = args.file_path || args.path;
  const maxLines = Number(args.max_lines) || 350;
  const offset = Number(args.offset) || 0;

  if (!filePath) {
    return {
      content: [{ type: "text", text: "Error: No file_path provided to read_file." }],
    };
  }

  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved)) {
    return {
      content: [{ type: "text", text: `Error: File '${resolved}' does not exist.` }],
    };
  }

  try {
    const raw = fs.readFileSync(resolved, "utf8");
    const allLines = raw.split("\n");
    const totalLines = allLines.length;

    const slice = allLines.slice(offset, offset + maxLines);
    const text = slice.join("\n");
    const hasMore = offset + maxLines < totalLines;

    let header = `[File: ${resolved} | Lines ${offset + 1}-${Math.min(offset + maxLines, totalLines)} of ${totalLines}]\n`;
    if (hasMore) {
      header += `(Note: Content truncated. Use offset=${offset + maxLines} to read subsequent lines)\n\n`;
    } else {
      header += "\n";
    }

    return {
      content: [{ type: "text", text: header + text }],
    };
  } catch (err) {
    return {
      content: [{ type: "text", text: `Error reading file '${resolved}': ${err.message}` }],
    };
  }
}

async function writeFileHandler(args) {
  const filePath = args.file_path || args.path;
  const content = args.content;
  const append = Boolean(args.append);

  if (!filePath || content === undefined) {
    return {
      content: [{ type: "text", text: "Error: file_path and content are required." }],
    };
  }

  const resolved = path.resolve(filePath);
  try {
    const dir = path.dirname(resolved);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    if (append) {
      fs.appendFileSync(resolved, content, "utf8");
      return {
        content: [{ type: "text", text: `Successfully appended to '${resolved}'.` }],
      };
    } else {
      fs.writeFileSync(resolved, content, "utf8");
      return {
        content: [{ type: "text", text: `Successfully wrote '${resolved}'.` }],
      };
    }
  } catch (err) {
    return {
      content: [{ type: "text", text: `Error writing file '${resolved}': ${err.message}` }],
    };
  }
}

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "search_files",
        description:
          "Fast intelligent search for notes and documents matching a keyword, concept, or natural phrase. Performs morphology stemming across Russian and English, searching both file paths/names and note contents in Obsidian (/data/obsidian) or projects. Returns ranked paths with previews.",
        inputSchema: {
          type: "object",
          properties: {
            keyword: {
              type: "string",
              description: "The search query, keyword, or phrase (e.g. 'лидерство', 'архитектура', 'docker')",
            },
            directory: {
              type: "string",
              description: "Root directory to search in (defaults to /data/obsidian). Can also be /data/projects or any subfolder.",
            },
            max_results: {
              type: "number",
              description: "Maximum number of matching files to return (defaults to 25)",
            },
          },
          required: ["keyword"],
        },
      },
      {
        name: "read_file",
        description:
          "Reads text contents of a markdown note, document, or code file from any path on the system. Supports line slicing via max_lines and offset to protect context window.",
        inputSchema: {
          type: "object",
          properties: {
            file_path: {
              type: "string",
              description: "The absolute or relative path to the file to read",
            },
            max_lines: {
              type: "number",
              description: "Maximum number of lines to read (defaults to 350)",
            },
            offset: {
              type: "number",
              description: "Starting line offset for reading long files (defaults to 0)",
            },
          },
          required: ["file_path"],
        },
      },
      {
        name: "write_file",
        description:
          "Writes or appends markdown text or code to a file in /data/obsidian or /data/projects. Automatically creates parent directories if needed.",
        inputSchema: {
          type: "object",
          properties: {
            file_path: {
              type: "string",
              description: "Target file path to write to",
            },
            content: {
              type: "string",
              description: "Text content to write or append",
            },
            append: {
              type: "boolean",
              description: "If true, appends content to the end of the file instead of overwriting",
            },
          },
          required: ["file_path", "content"],
        },
      },
      {
        name: "execute_command",
        description:
          "Executes any terminal shell command on the CachyOS Linux host via zsh. Supports full system PATH, mise runtimes, cargo, docker, and pacman.",
        inputSchema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description: "The CLI command string to execute",
            },
            cwd: {
              type: "string",
              description: "Working directory for execution (defaults to /data/projects/dotfiles)",
            },
          },
          required: ["command"],
        },
      },
      {
        name: "git_status",
        description:
          "Runs git status on a repository to list modified, untracked, and deleted files. Use whenever inspecting git changes.",
        inputSchema: {
          type: "object",
          properties: {
            repo_path: {
              type: "string",
              description: "Directory of the target git repository (defaults to /data/projects/dotfiles)",
            },
          },
        },
      },
      {
        name: "git_diff",
        description:
          "Runs git diff on a repository to inspect exact line-by-line file changes. Supports staged and unstaged diffs.",
        inputSchema: {
          type: "object",
          properties: {
            repo_path: {
              type: "string",
              description: "Directory of the target git repository (defaults to /data/projects/dotfiles)",
            },
            staged: {
              type: "boolean",
              description: "Shows diff of staged changes when true (--cached)",
            },
          },
        },
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const tool = request.params.name;
  const args = request.params.arguments || {};

  if (tool === "search_files") {
    return searchFilesHandler(args);
  }

  if (tool === "read_file") {
    return readFileHandler(args);
  }

  if (tool === "write_file") {
    return writeFileHandler(args);
  }

  if (tool === "git_status") {
    const cwd = args.repo_path || "/data/projects/dotfiles";
    return runCommand("git status", cwd);
  }

  if (tool === "git_diff") {
    const cwd = args.repo_path || "/data/projects/dotfiles";
    const flag = args.staged ? "--cached" : "";
    return runCommand(`git diff ${flag}`, cwd);
  }

  if (
    tool === "execute_command" ||
    tool === "host-cli" ||
    tool === "host_cli" ||
    tool === "cli" ||
    tool === "bash"
  ) {
    const cwd = args.cwd || "/data/projects/dotfiles";
    return runCommand(args.command, cwd);
  }

  throw new Error(`Unknown tool: ${tool}`);
});

const transport = new StdioServerTransport();
await server.connect(transport);
