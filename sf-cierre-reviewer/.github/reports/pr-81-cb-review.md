# Revisión de Código PL/SQL - PR#81: CIE-1216 Parametrización BULK LIMIT

**Fecha de Revisión:** 2026-08-26  
**Revisor:** GitHub Copilot (CB PL/SQL Reviewer - Cierre Bancario)  
**Ticket:** CIE-1216  
**Rama:** feature/CIE-1216  
**Commit HEAD:** fbfc20f0a2d35467a0ab0692437aefca7486a1b6  
**Commit BASE:** 4ba3f00bd4e8024541cf079318c4a03ccb7fd904

---

## 0. Verificación de Origen

**SHA del HEAD (remoto):** fbfc20f0a2d35467a0ab0692437aefca7486a1b6  
**Updated At:** 2026-08-26 (según cache remoto)  
**Fuente de datos:** Cache local (`.github/pr-cache/pr-81.json`, `pr-81.diff`)  
**Archivos en PR:** 4 (1 BKP + 1 modificación + 2 scripts SQL)  
**Estado:** ✅ Datos verificados del cache

---

## 1. Resumen Ejecutivo

### Cambio Propuesto
PR#81 modifica **PRA_CON_TRANSACCION** (COD_PROCESO=11, NRO_ORDEN=367, OBLIGATORIO=**S**) para:
1. **Parametrizar BULK COLLECT limit** vía `GE_PAR_DINAMICOS` parámetro `PRA_CON_TRA_LIMIT_LOTE` (default 50000)
2. **Diferir delete histórico a job asincrónico** en modo C (cierre central) usando DBMS_SCHEDULER

### Criticidad
**PRA_CON_TRANSACCION es CRÍTICO:**
- Volumetría: #2 en TOP-10 → 7,528,130 filas/día promedio; 19,972,569 pico máximo
- Ciclo 11 (Cierre Diario) - OBLIGATORIO = S (bloqueante)
- Tipo P (Paralelo) según matriz de cierre

### Veredicto Final
**🔴 NO APTO PARA MERGE (En estado actual)**

**Razones bloqueantes:** 2 Critical Issues + 1 Improvement crítica

---

## 2. Semáforo de Severidad

| Severidad | Color | Cantidad | Estado |
|-----------|-------|----------|--------|
| 🔴 Critical Issues | Rojo | **2** | **BLOQUEA MERGE** |
| 🟡 Improvements | Amarillo | **3** | Recomendadas |
| 🟢 Good Practices | Verde | **3** | Confirmadas |

---

## 3. Critical Issues

### 🔴 CRITICAL-001: Breaking Change en Patrón DELETE - Non-C Mode

**Procedimiento:** PRA_CON_TRANSACCION  
**Líneas afectadas:** Objetos_BD líneas 803-810

**ANTES (BKP):**
```plsql
-- Loop-based batched deletion (50k filas/batch)
/*Eliminamos registros de 2 dias habiles para atras, en lotes con commit intermedio
  para no sostener una transaccion unica de millones de filas (ver incidente de bloqueo prolongado)*/
LOOP
   DELETE FROM GE_CON_TRA_PROCESOS
    WHERE FECHA <= V_FEC_ANTERIOR - v_dia_lim
      AND ROWNUM <= c_lote_delete;
   EXIT WHEN SQL%ROWCOUNT = 0;
   COMMIT;
END LOOP;
```

**DESPUES (Objetos_BD, non-C mode):**
```plsql
IF P_LUGAR = 'C' THEN
   -- Deferred to async job
ELSE
   DELETE FROM GE_CON_TRA_PROCESOS
    WHERE FECHA <= V_FEC_ANTERIOR - v_dia_lim;  -- ❌ SIN BATCHING
   v_rows_del1 := SQL%ROWCOUNT;
   COMMIT;
END IF;
```

**Riesgo:**
1. **Eliminación masiva sin batching:** Potencialmente millones de filas en UNA transacción
2. **Lock table prolongado:** Bloquea otras transacciones del cierre
3. **Undo space:** ORA-30036 en instancias con undo bajo
4. **BKP tiene comentario explícito:** Reconoce incidente PREVIO de bloqueo prolongado
5. **Violación de patrón:** Regla de cierre = "batching para evitar locks"

**Impacto:** CRÍTICO en volumetría #2 (7.5M filas/día)

**Recomendación:**
- Restaurar LOOP con ROWNUM (como BKP)
- O parametrizar batch size para ambos modos

**Tags:** `[CIERRE-BREAKING-CHANGE]` `[VOLUMETRIA-RISK]` `[IDEMPOTENCIA-VIOLACION]`

---

### 🔴 CRITICAL-002: Inconsistencia de Idempotencia (C vs Non-C Mode)

**Procedimiento:** PRA_CON_TRANSACCION  
**Líneas:** 803-810 (delete pre-loop) + 1729-1755 (async job post-loop)

**Problema:**
- **Modo C:** Delete histórico DIFERIDO a job (asincrónico)
- **Modo Non-C:** Delete histórico SÍNCRONO sin batching
- Re-ejecución con distinto `p_lugar` genera comportamiento impredecible

**Violación de regla:** Cierre Bancario REGLA 1 = "Todo proceso debe ser idempotente"

**Escenario de fallo:**
1. Ejecución 1: `p_lugar='C'` → Delete diferido a job
2. Job aún no ejecutó
3. Ejecución 2: `p_lugar!='C'` → Delete síncrono masivo
4. Resultado: Estado inconsistente de GE_CON_TRANSACCIONES

**Impacto:** CRÍTICO en contabilidad (PRA_CON_TRANSACCION es OBLIGATORIO=S)

**Recomendación:**
- Comportamiento DELETE idéntico independientemente de `p_lugar`
- O rechazar cambio de parámetro si estado anterior = incompleto

**Tags:** `[IDEMPOTENCIA-VIOLACION]` `[ATOMICIDAD-BREAK]` `[CIERRE-RULE-INCUMPLIMIENTO]`

---

## 4. Improvements

### 🟡 IMPROVEMENT-001: Scripts SQL no Idempotentes

**Archivos:**
- `SQL/CIE-1216/7000_ins_ge_parametros.sql` (línea 3)
- `SQL/CIE-1216/7001_ins_ge_par_dinamicos.sql` (línea 3)

**Problema:** INSERT directo sin `WHERE NOT EXISTS` → `ORA-00001 unique constraint`

**Impacto:** Re-run de deployment fallará (no es reejecutable)

**Solución:** Usar MERGE o `INSERT ... WHERE NOT EXISTS`

**Ejemplo corregido:**
```sql
INSERT INTO GE_PARAMETROS (COD_PARAMETRO, DESCRIPCION, ...)
SELECT 'PRA_CON_TRA_LIMIT_LOTE', 'Límite BULK COLLECT...', ...
FROM dual
WHERE NOT EXISTS (
  SELECT 1 FROM GE_PARAMETROS WHERE COD_PARAMETRO = 'PRA_CON_TRA_LIMIT_LOTE'
);
```

**Tags:** `[DML-IDEMPOTENCIA]`

---

### 🟡 IMPROVEMENT-002: Variables Diagnóstico sin Consumo

**Líneas:** 54-59

- `v_rows_del1`, `v_rows_del2`, `v_rows_del3`: Asignadas pero nunca leídas para lógica
- Solo para logging
- Genera "ruido" en variables

**Solución:** Documentar como SOLO diagnóstico o consolidar en string único

**Tags:** `[VARIABLE-HYGIENE]`

---

### 🟡 IMPROVEMENT-003: Falta Parametrización de Delete Batch Size

**Inconsistencia:** BULK LIMIT está parametrizado, pero delete batch NO

**Situación Actual:**
```plsql
-- BULK COLLECT parametrizado ✅
v_limit_lote := nvl(to_number(fug_obt_pardinamico('PRA_CON_TRA_LIMIT_LOTE')),50000);

-- Delete batching NO parametrizado ❌
DELETE FROM GE_CON_TRA_PROCESOS
 WHERE FECHA <= V_FEC_ANTERIOR - v_dia_lim;  -- Unbatched
```

**Solución:** Agregar parámetro `PRA_CON_TRA_DELETE_BATCH_SIZE` si se restaura loop

**Tags:** `[CONSISTENCY]` `[CONFIG-MANAGEMENT]`

---

## 5. Good Practices

### 🟢 GOOD-001: Parametrización de BULK COLLECT Correcta

```plsql
v_limit_lote := nvl(to_number(fug_obt_pardinamico('PRA_CON_TRA_LIMIT_LOTE')),50000);
...
FETCH cursor1 BULK COLLECT INTO reg_movimientos LIMIT v_limit_lote;
```

✅ Sin recompilación, ajustable en PROD, default sensato

**Beneficios:**
- Ajuste dinámico sin código change
- Diferentes valores por ambiente
- Default fallback documentado

**Tags:** `[BEST-PRACTICE-PARAMETERIZATION]`

---

### 🟢 GOOD-002: Async Job + Error Handling Correcto

```plsql
DBMS_SCHEDULER.CREATE_JOB(
    job_name => v_del_job_name,
    auto_drop => TRUE,  -- ✅ Cleanup automático
    enabled => FALSE
);
DBMS_SCHEDULER.ENABLE(v_del_job_name);
it.pag_cie.PR_AT_INS_LOG(...'JOB lanzado='...);  -- ✅ Log

EXCEPTION
   WHEN OTHERS THEN
      it.pag_cie.PR_AT_INS_LOG(...'Error job'...);  -- ✅ Log error
```

✅ No bloquea cierre, auto-cleanup, logging completo

**Beneficios:**
- Cierre retorna rápido (modo C)
- Limpieza histórica en background
- Full traceability de fallas

**Tags:** `[ASYNC-PATTERN]` `[ERROR-HANDLING]`

---

### 🟢 GOOD-003: Schema-Qualified + Logging Consistente

✅ Todas referencias schema-qualified (IT.*)  
✅ Logging en puntos críticos  
✅ Traceabilidad operacional completa

**Verificaciones:**
- Refs a DBMS_SCHEDULER: OK
- Refs a tablas: IT.GE_CON_TRA_PROCESOS, IT.GE_PAR_DINAMICOS
- Logging calls: it.pag_cie.PR_AT_INS_LOG

**Tags:** `[SCHEMA-QUALIFICATION]` `[AUDIT-LOGGING]`

---

## 6. Impacto Cruzado

| Tabla (WRITE) | Programas | Ciclo | OBLIGATORIO | Riesgo |
|---|---|---|---|---|
| GE_CON_TRANSACCIONES | PRA_GEN_ASI_AUTOMATICOS | 11 | S | 🔴 ALTO |
| GE_MOVIMIENTOS | PRG_TRA_HISTORICO | 11 | N | 🟡 MEDIO |
| GE_CON_TRA_PROCESOS | PRB_CON_TRA_HIS | 10 | N | 🟡 MEDIO |

**Análisis de cascada:**
- CRITICAL-001 (breaking delete) puede generar filas huérfanas en GE_CON_TRANSACCIONES
- Delete async job puede fallar silenciosamente → Crecimiento indefinido de tabla histórica
- GE_MOVIMIENTOS reconciliation se vuelve inconsistente

---

## 7. Checklist de Cumplimiento Cierre Bancario

| Criterio | Estado | Notas |
|----------|--------|-------|
| ✅ Idempotencia (re-ejecución) | ❌ **FALLA** | Comportamiento distinto por p_lugar |
| ✅ Atomicidad transaccional | ❌ **FALLA** | Delete sin batching puede dejar locks |
| ✅ Schema qualification | ✅ **PASS** | Todas refs IT.* |
| ✅ Logging/Auditoria | ✅ **PASS** | Calls a it.pag_cie.PR_AT_INS_LOG |
| ✅ Error handling | ✅ **PASS** | EXCEPTION con log + re-raise |
| ✅ Parametrización | 🟡 **PARCIAL** | BULK OK, delete batch NO |
| ✅ Nomenclatura PL/SQL | ✅ **PASS** | Vars con prefijo v_, constantes cg_ |
| ✅ Documentación bloques | ✅ **PASS** | Comentarios en inicio de procedures |

**Resumen:**
- 4/8 PASS ✅
- 2/8 FALLA ❌ → **BLOQUEA MERGE**
- 2/8 PARCIAL 🟡 → Requiere ajustes menores

---

## 8. Supuestos & Caveats

1. **Contexto Jira:** No disponible → usamos PR body como criterios principales
2. **Volumetría GE_CON_TRA_PROCESOS:** Cardinality desconocida → asumimos riesgo REAL si >1M filas/ciclo
3. **Parámetro p_lugar:** Asumimos inmutable en una sesión; si varía entre calls = idempotencia rota
4. **DBMS_SCHEDULER:** Asumimos disponible en instancia Oracle destino (EE)
5. **Job frequency:** PR no especifica; asumimos daily housekeeping

---

## 9. Conclusión

PR#81 implementa mejoras válidas (**parametrización bulk**, **deferimiento async job**) pero **introduce breaking change CRÍTICO en patrón delete** que:

- ❌ Viola diseño explícitamente documentado en BKP (menciona "incidente de bloqueo prolongado")
- ❌ Viola regla de idempotencia del cierre bancario
- ❌ Introduce inconsistencia operacional (comportamiento distinto modo C vs non-C)
- ❌ Riesgo de lock prolongado en tabla #2 de volumetría

**Este cambio DEBE ser CORREGIDO antes de merge** para garantizar estabilidad de PRA_CON_TRANSACCION (OBLIGATORIO=S, Top-10 volumetría).

### Acciones Requeridas Antes de Merge

1. **CRÍTICA:** Restaurar loop-based delete con batching ROWNUM para modo non-C
2. **CRÍTICA:** Armonizar lógica delete entre modo C (async) y non-C (sync) para garantizar idempotencia
3. **IMPORTANTE:** Hacer scripts SQL idempotentes (INSERT ... WHERE NOT EXISTS)
4. **RECOMENDADA:** Parametrizar batch size de delete (consistencia)
5. **RECOMENDADA:** Consolidar vars diagnóstico

### Re-submit Expectation
- Correcciones críticas → Re-review
- Si cambios son menores → Expedited approval

---

## 10. Artefactos Generados

**Fecha Revisión:** 2026-08-26 14:32 UTC  
**Revisor:** GitHub Copilot (Modo: CB PL/SQL Reviewer - Cierre Bancario)  
**Versión Reporte:** 1.0  
**Output File:** `.github/reports/pr-81-cb-review.md` (este documento)

---

**Semáforo Final:** 🔴 **CRÍTICO - REQUIERE CORRECCIONES ANTES DE MERGE**

Para consultas o clarificaciones sobre esta revisión, contactar a GitHub Copilot usando el mismo parámetro de invocación:
```
@CB PL/SQL Reviewer PR#81 | .github/reports/pr-81-cb-review.md
```
