import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

function loadDotEnvFile(dotEnvPath) {
  if (!fs.existsSync(dotEnvPath)) return;
  const content = fs.readFileSync(dotEnvPath, "utf8");
  const lines = content.split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const idx = line.indexOf("=");
    if (idx <= 0) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim();
    if (key && !process.env[key]) {
      process.env[key] = value;
    }
  }
}

function loadEnv() {
  const scriptDir = path.dirname(fileURLToPath(import.meta.url));
  loadDotEnvFile(path.join(process.cwd(), ".env"));
  if (process.cwd() !== scriptDir) {
    loadDotEnvFile(path.join(scriptDir, ".env"));
  }
}

loadEnv();

const requiredEnv = ["JIRA_BASE_URL", "JIRA_EMAIL", "JIRA_API_TOKEN"];
for (const key of requiredEnv) {
  if (!process.env[key] || !process.env[key].trim()) {
    throw new Error(`Falta variable de entorno requerida en .env: ${key}`);
  }
}

const baseUrl = process.env.JIRA_BASE_URL.replace(/\/+$/, "");
const email = process.env.JIRA_EMAIL;
const token = process.env.JIRA_API_TOKEN;
const authHeader = `Basic ${Buffer.from(`${email}:${token}`).toString("base64")}`;

async function jiraRequest(apiPath, options = {}) {
  const response = await fetch(`${baseUrl}${apiPath}`, {
    ...options,
    headers: {
      "Authorization": authHeader,
      "Accept": "application/json",
      "Content-Type": "application/json",
      ...(options.headers || {})
    }
  });

  const text = await response.text();
  let payload;
  try {
    payload = text ? JSON.parse(text) : {};
  } catch {
    payload = { raw: text };
  }

  if (!response.ok) {
    const message = payload?.errorMessages?.join("; ") || payload?.message || response.statusText;
    throw new Error(`Error en API de Jira (${response.status}): ${message}`);
  }

  return payload;
}

const server = new Server(
  { name: "jira-mcp-local", version: "0.2.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "jira_get_issue",
        description: "Obtiene información detallada y Criterios de Aceptación de un ticket de Jira (ej: CIE-1180)",
        inputSchema: {
          type: "object",
          properties: {
            issueKey: { type: "string", description: "Clave del ticket de Jira (ej: CIE-1180)" }
          },
          required: ["issueKey"]
        }
      }
    ]
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    if (name === "jira_get_issue") {
      const issueKey = String(args?.issueKey || "").trim();
      if (!issueKey) throw new Error("issueKey es requerido");

      const fields = ["summary", "description", "status", "assignee", "reporter", "priority", "issuetype", "components"];
      const query = new URLSearchParams({ fields: fields.join(",") }).toString();
      const issue = await jiraRequest(`/rest/api/3/issue/${encodeURIComponent(issueKey)}?${query}`);

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(issue, null, 2)
          }
        ]
      };
    }

    throw new Error(`Herramienta no reconocida: ${name}`);
  } catch (error) {
    return {
      isError: true,
      content: [{ type: "text", text: error instanceof Error ? error.message : String(error) }]
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);