# CB PL/SQL Review — PR #47 · CIE-1180

> **Generado:** 2026-08-12 | **Revisor:** CB PL/SQL Reviewer Agent
> **PR:** [#47 — CIE-1180: Actualización en el programa prt_gen_previsiones](https://github.com/ueno-tecnologia-org/ueno_core/pull/47)
> **Autor:** beatriz-davalos_gvz | **Rama:** `feature/CIE-1180` → `master` | **Estado:** Open

---

## 1. Resumen Ejecutivo

El PR modifica `PRT_GEN_PREVISIONES` (Ciclo 11, Orden 340, OBLIGATORIO=S) para incorporar procesamiento en lotes de 1.000, pre-carga masiva de garantías en RAM, soporte multi-usuario de secuencias y lógica de reenganche. Las mejoras de performance y observabilidad son técnicamente sólidas; sin embargo, se detectaron **dos Critical Issues** que deben resolverse antes del merge: un `COMMIT` incorporado dentro del loop de lotes (que rompe el control transaccional del orquestador y puede dejar el período en estado parcial) y un **use-before-set de `v_categoria`** en `LF_OBT_GAR_COM` que puede producir montos de previsión incorrectos para el primer registro de cada lote nuevo.

**Ticket vs Cambio:** Alineado — el ticket reporta una incidencia en el proceso (Prioridad Alta, en Code Review). Las mejoras de reenganche, multiusuario y lotes corresponden directamente a resolver la incidencia de ejecución del proceso 11 orden 340.

| Metrica | Valor |
|---|---:|
| Critical Issues | 2 |
| Improvements | 4 |
| Good Practices | 5 |
| Riesgo general | **Alto** |

| Dimension | Estado | Observacion |
|---|---|---|
| Registro en malla (GE_PROCESOS_DET) | 🟢 | COD_PROCESO=11 \| NRO_ORDEN=340 \| OBLIGATORIO=S \| ACTIVO=S |
| Alineacion funcional Jira | 🟢 | CIE-1180 (Prioridad Alta) — cambios de reenganche/multiusuario/lotes alineados a la incidencia reportada |
| Idempotencia / reejecucion | 🔴 | COMMIT dentro del loop de lotes + use-before-set de v_categoria |
| Impacto cruzado | 🟡 | ge_cla_operaciones compartida con todo el ciclo 11; ta_previsiones leída por múltiples procesos |
| Paralelismo Fork/Join | 🟢 | Sin evidencia de violacion de barrera en el catalogo; proceso secuencial en ciclo 11 |
| Naming & Style (ITGF) | 🟡 | Prefijos LP_/LF_ correctos; v_cot_auxiliar dead variable; parametros no usados en LF_OBT_GAR_COM |
| Error handling | 🟡 | RAISE_APPLICATION_ERROR directo aceptable en CB; EXCEPTION en bloque principal cierra cursor y hace ROLLBACK, pero el COMMIT por lote ya compromete transacciones previas |
| Performance / Volumetria | 🟢 | Proceso no está en top-10 de volumetria; la pre-carga en RAM y FORALL son optimizaciones correctas |
| Hardcode de negocio | 🟢 | Porcentajes de riesgo leídos de pr_parametros; cod_transaccion 730/731/7730/7731 son constantes operativas propias del dominio |
| Higiene de variables y parametros | 🔴 | P_COD_MONEDA/P_COD_MON_LOCAL no usados; v_cot_auxiliar asignado sin uso; v_categoria stale (Critical) |
| Cambios DDL/DML (.sql) | N/A | No se incluyen scripts .sql en el PR |

---

## 2. Semaforo de Severidad

| Severidad | Color | Cantidad | Estado |
|---|---|---:|---|
| Critical Issues | 🔴 | 2 | Requiere corrección antes del merge |
| Improvements | 🟡 | 4 | Mejorar antes del merge o en siguiente iteracion |
| Good Practices | 🟢 | 5 | Mantener |

---

## 3. Critical Issues

### 🔴 Item 1 — COMMIT dentro del loop de lotes: rompe control transaccional del orquestador

- **📦 Objeto afectado:** `IT.PRT_GEN_PREVISIONES` — bloque principal, loop `OPEN c_tarjetas / LOOP … END LOOP`
- **🔎 Evidencia:**

  **Antes (BASE — sin COMMIT explícito):**
  ```plsql
  FORALL i IN reg_ge_cla_operaciones_type.FIRST .. reg_ge_cla_operaciones_type.LAST
     UPDATE ge_cla_operaciones
        SET tot_prevision         = reg_ge_cla_operaciones_type(i).tot_prevision,
            tot_pri_prevision     = reg_ge_cla_operaciones_type(i).tot_pri_prevision,
            tot_cap_pri_prevision = reg_ge_cla_operaciones_type(i).tot_cap_pri_prevision,
            tot_cap_seg_prevision = reg_ge_cla_operaciones_type(i).tot_cap_seg_prevision
      WHERE nro_cuenta = reg_ge_cla_operaciones_type(i).nro_cuenta;
  END;  -- sin COMMIT; transaccion controlada por el orquestador
  ```

  **Después (HEAD — COMMIT dentro del loop):**
  ```plsql
      if reg_ge_cla_operaciones_type.COUNT > 0 then 
         FORALL i IN reg_ge_cla_operaciones_type.FIRST .. reg_ge_cla_operaciones_type.LAST
            UPDATE ge_cla_operaciones
               SET tot_prevision         = reg_ge_cla_operaciones_type(i).tot_prevision,
                   tot_pri_prevision     = reg_ge_cla_operaciones_type(i).tot_pri_prevision,
                   tot_cap_pri_prevision = reg_ge_cla_operaciones_type(i).tot_cap_pri_prevision,
                   tot_cap_seg_prevision = reg_ge_cla_operaciones_type(i).tot_cap_seg_prevision
             WHERE nro_cuenta = reg_ge_cla_operaciones_type(i).nro_cuenta;
      end if;
      COMMIT;  -- ← DENTRO DEL LOOP: confirma cada lote de 1.000 individualmente
   END LOOP;
  ```

  _Referencia: HEAD `prt_gen_previsiones.prc` líneas ~597-607_

- **📏 Regla incumplida:**
  - `severity-mapping.md` → Critical: _"`COMMIT/ROLLBACK` no autorizado dentro de un procesador individual"_
  - `cb-plsql-reviewer.agent.md` → _"No se permite `COMMIT/ROLLBACK` dentro de procesadores individuales"_
  - `copilot-instructions.md` → _"Commit, rollback, savepoint strategy... must be handled only by the orchestrator"_

- **⚠️ Riesgo:**
  Si el proceso falla en el lote N (de M totales), los lotes 1..N-1 ya están irrevocablemente confirmados en `ta_previsiones`, `ge_movimientos` y `ge_cla_operaciones`. El `ROLLBACK` del bloque `EXCEPTION` solo revierte el lote N parcial. El período queda en estado **parcialmente procesado**: algunas cuentas con previsión del día y otras sin ella — inconsistencia contable sin posibilidad de rollback total. El orquestador no puede ejecutar un ROLLBACK efectivo sobre el trabajo previo.

- **💡 Recomendación:**
  Eliminar el `COMMIT` del cuerpo del procesador. El mecanismo de reenganche (`NOT EXISTS` en el cursor) ya garantiza que, en una re-ejecución, se salten las cuentas ya procesadas. La confirmación definitiva debe quedar exclusivamente en el orquestador.

  ```plsql
  -- Corrección: eliminar COMMIT del loop
      if reg_ge_cla_operaciones_type.COUNT > 0 then
         FORALL i IN reg_ge_cla_operaciones_type.FIRST .. reg_ge_cla_operaciones_type.LAST
            UPDATE ge_cla_operaciones
               SET tot_prevision         = reg_ge_cla_operaciones_type(i).tot_prevision,
                   tot_pri_prevision     = reg_ge_cla_operaciones_type(i).tot_pri_prevision,
                   tot_cap_pri_prevision = reg_ge_cla_operaciones_type(i).tot_cap_pri_prevision,
                   tot_cap_seg_prevision = reg_ge_cla_operaciones_type(i).tot_cap_seg_prevision
             WHERE nro_cuenta = reg_ge_cla_operaciones_type(i).nro_cuenta;
      end if;
      -- Sin COMMIT: el orquestador controla la transaccion
   END LOOP;
  ```

---

### 🔴 Item 2 — use-before-set: `v_categoria` stale en `LF_OBT_GAR_COM` → monto de previsión incorrecto

- **📦 Objeto afectado:** `IT.PRT_GEN_PREVISIONES` — función local `LF_OBT_GAR_COM` + loop de procesamiento de cuentas

- **🔎 Evidencia:**

  **Orden de cálculo en el loop de cuentas (HEAD — misma que BASE):**
  ```plsql
  -- 1. Se llama a LF_OBT_GAR_COM PRIMERO — v_categoria aún tiene el valor del registro ANTERIOR
  v_garantia  := lf_obt_gar_com(reg(i).nro_cuenta, reg(i).cod_moneda, v_cod_mon_local, v_capital);

  -- 2. Se actualiza v_categoria DESPUÉS
  v_categoria := trunc(reg(i).cat_automatica);
  ```

  **Dentro de `LF_OBT_GAR_COM` (HEAD) — consume `v_categoria` del scope exterior:**
  ```plsql
  FUNCTION LF_OBT_GAR_COM ( ... ) RETURN NUMBER IS
     ...
  BEGIN
     IF v_map_garantias.EXISTS(v_key) THEN
        FOR k IN 1 .. v_map_garantias(v_key).COUNT LOOP
           v_gar_compu := nvl(v_map_garantias(v_key)(k).mto_apl_computable, 0);
           -- v_categoria aquí corresponde al registro ANTERIOR, no al actual
           IF v_categoria > 2 AND v_map_garantias(v_key)(k).cod_garantia NOT IN (5,11) THEN
              IF v_gar_compu > round(nvl(P_TOT_DEUDA,0)/2, 0) THEN
                 v_gar_compu := round(nvl(P_TOT_DEUDA,0)/2, 0);  -- tope 50% aplicado incorrectamente
              END IF;
           END IF;
           v_tot_gara := NVL(v_tot_gara,0) + NVL(v_gar_compu,0);
        END LOOP;
     END IF;
     RETURN v_tot_gara;
  END;
  ```

  **Corrección (swap del orden de asignación):**
  ```plsql
  -- 1. Actualizar v_categoria PRIMERO con el valor del registro actual
  v_categoria := trunc(reg(i).cat_automatica);

  -- 2. Luego llamar a LF_OBT_GAR_COM con v_categoria ya actualizada
  v_garantia  := lf_obt_gar_com(reg(i).nro_cuenta, reg(i).cod_moneda, v_cod_mon_local, v_capital);
  ```

  _Referencia: HEAD `prt_gen_previsiones.prc` líneas ~351-353_

- **📏 Regla incumplida:**
  - `severity-mapping.md` → Critical (escalamiento): _"Si el problema de orden/efecto colateral impacta montos, categoria contable, asientos o resultado del cierre → `Critical Issues`"_
  - `cb-plsql-reviewer.agent.md` → _"Caso guia obligatorio: si `v_garantia` depende de `v_categoria`, verificar que `v_categoria` se calcule antes de `lf_obt_gar_com(...)` en la misma iteracion"_

- **⚠️ Riesgo:**
  Para el **primer registro de cada lote nuevo**, `v_categoria` tiene el valor del último registro del lote anterior (o es `NULL` en el primer lote). Si ese valor stale es > 2, la función aplica el tope del 50% sobre la garantía computable de una cuenta que quizás es categoría 1. Esto **subestima la garantía computable** y en consecuencia **sobreestima la previsión** para esa cuenta. El error afecta exactamente 1 cuenta por lote de 1.000 (la primera de cada lote), lo que puede pasar desapercibido en pruebas pero tiene impacto contable acumulado.

  > **Nota:** Este bug pre-existía en BASE con el mismo orden de llamadas. En HEAD se vuelve más relevante porque la función lee de un mapa en RAM sin escape de acceso a BD: el cálculo es directo e inmediato, sin oportunidad de que una query "natural" corrija el efecto colateral. Se debe corregir en esta versión.

- **💡 Recomendación:**
  Intercambiar el orden: actualizar `v_categoria` (y la lógica de grupo económico) **antes** de llamar a `LF_OBT_GAR_COM`. Adicionalmente, evaluar pasar `v_categoria` como parámetro explícito a la función para eliminar el efecto colateral implícito:

  ```plsql
  -- Opcion minima (swap de orden):
  v_categoria := trunc(reg(i).cat_automatica);

  IF reg(i).cod_gru_economico IS NOT NULL THEN
     BEGIN
        SELECT round(g.cat_automatica)
          INTO v_categoria
          FROM ge_gru_economicos g
         WHERE cod_gru_economico = reg(i).cod_gru_economico;
        IF v_categoria IS NULL THEN
           v_categoria := trunc(reg(i).cat_automatica);
        END IF;
     EXCEPTION
        WHEN NO_DATA_FOUND THEN v_categoria := trunc(reg(i).cat_automatica);
     END;
  END IF;

  -- Ahora v_categoria es la del registro actual
  v_garantia := lf_obt_gar_com(reg(i).nro_cuenta, reg(i).cod_moneda, v_cod_mon_local, v_capital);
  ```

---

## 4. Improvements

### 🟡 Item 3 — Parámetros `P_COD_MONEDA` y `P_COD_MON_LOCAL` declarados pero no usados en `LF_OBT_GAR_COM`

- **📦 Objeto afectado:** Función local `LF_OBT_GAR_COM`
- **🔎 Evidencia:**

  **Antes (BASE):** la función usaba `v_cot_aux` (tipo `ge_cotizaciones.val_conversion%type`) para posible conversión de moneda dentro del cursor de garantías.

  **Después (HEAD):** la lógica de conversión fue eliminada (la función ahora lee de RAM), pero los parámetros se conservaron sin referencia en el cuerpo:
  ```plsql
  FUNCTION LF_OBT_GAR_COM (
     P_NRO_CUENTA    IN ta_cta_tarjetas.nro_cuenta%TYPE,
     P_COD_MONEDA    IN ba_monedas.cod_moneda%TYPE,    -- ← no referenciado en el cuerpo HEAD
     P_COD_MON_LOCAL IN ba_monedas.cod_moneda%TYPE,   -- ← no referenciado en el cuerpo HEAD
     P_TOT_DEUDA     IN pr_cta_prestamos.sal_capital%TYPE
  ) RETURN NUMBER IS
  BEGIN
     -- P_COD_MONEDA y P_COD_MON_LOCAL no aparecen en ninguna expresión del cuerpo
     ...
  END;
  ```

- **📏 Regla:** `severity-mapping.md` → _"Parametro declarado y no usado"_ → 🟡
- **⚠️ Riesgo:** Confusión al mantenimiento futuro (se esperaría que la moneda influya en el cálculo). Firma engañosa.
- **💡 Recomendación:** Si la conversión de moneda ya no aplica en este flujo, eliminar `P_COD_MONEDA` y `P_COD_MON_LOCAL` de la firma y de todos los call sites. Si puede ser necesaria en el futuro, documentarlo con un comentario explícito.

---

### 🟡 Item 4 — `v_cot_auxiliar` inicializada a `null` en cada iteración pero nunca usada

- **📦 Objeto afectado:** Loop interno de cuentas — declaración de variable + asignación
- **🔎 Evidencia:**

  **Antes (BASE):** `v_cot_auxiliar` se declaraba y asignaba a null — también dead variable en BASE.

  **Después (HEAD):** persiste la asignación sin ningún consumidor posterior en el loop:
  ```plsql
  FOR i IN 1 .. reg.count LOOP
     v_lugar := 'Procesando cuenta Nro: ' || reg(i).nro_cuenta;
     v_total_procesado := v_total_procesado + 1;
     ...
     v_cot_auxiliar := null;  -- ← asignado pero nunca leído en ninguna expresión del loop
     ...
  END LOOP;
  ```

- **📏 Regla:** `severity-mapping.md` → _"Variable declarada y no usada"_ → 🟡
- **⚠️ Riesgo:** Dead code; ruido en mantenimiento.
- **💡 Recomendación:** Eliminar la declaración de `v_cot_auxiliar` y su asignación del loop.

---

### 🟡 Item 5 — `v_total_registros`: conteo asimétrico respecto al cursor principal

- **📦 Objeto afectado:** Bloque de conteo global de registros (inicio del body)
- **🔎 Evidencia:**

  **Cursor principal (`c_tarjetas` — HEAD):** hace JOIN con `ge_clientes`:
  ```plsql
  CURSOR c_tarjetas IS
  SELECT ...
    FROM ta_cta_tarjetas p
    JOIN ge_cta_clientes cc ON cc.nro_cuenta = p.nro_cuenta AND cc.relacion = 'P'
    JOIN ge_clientes c      ON c.cod_persona = cc.cod_persona   -- ← incluye ge_clientes
   WHERE ...
  ```

  **Conteo global (`v_total_registros` — HEAD):** omite el JOIN a `ge_clientes`:
  ```plsql
  SELECT COUNT(*)
    INTO v_total_registros
    FROM ta_cta_tarjetas p
    JOIN ge_cta_clientes cc ON cc.nro_cuenta = p.nro_cuenta AND cc.relacion = 'P'
   WHERE ...  -- ← ge_clientes NO incluida
  ```

- **📏 Regla:** Higiene de variables / trazabilidad → 🟡
- **⚠️ Riesgo:** El porcentaje de progreso reportado por `DBMS_APPLICATION_INFO` puede mostrar > 100% si existen registros en `ge_cta_clientes` sin correspondencia en `ge_clientes`. Confusión operativa durante monitoreo del cierre.
- **💡 Recomendación:** Agregar el JOIN a `ge_clientes` en el conteo para que sea idéntico al filtro del cursor.

---

### 🟡 Item 6 — `PAG_CIE.FU_OBT_MOV_USER` invocada por cada cuenta dentro del loop

- **📦 Objeto afectado:** Loop interno de cuentas — asignación de `v_usuario`
- **🔎 Evidencia:**

  **Después (HEAD):** la función se llama en cada iteración del loop de cuentas:
  ```plsql
  FOR i IN 1 .. reg.count LOOP
     ...
     v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE', 'USU_MOV_CIERRE', V_CAN_USER, 'S_USU_MOVCIERRE');
     -- v_usuario asignado por cada una de las potencialmente miles de cuentas
     ...
  END LOOP;
  ```

  **Antes (BASE):** se usaba `user` (pseudo-columna) como `r_gmovi.cod_usuario := user`.

- **📏 Regla:** `severity-mapping.md` → _"Oportunidad de mejora de performance no bloqueante"_ → 🟡
- **⚠️ Riesgo:** Si `FU_OBT_MOV_USER` ejecuta una query por llamada (round-robin de usuarios), se realiza 1 acceso a BD por cuenta procesada. Con miles de tarjetas esto puede generar carga innecesaria. La lógica de round-robin podría derivarse una vez por lote.
- **💡 Recomendación:** Mover la llamada a `FU_OBT_MOV_USER` fuera del loop interno de cuentas (una vez por lote o incluso una vez antes del loop principal si la distribución de usuarios es estable).

---

## 5. Good Practices

### 🟢 Item 1 — Pre-carga masiva de garantías en RAM (`v_map_garantias`) por lote
- **📦 Objeto:** Bloque de carga de garantías (antes del loop interno)
- **Descripción:** Un solo SELECT con `IN (TABLE(v_cuentas_list))` sustituye el cursor `c_garantias` que antes hacía 1 query por cuenta. Para lotes de 1.000 cuentas, esto reduce el número de accesos a `ta_cta_garantias` de ~1.000 a 1. Correcto uso del hint `INDEX(G UK_TA_CTA_GARANTIAS)` y `USE_NL(T)`.

### 🟢 Item 2 — Procesamiento en lotes de 1.000 registros (`LIMIT 1000`) con reinicialización de colecciones
- **📦 Objeto:** Loop principal con `FETCH ... BULK COLLECT INTO reg LIMIT 1000`
- **Descripción:** Reemplaza el `LIMIT 500000` del BASE, que cargaba potencialmente cientos de miles de registros en memoria en una sola operación. Los lotes de 1.000 son mucho más seguros en producción.

### 🟢 Item 3 — Reenganche implementado correctamente via `NOT EXISTS` en el cursor
- **📦 Objeto:** Definición del cursor `c_tarjetas`
- **Descripción:** La condición `AND NOT EXISTS (SELECT 1 FROM ta_previsiones tp WHERE tp.nro_cuenta = p.nro_cuenta AND tp.fecha = v_fec_actual)` garantiza que en una re-ejecución las cuentas ya procesadas se salten automáticamente, evitando duplicados sin necesidad de borrado previo.

### 🟢 Item 4 — Soporte multi-usuario para secuencias (`LP_OBT_SECUENCIA`)
- **📦 Objeto:** Procedimiento local `LP_OBT_SECUENCIA` + colecciones `v_usu_secuencia` / `v_usu_hora`
- **Descripción:** El manejo de secuencias y hora de movimiento se separó por usuario (associative array indexado por `VARCHAR2`), con reset automático al superar 995. Esto permite distribuir la carga de movimientos entre múltiples usuarios de cierre, alineado con la parametrización en `ba_cod_referencias`.

### 🟢 Item 5 — `DBMS_APPLICATION_INFO` para observabilidad de progreso en producción
- **📦 Objeto:** Bloque principal — `SET_ACTION` y `SET_CLIENT_INFO`
- **Descripción:** El uso de `DBMS_APPLICATION_INFO.SET_CLIENT_INFO` con porcentaje de avance (`Procesado: X de Y (Z%)`) permite a DBA y operaciones monitorear el progreso del proceso en tiempo real mediante `v$session`. El cleanup en el bloque EXCEPTION es correcto.

---

## Apendice: Contexto del Proceso

| Campo | Valor |
|---|---|
| Ticket Jira | CIE-1180 — "Incidencia - PROCESO 11 ORDEN 340 PRT_GEN_PREVISIONES" |
| Prioridad | 2 - Alta |
| Estado | Code Review |
| COD_PROCESO (catálogo) | 11 (Cierre Diario) |
| NRO_ORDEN | 340 |
| DESCRIPCION | CALC. PREV. TARJETAS |
| OBLIGATORIO | **S** — proceso bloqueante del cierre |
| ACTIVO | S |
| Tablas escritas | `ta_previsiones`, `ge_movimientos`, `ge_cla_operaciones` |
| BKP de referencia | `BKP/CIE-1180/prt_gen_previsiones.prc` ✓ (mismo ticket, presente en el PR) |

### Impacto Cruzado

| Tabla | Operacion | Programas del ciclo 11 que también escriben | Riesgo |
|---|---|---|---|
| `ge_cla_operaciones` | UPDATE (tot_prevision, tot_pri_prevision, ...) | PRP_PRO_PREVISIONES (ord 338), PRC_GEN_PREVISIONES (ord 339), PRV_GEN_PREVISIONES (ord 341) | ALTO — tabla compartida de clasificación; los procesos 338-344 son todos OBLIGATORIO=S |
| `ta_previsiones` | INSERT | PRP_PRO_PREVISIONES (ord 338), PRC_GEN_PREVISIONES (ord 339), PRV_GEN_PREVISIONES (ord 341), PRU_GEN_PREVISIONES (ord 342) | MEDIO — cada proceso maneja su propio módulo; riesgo de contención baja |
| `ge_movimientos` | INSERT | Múltiples procesos del cierre (INSERT es append-only) | BAJO |

---

_Fuentes de verdad consultadas: `.github/copilot-instructions.md`, `.github/agents/cb-plsql-reviewer.agent.md`, `.github/data/ge_procesos_det.csv`, `.github/skills/cb-rvw/rules/severity-mapping.md`, `.github/skills/cb-rvw/templates/dashboard.md`. Código HEAD/BASE obtenidos via GitHub API (GH_REMOTE_OK=true, JIRA_CONTEXT_OK=true)._
