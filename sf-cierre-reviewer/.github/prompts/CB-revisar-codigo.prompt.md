---
name: CB-revisar-codigo
agent: CB PL/SQL Reviewer
description: Revisa codigo PL/SQL del modulo Cierre Bancario con salida tipo dashboard (semaforo) y genera reporte .md.
argument-hint: "input | output.md" (output opcional)
---

Ejemplos de invocacion recomendada (texto plano):
- `@CB PL/SQL Reviewer PR#42 jira=on | .github/reports/pr-42-cb-review.md`
- `@CB PL/SQL Reviewer PR#42 jira=off | .github/reports/pr-42-cb-review.md`
- `@CB PL/SQL Reviewer PR#42 | .github/reports/pr-42-cb-review.md` (equivale a `jira=on`)

Pre-flight recomendado (ejecutar una vez desde terminal antes de invocar el agente):
- Sin Jira: `node .github/scripts/pr-fetch.mjs 42`
- Con Jira:  `node .github/scripts/pr-fetch.mjs 42 jira`

El script descarga el PR y lo guarda en `.github/pr-cache/`. El agente lee la cache directamente sin necesitar herramienta de terminal.

Regla de lectura de cache/token:
- Para `.github/pr-cache/*` y `.github/config/gh-token.txt`, usar lectura directa por ruta exacta.
- No usar resultados de `search/file_search` como criterio de existencia en esas rutas.

Nota operativa:
- Usar `PR#<n>` como input, no URLs con formato markdown ni URI internos de VS Code.
- El comando del agente debe funcionar sin cache previa usando `fetch` remoto; el pre-fetch es solo fallback opcional.

Review this PL/SQL code strictly against:
1. The rules defined in `.github/copilot-instructions.md` (general core standards).
2. The Cierre Bancario-specific rules defined in the `CB PL/SQL Reviewer` agent.

Use the `CB PL/SQL Reviewer` agent as source of behavior.
For process guidance, align with `.github/skills/cb-rvw/` assets:
- `checklists/plsql-cb-checklist.md`
- `rules/severity-mapping.md`
- `templates/dashboard.md`

Mandatory PR connectivity rule:
- If input is `PR#...` or a PR URL, validate remote access primarily via `fetch` to GitHub API (`/pulls/<N>`, `/pulls/<N>/files`, and diff media type).
- `gh auth`/`gh pr view` are optional fallback checks and must not be required to proceed when `fetch` already succeeded.
- For PR analysis, use only remote PR artifacts.
- If remote access fails, stop immediately and return:
	`BLOQUEADO: sin conexion valida a GitHub para consultar el PR remoto.`
- Do not continue with local-only assumptions for PR review.
- Do not bypass with `git fetch origin pull/<n>/head` or local branch diffs.
- Hard stop: after returning BLOQUEADO, end execution with no further analysis.
- Do not run local git reconstruction commands (`git log`, `git show`, `git diff`, `git branch`, `git status`) after a PR connectivity failure.
- In PR mode, do not read source files from local path `ueno_core/` to produce findings.
- In blocked mode, output only the single blocking line (no findings or summary).

Mandatory Jira rule for PR mode:
- In PR mode, Jira context is required by default unless user explicitly sets `jira=off`.
- Obtain Jira context in this order: `.github/pr-cache/pr-<N>-jira.json` -> `jira_get_issue` -> direct `fetch` to Jira API using `tools/mcp-jira/.env` credentials.
- If Jira context cannot be retrieved (tool unavailable, auth failure, timeout, permission error, ticket not found), stop immediately and return:
	`BLOQUEADO: jira=on requiere acceso valido a Jira para consultar la tarea del ticket.`
- In Jira-blocked mode, output only that single blocking line (no findings or summary).

Execution gate (non-bypass):
- For PR reviews, continue to technical analysis only if both checks are true:
	1) `GH_REMOTE_OK=true` (GitHub `fetch` path successful, or cache valida disponible), and
	2) if `jira!=off`, `JIRA_CONTEXT_OK=true`.
- If either check is false, do not run local git reconstruction commands, do not read local source route, and do not emit technical conclusions.

Mandatory BKP consistency rule:
- If the report includes a BKP reference, it must match the same PR ticket (example: PR CIE-1179 -> BKP/CIE-1179).
- Never use BKP from another ticket (example: BKP/CIE-1124 for PR CIE-1179).

Generate the markdown report file too:
- If the argument includes `input | output.md`, save to `output.md`
- If output path is missing and input is PR, save to `.github/reports/pr-{number}-{headRefName}-cb-review-YYYYMMDD-HHMM.md` (from `gh pr view`)
- If output path is missing and input is file/list, save to `.github/reports/{branch}-cb-review-YYYYMMDD-HHMM.md`
- If that path fails, save to `.github/reports/cb-review-latest.md`

If the severity traffic light is fully GREEN (Critical Issues = 0 and Improvements = 0, with coverage dimensions in green), stop immediately:
- Do not fabricate corrections or improvement suggestions.
- Keep output concise and non-redundant.
- Still generate the markdown report with the same concise content.

Respond in Spanish.
