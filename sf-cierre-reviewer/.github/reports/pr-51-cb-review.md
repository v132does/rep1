# CB Review — PR #51 · CIE-1178
> `feature/CIE-1178` → `master` | Generado: 2026-08-12

---

## Contexto Jira — CIE-1178

| Campo | Valor |
|---|---|
| Ticket | CIE-1178 |
| Tipo | Error |
| Prioridad | 2 - Alta |
| Resumen | Error programa PRB_GEN_ASI_GARANTIAS |
| Descripción | Reporta fallo en el programa 11.337 durante cierre 29/07/2026. Solicita "aplicar la solución definitiva al procedimiento para el uso de múltiples usuarios." |
| Estado | En curso |
| Asignado | Fabiola Beatriz Davalos Moraes |
| Epic padre | CIE-906 — Q3/2026 Incidencias Cierre |
| Bloqueado por | FSOP-63538 (Cierre_bankitti-29_07_26, En Ejecución) |

---

## 1. Resumen Ejecutivo

El PR refactoriza `IT.PRB_GEN_ASI_GARANTIAS` (Ciclo 11 · Orden 337 · OBLIGATORIO=S) para resolver el error de agotamiento de capacidad de usuarios/secuencias reportado en CIE-1178. Los cambios principales son: migración a BULK COLLECT/FORALL, centralización de la lógica de rotación de usuarios en `lp_asignar_secuencia_usuario`, unificación de los procedimientos de garantías COMPUTABLE y NO COMPUTABLE en uno solo, y caché en memoria para parámetros dinámicos.

La solución funcional al problema multiusuario está correctamente implementada. Sin embargo, el procedimiento continúa sin protección de idempotencia sobre `ge_movimientos`, lo cual es un riesgo bloqueante para un proceso OBLIGATORIO='S'.

**Ticket vs Cambio:** Alineado — el PR implementa la solución definitiva multiusuario pedida en el ticket y agrega mejoras de performance pertinentes. El alcance va un poco más allá (refactoring de performance) pero es justificado.

| Metrica | Valor |
|---|---:|
| Critical Issues | 1 |
| Improvements | 4 |
| Good Practices | 6 |
| Riesgo general | Alto |

| Dimension | Estado | Observacion |
|---|---|---|
| Registro en malla (GE_PROCESOS_DET) | 🟢 | COD_PROCESO=11 \| ORDEN=337 \| OBLIGATORIO=S \| ACTIVO=S |
| Impacto cruzado | 🟢 | Escribe en `ge_movimientos`; sin otros programas del mismo ciclo sobreescribiendo ese par (fecha, cod_tra_padre=200) |
| Paralelismo Fork/Join | 🟢 | FRECUENCIA=D (serie). Sin flag P/F declarado en la malla. |
| Naming & Style (ITGF) | 🟡 | `V_CAN_USER` capitalizado inconsistentemente en llamadas |
| Error handling | 🟡 | Exception silenciada en inicialización de `v_can_user` |
| Performance / Volumetria | 🟢 | Programa NO en top-10 de volumetría; se introduce BULK/FORALL que mejora la situación |
| Hardcode de negocio | 🟡 | `cod_tra_padre=200`, literales de dominio hardcodeados |
| Higiene de variables y parametros | 🟢 | Sin variables declaradas y no usadas detectadas en HEAD |
| Cambios DDL/DML (.sql) | N/A | Sin archivos .sql en el PR |

---

## 2. Semaforo de Severidad

| Severidad | Color | Cantidad | Estado |
|---|---|---:|---|
| Critical Issues | 🔴 | 1 | Requiere corrección antes de merge |
| Improvements | 🟡 | 4 | Mejorar en este mismo PR o en deuda técnica documentada |
| Good Practices | 🟢 | 6 | Mantener |

---

## 3. Critical Issues

### 🔴 Item 1 — Proceso no idempotente: INSERT en `ge_movimientos` sin limpieza previa

- 📦 **Objeto afectado:** `IT.PRB_GEN_ASI_GARANTIAS` — procedimientos `lp_gen_asi_desafectacion` y `lp_gen_asi_procesar_garantias`
- 🔎 **Evidencia:**

  Antes (BKP/CIE-1178):
  ```plsql
  -- lp_gen_asi_desafectacion: INSERT ... SELECT sin DELETE previo
  INSERT INTO ge_movimientos (...)
    SELECT ... FROM ge_movimientos_ant a, pr_gar_tipos t
     WHERE fecha = v_fec_anterior
       AND hora  = reg.hora
       ...
  ```

  Después (HEAD):
  ```plsql
  -- lp_gen_asi_desafectacion: FORALL INSERT sin DELETE previo
  IF v_ins_mov.COUNT > 0 THEN
     FORALL i IN 1..v_ins_mov.COUNT
        INSERT INTO ge_movimientos VALUES v_ins_mov(i);
  END IF;

  -- lp_gen_asi_procesar_garantias: FORALL INSERT sin DELETE previo
  IF v_ins_mov.COUNT > 0 THEN
     FORALL i IN 1..v_ins_mov.COUNT
        INSERT INTO ge_movimientos VALUES v_ins_mov(i);
  END IF;
  ```

  No existe ningún `DELETE FROM ge_movimientos WHERE fecha = v_fec_actual AND cod_tra_padre = 200 (...)` en ningún punto del procedimiento (ni en el BKP ni en el HEAD).

- 📏 **Regla incumplida:** Regla Central del módulo — "Todo proceso debe ser idempotente y soportar reejecución." Combinado con `OBLIGATORIO = 'S'` eleva la severidad a Critical.
- ⚠️ **Riesgo:** En reejecución del proceso (falla parcial, reinicio manual del cierre), se generan asientos contables duplicados de desafectación y constitución de garantías en `ge_movimientos` para la misma `fecha` y `cod_tra_padre = 200`. Al no haber violación de clave única (se obtienen nuevos `cod_usuario`, `hora` y `nro_secuencia`), el error pasa silencioso y los saldos de garantías quedan incorrectos en el cierre diario.
- 💡 **Recomendación:** Agregar una limpieza controlada al inicio del cuerpo principal, antes de llamar a los procedimientos locales:

  ```plsql
  BEGIN
     -- Limpieza idempotente: eliminar asientos propios del proceso para la fecha actual
     DELETE FROM ge_movimientos gm
      WHERE gm.fecha         = v_fec_actual
        AND gm.cod_tra_padre = 200
        AND EXISTS (
              SELECT 1 FROM pr_gar_tipos pgt
               WHERE pgt.cod_modulo    = gm.cod_modulo
                 AND pgt.cod_modalidad = gm.cod_modalidad
                 AND gm.cod_transaccion IN (pgt.cod_transaccion1, pgt.cod_transaccion2)
            );
  EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20000,
           'ERROR. LIMPIEZA PREVIA GARANTIAS: ' || SQLERRM ||
           ' | Trace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
  END;

  lp_gen_asi_desafectacion;
  lp_gen_asi_procesar_garantias;
  ```

  Alternativamente, validar si el proceso ya fue ejecutado consultando por `(fecha, cod_tra_padre=200)` y salir temprano si ya existen registros (upsert pattern). Definir con el equipo de negocio cuál es la política de reejecución esperada.

---

## 4. Improvements

### 🟡 Item 1 — Exception silenciada en inicialización de `v_can_user`

- 📦 **Objeto afectado:** Cuerpo principal de `IT.PRB_GEN_ASI_GARANTIAS`
- 🔎 **Evidencia:**

  Antes (BKP) — idéntico al HEAD:
  ```plsql
  BEGIN
     SELECT COUNT(*)
       INTO v_can_user
       FROM ba_cod_referencias
      WHERE dominio     = 'USU_MOV_CIERRE'
        AND abreviatura = 'MOVCIERRE';
  EXCEPTION
     WHEN OTHERS THEN
        v_can_user := 1;  -- excepción silenciada, sin log
  END;
  ```

  Después (HEAD) — mantenido igual, sin corrección:
  ```plsql
  EXCEPTION
     WHEN OTHERS THEN
        v_can_user := 1;
  END;
  ```

- 📏 **Regla incumplida:** Error handling — `WHEN OTHERS THEN NULL` o swallow equivalente sin log ni re-raise.
- ⚠️ **Riesgo:** Si la tabla `ba_cod_referencias` falla (lock, down, permisos), el proceso continúa silenciosamente con un único usuario de cierre, lo cual puede provocar agotamiento de secuencias o colisiones bajo carga. El error no llega al log de la malla.
- 💡 **Recomendación:** Loguear mínimamente el evento o eliminar el bloque de excepción si `COUNT(*)` no puede fallar por razones de negocio. Si se tolera el default, al menos documentar el supuesto:

  ```plsql
  EXCEPTION
     WHEN OTHERS THEN
        -- Tabla ba_cod_referencias no disponible; se asume 1 usuario de cierre
        v_can_user := 1;
  END;
  ```

---

### 🟡 Item 2 — Hardcodes de valores de negocio

- 📦 **Objeto afectado:** `lp_asignar_secuencia_usuario`, `lp_gen_asi_procesar_garantias`, cuerpo principal
- 🔎 **Evidencia:**

  Antes (BKP):
  ```plsql
  v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
  v_hora    := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
  r_gmovi.cod_tra_padre := 200; --- Calculo de Garantias
  ```

  Después (HEAD) — mantenidos y extendidos:
  ```plsql
  v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
  v_usu_hora(v_usuario) := PAG_CIE.FU_OBT_HORA(v_usuario, 'S_HOR_MOVCIERRE','E');
  r_gmovi.cod_tra_padre := 200;
  -- También: 'COMPUTABLE', 'NO COMPUTABLE' en el cursor c_garantias
  ```

- 📏 **Regla incumplida:** "Business values handling — Hardcoding such values in the PL/SQL code is prohibited to maintain flexibility and data integrity."
- ⚠️ **Riesgo:** Cambios en los códigos de dominio, transacción o parámetros requieren modificar y recompilar el procedimiento en lugar de actualizar un registro de parametrización.
- 💡 **Recomendación:** Declarar constantes en el encabezado del procedimiento con comentario explicativo, o recuperarlos desde una función paramétrica. Como mínimo, usar constantes locales con nombre descriptivo para mejorar mantenibilidad.

---

### 🟡 Item 3 — Capitalización inconsistente de `V_CAN_USER`

- 📦 **Objeto afectado:** `lp_asignar_secuencia_usuario`
- 🔎 **Evidencia:**

  Antes (BKP):
  ```plsql
  v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
  ```

  Después (HEAD) — mantenido:
  ```plsql
  v_usuario := PAG_CIE.FU_OBT_MOV_USER('MOVCIERRE','USU_MOV_CIERRE',V_CAN_USER,'S_USU_MOVCIERRE');
  ```

  La variable está declarada como `v_can_user NUMBER` (minúsculas) pero se referencia como `V_CAN_USER` (mayúsculas) en las llamadas a funciones. PL/SQL es case-insensitive, por lo que no falla en compilación, pero viola el estándar ITGF de variables escalares en minúsculas con prefijo `v_`.

- 📏 **Regla incumplida:** Naming ITGF — variables internas en `v_` minúsculas.
- ⚠️ **Riesgo:** Bajo. Solo legibilidad y consistencia.
- 💡 **Recomendación:** Normalizar todas las referencias a `v_can_user` (minúsculas).

---

### 🟡 Item 4 — Archivo sin newline final

- 📦 **Objeto afectado:** `GESTION_FINANCIERA/Aplicaciones_Principales/Objetos_BD/Procedimientos/prb_gen_asi_garantias.prc`
- 🔎 **Evidencia:**

  Antes (BKP):
  ```plsql
  END prb_gen_asi_garantias;
  -- con newline final implícito
  ```

  Después (HEAD):
  ```
  END PRB_GEN_ASI_GARANTIAS;
  \ No newline at end of file
  ```

- 📏 **Regla incumplida:** "All code has to be encoded in UTF-8 without BOM." — Por extensión, los archivos de texto deben terminar con newline para compatibilidad con herramientas de diff y despliegue.
- ⚠️ **Riesgo:** Bajo. Puede causar advertencias en scripts de despliegue o concatenación de archivos SQL.
- 💡 **Recomendación:** Agregar un salto de línea al final del archivo.

---

## 5. Good Practices

### 🟢 Item 1 — Migración a BULK COLLECT / FORALL

El procesamiento row-by-row con `pag_gen.pr_ins_ge_movimiento` (un `INSERT` por iteración) fue reemplazado por colectas en memoria con `BULK COLLECT LIMIT 5000/2000` y `FORALL INSERT`. Esto reduce drásticamente el contexto switching entre PL/SQL y SQL, mejorando el throughput en escenarios con alta cantidad de garantías.

### 🟢 Item 2 — Caché en memoria para parámetros dinámicos

La llamada a `fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA', ...)` ahora se realiza una sola vez por combinación `(cod_modulo, cod_modalidad, cod_moneda, cod_oficina)` usando el `ASSOCIATIVE ARRAY` `v_cache_red`. En el original, se invocaba en cada iteración del cursor.

### 🟢 Item 3 — Centralización de rotación de usuarios en `lp_asignar_secuencia_usuario`

La lógica de rotación de usuario/hora/secuencia fue extraída a un único procedimiento local. El código original tenía la misma lógica duplicada en tres lugares. El nuevo diseño elimina esa duplicación y asegura consistencia en el comportamiento de rotación.

### 🟢 Item 4 — Unificación de COMPUTABLE y NO COMPUTABLE en un único cursor

Los procedimientos `lp_gen_asi_constitucion` y `lp_gen_asi_nocomp` (dos cursores idénticos con filtros diferentes) fueron consolidados en `lp_gen_asi_procesar_garantias` con `clasificacion IN ('COMPUTABLE', 'NO COMPUTABLE')` y `ORDER BY t.clasificacion`. La lógica de generación del concepto usa `CASE WHEN` inline. Reduce superficie de error de divergencia entre los dos bloques.

### 🟢 Item 5 — Cierre seguro de cursor en bloques EXCEPTION

Ambos procedimientos locales incluyen:
```plsql
EXCEPTION
   WHEN OTHERS THEN
      IF c_XXX%ISOPEN THEN
         CLOSE c_XXX;
      END IF;
      raise_application_error(-20000, '...' || SQLERRM || ' | Trace: ' || ...);
```
Esto previene cursor leaks ante errores en mitad del procesamiento BULK.

### 🟢 Item 6 — `DBMS_UTILITY.FORMAT_ERROR_BACKTRACE` en mensajes de error

Los mensajes de error ahora incluyen el backtrace completo, lo que facilita enormemente el diagnóstico de errores en producción frente al mensaje plano `SQLERRM` del original.

---

## Supuestos

- La única tabla afectada por writes en este procedimiento es `ge_movimientos` (no se identificaron otras tablas con INSERT/UPDATE/DELETE en el diff).
- La política de unicidad de `ge_movimientos` se asume en `(cod_usuario, fecha, hora, nro_secuencia)`; si existe una restricción diferente, el análisis de idempotencia puede variar.
- `PRB_GEN_ASI_GARANTIAS` no tiene flag P/F de paralelismo declarado en la malla de cierre; se asume ejecución serie dentro del Ciclo 11.
