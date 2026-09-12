#!/usr/bin/env bun
import fs from "fs";
import path from "path";
import { execSync } from "child_process";

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

interface L0Subsystem {
  id: string;
  name: string;
  summary: string;
  l1_path: string;
  tags: string[];
}

interface L0Index {
  $schema?: string;
  project: string;
  description: string;
  root_path: string;
  updated_at: string;
  project_type?: string;
  subsystems: L0Subsystem[];
  stow_packages?: string[];
  core_rules?: string[];
}

function runGit(cmd: string, cwd: string): string {
  try {
    return execSync(`git ${cmd}`, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trimEnd();
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

function findKnowledgeDir(rootDir: string): string | null {
  const candidates = [
    path.join(rootDir, ".agents", "knowledge", "dotfiles"),
    path.join(rootDir, ".agents", "knowledge"),
  ];

  for (const cand of candidates) {
    if (fs.existsSync(path.join(cand, "L0_index.json"))) {
      return cand;
    }
  }
  return null;
}

function discoverStowPackages(rootDir: string): string[] {
  const entries = fs.readdirSync(rootDir, { withFileTypes: true });
  const packages: string[] = [];

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    if (NON_STOW_DIRS.has(entry.name)) continue;
    if (entry.name.startsWith(".") && entry.name !== ".config") continue;

    const fullPath = path.join(rootDir, entry.name);
    const children = fs.readdirSync(fullPath);
    if (children.length > 0) {
      packages.push(entry.name);
    }
  }

  return packages.sort();
}

async function syncL0Index(l0Path: string, index: L0Index, discoveredPackages?: string[]): Promise<boolean> {
  let changed = false;
  const today = new Date().toISOString().slice(0, 10);

  if (discoveredPackages && index.stow_packages) {
    const currentSet = new Set(index.stow_packages);
    const discoveredSet = new Set(discoveredPackages);

    const added = discoveredPackages.filter((p) => !currentSet.has(p));
    const removed = index.stow_packages.filter((p) => !discoveredSet.has(p));

    if (added.length > 0 || removed.length > 0 || index.updated_at !== today) {
      index.stow_packages = discoveredPackages;
      index.updated_at = today;
      fs.writeFileSync(l0Path, JSON.stringify(index, null, 2) + "\n", "utf8");
      changed = true;

      if (added.length > 0) console.log(`✓ Added new Stow packages to L0: ${added.join(", ")}`);
      if (removed.length > 0) console.log(`ℹ Removed obsolete Stow packages from L0: ${removed.join(", ")}`);
      console.log(`✓ Updated L0 index timestamp: ${today}`);
    } else {
      console.log(`✓ L0 Stow packages already in sync (${discoveredPackages.length} packages).`);
    }
  } else if (index.updated_at !== today) {
    index.updated_at = today;
    fs.writeFileSync(l0Path, JSON.stringify(index, null, 2) + "\n", "utf8");
    changed = true;
    console.log(`✓ Updated L0 index timestamp: ${today}`);
  }

  return changed;
}

function buildSubsystemMatcher(sub: L0Subsystem, isDotfiles: boolean): (file: string) => boolean {
  if (isDotfiles) {
    const dotfilesPatterns: Record<string, RegExp> = {
      wm_niri: /^(niri|noctalia)\//,
      storage_nvme: /^(check\.sh|check_setup\.sh|patrition_delete\.sh|playbooks\/setup_system\.yml)/,
      ai_stack: /^(ollama|anythingllm|deploy\/khoj|docs\/ai_stack|playbooks\/setup_ai_stack|playbooks\/setup_ollama|playbooks\/setup_anythingllm|local-ai-stack)/,
      playbooks: /^playbooks\//,
      dev_runtimes: /^(cargo|mise|playbooks\/setup_rust)/,
      shell_ux: /^(zsh|ghostty|nvim|starship|atuin|sheldon|television|superfile|btop|zellij)\//,
    };
    if (dotfilesPatterns[sub.id]) {
      return (file: string) => dotfilesPatterns[sub.id].test(file);
    }
  }

  const idNormalized = sub.id.toLowerCase().replace(/_/g, "/");
  const idWithDash = sub.id.toLowerCase().replace(/_/g, "-");
  const idRaw = sub.id.toLowerCase();

  return (file: string) => {
    const f = file.toLowerCase();
    if (f.startsWith(idNormalized + "/") || f.startsWith(idWithDash + "/") || f.startsWith(idRaw + "/")) {
      return true;
    }

    const parts = f.split("/");
    if (parts.some((p) => p === idRaw || p === idWithDash || p === idNormalized)) {
      return true;
    }

    for (const tag of sub.tags) {
      const cleanTag = tag.toLowerCase().trim();
      if (cleanTag.length > 2 && (parts.includes(cleanTag) || f.startsWith(cleanTag + "/"))) {
        return true;
      }
    }
    return false;
  };
}

async function syncSubsystemsWithLocalAi(
  rootDir: string,
  knowledgeDir: string,
  index: L0Index,
  gitChangedFiles: string[]
): Promise<void> {
  const isDotfiles = index.project.toLowerCase() === "dotfiles";
  const subsystemChanges: Record<string, string[]> = {};
  const matchers = index.subsystems.map((sub) => ({
    sub,
    matches: buildSubsystemMatcher(sub, isDotfiles),
  }));

  for (const file of gitChangedFiles) {
    for (const { sub, matches } of matchers) {
      if (matches(file)) {
        if (!subsystemChanges[sub.id]) subsystemChanges[sub.id] = [];
        subsystemChanges[sub.id].push(file);
        break;
      }
    }
  }

  const changedSubsystemIds = Object.keys(subsystemChanges);
  if (changedSubsystemIds.length === 0) {
    console.log("✓ No subsystem configuration changes detected in Git status.");
    return;
  }

  const ollamaOnline = await isOllamaAvailable();
  if (!ollamaOnline) {
    console.log(`⚠ Local Ollama (${OLLAMA_URL}) is offline. Skipping LLM doc refinement.`);
    console.log(`  Changed subsystems detected: ${changedSubsystemIds.join(", ")}`);
    return;
  }

  console.log(`🤖 Local Ollama online (${OLLAMA_MODEL}). Analyzing ${changedSubsystemIds.length} changed subsystem(s)...`);

  for (const subId of changedSubsystemIds) {
    const subDef = index.subsystems.find((s) => s.id === subId);
    const relativePath = subDef?.l1_path || `subsystems/${subId}.md`;
    const filePath = path.join(knowledgeDir, relativePath);

    if (!fs.existsSync(filePath)) {
      console.warn(`  ⚠ Subsystem doc not found at ${filePath}, skipping.`);
      continue;
    }

    const currentDoc = fs.readFileSync(filePath, "utf8");
    const changedFiles = subsystemChanges[subId];
    console.log(`  ↳ Updating ${subId} (modified files: ${changedFiles.join(", ")})`);

    let diffText = "";
    for (const f of changedFiles.slice(0, 5)) {
      const d = runGit(`diff HEAD -- "${f}"`, rootDir);
      if (d) diffText += `\n--- Diff for ${f} ---\n${d.slice(0, 1500)}`;
    }

    if (!diffText) {
      diffText = `Files modified or added: ${changedFiles.join(", ")}`;
    }

    const systemPrompt =
      `You are a technical documentation assistant for the project '${index.project}' (${index.project_type || "software project"}). ` +
      `Project description: ${index.description}. ` +
      "Your task is to review the current subsystem L1 documentation and recent git changes, " +
      "and return the updated, concise markdown document. " +
      "Keep all existing structure, contracts, rules, and commands. Add or clarify new configurations, APIs, or architectural changes. " +
      "Output ONLY the markdown content, no commentary.";

    const prompt =
      `# Current Document (${path.basename(filePath)}):\n${currentDoc}\n\n` +
      `# Recent Git Changes:\n${diffText}\n\n` +
      "Please provide the updated markdown for this subsystem document:";

    try {
      const updatedMarkdown = await generateWithOllama(prompt, systemPrompt);
      if (updatedMarkdown && updatedMarkdown.length > 150) {
        fs.writeFileSync(filePath, updatedMarkdown + "\n", "utf8");
        console.log(`    ✓ Successfully updated ${path.basename(filePath)} via ${OLLAMA_MODEL}`);
      }
    } catch (err: any) {
      console.warn(`    ⚠ Failed to update ${subId} with Ollama: ${err.message}`);
    }
  }
}

async function main() {
  const targetArg = process.argv[2];
  const rootDir = targetArg ? path.resolve(targetArg) : process.cwd();

  console.log(`=== 🔄 OpenViking Knowledge Base Synchronizer ===`);
  console.log(`Target project: ${rootDir}`);

  if (!fs.existsSync(rootDir)) {
    console.error(`✗ Error: Directory not found: ${rootDir}`);
    process.exit(1);
  }

  const knowledgeDir = findKnowledgeDir(rootDir);
  if (!knowledgeDir) {
    console.error(`✗ Error: Knowledge base not found in ${rootDir}`);
    console.error(`  Run 'context-init ${rootDir}' to initialize OpenViking knowledge base first.`);
    process.exit(1);
  }

  const l0Path = path.join(knowledgeDir, "L0_index.json");
  const rawL0 = fs.readFileSync(l0Path, "utf8");
  const index = JSON.parse(rawL0) as L0Index;

  console.log(`Knowledge base: ${knowledgeDir} (${index.project})`);

  // 1. If Stow packages are defined (e.g. dotfiles), scan and sync them
  if (Array.isArray(index.stow_packages)) {
    const packages = discoverStowPackages(rootDir);
    console.log(`Discovered ${packages.length} Stow packages in repository.`);
    await syncL0Index(l0Path, index, packages);
  } else {
    await syncL0Index(l0Path, index);
  }

  // 2. Check git changes for L1 subsystem docs
  const statusOutput = runGit("status --porcelain", rootDir);
  const changedFiles: string[] = [];
  for (const line of statusOutput.split("\n")) {
    const match = line.match(/^..\s+(.*)$/);
    if (match) {
      const rawPath = match[1].trim();
      const filePath = rawPath.includes(" -> ") ? rawPath.split(" -> ")[1].trim() : rawPath;
      changedFiles.push(filePath.replace(/^"|"$/g, ""));
    }
  }

  // 3. Update L1 subsystems with Local AI
  await syncSubsystemsWithLocalAi(rootDir, knowledgeDir, index, changedFiles);

  console.log("=== ✨ Knowledge Base Sync Complete ===\n");
}

main().catch((err) => {
  console.error("Fatal error during knowledge sync:", err);
  process.exit(1);
});
