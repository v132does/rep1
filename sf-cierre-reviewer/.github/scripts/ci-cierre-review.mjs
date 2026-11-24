#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const prNumber = process.env.PR_NUMBER;
const repo = process.env.GITHUB_REPOSITORY;
const ghToken = process.env.GITHUB_TOKEN;
const jiraBaseUrl = process.env.JIRA_BASE_URL;
const jiraEmail = process.env.JIRA_EMAIL;
const jiraToken = process.env.JIRA_API_TOKEN;

if (!prNumber || !repo || !ghToken) {
  console.error("Faltan variables de entorno requeridas de GitHub.");
  process.exit(1);
}

const reportsDir = path.resolve(".github", "reports");
if (!fs.existsSync(reportsDir)) fs.mkdirSync(reportsDir, { recursive: true });

async function run() {
  console.log(`[CI-REVIEW] Iniciando análisis integral para PR #${prNumber}...`);

  // 1. Obtener metadatos del PR
  const headers = { Authorization: `Bearer ${ghToken}`, Accept: "application/vnd.github+json", "User-Agent": "sf-ci" };
  const prRes = await fetch(`https://api.github.com/repos/${repo}/pulls/${prNumber}`, { headers });
  const prData = await prRes.json();

  // 2. Obtener lista detallada de archivos modificados
  const filesRes = await fetch(`https://api.github.com/repos/${repo}/pulls/${prNumber}/files?per_page=100`, { headers });
  const files = await filesRes.json();

  // 3. Extraer Ticket Jira
  const match = (prData.title + " " + prData.head.ref).match(/([A-Z]+-\d+)/);
  const ticket = match ? match[1] : "UNKNOWN";

  // 4. Consultar Jira
  let jiraSummary = "No consultado";
  let jiraStatus = "N/A";
  let jiraCAs = [];

  if (jiraBaseUrl && jiraEmail && jiraToken && ticket.startsWith("CIE-")) {
    try {
      const auth = Buffer.from(`${jiraEmail}:${jiraToken}`).toString("base64");
      const jRes = await fetch(`${jiraBaseUrl}/rest/api/3/issue/${ticket}`, {
        headers: { Authorization: `Basic ${auth}`, Accept: "application/json" },
      });
      if (jRes.ok) {
        const jData = await jRes.json();
        jiraSummary = jData.fields?.summary || "Sin resumen";
        jiraStatus = jData.fields?.status?.name || "Desconocido";

        function extractAdf(node) {
          if (!node) return "";
          if (node.text) return node.text;
          if (Array.isArray(node.content)) return node.content.map(extractAdf).join(" ");
          return "";
        }
        const descText = extractAdf(jData.fields?.description);
        jiraCAs = descText.split("\n").filter(l => /criterio|requisito|ca\d|req/i.test(l)).slice(0, 6).map(l => l.trim());
      }
    } catch (err) {
      console.warn(`[CI-REVIEW] Error Jira: ${err.message}`);
    }
  }

  // 5. Categorizar archivos y verificar BKP
  const modifiedBD = [];
  const bkpFiles = [];
  const sqlScripts = [];
  const alerts = [];

  files.forEach(f => {
    const filename = f.filename;
    if (filename.includes("Objetos_BD/")) modifiedBD.push(f);
    else if (filename.includes("BKP/")) bkpFiles.push(path.basename(filename).toLowerCase());
    else if (filename.includes("SQL/")) sqlScripts.push(f);
  });

  // Validar paridad: Cada objeto en Objetos_BD debe tener un respaldo en BKP/
  modifiedBD.forEach(f => {
    const baseName = path.basename(f.filename).toLowerCase();
    const hasBackup = bkpFiles.some(b => b.includes(baseName.replace(/\.[^/.]+$/, "")) || baseName.includes(b.replace(/\.[^/.]+$/, "")));
    if (!hasBackup) {
      alerts.push(`🔴 **Falta Respaldo (BKP)**: El objeto \`${path.basename(f.filename)}\` fue modificado pero no se detectó su backup correspondiente en \`GESTION_FINANCIERA/Aplicaciones_Principales/BKP/\`.`);
    } else {
      alerts.push(`🟢 **Respaldo Validado**: Backup verificado en \`BKP/\` para \`${path.basename(f.filename)}\`.`);
    }
  });

  // 6. Analizar scripts SQL (DML, DDL, Parámetros y Cadenas)
  sqlScripts.forEach(f => {
    const patch = f.patch || "";
    const name = f.filename;

    // Verificar si el script está en su subcarpeta de ticket correspondiente (SQL/CIE-XXXX/)
    if (ticket !== "UNKNOWN" && !name.includes(ticket)) {
      alerts.push(`🟡 **Estructura de Carpetas**: El script \`${path.basename(name)}\` debería ubicarse dentro de \`SQL/${ticket}/\`.`);
    }

    // Detección de impacto en la cadena de Cierre
    if (/GE_PROCESOS_DET/i.test(patch)) {
      alerts.push(`⚠️ **Modificación de Cadena (GE_PROCESOS_DET)** en \`${path.basename(name)}\`: Se detectaron cambios que alteran el orden, exclusión o incorporación de procesos en el cierre.`);
    }
    if (/GE_PROCESOS_DEP/i.test(patch)) {
      alerts.push(`⚠️ **Modificación de Dependencias (GE_PROCESOS_DEP)** en \`${path.basename(name)}\`: Se altera la matriz de ejecución paralela.`);
    }

    // Regla de transacción en scripts
    if (/\b(INSERT|UPDATE|DELETE)\b/i.test(patch) && !/\bCOMMIT\b/i.test(patch)) {
      alerts.push(`🟡 **Script DML sin COMMIT**: \`${path.basename(name)}\` contiene sentencias de inserción/actualización sin un COMMIT explícito.`);
    }
  });

  // 7. Auditoría de código PL/SQL sobre Objetos_BD
  modifiedBD.forEach(f => {
    const patch = f.patch || "";
    const lines = patch.split("\n").filter(l => l.startsWith("+") && !l.startsWith("+++"));

    let inLoop = false;
    lines.forEach(l => {
      if (/\b(LOOP|WHILE|FOR)\b/i.test(l)) inLoop = true;
      if (/\bEND\s+LOOP\b/i.test(l)) inLoop = false;

      if (inLoop && /\b(UPDATE|INSERT|DELETE)\b/i.test(l) && !/--/.test(l)) {
        alerts.push(`⚠️ **DML dentro de bucle** en \`${path.basename(f.filename)}\`: \`${l.trim()}\``);
      }
      if (/WHEN\s+OTHERS\s+THEN\s*(NULL|RETURN\s+0)/i.test(l)) {
        alerts.push(`🔴 **Excepción suprimida** en \`${path.basename(f.filename)}\`: Se detectó \`WHEN OTHERS\` sin registrar ni propagar el error.`);
      }
    });

    if (/PRP_GEN_CTA_GARANTIA|CO_TRANSACCION|CLI_TRANSACCIONES/i.test(patch)) {
      alerts.push(`ℹ️ **Alerta Exadata**: Modificación sobre tabla/procedimiento de alta volumetría (>1.5M reg).`);
    }
  });

  // 8. Determinar Semáforo y Alerta de Contenido
  const hasDbChanges = modifiedBD.length > 0 || sqlScripts.length > 0;

  let semaforo = "🟢 APROBADO";

  if (!hasDbChanges) {
    semaforo = "⚪ INFORMATIVO (Sin cambios detectados en Objetos_BD ni SQL)";
    alerts.push(`ℹ️ **Sin archivos de BD**: Este Pull Request no contiene modificaciones en \`Objetos_BD/\` ni scripts en \`SQL/\`. Si este ticket requería cambios de base de datos, verifique si olvidó incluirlos en el commit.`);
  } else if (alerts.some(a => a.startsWith("🔴"))) {
    semaforo = "🔴 RECHAZADO (Requiere Corrección)";
  } else if (alerts.some(a => a.startsWith("⚠️") || a.startsWith("🟡"))) {
    semaforo = "🟡 OBSERVADO (Revisar advertencias)";
  }

  // 9. Armar Reporte Markdown
  const report = [
    `# Reporte de Auditoría Integral — Cierre Bancario`,
    `**Pull Request**: #${prNumber} — ${prData.title}`,
    `**Rama**: \`${prData.head.ref}\` ➔ \`${prData.base.ref}\``,
    `**Ticket Jira**: [${ticket}](${jiraBaseUrl}/browse/${ticket}) (${jiraStatus})`,
    `**Resultado de Validación**: ${semaforo}`,
    ``,
    `---`,
    `### 1. Requerimiento y Criterios (Jira)`,
    `- **Objetivo**: ${jiraSummary}`,
    jiraCAs.length > 0 ? jiraCAs.map(c => `  - ${c}`).join("\n") : `  - *Sin criterios estructurados.*`,
    ``,
    `### 2. Control de Objetos y Respaldos (BKP)`,
    modifiedBD.length > 0
      ? modifiedBD.map(f => `- **Objeto BD:** \`${path.basename(f.filename)}\``).join("\n")
      : `- *No se detectaron modificaciones directas en Objetos_BD.*`,
    ``,
    `### 3. Scripts de Configuración y Cadena (SQL/)`,
    sqlScripts.length > 0
      ? sqlScripts.map(f => `- **Script:** \`${path.basename(f.filename)}\` en \`${path.dirname(f.filename)}\``).join("\n")
      : `- *No se incluyeron scripts DDL/DML de soporte.*`,
    ``,
    `### 4. Hallazgos Técnicos y Alertas Operativas`,
    alerts.length > 0 ? alerts.map(a => `- ${a}`).join("\n") : `✅ Todos los controles estáticos de código, cadena y respaldos fueron aprobados.`,
    ``,
    `> *Auditoría ejecutada de forma automática por la suite centralizada sf-cierre-reviewer.*`
  ].join("\n");

  fs.writeFileSync(path.join(reportsDir, `pr-${prNumber}-cb-review.md`), report, "utf8");

  // Publicar Comentario en GitHub
  await fetch(`https://api.github.com/repos/${repo}/issues/${prNumber}/comments`, {
    method: "POST",
    headers: { Authorization: `Bearer ${ghToken}`, "Content-Type": "application/json", "User-Agent": "sf-ci" },
    body: JSON.stringify({ body: report }),
  });

  console.log("[CI-REVIEW] Auditoría finalizada y comentario publicado.");
}

run().catch(err => {
  console.error(`[CI-REVIEW] Error: ${err.message}`);
  process.exit(1);
});