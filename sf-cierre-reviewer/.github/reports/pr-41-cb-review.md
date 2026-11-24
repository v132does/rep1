# CB Review — PR#41 · CIE-1184
> Generado: 2026-08-12 | Agente: CB PL/SQL Reviewer | Rama: feature/CIE-1184 → master

---

## 1. Resumen Ejecutivo

**Alcance del PR:** Mejora del procedimiento `IT.PRG_VER_JOB_CIERRE` para recibir el `cod_proceso` como parámetro, haciendo el verificador de jobs reutilizable para los 4 ciclos del cierre (7, 10, 11, 12). Se actualiza la semántica del dominio `JOBS_PARALELOS` en `BA_COD_REFERENCIAS` y se ajusta el registro en la malla (`GE_PROCESOS_DET`).

**Contexto Jira CIE-1184:**
- **Summary:** Mejorar el proceso de registro y control de Jobs dentro del Cierre
- **Status:** UAT / Pruebas de Aceptación | **Assignee:** Matias Alejandro Melgarejo Ortiz
- **Descripcion:** Modificar registro del dominio JOBS_PARALELOS (nueva semántica: `val_maximo` → frecuencia D/M, `abreviatura` → cod_proceso). Modificar `PRG_VER_JOB_CIERRE` para recibir como parámetro desde qué cadena se invoca (7, 10, 11, 12). Evaluar la cadena para buscar por dominio los jobs a controlar.
- **Trazabilidad Ticket vs Cambio:** **Alineado** ✅ — el cambio implementa exactamente lo pedido: nueva firma con `P_COD_PROCESO`, cursor filtrado por ciclo, frecuencia ahora viene del dominio en lugar de `GE_PROCESOS_DET`.

**Registro en malla:** `PRG_VER_JOB_CIERRE` — COD_PROCESO: `11` | NRO_ORDEN: `994` | OBLIGATORIO: `N` | FRECUENCIA: `D` | ACTIVO: `S`
→ Proceso **no bloqueante** del cierre. Criterio de revisión normal.

| Metrica | Valor |
|---|---:|
| Critical Issues | 1 |
| Improvements | 5 |
| Good Practices | 6 |
| Riesgo general | **Medio** |

| Dimension | Estado | Observacion |
|---|---|---|
| Registro en malla (GE_PROCESOS_DET) | 🟡 | COD_PROCESO=11 \| ORDEN=994 \| OBLIGATORIO=N \| ACTIVO=S — registro modificado por el script SQL |
| Impacto cruzado | 🟡 | WRITE sobre BA_PROGRAMAS y GE_PROCESOS_DET; verificar comportamiento del orquestador con COD_PROGRAMA con parámetro incrustado |
| Paralelismo Fork/Join | 🟢 | PRG_VER_JOB_CIERRE no figura en la matriz de paralelismo |
| Naming & Style (ITGF) | 🟡 | Cursor `c_jobs` debería ser `cu_jobs`; schema-qualification faltante en 3 referencias |
| Error handling | 🟢 | Errores no se tragan; RAISE y RAISE_APPLICATION_ERROR correctamente usados |
| Performance / Volumetria | 🟢 | Programa no está en el top-10 de volumetría |
| Hardcode de negocio | 🟢 | Hardcode `cod_proceso = 11` eliminado correctamente |
| Cambios DDL/DML (.sql) | 🔴 | INSERT en BA_PROGRAMAS no idempotente — falla en re-ejecución |

---

## 2. Semaforo de Severidad

| Severidad | Color | Cantidad | Estado |
|---|---|---:|---|
| Critical Issues | 🔴 | 1 | Requiere corrección |
| Improvements | 🟡 | 5 | Mejorar |
| Good Practices | 🟢 | 6 | Mantener |

---

## 3. Critical Issues

### 🔴 Item 1 — INSERT en BA_PROGRAMAS no es idempotente

- 📦 **Objeto afectado:** `GESTION_FINANCIERA/Aplicaciones_Principales/SQL/CIE-1184/7000_upd_ba_cod_referencias.sql`
- 🔎 **Evidencia:**

  Antes (guarda solo elimina nombre antiguo — no cubre el nombre nuevo):
  ```sql
  delete from ba_programas
   where cod_programa = 'PRG_VER_JOB_CIERRE'; --1 registro afectado
  /
  commit;
  /
  INSERT INTO BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO,
                             UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OBSERVACION,
                             OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
  VALUES ('PRG_VER_JOB_CIERRE(11)', 'VERIFICA JOB DINAMICO', 4, 3, 'BASE DE DATOS',
          'BASE DE DATOS', 'Procedimiento que se ejecuta en el cierre e invoca al PRG_VER_JOB_DINAMICO del cierre',
          null, 'S', ' ', 'N');
  ```

  Correcto (guarda ampliada para cubrir ambos nombres):
  ```sql
  delete from ba_programas
   where cod_programa IN ('PRG_VER_JOB_CIERRE', 'PRG_VER_JOB_CIERRE(11)');
  /
  commit;
  /
  INSERT INTO BA_PROGRAMAS (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO,
                             UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, OBSERVACION,
                             OPE_MOD_CERRADO, UBI_MENU, INA_CIERRE)
  VALUES ('PRG_VER_JOB_CIERRE(11)', 'VERIFICA JOB DINAMICO', 4, 3, 'BASE DE DATOS',
          'BASE DE DATOS', 'Procedimiento que se ejecuta en el cierre e invoca al PRG_VER_JOB_DINAMICO del cierre',
          null, 'S', ' ', 'N');
  ```

- 📏 **Regla incumplida:** Idempotencia y reejecución — todo script del cierre debe poder ejecutarse múltiples veces sin error.
- ⚠️ **Riesgo:** En la 1ª ejecución el DELETE elimina `'PRG_VER_JOB_CIERRE'` y el INSERT crea `'PRG_VER_JOB_CIERRE(11)'`. En una re-ejecución: el DELETE del nombre antiguo afecta 0 filas, pero el INSERT intenta insertar `'PRG_VER_JOB_CIERRE(11)'` que ya existe → **ORA-00001: unique constraint violated**. El script queda en error con COMMITs previos ya comprometidos.
- 💡 **Recomendación:** Ampliar el DELETE a `cod_programa IN ('PRG_VER_JOB_CIERRE', 'PRG_VER_JOB_CIERRE(11)')` para cubrir ambas variantes.

---

## 4. Improvements

### 🟡 Item 1 — Variable `v_frecuencia` comentada debe ser eliminada

- 📦 **Objeto afectado:** `prg_ver_job_cierre.prc` — sección de declaraciones
- 🔎 **Evidencia:**

  Antes (variable activa):
  ```plsql
  v_frecuencia     VARCHAR2(1);
  ```

  Después — estado actual en el PR (comentada, no eliminada):
  ```plsql
  --v_frecuencia     VARCHAR2(1);
  ```

  Correcto (eliminar la línea completamente):
  ```plsql
  v_fec_actual      ge_calendarios.fec_actual%type;
  v_ult_dia_mes    ge_calendarios.ult_dia_mes_habil%type;
  ```

- 📏 **Regla incumplida:** `copilot-instructions.md` — "Avoid leaving unused variables or commented-out code in the final version."
- ⚠️ **Riesgo:** Ruido en el código; confusión en futuros revisores sobre si la variable fue intencionalmente removida.
- 💡 **Recomendación:** Eliminar completamente la línea comentada.

---

### 🟡 Item 2 — Schema-qualification faltante en `ba_cod_referencias` y `ge_calendarios`

- 📦 **Objeto afectado:** `prg_ver_job_cierre.prc` — cursor `c_jobs` y declaraciones de variables
- 🔎 **Evidencia:**

  Estado actual (sin schema):
  ```plsql
  FROM ba_cod_referencias
   WHERE dominio = 'JOBS_PARALELOS'
  ...
  v_fec_actual      ge_calendarios.fec_actual%type;
  v_ult_dia_mes    ge_calendarios.ult_dia_mes_habil%type;
  ```

  Correcto (con schema):
  ```plsql
  FROM IT.ba_cod_referencias
   WHERE dominio = 'JOBS_PARALELOS'
  ...
  v_fec_actual      IT.ge_calendarios.fec_actual%type;
  v_ult_dia_mes    IT.ge_calendarios.ult_dia_mes_habil%type;
  ```

- 📏 **Regla incumplida:** `copilot-instructions.md` — "Schema-qualify every object reference: IT.TABLE_NAME."
- ⚠️ **Riesgo:** Resolución dependiente del search_path de la sesión Oracle.
- 💡 **Recomendación:** Anteponer `IT.` a todas las referencias de tabla y tipo-ancla.

---

### 🟡 Item 3 — Parámetro `GE_PROCESOS.COD_PROCESO%TYPE` sin schema-qualification (nuevo en este PR)

- 📦 **Objeto afectado:** `prg_ver_job_cierre.prc` — firma del procedimiento
- 🔎 **Evidencia:**

  Antes (no existía parámetro):
  ```plsql
  CREATE OR REPLACE PROCEDURE IT.PRG_VER_JOB_CIERRE AS
  ```

  Después — introducido en este PR sin schema:
  ```plsql
  CREATE OR REPLACE PROCEDURE IT.PRG_VER_JOB_CIERRE(P_COD_PROCESO IN GE_PROCESOS.COD_PROCESO%TYPE) AS
  ```

  Correcto:
  ```plsql
  CREATE OR REPLACE PROCEDURE IT.PRG_VER_JOB_CIERRE(P_COD_PROCESO IN IT.GE_PROCESOS.COD_PROCESO%TYPE) AS
  ```

- 📏 **Regla incumplida:** `copilot-instructions.md` — "Schema-qualify every object reference."
- ⚠️ **Riesgo:** Mismo que Item 2 — resolución dependiente del contexto de sesión.
- 💡 **Recomendación:** Calificar con `IT.GE_PROCESOS.COD_PROCESO%TYPE`.

---

### 🟡 Item 4 — Cursor naming no cumple convención ITGF (`cu` prefix)

- 📦 **Objeto afectado:** `prg_ver_job_cierre.prc` — declaración del cursor
- 🔎 **Evidencia:**

  Estado actual:
  ```plsql
  CURSOR c_jobs IS
  ...
  FOR r_job IN c_jobs LOOP
  ```

  Correcto (ITGF):
  ```plsql
  CURSOR cu_jobs IS
  ...
  FOR r_job IN cu_jobs LOOP
  ```

- 📏 **Regla incumplida:** `itgf-standard.instructions.md` — "Cursores: prefijo `cu`."
- ⚠️ **Riesgo:** Inconsistencia con el estándar ITGF; pre-existente en BKP, este PR es oportunidad de normalizar.
- 💡 **Recomendación:** Renombrar a `cu_jobs`.

---

### 🟡 Item 5 — COMMITs intermedios en el script SQL — falta de atomicidad

- 📦 **Objeto afectado:** `SQL/CIE-1184/7000_upd_ba_cod_referencias.sql`
- 🔎 **Evidencia:**

  Estado actual (3 COMMITs intermedios):
  ```sql
  update ba_cod_referencias ...;
  /
  commit;       -- 1er commit parcial
  /
  delete from ge_procesos_det ...;
  /
  commit;       -- 2do commit parcial
  /
  delete from ba_programas ...;
  /
  commit;       -- 3er commit parcial (estado inconsistente si INSERT falla)
  /
  INSERT INTO BA_PROGRAMAS ...;
  insert into ge_procesos_det ...;
  commit;
  ```

  Correcto (un único COMMIT al final):
  ```sql
  update ba_cod_referencias ...;
  /
  delete from ge_procesos_det ...;
  /
  delete from ba_programas ...;
  /
  INSERT INTO BA_PROGRAMAS ...;
  /
  insert into ge_procesos_det ...;
  /
  commit;
  ```

- 📏 **Regla:** Atomicidad del deployment script.
- ⚠️ **Riesgo:** Si el INSERT en `BA_PROGRAMAS` falla (ver Critical Issue #1), los DELETEs previos ya están comprometidos → estado parcialmente migrado.
- 💡 **Recomendación:** Consolidar en un único COMMIT al final.

---

## 5. Good Practices

### 🟢 Item 1 — Eliminación del hardcode `cod_proceso = 11` en la consulta interna

- 📦 **Objeto:** `prg_ver_job_cierre.prc`
- 🔎 **Evidencia:**

  Antes (hardcode — el procedimiento solo servía implícitamente para ciclo 11):
  ```plsql
  select frecuencia
    into v_frecuencia
    from ge_procesos_det a
   where cod_proceso = 11
     and a.cod_programa = r_job.cod_programa;
  exception
    when no_data_found then
      v_frecuencia := 'D';
  end;
  ```

  Después (eliminado — frecuencia viene del dominio parametrizado):
  ```plsql
  if r_job.frecuencia = 'D' then
    v_monitorear := true;
  ```

- 💡 **Patrón correcto:** Hardcode reemplazado por datos parametrizados en `BA_COD_REFERENCIAS`.

---

### 🟢 Item 2 — Procedimiento ahora reutilizable para los 4 ciclos del cierre

- 📦 **Objeto:** `prg_ver_job_cierre.prc`
- 🔎 **Evidencia:**

  Antes (sin parámetro — aplicable solo al ciclo 11 de facto):
  ```plsql
  CREATE OR REPLACE PROCEDURE IT.PRG_VER_JOB_CIERRE AS
  ```

  Después (parametrizado por ciclo):
  ```plsql
  CREATE OR REPLACE PROCEDURE IT.PRG_VER_JOB_CIERRE(P_COD_PROCESO IN GE_PROCESOS.COD_PROCESO%TYPE) AS
  ...
  AND abreviatura = to_char(P_COD_PROCESO);
  ```

- 💡 **Patrón correcto:** El procedimiento soporta nativamente ciclos 7, 10, 11 y 12 sin duplicación de código.

---

### 🟢 Item 3 — `v_monitorear` inicializado en cada iteración del loop

- 📦 **Objeto:** `prg_ver_job_cierre.prc`
- 🔎 **Evidencia:**

  Antes (sin inicialización dentro del loop — riesgo de carry-over entre iteraciones):
  ```plsql
  FOR r_job IN c_jobs LOOP
    if v_frecuencia = 'D' then
      v_monitorear := true;
  ```

  Después:
  ```plsql
  FOR r_job IN c_jobs LOOP
    v_monitorear := false;
    if r_job.frecuencia = 'D' then
      v_monitorear := true;
  ```

- 💡 **Patrón correcto:** Elimina el riesgo de contaminación de estado entre iteraciones.

---

### 🟢 Item 4 — Patrón DELETE+INSERT en `GE_PROCESOS_DET` es idempotente

- 📦 **Objeto:** `SQL/CIE-1184/7000_upd_ba_cod_referencias.sql`
- 🔎 **Evidencia:**
  ```sql
  delete from ge_procesos_det
    where cod_proceso = 11
      and nro_orden = 994;
  ...
  insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, ..., 'PRG_VER_JOB_CIERRE(11)', ...);
  ```
- 💡 **Patrón correcto:** DELETE-then-INSERT sobre clave (COD_PROCESO, NRO_ORDEN) garantiza idempotencia para el registro de la malla.

---

### 🟢 Item 5 — BKP del ticket CIE-1184 correctamente incluido en el PR

- 📦 **Objeto:** `BKP/CIE-1184/prg_ver_job_cierre.prc`
- 💡 **Patrón correcto:** BKP corresponde al mismo ticket del PR (CIE-1184 = CIE-1184). Facilita rollback y auditoría histórica.

---

### 🟢 Item 6 — Named notation en llamada a `prg_ver_job_dinamico`

- 📦 **Objeto:** `prg_ver_job_cierre.prc`
- 🔎 **Evidencia:**
  ```plsql
  IT.prg_ver_job_dinamico(
    p_pref_job => r_job.nombre_job,
    p_err_out  => v_err_individual
  );
  ```
- 💡 **Patrón correcto:** Named notation mejora legibilidad y resistencia a cambios de firma.

---

## 6. Impacto Cruzado

| Tabla (WRITE) | Observacion | Ciclo | OBLIGATORIO | Riesgo |
|---|---|---|---|---|
| `BA_PROGRAMAS` | DELETE + INSERT. Tabla maestra usada por el orquestador para construir la invocación dinámica de programas | 11 | N/A | 🟡 Medio |
| `GE_PROCESOS_DET` | DELETE + INSERT del registro (COD_PROCESO=11, NRO_ORDEN=994). Tabla central de la malla | 11 | N | 🟡 Medio |
| `BA_COD_REFERENCIAS` | UPDATE dominio JOBS_PARALELOS para `JOB_CTA_NO_CAP_` — cambio de semántica de columnas | 11 | N/A | 🟢 Bajo |

> **Verificación pendiente:** El nuevo `COD_PROGRAMA = 'PRG_VER_JOB_CIERRE(11)'` asume que el orquestador de la malla genera dinámicamente `BEGIN IT.PRG_VER_JOB_CIERRE(11); END;`. Este comportamiento debe confirmarse en el código del proceso invocador antes del merge.

---

## Supuestos

- El orquestador de la malla usa `EXECUTE IMMEDIATE 'BEGIN IT.' || cod_programa || '; END;'` o patrón similar, permitiendo que `COD_PROGRAMA = 'PRG_VER_JOB_CIERRE(11)'` sea interpretado como llamada con parámetro literal.
- El `UPDATE` en `BA_COD_REFERENCIAS` para `JOB_CTA_NO_CAP_` refleja el único job mensual configurado actualmente en el dominio; los demás jobs ya tienen la estructura correcta o serán migrados en tickets futuros.

---

*Reporte generado con datos remotos del PR (cache: pr-41.json + pr-41.diff) y contexto Jira (cache: pr-41-jira.json).*