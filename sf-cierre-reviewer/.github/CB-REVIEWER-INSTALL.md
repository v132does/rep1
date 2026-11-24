# Manual de Instalación y Uso — Agente SF-CIERRE Reviewer (Cursor)

Agente de revisión de código PL/SQL para el módulo **Cierre Bancario** de `ueno_core`. Analiza Pull Requests o archivos puntuales contra las reglas del core, genera un dashboard con semáforo de severidad, valida 1 a 1 los Criterios de Aceptación de Jira y produce un reporte estructurado en formato `.md`.

---

## 1. Requisitos previos

| Requisito | Uso | Obligatorio |
|---|---|---|
| **Cursor IDE** | Entorno de desarrollo y ejecución de agentes | Sí |
| **Node.js 18+** | Correr scripts de pre-fetch y el servidor MCP de Jira | Sí |
| **Token de GitHub (PAT)** con acceso a `ueno-tecnologia-org/ueno_core` | Consultar PRs y diffs vía API | Sí |
| **Autorización SSO del token** para `ueno-tecnologia-org` | Evitar error `HTTP 403` al consultar la API | Sí |
| **Credenciales de Jira (Atlassian API Token)** | Extracción de Criterios de Aceptación (CA) | Condicional: requerida salvo `jira=off` |
| **GitHub CLI (`gh`)** | Diagnóstico y pre-fetch alternativo por consola | Opcional |

---

## 2. Estructura de archivos del agente

```text
sf-cierre-reviewer/
├── .cursor/
│   └── rules/
│       └── 01-sf-cierre-reviewer.mdc         # Regla principal del agente en Cursor
├── .github/
│   ├── data/
│   │   ├── ge_procesos.csv                   # Catálogo de ciclos del cierre
│   │   ├── ge_procesos_det.csv               # Catálogo maestro de programas del cierre
│   │   └── ge_procesos_dep.csv               # Matriz de paralelismo y dependencias (P/F)
│   ├── scripts/
│   │   ├── pr-fetch.mjs                      # Pre-fetch principal por GitHub API (Node)
│   │   └── pr-fetch.ps1                      # Pre-fetch alternativo con GitHub CLI
│   ├── config/
│   │   └── gh-token.txt                      # Token de GitHub (NO versionar)
│   ├── pr-cache/                             # Cache local de PRs descargados (NO versionar)
│   └── reports/                              # Reportes generados (.md)
├── tools/
│   └── mcp-jira/
│       ├── jira-mcp-server.mjs               # Servidor MCP de Jira para Cursor
│       ├── .env                              # Credenciales de Jira (NO versionar)
│       ├── .env.example
│       └── package.json
├── .instructions.md                          # Protocolo operativo del agente
└── CB-REVIEWER-INSTALL.md                    # Este manual de instalación
```

---

## 3. Instalación paso a paso

### 3.1 Instalar Node.js
Si no cuentas con Node.js en tu equipo:
```powershell
winget install OpenJS.NodeJS.LTS
```
Reiniciar Cursor después de la instalación.

### 3.2 Generar y configurar el token de GitHub

1. En GitHub, ir a `Settings → Developer settings → Personal access tokens → Tokens (classic)`.
2. Crear un token con scope `repo` (lectura).
3. **Autorización SSO:** En la lista de tokens, hacer clic en **Configure SSO** junto al token generado y autorizar la organización `ueno-tecnologia-org`.
4. Crear la carpeta `.github/config/` si no existe y guardar el token en:
   ```text
   .github/config/gh-token.txt
   ```
   *(Solo el valor del token, sin comillas, espacios ni saltos de línea)*.

### 3.3 Instalar dependencias del servidor MCP de Jira

Abrir una terminal en Cursor (`Ctrl + ~`) y ejecutar:
```powershell
cd tools/mcp-jira
npm install
```

### 3.4 Configurar credenciales de Jira

Copiar el archivo `.env.example` a `.env` dentro de `tools/mcp-jira/`:
```powershell
cp .env.example .env
```
Completar las variables con tus credenciales:
```env
JIRA_BASE_URL=[https://tu-org.atlassian.net](https://tu-org.atlassian.net)
JIRA_EMAIL=tu-email@ueno.com.py
JIRA_API_TOKEN=<token_generado_en_id.atlassian.com>
```

### 3.5 Registrar el servidor MCP en Cursor

En Cursor, abrir `Settings → Features → MCP Servers` (o configurar `.cursor/mcp.json` o `.vscode/mcp.json`) con la definición del servidor:

```json
{
  "mcpServers": {
    "jira": {
      "command": "node",
      "args": ["jira-mcp-server.mjs"],
      "cwd": "tools/mcp-jira"
    }
  }
}
```

---

## 4. Comandos de uso en Cursor

### Revisar un Pull Request con contexto de Jira
En el panel de chat de Cursor (**Agents Window**), invocar la regla usando `@`:
```text
@01-sf-cierre-reviewer Revisa el PR#42 | .github/reports/pr-42-cb-review.md
```

### Omitir contexto de Jira (solo revisión técnica PL/SQL)
```text
@01-sf-cierre-reviewer Revisa el PR#42 jira=off | .github/reports/pr-42-cb-review.md
```

### Revisar un archivo puntual
```text
@01-sf-cierre-reviewer GESTION_FINANCIERA/Aplicaciones_Principales/Objetos_BD/Procedimientos/PRA_CON_TRANSACCION.prc
```

### Pre-descargar un PR manualmente (opcional para trabajar sin conexión)
```powershell
node .github/scripts/pr-fetch.mjs <NUMERO_PR> jira
```

---

## 5. Qué valida el agente en cada revisión

1. **Trazabilidad 1 a 1 con Jira:** Evalúa individualmente cada Criterio de Aceptación (CA-01, CA-02...) declarado en el ticket.
2. **Comparación Estricta BKP vs Objetos_BD:** Los hallazgos críticos solo se levantan sobre el código modificado o nuevo introducido en el PR.
3. **Idempotencia y Reejecución:** Garantiza que el proceso pueda correr múltiples veces sin generar inconsistencias ni duplicados.
4. **Persistencia por Lotes (Batching):** Si el proceso hace `COMMIT` parcial, valida que contadores y secuencias se persistan dentro del ciclo del lote.
5. **Cadena de Cierre y Paralelismo:** Cruza contra `ge_procesos_dep.csv` para validar barreras de sincronización (Tipo F) e inicios paralelos (Tipo P).
6. **Concurrencia 24/7:** Previene bloqueos prolongados sobre tablas transaccionales compartidas con SIPAP/SPI.
7. **Generación del Reporte:** Construye el dashboard con verificación de SHA y semáforo de severidad en `.github/reports/`.