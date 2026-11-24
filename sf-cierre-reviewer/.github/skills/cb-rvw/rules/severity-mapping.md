# Severity Mapping (Semaforo) — Cierre Bancario

## Critical Issues (🔴)
Aplicar cuando exista riesgo de:
- Proceso no idempotente: puede generar duplicados o inconsistencias al reejecutar.
- Falta de registro de `HORA_INICIO` o `HORA_FIN` en `IT.GE_PROCESOS_DET`.
- Escritura en `IT.GE_PROCESOS_DET` de un `cod_proceso` ajeno al procesador.
- Violacion de limites de gobernanza: procesador escribe en `IT.GE_PROCESOS` directamente.
- `COMMIT/ROLLBACK` no autorizado dentro de un procesador individual.
- **Error handling sin `RAISE` y sin fallback seguro:** los errores se tragan (`WHEN OTHERS THEN NULL` o equivalente) y el flujo continua sin ningun valor de reemplazo controlado, dejando estado indeterminado o inconsistente que llega al orquestador sin señal de alerta.
- **Paralelismo roto:** proceso tipo F (barrera) que ejecuta sin esperar el fin de su proceso P padre.
- **Bloqueos en paralelismo mal gestionados:** uso excesivo de `SELECT ... FOR UPDATE`, `LOCK TABLE` o contencion prolongada con riesgo de deadlock en la malla.
- **`cod_proceso` incorrecto:** el proceso corre en el ciclo equivocado (ej: logica de cierre diario en ciclo 10).
- Incumplimiento bloqueante de reglas del core (`copilot-instructions.md`).
- **DDL destructivo sin guardia:** `DROP COLUMN`, `DROP TABLE`, `TRUNCATE` sin control explicito.
- **DML sin WHERE:** `UPDATE` o `DELETE` sin filtro sobre tablas de la malla de cierre.
- **Desactivacion de proceso obligatorio en GE_PROCESOS_DET** sin justificacion (OBLIGATORIO=S -> ACTIVO=N).
- **DDL no idempotente:** `ALTER TABLE ADD COLUMN` que falla en re-ejecucion (sin guard Oracle).
- **Columna nueva NOT NULL sin DEFAULT** que rompe INSERT existentes.

## Regla de no-asuncion sobre seleccion no determinista (`ROWNUM`/`FETCH FIRST` sin `ORDER BY`)
No clasificar automaticamente como Critical un `SELECT ... WHERE ... AND ROWNUM = 1` (u otro limitador sin `ORDER BY`) que devuelve una fila arbitraria entre varias coincidentes.
- Si el autor/negocio confirma explicitamente que **cualquier fila coincidente es funcionalmente equivalente** para el caso de uso (ej: todas las filas candidatas comparten el mismo valor relevante, o el criterio de negocio es "cualquiera sirve"), esto **no es un hallazgo de integridad**. A lo sumo, sugerir como `Improvement` agregar un comentario en el codigo que documente esa intencion (para que futuros revisores no lo reinterpreten como bug).
- Solo clasificar como `Critical` si se confirma (por el codigo, el ticket, o el autor) que las filas candidatas SI pueden diferir en un valor relevante para el resultado (ej: usuarios distintos que deben tratarse distinto), y no hay un criterio de negocio que respalde la eleccion arbitraria.
- Ante duda, preguntar/anotar el supuesto en vez de asumir directamente Critical.

## Regla de no-asuncion sobre patrones explicitamente solicitados por revisores humanos
Si un patron de codigo (ej: `INSTR(columna, valor) > 0` en reemplazo de un `LIKE '%valor%'` previo) fue implementado como respuesta directa a un pedido explicito de un revisor humano documentado (comentario de PR, ticket, o indicado por el autor), **no clasificar ese cambio como Critical ni Improvement negativo**: es una mejora deliberada sobre el estado anterior, no un defecto nuevo introducido por el PR. Si aun asi existe un riesgo residual real (ej: coincidencias parciales de substring), documentarlo como `Improvement` de refinamiento opcional, dejando explicito que el cambio ya es una mejora sobre el comportamiento previo y fue solicitado explicitamente.

## Improvements (🟡)
Aplicar cuando exista:
- **Fallback silencioso sin logging (con valor de reemplazo seguro):** bloque `WHEN OTHERS` (u otra excepcion) que asigna un valor de respaldo razonable/conocido (ej. el identificador original previo al cambio) y permite continuar el flujo, pero no deja registro/log de que se uso el fallback. Distinto del caso Critical: aqui SI hay un valor de reemplazo controlado y el flujo no queda indeterminado, solo falta trazabilidad.
- **DML de catalogo no idempotente:** INSERT directo sin verificacion de existencia previa.
- **Cambio en tabla de parametros** sin comentario de justificacion en el script.
- **Parametro declarado y no usado:** en procedure/function local o publica (ej: `p_cod_moneda` sin referencias efectivas).
- **Variable declarada y no usada:** variable local/global inicializada o asignada sin impacto funcional.
- **Dependencia implicita por efecto colateral:** funcion/procedimiento local que modifica variables externas y condiciona calculos posteriores sin contrato explicito (ej: cambia `v_categoria` fuera de su retorno).
- **Use-before-set / orden incorrecto de calculo:** una variable de entrada para un calculo clave se actualiza despues de invocar la funcion que depende de ella (ej: `v_garantia := lf_obt_gar_com(...)` antes de refrescar `v_categoria` del registro actual).
- Desviacion de convenciones de naming ITGF (prefijos de paquete, procedimiento, funcion, variables).
- Oportunidad de mejora de performance no bloqueante (row-by-row vs bulk).
- **Alerta de volumetria:** SOLO si el programa está en el top-10 de volumetria y no tiene optimizaciones evidentes (ver `reglas_operativas_cierre.md` Regla 2).
- Mejoras de mantenibilidad, legibilidad o trazabilidad.
- Hardcode de valores de negocio que deberian venir de parametros.
- `cod_proceso` sin constante o parametro explicito.

Regla de escalamiento para higiene de variables:
- Si el problema de orden/efecto colateral impacta montos, categoria contable, asientos o resultado del cierre: clasificar como `Critical Issues (🔴)`.
- Si solo afecta legibilidad o mantenimiento sin alterar resultado funcional: clasificar como `Improvements (🟡)`.

## Good Practices (🟢)
Aplicar cuando se confirme:
- Idempotencia correctamente implementada (borrado previo + reinsert, upsert).
- `HORA_INICIO`/`HORA_FIN` actualizados en el momento correcto del flujo.
- Error handling con log y re-raise consistente.
- Objetos schema-qualified con `IT.`.
- Naming ITGF respetado: prefijos de paquete, procedimiento, funcion y variables correctos.
- Paralelismo Fork/Join correctamente implementado segun la matriz de la malla.
- Logica de negocio parametrizada sin hardcodes.
- Patrones que reducen riesgo operativo en reejecuciones de cierre.

## Tabla de Semaforo obligatoria

| Severidad | Color | Cantidad | Estado |
|---|---|---:|---|
| Critical Issues | 🔴 | N | Requiere correccion |
| Improvements | 🟡 | N | Mejorar |
| Good Practices | 🟢 | N | Mantener |
