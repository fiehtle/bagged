import fs from "node:fs";
import path from "node:path";

function parseEnvFile(contents) {
  const entries = {};

  for (const rawLine of contents.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }

    const separatorIndex = line.indexOf("=");
    if (separatorIndex === -1) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    let value = line.slice(separatorIndex + 1).trim();

    if (
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    entries[key] = value;
  }

  return entries;
}

export function loadLocalEnv({ cwd = process.cwd() } = {}) {
  for (const filename of [".env", ".env.local"]) {
    const filePath = path.join(cwd, filename);
    if (!fs.existsSync(filePath)) {
      continue;
    }

    const contents = fs.readFileSync(filePath, "utf8");
    const entries = parseEnvFile(contents);
    for (const [key, value] of Object.entries(entries)) {
      if (!(key in process.env)) {
        process.env[key] = value;
      }
    }
  }
}
