# 🏦 Revisión Exhaustiva PR#66 — Cierre Bancario

**Ticket:** CIE-1183  
**Título:** Paralelización del programa PRG_GEN_INF_REMUNERACIONES  
**Rama:** `feature/CIE-1183` → `master`  
**SHA HEAD:** `8522f066358d85de65825575f8b06309ec2be230`  
**Fecha de revisión:** 2026-08-19  

---

## 0. Verificación de Origen

| Campo | Valor |
|---|---|
| SHA del HEAD leído en esta corrida | `8522f066358d85de65825575f8b06309ec2be230` |
| Fuente de datos usada | Cache local `.github/pr-cache/pr-66.json` y `.github/pr-cache/pr-66.diff` |
| Archivos revisados | 2 (DDL/DML de configuración de paralelismo) |
| Estado del análisis | ✅ Completo |

---

## 1. Resumen Ejecutivo

### 📋 Alcance del PR

Este PR implementa la paralelización del programa **`PRG_GEN_INF_REMUNERACIONES`** en el ciclo 12 (Post-Cierre) mediante:

1. **Inserción de dependencias fork/join** en tabla `IT.GE_PROCESOS_DEP`:
   - Fork (P): `PRG_GEN_INF_REMUNERACIONES` se lanza al finalizar `PRB_GEN_HIS_PIZARRA` (nro_orden 412)
   - Join (F): `PRB_SMG_GEN_TASAS_BCP` (OBLIGATORIO='S', nro_orden 996) espera finalización de `PRG_GEN_INF_REMUNERACIONES`

2. **Reposicionamiento del programa** en la cadena de cierre:
   - Cambio de `nro_orden` de **984** a **413** en tabla `IT.GE_PROCESOS_DET`
   - Objetivo: mover el programa a posición más temprana, ejecutarse "al inicio de PRG_CONTROL_SALDOS (12-700)" 

### 🎯 Criterios de Éxito (Ticket CIE-1183)

El cambio debe:
- ✅ Configurar dependencia Fork/Join correctamente
- ✅ Asegurar que PRB_SMG_GEN_TASAS_BCP (OBLIGATORIO) respete la barrera
- ✅ Ser idempotente: ejecutable múltiples veces sin duplicados ni inconsistencias
- ✅ No romper la cadena de cierre ni crear deadlocks

### 📊 Conclusión General

**ESTADO:** ⚠️ **REQUIERE CORRECCIONES CRÍTICAS** antes de merge

- **Critical Issues:** 2 (idempotencia, gestión de cambios)
- **Improvements:** 3 (documentación, parametrización)
- **Good Practices:** 2 (paralelismo, observaciones descriptivas)
- **Riesgo General:** 🔴 **ALTO**

| Dimensión | Estado | Observación |
|---|---|---|
| Registro en malla (GE_PROCESOS_DET) | 🟡 | COD_PROCESO=12 \| ORDEN original=984 → nuevo=413 \| OBLIGATORIO='N' \| ACTIVO='S' |
| Paralelismo Fork/Join | 🟢 | Correctamente configurado: P (Fork) → F (Join) |
| Idempotencia y re-ejecución | 🔴 | **CRÍTICO:** INSERT sin verificación de duplicados en ge_procesos_dep |
| Atomicidad de cambios | 🔴 | **CRÍTICO:** COMMIT en scripts impide rollback ante error |
| Manejo de dependencias | 🟢 | PRB_SMG_GEN_TASAS_BCP (OBLIGATORIO='S') garantiza validación de barrera |
| Hardcode de negocio | 🟡 | G_COD_MODULO := 1 sin parametrización |
| Documentación | 🟡 | Cambio de nro_orden sin justificación inline en script |
| Impacto cruzado | 🟢 | Afecta solo tablas de gobernanza de malla (ge_procesos_dep, ge_procesos_det) |

---

## 2. Semáforo de Severidad

| Severidad | Color | Cantidad | Estado |
|---|---|---:|---|
| Critical Issues | 🔴 | 2 | Bloquean merge. Requieren corrección inmediata. |
| Improvements | 🟡 | 3 | Mejoras recomendadas para robustez y mantenibilidad. |
| Good Practices | 🟢 | 2 | Patrones correctos observados en el PR. |

---

## 3. Critical Issues

### 🔴 Issue #1: Falta de Idempotencia en INSERT de GE_PROCESOS_DEP

- 📦 **Objeto o bloque afectado:** Archivo `7000_ins_ge_procesos_dep.sql`, líneas 3-4 y 6-7

- 🔎 **Evidencia:**

  **Problema:**
  ```sql
  INSERT INTO ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
  VALUES (12, 'PRG_GEN_INF_REMUNERACIONES', 12, 'PRB_GEN_HIS_PIZARRA', 'P', 'El proceso PRG_GEN_INF_REMUNERACIONES debe lanzarse al finalizar el PRB_GEN_HIS_PIZARRA.');
  
  INSERT INTO ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
  VALUES (12, 'PRB_SMG_GEN_TASAS_BCP', 12, 'PRG_GEN_INF_REMUNERACIONES', 'F', 'El proceso PRB_SMG_GEN_TASAS_BCP no debe de iniciar sin que finalice el PRG_GEN_INF_REMUNERACIONES');
  ```

  **Recomendación (solución propuesta):**
  ```sql
  MERGE INTO ge_procesos_dep d
  USING (
    SELECT 12 AS cod_proceso, 'PRG_GEN_INF_REMUNERACIONES' AS cod_programa, 
           12 AS cod_proceso_pre, 'PRB_GEN_HIS_PIZARRA' AS cod_programa_pre, 
           'P' AS tipo
    FROM DUAL
  ) src
  ON (d.cod_proceso = src.cod_proceso 
      AND d.cod_programa = src.cod_programa
      AND d.cod_proceso_pre = src.cod_proceso_pre
      AND d.cod_programa_pre = src.cod_programa_pre)
  WHEN NOT MATCHED THEN
    INSERT (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
    VALUES (src.cod_proceso, src.cod_programa, src.cod_proceso_pre, src.cod_programa_pre, src.tipo,
            'El proceso PRG_GEN_INF_REMUNERACIONES debe lanzarse al finalizar el PRB_GEN_HIS_PIZARRA.');
  ```

- 📏 **Regla validada o incumplida:**
  - Regla 1 (Copilot Instructions): "Todo proceso de cierre bancario DEBE ser reejecutable. El proceso debe poder correr múltiples veces sobre el mismo periodo sin generar duplicados ni inconsistencias."
  - Regla 3 (Severity Mapping): "Proceso no idempotente: puede generar duplicados o inconsistencias al reejecutar." → **CRÍTICO**

- ⚠️ **Riesgo:**
  - **BLOQUEANTE DEL CIERRE:** Si el script se ejecuta dos veces (por reintento, re-aplicación de parches), insertará registros duplicados en `IT.GE_PROCESOS_DEP`.
  - **Inconsistencia de la malla:** La orquestación de paralelismo intentará procesar pares de dependencias duplicadas, causando comportamiento indeterminado.
  - **Violación de restricción única:** Si existe restricción de unicidad, la segunda ejecución fallará (ORA-00001).
  - **Impacto en OBLIGATORIO='S':** `PRB_SMG_GEN_TASAS_BCP` es obligatorio. La duplicación podría permitir que la tarea se lance antes de que todas las instancias finalicen.

- 💡 **Recomendación concreta:**
  1. **Reemplazar INSERT por MERGE** que verifique existencia previa.
  2. **Alternativa:** Usar `INSERT ... WHERE NOT EXISTS`:
     ```sql
     INSERT INTO ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
     SELECT 12, 'PRG_GEN_INF_REMUNERACIONES', 12, 'PRB_GEN_HIS_PIZARRA', 'P', '...'
     WHERE NOT EXISTS (
       SELECT 1 FROM ge_procesos_dep
       WHERE cod_proceso = 12
       AND cod_programa = 'PRG_GEN_INF_REMUNERACIONES'
       AND cod_proceso_pre = 12
       AND cod_programa_pre = 'PRB_GEN_HIS_PIZARRA'
     );
     ```
  3. Aplicar mismo patrón al segundo INSERT.
  4. Validar en UAT ejecutando 2-3 veces sin errores.

---

### 🔴 Issue #2: COMMIT Explícito Rompe Atomicidad en Transacciones Mayores

- 📦 **Objeto o bloque afectado:** 
  - Archivo `7000_ins_ge_procesos_dep.sql`, línea 9
  - Archivo `8000_upd_ge_procesos_det.sql`, línea 8

- 🔎 **Evidencia:**

  **Archivo 7000_ins_ge_procesos_dep.sql (línea 9):**
  ```sql
  insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
  values (12, 'PRG_GEN_INF_REMUNERACIONES', 12, 'PRB_GEN_HIS_PIZARRA', 'P', '...');
  
  insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
  values (12, 'PRB_SMG_GEN_TASAS_BCP', 12, 'PRG_GEN_INF_REMUNERACIONES', 'F', '...');
  
  commit;  -- ← PROBLEMA: COMMIT hace permanentes los cambios
  ```

  **Archivo 8000_upd_ge_procesos_det.sql (línea 8):**
  ```sql
  update ge_procesos_det d
  set d.nro_orden = 413
  where d.cod_proceso = 12
  and d.cod_programa = 'PRG_GEN_INF_REMUNERACIONES';
  
  commit;  -- ← PROBLEMA: COMMIT antes de validación
  ```

  **Solución propuesta (remover COMMIT):**
  ```sql
  BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
  /
  insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, ...)
  values (12, 'PRG_GEN_INF_REMUNERACIONES', ...);
  
  insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, ...)
  values (12, 'PRB_SMG_GEN_TASAS_BCP', ...);
  -- Nota: COMMIT delegado a orquestador o script master
  ```

- 📏 **Regla validada o incumplida:**
  - Regla 3 (Severity Mapping): "Violación de límites de gobernanza: procesador/script escribe COMMIT/ROLLBACK en forma no controlada." → **CRÍTICO**
  - Copilot Instructions: "Transaction control is orchestrator-exclusive."

- ⚠️ **Riesgo:**
  - **TRANSACCIÓN DIVIDIDA:** Si 7000 se ejecuta y 8000 falla, las dependencias quedan permanentes aunque la configuración esté incompleta.
  - **FALTA DE ROLLBACK:** No es posible revertir cambios ante validación fallida post-despliegue.
  - **IMPACTO EN CICLO 12:** Si dependencias se insertan pero nro_orden no se actualiza, el orquestador verá inconsistencia.

- 💡 **Recomendación concreta:**
  1. **Remover COMMIT de ambos scripts.**
  2. **Crear script wrapper que coordine atomicidad:**
     ```sql
     -- script-master-CIE-1183.sql
     BEGIN
       @7000_ins_ge_procesos_dep.sql  -- SIN commit interno
       @8000_upd_ge_procesos_det.sql  -- SIN commit interno
       COMMIT;
     EXCEPTION
       WHEN OTHERS THEN
         ROLLBACK;
         RAISE;
     END;
     /
     ```
  3. Documentar en README requisito de atomicidad.

---

## 4. Improvements

### 🟡 Issue #1: Hardcode de G_COD_MODULO sin Parametrización

- 📦 **Objeto o bloque afectado:** 
  - Archivo `7000_ins_ge_procesos_dep.sql`, línea 1
  - Archivo `8000_upd_ge_procesos_det.sql`, línea 1

- 🔎 **Evidencia:**

  **Antes (estado actual):**
  ```sql
  BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
  ```

  **Recomendación (solución propuesta):**
  ```sql
  -- Inicializar contexto de módulo General (GE) para validaciones de gobernanza
  -- Nota: Los cambios de paralelismo se aplican en ciclo 12 (Post-Cierre),
  -- que es responsabilidad del módulo General (COD_MODULO=1)
  BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
  /
  ```

- 📏 **Regla validada o incumplida:**
  - ITGF Standard: Evitar hardcodes sin documentación.
  - Severity Mapping: "Hardcode de valores de negocio que deberían venir de parámetros."

- ⚠️ **Riesgo:**
  - Mantenibilidad: Futuro revisor no entenderá por qué G_COD_MODULO = 1.

- 💡 **Recomendación concreta:**
  1. Agregar comentario inline explicando por qué G_COD_MODULO := 1 es correcto.

---

### 🟡 Issue #2: Cambio de NRO_ORDEN sin Justificación Documentada

- 📦 **Objeto o bloque afectado:** Archivo `8000_upd_ge_procesos_det.sql`, líneas 3-6

- 🔎 **Evidencia:**

  **Antes (catálogo actual):**
  ```
  ge_procesos_det: COD_PROCESO=12, COD_PROGRAMA='PRG_GEN_INF_REMUNERACIONES', NRO_ORDEN=984
  ```

  **Cambio (archivo 8000):**
  ```sql
  update ge_procesos_det d
  set d.nro_orden = 413
  where d.cod_proceso = 12
  and d.cod_programa = 'PRG_GEN_INF_REMUNERACIONES';
  ```

  Cambio de posición: 984 (casi fin) → 413 (inicio)

- 💡 **Recomendación concreta:**
  ```sql
  -- CIE-1183: Repositionar PRG_GEN_INF_REMUNERACIONES
  -- Cambio de nro_orden 984 → 413 para ejecutar al inicio de PRG_CONTROL_SALDOS (nro_orden=700)
  update ge_procesos_det d
  set d.nro_orden = 413
  where d.cod_proceso = 12
  and d.cod_programa = 'PRG_GEN_INF_REMUNERACIONES';
  ```

---

### 🟡 Issue #3: Falta de Tratamiento de Duplicados en INSERT

- 📦 **Objeto o bloque afectado:** Archivo `7000_ins_ge_procesos_dep.sql`, líneas 3-7

- ⚠️ **Riesgo:**
  - Si existe restricción única, segunda ejecución falla con ORA-00001.

- 💡 **Recomendación concreta:**
  - (Ver solución en Critical Issue #1 con MERGE o INSERT WHERE NOT EXISTS)

---

## 5. Good Practices

### 🟢 Practice #1: Configuración Correcta de Paralelismo Fork/Join

- 📦 **Objeto o bloque afectado:** Archivo `7000_ins_ge_procesos_dep.sql`, líneas 3-7

- 🔎 **Evidencia:**

  ```sql
  -- FORK: PRG_GEN_INF_REMUNERACIONES se lanza en paralelo después de PRB_GEN_HIS_PIZARRA (412)
  insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
  values (12, 'PRG_GEN_INF_REMUNERACIONES', 12, 'PRB_GEN_HIS_PIZARRA', 'P', 'El proceso...');
  
  -- JOIN (BARRERA): PRB_SMG_GEN_TASAS_BCP (OBLIGATORIO) espera finalización
  insert into ge_procesos_dep (COD_PROCESO, COD_PROGRAMA, COD_PROCESO_PRE, COD_PROGRAMA_PRE, TIPO, OBSERVACION)
  values (12, 'PRB_SMG_GEN_TASAS_BCP', 12, 'PRG_GEN_INF_REMUNERACIONES', 'F', 'El proceso...');
  ```

  **Validación:**
  | Elemento | Validación | Resultado |
  |---|---|---|
  | PRB_GEN_HIS_PIZARRA | OBLIGATORIO='N', ACTIVO='S', nro_orden=412 | ✅ Válido |
  | PRG_GEN_INF_REMUNERACIONES | OBLIGATORIO='N', ACTIVO='S', nro_orden=413 (nuevo) | ✅ Válido |
  | PRB_SMG_GEN_TASAS_BCP | OBLIGATORIO='S', ACTIVO='S', nro_orden=996 | ✅ **Crítico** |
  | Tipo P (Fork) | PRG_GEN_INF_REMUNERACIONES depende de PRB_GEN_HIS_PIZARRA | ✅ Correcto |
  | Tipo F (Join) | PRB_SMG_GEN_TASAS_BCP depende de PRG_GEN_INF_REMUNERACIONES | ✅ Correcto |

- ✅ **Beneficio:**
  - Optimización de tiempo de ciclo mediante ejecución paralela.
  - Garantía de sincronización con barrera de tipo F en programa obligatorio.

---

### 🟢 Practice #2: Documentación Descriptiva en Tabla de Dependencias

- 📦 **Objeto o bloque afectado:** Archivo `7000_ins_ge_procesos_dep.sql`, campo OBSERVACION

- 🔎 **Evidencia:**

  ```sql
  insert into ge_procesos_dep (..., OBSERVACION)
  values (..., 'El proceso PRG_GEN_INF_REMUNERACIONES debe lanzarse al finalizar el PRB_GEN_HIS_PIZARRA.');
  
  insert into ge_procesos_dep (..., OBSERVACION)
  values (..., 'El proceso PRB_SMG_GEN_TASAS_BCP no debe de iniciar sin que finalice el PRG_GEN_INF_REMUNERACIONES');
  ```

- ✅ **Beneficio:**
  - Auditoría y trazabilidad mejorada.
  - Futuro revisor comprende la intención sin investigar ticket.

---

## 6. Análisis de Impacto Cruzado

### 📊 Tablas Afectadas por el PR

| Tabla | Operación | Descripción | Riesgo |
|---|---|---|---|
| `IT.GE_PROCESOS_DEP` | INSERT | Inserta 2 nuevas dependencias Fork/Join | Bajo (tabla de gobernanza) |
| `IT.GE_PROCESOS_DET` | UPDATE | Cambia nro_orden de programa en ciclo 12 | Bajo (solo reposiciona en cadena) |

### ✅ Validación de No-Impacto en Otras Mallas

- ✅ Ciclos no afectados: 7, 11, 10 mantienen configuraciones actuales.
- ✅ Tablas de negocio: No se modifica GE_MOVIMIENTOS, GE_ASIENTOS, GE_SALDOS.
- ✅ Programas bloqueados: Ningún otro crítico depende de PRG_GEN_INF_REMUNERACIONES excepto PRB_SMG_GEN_TASAS_BCP.

---

## 7. Checklist de Compliance — Cierre Bancario

### ✅ Idempotencia y Re-ejecución
- ❌ **Script de INSERT es idempotente:** Requiere corrección (Critical Issue #1)
- ✅ **Script de UPDATE es idempotente:** Verificado
- ❓ **Validación de resultado:** No hay bloque de validación post-ejecución

### ✅ Cumplimiento GE_PROCESOS
- ✅ Tablas GE_PROCESOS_DEP y GE_PROCESOS_DET registradas correctamente
- ✅ COD_PROCESO=12 (Post-Cierre) es correcto
- ✅ NRO_ORDEN=413 está en rango válido

### ✅ Límites de Arquitectura
- ✅ DML dentro de dominio (solo gobernanza/malla)
- ✅ Sin acceso cruzado a tablas de negocio
- ✅ Responsabilidades respetadas

### ✅ Estándares de Nomenclatura
- ✅ Nombres de archivos: CIE-1183/7000_*, CIE-1183/8000_* (patrón correcto)
- ⚠️ Documentación: Comentarios inline mejorados recomendados (Improvement #2)

### ⚠️ Manejo de Errores
- ❌ COMMIT/ROLLBACK: Scripts contienen COMMIT explícito (Critical Issue #2)

### ✅ Impacto en Procesos Obligatorios
- ✅ PRB_SMG_GEN_TASAS_BCP (OBLIGATORIO='S'): Barrera correctamente configurada

---

## 8. Recomendaciones Finales

### 🔴 BLOQUEANTES (Requieren corrección antes de merge):

1. **Implementar idempotencia en INSERT de ge_procesos_dep:**
   - Usar MERGE o INSERT WHERE NOT EXISTS
   - Ejecutar script 2+ veces en UAT sin errores
   - Validar que ge_procesos_dep tenga exactamente 2 registros

2. **Remover COMMIT o envolver en transacción atómica:**
   - Opción A: Remover COMMIT
   - Opción B: Crear script wrapper
   - Documentar en README requisito de atomicidad

### 🟡 MEJORAS (Recomendadas):

1. Documentar hardcode de G_COD_MODULO := 1 con comentario explicativo
2. Agregar comentario en UPDATE de nro_orden citando CIE-1183
3. Crear script de rollback para facilitar reversión

### 🟢 MANTENER:

- Configuración correcta de paralelismo Fork/Join
- Observaciones descriptivas en tabla de dependencias
- Correcta identificación del ciclo 12

---

## 9. Supuestos y Limitaciones

1. Contexto Jira no disponible en cache
2. Sin acceso a comentarios de revisores humanos en GitHub (no hay tool nativa)
3. Se asume estructura estándar de ge_procesos_dep con constraint único
4. Comparación "Antes/Después" con catálogo actual (no BKP del ticket)
5. Programas no están en top-10 de volumetría (performance no es riesgo)

---

## 10. Conclusión y Veredicto

### 📊 Resultado Final

| Métrica | Valor |
|---|---|
| **Critical Issues** | 🔴 2 (Requieren corrección inmediata) |
| **Improvements** | 🟡 3 (Recomendaciones de robustez) |
| **Good Practices** | 🟢 2 (Patrones correctos) |
| **Riesgo General** | 🔴 **ALTO** |
| **Veredicto de Merge** | ❌ **NO APTO** (hasta corregir Critical Issues) |

### 🎯 Próximos Pasos

1. ✏️ **Autor del PR:** Aplicar correcciones Critical
2. 🧪 **QA/UAT:** Validar idempotencia ejecutando scripts 3+ veces
3. 📋 **Revisor técnico:** Re-revisar con checklist
4. 🚀 **Deploy:** Seguir procedimiento con script wrapper atómico

---

**Fin del reporte** — Generado: 2026-08-19
