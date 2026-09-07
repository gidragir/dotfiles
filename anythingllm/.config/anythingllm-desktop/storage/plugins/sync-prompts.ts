import fs from "fs";
import path from "path";
import { Database } from "bun:sqlite";

const DB_PATH = path.resolve(
  process.env.HOME || "",
  ".config/anythingllm-desktop/storage/anythingllm.db"
);

const PROMPTS_DIR = path.resolve(
  import.meta.dir,
  "../../prompts"
);

if (!fs.existsSync(DB_PATH)) {
  console.log(`[sync-prompts] Database not found at ${DB_PATH}. Skipping.`);
  process.exit(0);
}

const db = new Database(DB_PATH);

function updateWorkspacePrompt(workspaceIdentifier: string | number, filename: string) {
  const promptPath = path.join(PROMPTS_DIR, filename);
  if (!fs.existsSync(promptPath)) {
    console.log(`[sync-prompts] Warning: Prompt file ${promptPath} not found.`);
    return;
  }
  const content = fs.readFileSync(promptPath, "utf8").trim();
  let query;
  if (typeof workspaceIdentifier === "number") {
    query = db.query("UPDATE workspaces SET openAiPrompt = ? WHERE id = ?");
  } else {
    query = db.query("UPDATE workspaces SET openAiPrompt = ? WHERE slug = ?");
  }
  const info = query.run(content, workspaceIdentifier);
  console.log(`[sync-prompts] Synced ${filename} -> workspace ${workspaceIdentifier} (${info.changes} row(s) updated).`);
}

// 1. Assistant Chats (Thinking Partner & Obsidian)
updateWorkspacePrompt("assistant-chats", "assistant-chats.md");
updateWorkspacePrompt(2, "assistant-chats.md");

// 2. Default Workspace (Developer & Systems Workspace)
updateWorkspacePrompt(1, "dev-workspace.md");

db.close();
console.log("[sync-prompts] All prompts successfully synchronized.");
