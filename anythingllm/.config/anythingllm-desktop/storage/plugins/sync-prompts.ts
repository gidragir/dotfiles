import fs from "fs";
import path from "path";
import { Database } from "bun:sqlite";

const DB_PATH = path.resolve(
  process.env.HOME || "",
  ".config/anythingllm-desktop/storage/anythingllm.db"
);

const ENV_PATH = path.resolve(
  process.env.HOME || "",
  ".config/anythingllm-desktop/storage/.env"
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
    chatProvider: "generic-openai",
    chatModel: "gemma4:e4b-it-q4_K_M",
    agentProvider: "generic-openai",
    agentModel: "gemma4:e4b-it-q4_K_M",
  },
  {
    slug: "onlychat",
    promptFile: "onlychats.md",
    chatProvider: "generic-openai",
    chatModel: "gemma4:e4b-it-q4_K_M",
    agentProvider: "generic-openai",
    agentModel: "gemma4:e4b-it-q4_K_M",
  },
  {
    slug: "my-workspace",
    promptFile: "main-workspace.md",
    chatProvider: "generic-openai",
    chatModel: "qwen3-vl:4b-instruct",
    agentProvider: "generic-openai",
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
  console.log(`[sync-prompts] Configured '${ws.slug}': model=${ws.chatModel} via ${ws.chatProvider} (${info.changes} row updated).`);
}

// Synchronize system settings (allowed filesystem paths, disabled duplicate skills, Headroom proxy)
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
    value: JSON.stringify([]),
  },
  {
    label: "disabled_filesystem_skills",
    value: JSON.stringify([]),
  },
  {
    label: "disabled_agent_skills",
    value: JSON.stringify(["web-scraping", "document-summarizer", "rag-memory"]),
  },
  {
    label: "memory_enabled",
    value: "true",
  },
  {
    label: "onboarding_complete",
    value: "true",
  },
  {
    label: "generic_openai_base_path",
    value: "http://127.0.0.1:8787/v1",
  },
  {
    label: "generic_openai_api_key",
    value: "headroom",
  },
  {
    label: "generic_openai_model_pref",
    value: "gemma4:e4b-it-q4_K_M",
  },
  {
    label: "generic_openai_token_limit",
    value: "16384",
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
console.log("[sync-prompts] System settings synchronized (disabled duplicate skills, Generic OpenAI proxy configured).");

// Synchronize local folders for RAG
const obsidianDocId = "local-obsidian-sync";
db.query(`
  INSERT INTO workspace_documents (docId, filename, docpath, workspaceId, watched, createdAt, lastUpdatedAt)
  VALUES (?, ?, ?, ?, ?, datetime('now'), datetime('now'))
  ON CONFLICT(docId) DO UPDATE SET watched = 1
`).run(obsidianDocId, "obsidian", "local:///data/obsidian", 1, 1);

const workspaceDoc = db.query(`SELECT id FROM workspace_documents WHERE docId = ?`).get(obsidianDocId) as { id: number };

if (workspaceDoc) {
  db.query(`
    INSERT INTO document_sync_queues (staleAfterMs, nextSyncAt, createdAt, lastSyncedAt, type, workspaceDocId)
    VALUES (?, datetime('now'), datetime('now'), datetime('now'), ?, ?)
    ON CONFLICT(workspaceDocId) DO NOTHING
  `).run(604800000, "local", workspaceDoc.id);
}
console.log("[sync-prompts] Local RAG sync queue for /data/obsidian ensured.");

db.close();

// Synchronize storage/.env for standalone backend
if (fs.existsSync(ENV_PATH)) {
  let envContent = fs.readFileSync(ENV_PATH, "utf8");
  const updates: Record<string, string> = {
    LLM_PROVIDER: "anythingllm_ollama",
    GENERIC_OPEN_AI_BASE_PATH: "http://127.0.0.1:8787/v1",
    GENERIC_OPEN_AI_API_KEY: "headroom",
    GENERIC_OPEN_AI_MODEL_PREF: "gemma4:e4b-it-q4_K_M",
    GENERIC_OPEN_AI_TOKEN_LIMIT: "16384",
    AGENT_SKILL_RERANKER_TOP_N: "30",
    AGENT_SKILL_RERANKER_ENABLED: "true",
  };

  for (const [key, val] of Object.entries(updates)) {
    const regex = new RegExp(`^${key}=.*$`, "m");
    if (regex.test(envContent)) {
      envContent = envContent.replace(regex, `${key}='${val}'`);
    } else {
      envContent += `\n${key}='${val}'`;
    }
  }
  fs.writeFileSync(ENV_PATH, envContent.trim() + "\n", "utf8");
  console.log(`[sync-prompts] Synchronized environment variables in ${ENV_PATH}.`);
}

console.log("[sync-prompts] All workspaces, models, and settings synchronized successfully.");
