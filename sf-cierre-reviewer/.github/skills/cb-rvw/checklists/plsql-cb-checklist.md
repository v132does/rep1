# CB PL/SQL Checklist

> Nota: este checklist es un resumen operativo. Las reglas de referencia son `.github/copilot-instructions.md`, `.github/itgf-standard.instructions.md`, `.github/reglas_operativas_cierre.md` y `.github/agents/cb-plsql-reviewer.agent.md`.

## Idempotencia y Reejecucion
- [ ] El proceso actualiza `HORA_INICIO` en `IT.GE_PROCESOS_DET` al arrancar.
- [ ] El proceso actualiza `HORA_FIN` en `IT.GE_PROCESOS_DET` al finalizar correctamente.
- [ ] El proceso puede ejecutarse multiples veces sobre el mismo periodo sin duplicar datos (usa borrado previo, upsert, o validacion de estado).
- [ ] El `cod_proceso` utilizado corresponde a los valores validos del cierre bancario (7, 10, 11, 12).

## Registro en Malla de Cierre (GE_PROCESOS_DET)
- [ ] El programa existe en `data/ge_procesos_det.csv` (buscar por COD_PROGRAMA).
- [ ] El `COD_PROCESO` del registro coincide con el ciclo esperado segun la logica del codigo.
- [ ] `ACTIVO = 'S'` — si es 'N', alertar que el programa esta desactivado en la malla.
- [ ] `OBLIGATORIO` identificado — si es 'S', aplicar criterio de revision estricto.

## Resolucion de Logica Real (Wrapper vs Implementacion)
- [ ] Se identifico si el programa revisado es un wrapper delgado que delega su logica principal a otro `procedure`/`function`/`package.metodo`.
- [ ] Si delega: se busco y se leyo la definicion del programa delegado (local en `ueno_core/` o remoto via `gh api`/busqueda).
- [ ] El criterio completo de revision (idempotencia, error handling, hardcodes, higiene de variables, dataflow, DDL/DML) se aplico sobre el programa **delegado real**, no solo sobre el wrapper.
- [ ] El programa delegado NO se reporta como "fuera de la malla" si el wrapper que lo invoca si esta registrado y activo; hereda su clasificacion OBLIGATORIO/ACTIVO/COD_PROCESO/NRO_ORDEN.
- [ ] Si no se pudo acceder al programa delegado, se declaro explicitamente en `Supuestos` con su nombre.

## Contexto Funcional (Jira)
- [ ] Se derivo el ticket desde el PR (ej: CIE-1180) y se verifico su existencia.
- [ ] Si Jira esta disponible, se revisaron `summary/description/acceptance criteria` y se valido alineacion del cambio.
- [ ] Si Jira no estuvo disponible, el reporte deja constancia explicita en `Supuestos`.

## Investigacion en ueno_core
- [ ] Para cada funcion/procedimiento invocado: buscar definicion en `ueno_core/` para verificar `PRAGMA autonomous_transaction`, manejo de excepciones.
- [ ] Para tablas con WRITE: buscar indices y DDL SOLO si estan en top-10 de volumetria (`reglas_operativas_cierre.md` Regla 2).
- [ ] Buscar en `ueno_core/` otros programas del cierre que referencien las mismas tablas (impacto cruzado).
- [ ] Validar supuestos: si algo es desconocido, investigar en el repo antes de asumir.

## Impacto Cruzado
- [ ] Identificadas las tablas con operaciones WRITE (INSERT/UPDATE/DELETE) en el codigo revisado.
- [ ] Buscados en `ueno_core/` otros programas que referencien esas mismas tablas.
- [ ] Cruzado con `data/ge_procesos_det.csv` para identificar cuales pertenecen a la malla.
- [ ] Evaluado el nivel de riesgo: ALTO si impacta programas OBLIGATORIO='S' del mismo ciclo.

## Comentarios de Revisores (GitHub) — Modo PR (informativo, no bloqueante)
- [ ] Se consultaron los tres canales: `/issues/<N>/comments`, `/pulls/<N>/comments` y `/pulls/<N>/reviews`.
- [ ] Se registraron cantidades o errores por canal; `comments: []` no se tomo como evidencia suficiente para descartar comentarios inline.
- [ ] Cada solicitud de un revisor humano fue cruzada contra el codigo HEAD y clasificada: Aplicado / Parcial / Pendiente.
- [ ] Los pedidos Pendiente se documentaron como observacion de seguimiento, sin alterar el veredicto de merge (que depende solo del semaforo tecnico).
- [ ] El reporte distingue `Sin comentarios` (tres canales OK y vacios) de `No se pudo verificar` (algun canal fallo).

## Naming & Style (estandar ITGF)
- [ ] Objetos referenciados con esquema `IT.` (ej: `IT.GE_PROCESOS_DET`).
- [ ] Paquetes con prefijo `pa` + letra de modulo (ej: `pag_`, `paa_`, `pac_`, `pap_`, `pab_`).
- [ ] Procedimientos con prefijo `pr` + prefijo funcional (`pro`, `act`, `ins`, `bor`, `val`, etc.).
- [ ] Funciones con prefijo `fu` + prefijo funcional (`obt`, `ver`, `con`, etc.).
- [ ] Cursores con prefijo `cu`.
- [ ] Variables internas: `r_` (record), `v_` (escalar), `g_` (global de paquete).
- [ ] Parametros: `p_` (escalar), `rp_` (record parametro).
- [ ] Triggers operativos: `TB_`/`TA_`; triggers de auditoria: `AB_`/`AA_`.
- [ ] Indentacion de 2 espacios (sin tabs).
- [ ] SQL keywords en mayusculas, nombres de tablas/columnas en minusculas.
- [ ] Un parametro por linea en declaraciones y llamadas con multiples parametros.
- [ ] Sin variables declaradas y no usadas.
- [ ] Sin codigo comentado en version final.

## Error Handling
- [ ] En `WHEN OTHERS` se loguea el error (mecanismo de logging propio de Cierre Bancario, ej. `PRG_ACT_LOG_PROCESOS`, o `RAISE` directo). **No sugerir paquetes de logging/errores de otros modulos o motores del core.**
- [ ] Siempre se hace `RAISE` despues del log para propagar el error al orquestador.
- [ ] No existe `WHEN OTHERS THEN NULL`.
- [ ] No hay `RAISE_APPLICATION_ERROR` directo para errores de negocio catalogados.

## Volumetria y Performance (Regla 2)
- [ ] Si el programa aparece en el top-10 de volumetria (`reglas_operativas_cierre.md` Regla 2), incluir alerta con los numeros exactos.
- [ ] No hay loops row-by-row evitables sobre DML masivo.
- [ ] Se usa `BULK COLLECT`/`FORALL` cuando el volumen lo amerita.
- [ ] SQL set-based priorizado sobre procesamiento procedural innecesario.
- [ ] Si el programa es de alto volumen, validar uso de indices y evitar full table scans innecesarios.

## Paralelismo Fork/Join (Regla 3)
- [ ] Si el proceso es tipo **F (Barrera/Join):** valida que espera el fin del proceso padre antes de ejecutar.
- [ ] Si el proceso es tipo **P (Fork):** no bloquea el flujo principal del orquestador.
- [ ] No hay dependencias de secuencia rota: un proceso F que corre sin que su P haya finalizado es Critical.
- [ ] En procesos paralelos, no existen bloqueos riesgosos (`SELECT ... FOR UPDATE`, `LOCK TABLE` o contencion prolongada) que puedan generar deadlocks en la malla.
- [ ] El `cod_proceso` corresponde al ciclo correcto segun el orden: 7 → 11 → 12 → 10.

## Criticidad de la Malla (Regla 1)
- [ ] Se puede determinar si el proceso es `OBLIGATORIO = 'S'` (bloqueante) o `'N'` (candidato a extraccion).
- [ ] Los procesos criticos (`S`) tienen analisis exhaustivo de dependencias en el codigo.

## Hardcode de negocio
- [ ] Valores de negocio (codigos, montos, fechas especiales) recuperados de parametros/tablas, no hardcodeados.
- [ ] `cod_proceso` no esta hardcodeado en medio de logica de negocio sin una constante o parametro claro.

## Higiene de Variables y Parametros
- [ ] No hay parametros declarados y no usados en procedures/funciones (ej: `p_cod_moneda` sin uso).
- [ ] No hay variables declaradas/asignadas y no usadas (evitar ruido y falsos supuestos).
- [ ] Las funciones locales no generan efectos colaterales sobre variables externas sin contrato explicito (OUT/IN OUT o retorno claro).
- [ ] No existe dependencia de orden oculta entre llamadas (ej: una llamada "ensucia" `v_categoria` y otra consume ese estado sin validacion).
- [ ] Si existe estado compartido mutable, esta documentado y cubierto con validacion explicita en el flujo.
- [ ] No existe `use-before-set` en el flujo: una funcion no se invoca con variables de contexto stale del registro anterior.
- [ ] En loops de calculo, validar orden de asignacion: primero calcular categoria/estado del registro actual y luego llamar funciones dependientes (ej: `lf_obt_gar_com`).

## Cambios de Esquema y Datos (archivos .sql)
- [ ] DDL idempotente: `ALTER TABLE` con guard (`IF NOT EXISTS` o equivalente Oracle) o script protegido para re-ejecucion segura.
- [ ] No hay `DROP COLUMN`, `DROP TABLE` ni `TRUNCATE` sin justificacion explicita y aprobacion.
- [ ] Columnas nuevas: tienen `DEFAULT` valido o permiten `NULL`; no rompen codigo existente que usa `SELECT *` o inserta sin lista de columnas.
- [ ] DML de catalogo idempotente: usa `MERGE`, `INSERT ... WHERE NOT EXISTS`, o borrado previo controlado.
- [ ] `UPDATE`/`DELETE` masivos tienen `WHERE` clause especifica; no hay actualizaciones sin filtro.
- [ ] Cambios en `IT.GE_PROCESOS` o `IT.GE_PROCESOS_DET` (activar/desactivar procesos) son justificados y no rompen dependencias de la malla.
- [ ] Cambios en tablas de parametros o configuracion no eliminan registros usados activamente por la malla de cierre.
- [ ] Script ejecutable en el orden correcto del deployment (secuencias → tablas → packages → scripts DML).
