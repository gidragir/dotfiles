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

interface WorkspaceConfig {
  slug: string;
  promptFile: string;
  chatProvider: string;
  chatModel: string;
  agentProvider: string;
  agentModel: string;
}

const workspaces: WorkspaceConfig[] = [
  {
    slug: "assistant-chats",
    promptFile: "assistant-chats.md",
    chatProvider: "anythingllm_ollama",
    chatModel: "gemma4:e4b-it-q4_K_M",
    agentProvider: "anythingllm_ollama",
    agentModel: "gemma4:e4b-it-q4_K_M",
  },
  {
    slug: "onlychat",
    promptFile: "onlychats.md",
    chatProvider: "anythingllm_ollama",
    chatModel: "gemma4:e4b-it-q4_K_M",
    agentProvider: "anythingllm_ollama",
    agentModel: "gemma4:e4b-it-q4_K_M",
  },
  {
    slug: "my-workspace",
    promptFile: "main-workspace.md",
    chatProvider: "anythingllm_ollama",
    chatModel: "qwen3-vl:4b-instruct",
    agentProvider: "anythingllm_ollama",
    agentModel: "qwen3-vl:4b-instruct",
  },
];

for (const ws of workspaces) {
  const promptPath = path.join(PROMPTS_DIR, ws.promptFile);
  if (!fs.existsSync(promptPath)) {
    console.log(`[sync-prompts] Warning: File ${promptPath} not found.`);
    continue;
  }
  const content = fs.readFileSync(promptPath, "utf8").trim();
  const query = db.query(`
    UPDATE workspaces
    SET openAiPrompt = ?,
        chatProvider = ?,
        chatModel = ?,
        agentProvider = ?,
        agentModel = ?
    WHERE slug = ?
  `);
  const info = query.run(
    content,
    ws.chatProvider,
    ws.chatModel,
    ws.agentProvider,
    ws.agentModel,
    ws.slug
  );
  console.log(`[sync-prompts] Configured '${ws.slug}': model=${ws.chatModel} (${info.changes} row updated).`);
}

// Synchronize system settings (allowed filesystem paths, default agent skills)
interface SystemSetting {
  label: string;
  value: string;
}

const systemSettings: SystemSetting[] = [
  {
    label: "allowed_filesystem_folders",
    value: JSON.stringify(["/data/obsidian", "/data/projects"]),
  },
  {
    label: "default_agent_skills",
    value: JSON.stringify(["filesystem-agent"]),
  },
  {
    label: "disabled_filesystem_skills",
    value: JSON.stringify([]),
  },
  {
    label: "disabled_agent_skills",
    value: JSON.stringify([]),
  },
  {
    label: "memory_enabled",
    value: "true",
  },
  {
    label: "onboarding_complete",
    value: "true",
  },
];

for (const setting of systemSettings) {
  const query = db.query(`
    INSERT INTO system_settings (label, value, createdAt, lastUpdatedAt)
    VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT(label) DO UPDATE SET
      value = excluded.value,
      lastUpdatedAt = CURRENT_TIMESTAMP
  `);
  query.run(setting.label, setting.value);
}
console.log("[sync-prompts] System settings synchronized (allowed folders: /data/obsidian, /data/projects).");

db.close();
console.log("[sync-prompts] All workspaces, models, and settings synchronized successfully.");

