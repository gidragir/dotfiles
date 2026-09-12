#!/usr/bin/env bun
import fs from "fs";
import path from "path";
import { execSync } from "child_process";

const ROOT_DIR = path.resolve(import.meta.dir, "..");
const KNOWLEDGE_DIR = path.join(ROOT_DIR, ".agents/knowledge/dotfiles");
const L0_PATH = path.join(KNOWLEDGE_DIR, "L0_index.json");
const SUBSYSTEMS_DIR = path.join(KNOWLEDGE_DIR, "subsystems");
const OLLAMA_URL = process.env.OLLAMA_HOST || "http://127.0.0.1:11434";
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || "qwen2.5-coder:14b";

const NON_STOW_DIRS = new Set([
  ".git",
  ".agents",
  ".gemini",
  "scripts",
  "docs",
  "playbooks",
  "deploy",
  "evals",
  "node_modules",
  "target",
  "dist",
]);

interface L0Index {
  project: string;
  description: string;
  root_path: string;
  updated_at: string;
  subsystems: Array<{
    id: string;
    name: string;
    summary: string;
    l1_path: string;
    tags: string[];
  }>;
  stow_packages: string[];
  core_rules: string[];
}

const SUBSYSTEM_FILE_PATTERNS: Record<string, RegExp> = {
  wm_niri: /^(niri|noctalia)\//,
  storage_nvme: /^(check\.sh|check_setup\.sh|patrition_delete\.sh|playbooks\/setup_system\.yml)/,
  ai_stack: /^(ollama|anythingllm|deploy\/khoj|docs\/ai_stack|playbooks\/setup_ai_stack|playbooks\/setup_ollama|playbooks\/setup_anythingllm)/,
  playbooks: /^playbooks\//,
  dev_runtimes: /^(cargo|mise|playbooks\/setup_rust)/,
  shell_ux: /^(zsh|ghostty|nvim|starship|atuin|sheldon|television|superfile|btop|zellij)\//,
};

function runGit(cmd: string): string {
  try {
    return execSync(`git ${cmd}`, { cwd: ROOT_DIR, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return "";
  }
}

async function isOllamaAvailable(): Promise<boolean> {
  try {
    const res = await fetch(`${OLLAMA_URL}/api/tags`, { signal: AbortSignal.timeout(1500) });
    return res.ok;
  } catch {
    return false;
  }
}

async function generateWithOllama(prompt: string, systemPrompt: string): Promise<string> {
  const res = await fetch(`${OLLAMA_URL}/api/generate`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: OLLAMA_MODEL,
      system: systemPrompt,
      prompt: prompt,
      stream: false,
      options: {
        temperature: 0.2,
        num_predict: 2048,
      },
    }),
  });

  if (!res.ok) {
    throw new Error(`Ollama API error: ${res.statusText}`);
  }

  const data = (await res.json()) as { response: string };
  return data.response.trim();
}

function discoverStowPackages(): string[] {
  const entries = fs.readdirSync(ROOT_DIR, { withFileTypes: true });
  const packages: string[] = [];

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (NON_STOW_DIRS.has(entry.name)) continue;
    if (entry.name.startsWith(".") && entry.name !== ".config") continue;

    const fullPath = path.join(ROOT_DIR, entry.name);
    // A stow package typically contains .config, .zsh, or dotfiles inside
    const children = fs.readdirSync(fullPath);
    if (children.length > 0) {
      packages.push(entry.name);
    }
  }

  return packages.sort();
}

async function syncL0Index(discoveredPackages: string[]): Promise<boolean> {
  if (!fs.existsSync(L0_PATH)) {
    console.error(`✗ L0 index not found at ${L0_PATH}`);
    return false;
  }

  const raw = fs.readFileSync(L0_PATH, "utf8");
  const index = JSON.parse(raw) as L0Index;

  const currentSet = new Set(index.stow_packages);
  const discoveredSet = new Set(discoveredPackages);

  const added = discoveredPackages.filter((p) => !currentSet.has(p));
  const removed = index.stow_packages.filter((p) => !discoveredSet.has(p));

  const today = new Date().toISOString().slice(0, 10);
  let changed = false;

  if (added.length > 0 || removed.length > 0 || index.updated_at !== today) {
    index.stow_packages = discoveredPackages;
    index.updated_at = today;
    fs.writeFileSync(L0_PATH, JSON.stringify(index, null, 2) + "\n", "utf8");
    changed = true;

    if (added.length > 0) console.log(`✓ Added new Stow packages to L0: ${added.join(", ")}`);
    if (removed.length > 0) console.log(`ℹ Removed obsolete Stow packages from L0: ${removed.join(", ")}`);
    console.log(`✓ Updated L0 index timestamp: ${today}`);
  } else {
    console.log(`✓ L0 Stow packages already in sync (${discoveredPackages.length} packages).`);
  }

  return changed;
}

async function syncSubsystemsWithLocalAi(gitChangedFiles: string[]): Promise<void> {
  const subsystemChanges: Record<string, string[]> = {};

  for (const file of gitChangedFiles) {
    for (const [subsystemId, pattern] of Object.entries(SUBSYSTEM_FILE_PATTERNS)) {
      if (pattern.test(file)) {
        if (!subsystemChanges[subsystemId]) subsystemChanges[subsystemId] = [];
        subsystemChanges[subsystemId].push(file);
        break;
      }
    }
  }

  const changedSubsystems = Object.keys(subsystemChanges);
  if (changedSubsystems.length === 0) {
    console.log("✓ No subsystem configuration changes detected in Git status.");
    return;
  }

  const ollamaOnline = await isOllamaAvailable();
  if (!ollamaOnline) {
    console.log(`⚠ Local Ollama (${OLLAMA_URL}) is offline. Skipping LLM doc refinement.`);
    console.log(`  Changed subsystems detected: ${changedSubsystems.join(", ")}`);
    return;
  }

  console.log(`🤖 Local Ollama online (${OLLAMA_MODEL}). Analyzing ${changedSubsystems.length} changed subsystem(s)...`);

  for (const subId of changedSubsystems) {
    const filePath = path.join(SUBSYSTEMS_DIR, `${subId}.md`);
    if (!fs.existsSync(filePath)) continue;

    const currentDoc = fs.readFileSync(filePath, "utf8");
    const changedFiles = subsystemChanges[subId];
    console.log(`  ↳ Updating ${subId} (modified files: ${changedFiles.join(", ")})`);

    let diffText = "";
    for (const f of changedFiles.slice(0, 5)) {
      const d = runGit(`diff HEAD -- "${f}"`);
      if (d) diffText += `\n--- Diff for ${f} ---\n${d.slice(0, 1500)}`;
    }

    if (!diffText) {
      diffText = `Files modified or added: ${changedFiles.join(", ")}`;
    }

    const systemPrompt =
      "You are a technical documentation assistant for a CachyOS Linux workstation dotfiles repo. " +
      "Your task is to review the current subsystem L1 documentation and recent git changes, " +
      "and return the updated, concise markdown document. " +
      "Keep all existing structure, rules, and commands. Add or clarify new configurations or hotkeys. " +
      "Output ONLY the markdown content, no commentary.";

    const prompt =
      `# Current Document (${subId}.md):\n${currentDoc}\n\n` +
      `# Recent Git Changes:\n${diffText}\n\n` +
      "Please provide the updated markdown for this subsystem document:";

    try {
      const updatedMarkdown = await generateWithOllama(prompt, systemPrompt);
      if (updatedMarkdown && updatedMarkdown.length > 200) {
        fs.writeFileSync(filePath, updatedMarkdown + "\n", "utf8");
        console.log(`    ✓ Successfully updated ${subId}.md via ${OLLAMA_MODEL}`);
      }
    } catch (err: any) {
      console.warn(`    ⚠ Failed to update ${subId} with Ollama: ${err.message}`);
    }
  }
}

async function main() {
  console.log("=== 🔄 Dotfiles Knowledge Base Synchronizer ===");

  // 1. Scan Stow packages
  const packages = discoverStowPackages();
  console.log(`Discovered ${packages.length} Stow packages in repository.`);

  // 2. Sync L0 index
  await syncL0Index(packages);

  // 3. Check git changes for L1 subsystem docs
  const statusOutput = runGit("status --porcelain");
  const changedFiles = statusOutput
    .split("\n")
    .map((l) => l.slice(3).trim())
    .filter(Boolean);

  // 4. Update L1 subsystems with Local AI
  await syncSubsystemsWithLocalAi(changedFiles);

  console.log("=== ✨ Knowledge Base Sync Complete ===\n");
}

main().catch((err) => {
  console.error("Fatal error during knowledge sync:", err);
  process.exit(1);
});
