import fs from "fs";
import path from "path";
import { execSync } from "child_process";

const skillsDir = path.resolve(import.meta.dir, "agent-skills");

function findSkillHandlers(dir: string): string[] {
  const results: string[] = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    if (entry.name.startsWith(".") || entry.name.startsWith("_")) continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const handlerPath = path.join(fullPath, "handler.ts");
      if (fs.existsSync(handlerPath)) {
        results.push(handlerPath);
      }
    }
  }
  return results;
}

const handlers = findSkillHandlers(skillsDir);

if (handlers.length === 0) {
  console.log("No skill handlers found to build.");
} else {
  for (const handler of handlers) {
    const outFile = handler.replace(/\.ts$/, ".js");
    console.log(`Building ${path.relative(import.meta.dir, handler)} -> ${path.basename(outFile)}...`);
    execSync(`bun build ${handler} --outfile ${outFile} --target node --format cjs`, {
      stdio: "inherit",
    });
  }
  console.log(`Successfully built ${handlers.length} skill(s).`);
}
