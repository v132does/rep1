---
name: cb-rvw
description: Workflow de code review PL/SQL Cierre Bancario con checklist, semaforo de severidad y generacion de reporte markdown. Usar para revisar un archivo puntual o un conjunto de archivos modificados (PR).
disable-model-invocation: false
---

# CB Review Workflow

Estandariza revisiones PL/SQL del modulo Cierre Bancario con salida dashboard y evidencia accionable.

## Source of Truth
- Politica y reglas generales del core: `.github/copilot-instructions.md`
- Reglas especificas del modulo: `.github/agents/cb-plsql-reviewer.agent.md`
- Este skill define el flujo (no reemplaza reglas de negocio del repositorio)

## When to Use
- Revisar 1 package (`.spc` o `.bdy`) con criterio estricto de Cierre Bancario.
- Revisar multiples archivos modificados para consolidar un unico reporte.
- Generar informe formal en `.md` para seguimiento o auditoria.

## Inputs
- `input`: PR number (`PR#123`), URL de PR, ruta de archivo, o lista de archivos separada por comas.
- `output` (opcional): ruta de reporte markdown.
- `jira` (opcional): `on` (default en modo PR), `off`.

Formato sugerido:
- PR: `PR#123 | reports/pr-123-cb-review.md`
- Archivo: `Objetos BD/Package/CB_CIERRE_DIARIO.bdy | reports/cb-diario-review.md`

Si no se pasa `output`, usar:
- En modo PR: `.github/reports/pr-{number}-{headRefName}-cb-review-YYYYMMDD-HHMM.md`
- En modo archivo: `.github/reports/{branch}-cb-review-YYYYMMDD-HHMM.md`
- fallback: `.github/reports/cb-review-latest.md`

## Workflow
### Modo PR
**Resolucion automatica de datos del PR (para cualquier PR#<N>):**

Flujo principal (sin terminal):

**A — GitHub API via fetch (obligatorio):**
- Token: leer `.github/config/gh-token.txt` por ruta exacta.
- Importante: no depender de `search` para detectar `gh-token.txt` porque puede estar excluido por ignore.
- `fetch GET https://api.github.com/repos/ueno-tecnologia-org/ueno_core/pulls/<N>` (header `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`).
- `fetch GET https://api.github.com/repos/ueno-tecnologia-org/ueno_core/pulls/<N>/files`.
- `fetch GET https://api.github.com/repos/ueno-tecnologia-org/ueno_core/pulls/<N>` (header `Accept: application/vnd.github.diff`) para el diff.
- Registrar `head.sha` y `updated_at` de la respuesta de metadata: son obligatorios para la seccion `## 0. Verificacion de Origen` del reporte.

**B — Cache local (opcional):** leer `.github/pr-cache/pr-<N>.json` + `.github/pr-cache/pr-<N>.diff` solo como respaldo.
- Importante: no validar existencia con busquedas globales (`search`/`file_search`) porque pueden ocultar rutas ignoradas.
- Validar por lectura directa de ruta exacta; si la lectura devuelve contenido, considerar cache disponible.

Si ninguna opcion funciona:
- Responder `BLOQUEADO: token GitHub no disponible o invalido en .github/config/gh-token.txt` y detener ejecucion.

**Regla anti-reutilizacion de analisis previo (obligatoria, sin excepciones):**
- Cada invocacion del reviewer debe **releer el contenido actual** de `.github/pr-cache/pr-<N>.diff` (o el `fetch` en vivo) con una llamada de lectura nueva en ese mismo turno, **incluso si en esta misma conversacion ya se reviso el mismo PR antes**.
- Prohibido reutilizar, copiar o parafrasear hallazgos/fragmentos "Antes/Despues" de un reporte generado en un turno anterior de la conversacion sin volver a leer el archivo fuente en el turno actual.
- Si el archivo fue leido en un turno anterior de la conversacion, asumir que pudo haber cambiado desde entonces: releerlo igual antes de escribir el reporte.
- Cada fragmento de codigo citado como evidencia debe provenir de la lectura hecha en el turno actual, no de memoria conversacional.

4. Filtrar archivos PL/SQL (`.spc`, `.bdy`, `.prc`, `.fnc`) y scripts SQL (`.sql`) desde la respuesta del PR.
   - Los `.sql` se ubican tipicamente en carpetas llamadas `sql/` dentro del repositorio.
   - Los `.sql` se clasifican por tipo antes de revisar: DDL (ALTER/CREATE/DROP), DML de catalogo (INSERT/UPDATE/DELETE en tablas de parametros o malla), o mixto.
5. Derivar ticket del PR desde `headRefName` o `title` (ej: `CIE-1179`).
6. **Contexto Jira (obligatorio por defecto en modo PR):**
   - Verificar primero `.github/pr-cache/pr-<N>-jira.json` leyendo la ruta exacta.
   - Si no existe cache Jira, intentar via herramienta MCP `jira_get_issue(issueKey=<TICKET>)`.
   - Si MCP no esta disponible, consultar Jira directamente por `fetch`:
     - Leer credenciales desde `tools/mcp-jira/.env` (ruta exacta): `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`.
     - Llamar `GET {JIRA_BASE_URL}/rest/api/3/issue/<TICKET>` con `Authorization: Basic <base64(email:token)>` y `Accept: application/json`.
     - Si responde 200, considerar `JIRA_CONTEXT_OK=true` y continuar.
   - Extraer y resumir: `summary`, `description`, `acceptance criteria`, `status`, `labels`, `components`.
   - Usar ese resumen funcional como contexto para validar si el cambio implementa lo pedido.
   - Si no hay contexto Jira (cache ni MCP) y no se indico `jira=off`, detener flujo indicando: `node .github/scripts/pr-fetch.mjs <N> jira`.
7. Resolver contenido remoto por archivo usando GitHub API (sin ruta local):
   - HEAD: `gh api repos/ueno-tecnologia-org/ueno_core/contents/<path>?ref=<headRefOid>`
   - BASE: `gh api repos/ueno-tecnologia-org/ueno_core/contents/<path>?ref=<baseRefOid>`
   - Cross-impact remoto: `gh api search/code -f q="repo:ueno-tecnologia-org/ueno_core NOMBRE_TABLA (extension:prc OR extension:bdy OR extension:fnc OR extension:spc)"`
8. Si existe BKP del ticket dentro de los archivos del PR remoto, usarlo como referencia; si no existe, no usar BKP de otro ticket.
9. Si el PR tiene mas de 10 archivos PL/SQL, priorizar los `.bdy` y `.prc` (implementacion).
10. Ejecutar pase obligatorio de higiene de variables en cada objeto revisado:
   - Listar parametros de cada `procedure/function` cambiada y verificar referencia efectiva en el cuerpo.
   - Marcar en `Improvements (🟡)` cualquier parametro declarado y no usado.
   - Detectar variables asignadas y no consumidas posteriormente.
   - Detectar efectos colaterales: funciones/procedures locales que escriben estado externo consumido por otra rutina.
   - Validar orden de calculo por iteracion (dataflow): ninguna funcion debe consumir variables de contexto stale del registro anterior.
   - Regla practica: si `lf_obt_gar_com(...)` depende de `v_categoria`, `v_categoria` debe calcularse antes de invocar `lf_obt_gar_com(...)` en el mismo loop.
   - Si el efecto colateral cambia categoria/montos/resultado contable, escalar a `Critical Issues (🔴)`.
11. Cruzar comentarios de revisores humanos del PR (GitHub) — intentar siempre, es informativo (no bloqueante):
   - Es obligatorio consultar, para el PR exacto, los tres canales: comentarios generales (`GET /issues/<N>/comments`), comentarios inline (`GET /pulls/<N>/comments`) y reviews (`GET /pulls/<N>/reviews`). Usar primero la herramienta nativa de GitHub; si no expone los tres canales, completar la consulta mediante API `fetch`/`gh` autenticada.
   - No concluir "sin comentarios" solo porque una respuesta trae `comments: []`: los comentarios inline viven en `/pulls/<N>/comments` y el estado `CHANGES_REQUESTED` vive en `/pulls/<N>/reviews`.
   - Registrar en el reporte el resultado de cada canal: cantidad obtenida, o el error HTTP/autenticacion si fallo. Distinguir estrictamente `Sin comentarios` de `No se pudo verificar`.
   - Para cada solicitud de un revisor humano, verificar si ya fue aplicada, aplicada parcialmente o sigue pendiente en el codigo HEAD.
   - Reportar en la seccion `Comentarios de Revisores (GitHub)` del dashboard.
   - Los pedidos `Pendiente` se documentan como observacion de seguimiento, pero **no** cambian ni degradan el veredicto de merge; ese veredicto depende exclusivamente del semaforo tecnico (Critical/Improvements/Good Practices).
   - Si no hay forma de leer comentarios del PR, declarar el supuesto explicitamente y continuar el analisis tecnico normalmente.
12. Resolucion de logica real (wrapper vs implementacion) — obligatorio:
   - Si algun archivo del PR es un wrapper delgado que delega su logica principal a otro `procedure`/`function` (ver seccion homonima en `cb-plsql-reviewer.agent.md`), identificar el programa delegado y resolver su contenido remoto (mismo mecanismo del punto 7: `gh api .../contents/<path>` o busqueda remota).
   - Aplicar el criterio completo de revision sobre el programa delegado, no solo sobre el wrapper.
   - Declarar en el reporte que programa(s) delegado(s) fueron analizados; si no se pudo acceder, declararlo en `Supuestos` con el nombre exacto.
13. Leer el diff de cada archivo PL/SQL de forma **integra y secuencial** (sin muestreo de inicio/fin) antes de redactar hallazgos; nunca basar un hallazgo en el `body`/descripcion del PR sin verificarlo contra el codigo real. Si el diff supera ~300 lineas, leerlo en tramos consecutivos completos.
14. Prestar atencion especial a secciones donde cambia la estructura de control (loops, `EXIT WHEN`, reubicacion de `COMMIT`) y a cualquier linea comentada en el lado "despues": son puntos de alta probabilidad de bugs de limite transaccional (ver Regla 5 del agente, `Consistencia de commits por lote con contadores/watermarks externos`).
15. Continuar con los pasos del workflow estandar (checklist, severidad, dashboard, reporte).

Regla estricta:
- En modo PR, el camino principal es `fetch` directo a GitHub API; no depender de herramientas de terminal.
- Cache `.github/pr-cache/pr-<N>.json` y `.github/pr-cache/pr-<N>.diff` es solo respaldo opcional.
- Si `fetch` a GitHub falla por token ausente/invalido, marcar estado **BLOQUEADO** indicando `.github/config/gh-token.txt`.
- No usar `git fetch origin pull/<n>/head` como bypass.
- No usar `git diff` local ni ruta `ueno_core/` como fuente principal en modo PR.
- Hard stop: tras estado **BLOQUEADO**, no emitir hallazgos tecnicos.
- No usar BKP de ticket distinto al PR (ej: PR CIE-1179 no puede usar BKP CIE-1124).
- No ejecutar comandos `git` de inspeccion (`git status`, `git branch`, `git show`, `git log`, `git diff`) en modo PR.
- Si queda **BLOQUEADO**, la salida debe incluir el comando de desbloqueo exacto (ver arriba).
- Gate de ejecucion en PR: solo continuar al analisis tecnico si `GH_REMOTE_OK=true`.
   - `GH_REMOTE_OK=true` cuando la consulta remota por `fetch` a GitHub responda 200, o cuando exista cache valida.
- Si `jira!=off`, solo continuar al analisis tecnico si ademas `JIRA_CONTEXT_OK=true`.
- Si falla Jira (sin cache, sin MCP, sin fetch directo, sin permisos, timeout, ticket no encontrado) y `jira!=off`, responder solo:
   `BLOQUEADO: jira=on requiere acceso valido a Jira para consultar la tarea del ticket.`
- Prohibido bypass: ante bloqueo de GitHub o Jira, no ejecutar reconstruccion local del PR (`git fetch pull/*`, `git diff`, `git show`, `git log`, `git checkout`, ramas locales) ni emitir hallazgos tecnicos.
- En modo PR, fuente de verdad de codigo = artefactos remotos del PR (gh pr view/diff + gh api contents por `headRefOid`/`baseRefOid`).
- En modo PR, no leer archivos desde ruta local `ueno_core/` para construir evidencia tecnica.

### Modo archivo
1. Leer `.github/copilot-instructions.md` (reglas generales del core).
2. Leer `.github/agents/cb-plsql-reviewer.agent.md` (reglas especificas del cierre bancario).
3. Ejecutar validacion por dimensiones usando `checklists/plsql-cb-checklist.md`.
4. **Investigacion en ueno_core (optimizada por contexto):**
   - No escanear ni leer masivamente todo `ueno_core/` con el LLM.
   - Ejecutar comandos de terminal para localizar referencias y trabajar SOLO con la lista devuelta.
   - Ejemplos de busqueda:
     - `grep -rnw 'ueno_core/' -e 'NOMBRE_TABLA'`
     - `grep -RniE "(FROM|JOIN|INSERT INTO|UPDATE|DELETE FROM)[[:space:]]+NOMBRE_TABLA" ueno_core/`
   - Leer unicamente los archivos candidatos devueltos por terminal para validar impacto cruzado.
   - Buscar indices y estructura de tablas SOLO si estan en el top-10 de volumetria.
   - Buscar definicion de procedimientos/funciones invocados SOLO cuando aparezcan en la lista de candidatos de terminal.
5. **Resolucion de logica real (wrapper vs implementacion) — obligatorio:** si el programa revisado es un wrapper delgado que delega su logica principal a otro `procedure`/`function` (ver seccion homonima en `cb-plsql-reviewer.agent.md`), buscar y analizar tambien el programa delegado con el mismo criterio completo de revision. No limitar el analisis al wrapper.
6. Clasificar hallazgos con `rules/severity-mapping.md`.
7. Formatear salida con `templates/dashboard.md`.
8. Guardar reporte en `.md` con el mismo contenido mostrado en chat.

## Coverage Dimensions
- Alineacion funcional con Jira: validacion 1 a 1 de criterios de aceptacion contra el diff + deteccion de scope creep (cuando hay ticket disponible)
- Comentarios de revisores humanos del PR (GitHub) — solo Modo PR
- Resolucion de logica real (wrapper vs implementacion delegada)
- Idempotencia y reejecucion
- Gobernanza (GE_PROCESOS / GE_PROCESOS_DET)
- Consistencia de commits por lote con contadores/secuencias/watermarks externos (ver Regla 5 del agente)
- Cambios de esquema y datos (DDL/DML .sql)
- Higiene de variables y parametros
- Naming & Style
- Error handling
- Performance
- Hardcode de negocio

## Output Rules
- Idioma: espanol.
- La estructura y detalle de salida se rigen por el agente `CB PL/SQL Reviewer` y `templates/dashboard.md`.
- Si una seccion no tiene hallazgos: `Sin hallazgos`.
- Cuando exista contexto Jira, validar explicitamente si el cambio cumple alcance y criterios de aceptacion del ticket.
- Evidencia obligatoria de hallazgos: usar siempre fragmentos de codigo con formato **Antes** y **Despues** en bloques `sql` (o `plsql`), no solo referencias tipo `archivo:linea`.
- Las referencias de linea pueden agregarse como complemento, pero nunca reemplazan los fragmentos de codigo.
- Regla de consistencia: un hallazgo no puede aparecer como `Good Practice` y `Critical/Improvement` al mismo tiempo.
- Regla contable estricta: `COMMIT` o `ROLLBACK` dentro de procesador individual nunca se clasifica como Good Practice.
- Si el semaforo es 100% verde (Critical Issues = 0, Improvements = 0 y dimensiones en verde), terminar de inmediato sin proponer correcciones forzadas.
- En VERDE total, usar salida breve y no redundante (manteniendo dashboard y reporte .md).

## Suggested Commands
- PR completo: `/cb-rvw PR#123`
- PR con salida custom: `/cb-rvw PR#123 | .github/reports/pr-123-cb-review.md`
- PR sin Jira (solo tecnico): `/cb-rvw PR#123 jira=off | .github/reports/pr-123-cb-review.md`
- PR con Jira obligatorio: `/cb-rvw PR#123 jira=on | .github/reports/pr-123-cb-review.md`
- Archivo puntual: `/cb-rvw Objetos BD/Package/CB_CIERRE_DIARIO.bdy`
- Archivo con salida custom: `/cb-rvw Objetos BD/Package/CB_CIERRE_DIARIO.bdy | .github/reports/cb-diario-review.md`
- Multiples archivos: `/cb-rvw file1.bdy,file2.spc | .github/reports/pr-123-cb-review.md`
