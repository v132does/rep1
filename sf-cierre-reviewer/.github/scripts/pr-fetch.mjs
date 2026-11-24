#!/usr/bin/env node
/**
 * pr-fetch.mjs — Descarga datos de un PR de GitHub y los guarda en .github/pr-cache/
 * Uso: node .github/scripts/pr-fetch.mjs <PR_NUMBER> [jira]
 * Compatible con Windows, Linux y macOS.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(scriptDir, "..", "..");

const [prNumberArg, modeArg] = process.argv.slice(2);
const prNumber = parseInt(prNumberArg, 10);

if (!prNumber || isNaN(prNumber)) {
  console.error("Uso: node .github/scripts/pr-fetch.mjs <PR_NUMBER> [jira]");
  process.exit(1);
}

const withJira = modeArg === "jira";
const repo = "ueno-tecnologia-org/ueno_core";
const cacheDir = path.join(rootDir, ".github", "pr-cache");
const tokenFile = path.join(rootDir, ".github", "config", "gh-token.txt");

if (!fs.existsSync(cacheDir)) {
  fs.mkdirSync(cacheDir, { recursive: true });
}

function readToken() {
  if (fs.existsSync(tokenFile)) {
    return fs.readFileSync(tokenFile, "utf8").trim();
  }
  return process.env.GH_TOKEN || process.env.GITHUB_TOKEN || "";
}

async function ghFetch(url, extraHeaders = {}) {
  const token = readToken();
  if (!token) {
    throw new Error(
      "Token de GitHub no encontrado. Ejecuta: gh auth token > .github/config/gh-token.txt"
    );
  }
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "cb-pr-fetch/1.0",
      ...extraHeaders,
    },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`GitHub API ${res.status} ${res.statusText}: ${body}`);
  }
  return res;
}

async function fetchPrMeta() {
  process.stdout.write(`[1/3] Metadata del PR #${prNumber}... `);
  const res = await ghFetch(
    `https://api.github.com/repos/${repo}/pulls/${prNumber}`,
    { Accept: "application/vnd.github+json" }
  );
  const data = await res.json();
  const filesRes = await ghFetch(
    `https://api.github.com/repos/${repo}/pulls/${prNumber}/files?per_page=100`,
    { Accept: "application/vnd.github+json" }
  );
  const files = await filesRes.json();
  const meta = {
    number: data.number,
    title: data.title,
    body: data.body,
    headRefName: data.head.ref,
    headRefOid: data.head.sha,
    baseRefName: data.base.ref,
    baseRefOid: data.base.sha,
    labels: (data.labels || []).map((l) => l.name),
    files: files.map((f) => ({ path: f.filename, status: f.status })),
  };
  fs.writeFileSync(
    path.join(cacheDir, `pr-${prNumber}.json`),
    JSON.stringify(meta, null, 2),
    "utf8"
  );
  console.log("OK");
  return meta;
}

async function fetchPrDiff() {
  process.stdout.write(`[2/3] Diff del PR #${prNumber}... `);
  const res = await ghFetch(
    `https://api.github.com/repos/${repo}/pulls/${prNumber}`,
    { Accept: "application/vnd.github.diff" }
  );
  const diff = await res.text();
  fs.writeFileSync(path.join(cacheDir, `pr-${prNumber}.diff`), diff, "utf8");
  console.log("OK");
}

function deriveTicket(headRefName, title) {
  const m = (headRefName + " " + title).match(/([A-Z]+-\d+)/);
  return m ? m[1] : "UNKNOWN";
}

async function fetchJira(ticket) {
  process.stdout.write(`[3/3] Jira ${ticket}... `);

  // leer credenciales Jira desde tools/mcp-jira/.env
  const envPath = path.join(rootDir, "tools", "mcp-jira", ".env");
  const jiraEnv = {};
  if (fs.existsSync(envPath)) {
    for (const line of fs.readFileSync(envPath, "utf8").split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const idx = trimmed.indexOf("=");
      if (idx > 0) {
        jiraEnv[trimmed.slice(0, idx).trim()] = trimmed.slice(idx + 1).trim();
      }
    }
  }

  const baseUrl = jiraEnv.JIRA_BASE_URL || process.env.JIRA_BASE_URL || "";
  const email = jiraEnv.JIRA_EMAIL || process.env.JIRA_EMAIL || "";
  const apiToken = jiraEnv.JIRA_API_TOKEN || process.env.JIRA_API_TOKEN || "";

  if (!baseUrl || !email || !apiToken || apiToken === "<tu_token>") {
    console.log("OMITIDO (credenciales Jira no configuradas)");
    fs.writeFileSync(
      path.join(cacheDir, `pr-${prNumber}-jira.json`),
      JSON.stringify({ error: "Jira no configurado" }),
      "utf8"
    );
    return;
  }

  try {
    const auth = Buffer.from(`${email}:${apiToken}`).toString("base64");
    const res = await fetch(
      `${baseUrl}/rest/api/3/issue/${encodeURIComponent(ticket)}`,
      {
        headers: {
          Authorization: `Basic ${auth}`,
          Accept: "application/json",
        },
      }
    );
    if (!res.ok) {
      throw new Error(`${res.status} ${res.statusText}`);
    }
    const data = await res.json();
    fs.writeFileSync(
      path.join(cacheDir, `pr-${prNumber}-jira.json`),
      JSON.stringify(data, null, 2),
      "utf8"
    );
    console.log("OK");
  } catch (err) {
    console.log(`FALLO (${err.message})`);
    fs.writeFileSync(
      path.join(cacheDir, `pr-${prNumber}-jira.json`),
      JSON.stringify({ error: err.message }),
      "utf8"
    );
  }
}

// --- main ---
console.log(`=== PR-FETCH PR#${prNumber} ===`);
try {
  const meta = await fetchPrMeta();
  await fetchPrDiff();

  const ticket = deriveTicket(meta.headRefName, meta.title);
  const plsqlCount = meta.files.filter((f) =>
    /\.(spc|bdy|prc|fnc)$/i.test(f.path)
  ).length;

  if (withJira) {
    await fetchJira(ticket);
  } else {
    console.log("[3/3] Jira: omitido (pasar 'jira' como segundo argumento para incluir)");
  }

  console.log(`\nCache generado en: .github/pr-cache/`);
  console.log(`  pr-${prNumber}.json   (metadata + archivos)`);
  console.log(`  pr-${prNumber}.diff   (diff completo)`);
  if (withJira) console.log(`  pr-${prNumber}-jira.json`);
  console.log(`\nArchivos PL/SQL en el PR: ${plsqlCount}`);
  console.log(`Ticket: ${ticket} | Branch: ${meta.headRefName}`);
  console.log(`\nAhora podes invocar el revisor en VS Code:`);
  console.log(`  @CB PL/SQL Reviewer PR#${prNumber} | .github/reports/pr-${prNumber}-cb-review.md`);
} catch (err) {
  console.error(`\nERROR: ${err.message}`);
  process.exit(1);
}
