# MCP Jira (local)

Servidor MCP minimo para consultar Jira desde Copilot/cliente MCP.

## Que expone

- `jira_get_issue`: trae una tarea por key (ejemplo `CIE-1180`).
- `jira_search_issues`: busca tareas por JQL.

## Requisitos

- Node.js 18+
- Jira Cloud con API Token

## Variables de entorno

Copiar `.env.example` y configurar:

- `JIRA_BASE_URL` (ejemplo `https://tu-org.atlassian.net`)
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

## Instalar

```bash
cd tools/mcp-jira
npm install
```

## Ejecutar (stdio)

```bash
npm start
```

## Ejemplo de configuracion MCP (referencial)

Usar este bloque en la configuracion MCP de tu cliente (ajustar ruta/cwd segun tu entorno):

```json
{
  "servers": {
    "jira": {
      "command": "node",
      "args": [
        "jira-mcp-server.mjs"
      ],
      "cwd": "tools/mcp-jira",
      "env": {
        "JIRA_BASE_URL": "https://tu-org.atlassian.net",
        "JIRA_EMAIL": "you@company.com",
        "JIRA_API_TOKEN": "<token>"
      }
    }
  }
}
```

## Notas

- No guardar credenciales reales en archivos versionados.
- Si queres, se puede extender con transiciones, comentarios o cambio de estado.
