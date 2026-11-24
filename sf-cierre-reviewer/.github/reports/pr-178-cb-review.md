# Revisión Exhaustiva PR#178 — Cierre Bancario

**Ticket:** CIE-1258  
**Título:** Tarea Técnica de optimización PRP_GEN_CTA_GARANTIAS Fase 1  
**Rama:** `feature/CIE-1258` → `master`  
**SHA HEAD:** `e0e53e8150aa43bf017317247c9a5d30e83fa1c3`  
**Fecha de revisión:** 2026-10-30  

---

## 0. Verificación de Origen

| Campo | Valor |
|---|---|
| **Commit / SHA Evaluado** | `e0e53e8150aa43bf017317247c9a5d30e83fa1c3` |
| **Ticket Jira** | `CIE-1258` |
| **Ubicación en Cadena** | Ciclo `COD_PROCESO=11` (Cierre de Día) \| `NRO_ORDEN=330` \| `OBLIGATORIO=S` \| `ACTIVO=S` |
| Fuente de datos | Cache `.github/pr-cache/pr-178.json`, `pr-178-objetos.patch`, `pr-178-objetos.prc`, `pr-178-bkp.prc`, `pr-178-base.prc`, `pr-178-jira.json` |
| Archivos revisados | 2 — BKP nuevo + `Objetos_BD/.../prp_gen_cta_garantia.prc` (modificado) |
| Comparación BKP vs Objetos_BD | BKP/`base` idénticos (155.567 bytes); HEAD aporta +99/−29 sobre el productivo |
| Estado del análisis | Completo |

---

## 1. Resumen Ejecutivo

- **Estado:** APTO CON OBSERVACIONES
- **Alineación con Jira:** Alineado

Fase 1 de optimización de `IT.PRP_GEN_CTA_GARANTIA`: push-down de predicados en `lf_obt_mto_gar_utilizado` / `lf_obt_mto_gar_aplicado`, `EXIT WHEN` anticipado en el bucle de Paso 18, e inline de los `UPDATE` del Paso 23 (reemplazo de `lp_act_gar_nocomputable`). No hay Critical Issues introducidos por el diff. Persisten riesgos heredados (excepción silenciada en funciones de monto) y el Paso 23 sigue siendo DML fila a fila.

| Métrica | Valor |
|---|---:|
| Critical Issues | 0 |
| Improvements | 3 |
| Good Practices | 3 |
| Riesgo general | Bajo–Medio |

| Dimensión | Estado | Observación |
|---|---|---|
| Registro en malla (`GE_PROCESOS_DET`) | 🟢 | Ciclo 11 \| orden 330 \| `OBLIGATORIO=S` \| `ACTIVO=S` |
| Paralelismo Fork/Join (`GE_PROCESOS_DEP`) | 🟢 | Programa no figura en matriz P/F local |
| Idempotencia / reejecución | 🟢 | Sin cambios de patrón de persistencia ni `COMMIT` por lote nuevos |
| Performance / Exadata | 🟢 | Push-down elimina full-scan N+1 de las 5 tablas en cada llamada |
| Concurrencia 24/7 | 🟢 | Sin `LOCK TABLE` / `FOR UPDATE` nuevos |
| Error handling | 🟡 | `WHEN OTHERS THEN RETURN 0` preexistente en funciones de monto |
| Scope creep | 🟢 | Solo BKP del ticket + procedimiento objetivo |

---

## 2. Trazabilidad Jira (Validación 1 a 1)

| Campo | Valor |
|---|---|
| Ticket | `CIE-1258` |
| Summary | Tarea Técnica de optimización PRP_GEN_CTA_GARANTIAS Fase 1 |
| Status | Finalizado |
| Ticket vs Cambio | Alineado — sin scope creep |

| # | Criterio de Aceptación (Jira) | Estado | Evidencia en Código (`Objetos_BD/`) |
|---|----------------------------------|--------|------------------------------------|
| CA-01 / Req 1 | Refactor de `lf_obt_mto_gar_utilizado` y `lf_obt_mto_gar_aplicado` con filtro push-down por `p_nro_garantia` / `p_nro_cuenta` dentro de cada rama del `UNION ALL` | Cumple | Cada rama de `pr_/cc_/ta_/ov_/cx_cta_garantias` filtra en origen; se elimina el `WHERE` externo post-`UNION` |
| CA-02 / Req 2 | En Paso 18 (`FOR c_garantias`), `EXIT WHEN v_tot_utilizado <= 0 AND v_tot_aplicado <= 0`; mantener consumo de saldos en RAM | Cumple | `EXIT WHEN` añadido al inicio del bucle interno; se conservan decrementos de `v_tot_utilizado` / `v_tot_aplicado` |
| CA-03 / Req 3 | Paso 23: reemplazar `lp_act_gar_nocomputable` por `UPDATE` directos según `cod_modulo` | Cumple | Bloque `IF/ELSIF` inline idéntico en semántica (módulos 4/5/6/15/8); la subrutina queda sin call sites |
| CA-04 | Paridad funcional vía `MINUS` sobre las 5 tablas `*_cta_garantias` (0 filas) | No Verificable | Criterio de prueba de ejecución; no demostrable solo con el diff |
| CA-05 | Reducción significativa de duración en pasos 11, 12, 18 y 23 (`ge_pro_programas_log`) | No Verificable | Requiere corrida comparativa en ambiente; el código habilita la mejora en 11/12/18 vía funciones y en 23 vía menos context switch |

**Desvío de alcance:** No. Archivos = BKP `CIE-1258` + procedimiento productivo del ticket.

---

## 3. Semáforo de Severidad

| Severidad | Color | Cantidad | Estado |
|---|---|---|---|
| Critical Issues | 🔴 Rojo | 0 | Sin bloqueo |
| Improvements | 🟡 Amarillo | 3 | Recomendación |
| Good Practices | 🟢 Verde | 3 | Destacado |

---

## 4. Detalle de Hallazgos Críticos (Critical Issues)

Sin hallazgos.

No se introducen `COMMIT` parciales con watermarks fuera de lote, `LOCK TABLE` / `FOR UPDATE` sobre tablas compartidas, ni silenciamiento nuevo de excepciones en el código modificado. El procedimiento sigue siendo `OBLIGATORIO=S`, pero los `WHEN OTHERS THEN RETURN 0` de las funciones de monto ya existían en BKP y se clasifican como Improvement (heredado).

---

## 5. Mejoras Recomendadas (Improvements)

### 🟡 Item 1 — `WHEN OTHERS THEN RETURN 0` en funciones de monto [PREEXISTENTE BKP = Objetos_BD]

- **Objeto:** `lf_obt_mto_gar_utilizado`, `lf_obt_mto_gar_aplicado`
- **Evidencia (igual en BKP y HEAD):**
  ```plsql
  EXCEPTION
      WHEN NO_DATA_FOUND THEN
          RETURN 0;
      WHEN OTHERS THEN
          RETURN 0;
  ```
- **Riesgo:** En programa `OBLIGATORIO=S`, un error de conversión/join se interpreta como monto 0 y puede distorsionar cobertura de garantías sin traza.
- **Recomendación:** Propagar con `RAISE` (o log + `RAISE`) salvo fallback explícitamente aprobado; al menos registrar `SQLERRM` vía mecanismo de log del cierre.

### 🟡 Item 2 — Paso 23 sigue en DML slow-by-slow pese al inline

- **Objeto:** bucle `FOR i IN 1 .. v_clientes.COUNT` sobre `c_aju_tot_garantia`
- **Evidencia:** 5 ramas `UPDATE ... SET mto_aplicado = mto_aplicado + v_monto` fila a fila (semántica = antiguo `lp_act_gar_nocomputable`).
- **Riesgo:** Se elimina context switch de subprograma, pero el costo dominante de muchos `UPDATE` unitarios permanece (Paso 23 ~4:50 en el ticket).
- **Recomendación (Fase 2):** acumular deltas en colección y `FORALL` / `MERGE` por tabla destino, respetando el prorrateo del último elemento.

### 🟡 Item 3 — `lp_act_gar_nocomputable` queda como código muerto

- **Objeto:** declaración local `PROCEDURE lp_act_gar_nocomputable` (sin call sites en HEAD; BKP tenía 1 llamada en Paso 23).
- **Riesgo:** duplicación de lógica (inline vs subprograma) y mantenimiento divergente futuro.
- **Recomendación:** eliminar el subprograma en el mismo PR o en un follow-up inmediato, o reutilizarlo si se prefiere una sola fuente de verdad.

---

## 6. Buenas Prácticas Observadas (Good Practices)

### 🟢 GP-1 — Predicate push-down en `UNION ALL`
Filtro por garantía/cuenta dentro de cada rama (`pr/cc/ta/ov/cx`), alineado al Req 1 y a buenas prácticas Exadata (evitar materializar uniones completas antes del predicado).

### 🟢 GP-2 — Early-exit sin alterar prioridad de garantías
`EXIT WHEN` solo cuando ambos saldos residuales están cubiertos; no reordena el cursor `c_garantias`.

### 🟢 GP-3 — BKP versionado del ticket
Se agrega `BKP/CIE-1258/prp_gen_cta_garantia.prc` idéntico a `master` base, permitiendo comparación estricta BKP vs `Objetos_BD`.

---

## 7. Análisis de Impacto Cruzado y Dependencias (`GE_PROCESOS_DEP`)

| Tabla / Programa Modificado | Dependencia (P / F) | Programa Relacionado | Nivel de Riesgo |
|-----------------------------|---------------------|----------------------|-----------------|
| `PRP_GEN_CTA_GARANTIA` (ciclo 11 / orden 330) | No listado en `ge_procesos_dep.csv` | Cadena secuencial del cierre de día | Bajo — sin cambio de malla P/F |
| `pr_cta_garantias` / `cc_cta_garantias` / `ta_cta_garantias` / `ov_cta_garantias` / `cx_cta_garantias` | N/A (lectura+update de negocio) | Consumidores de cobertura/previsión posteriores al paso 330 | Medio — paridad debe validarse con `MINUS` (CA-04) |
| `ge_cuentas` (JOIN en funciones de monto) | N/A | — | Bajo — solo lectura |
| `pv_cta_gar_nocomputables` (Paso 23) | N/A | Alimenta prorrateo no computable | Bajo — sin cambio de consulta |

**Nota de paralelismo:** al no ser nodo Tipo P ni barrera Tipo F en el catálogo local, no aplica exigir aislamiento fork/join adicional. El carácter `OBLIGATORIO=S` sí eleva la severidad de cualquier regresión de montos: la prueba de paridad del ticket es mandatoria antes de merge a productivo.
)
