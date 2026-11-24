## 0. Verificacion de Origen

| Campo | Valor |
|---|---|
| SHA del HEAD leido en esta corrida | `42ca5a37a4c0bac7653635ff3980b8ae9b06de5c` |
| Fecha/hora `updated_at` del PR | `2026-08-28T03:36:00Z` |
| Fuente de datos usada | GitHub API remota + cache local `.github/pr-cache/pr-86.json`, `.diff` y `.jira.json` |
| Ticket derivado | `CIE-1198` |
| Rama | `feature/CIE-1198` |

Se reviso el ultimo commit del PR (`headRefOid`) y el diff del trigger `TA_GE_PROCESOS_DET` junto con el script de parametrizacion de `BA_COD_REFERENCIAS`. El cambio relevante queda en `GESTION_FINANCIERA/Aplicaciones_Principales/Objetos_BD/Triggers/ta_ge_procesos_det.trg` y no en archivos de desarrollo/backup.

## 1. Resumen Ejecutivo

El PR modifica el disparo `TA_GE_PROCESOS_DET` para cambiar el mecanismo de lanzamiento de jobs del cierre, usando un helper `pr_crear_job_dinamico` y parametrizando los prefijos activos en `BA_COD_REFERENCIAS`. Tambien se elimina el registro de `PRP_ACT_DEV_DIARIOS` del cierre y se agrega un script de carga para esas referencias.

El cambio cumple la intencion funcional principal del ticket: centralizar el lanzamiento de jobs desde el trigger y parametrizar los prefijos de job. Sin embargo, hay una condicion de riesgo nueva y concreta en el trigger: el helper captura errores con `WHEN OTHERS THEN NULL` sin log ni re-raise, ocultando fallos de orchestration del cierre. Eso transforma una falla de scheduling en un caso silencioso, que es incompatible con el requerimiento de gobernanza del cierre y la reputacion del trigger como punto de integracion.

**Veredicto tecnico: NO APTO PARA MERGE.**

| Metrica | Valor |
|---|---:|
| Critical Issues | 1 |
| Improvements | 2 |
| Good Practices | 2 |
| Riesgo general | Medio/Alto |

| Dimension | Estado | Observacion |
|---|---|---|
| Alineacion funcional con Jira | 🟢 | El cambio concreta la modificacion del trigger y la parametrizacion solicitada. |
| Gobernanza / GE_PROCESOS | 🟡 | Se usan jobs dinamicos y se elimina una entrada del proceso; la observabilidad de fallos queda comprometida. |
| Idempotencia / reejecucion | 🟡 | La carga de BA_COD_REFERENCIAS no es idempotente y el trigger no registra errores de scheduling. |
| Cambios DDL/DML | 🟡 | Existe script de insercion y delete sobre `GE_PROCESOS_DET` con riesgo de re-ejecucion. |
| Error handling | 🔴 | `WHEN OTHERS THEN NULL` oculta fallos en el helper de jobs. |
| Naming & Style | 🟢 | El codigo mantiene nombres descriptivos y enfoque de disparo. |
| Performance / Volumetria | 🟢 | El uso de `DBMS_SCHEDULER` y validacion previa es razonable para el caso. |

## 2. Trazabilidad Jira

| Campo | Valor |
|---|---|
| Ticket | `CIE-1198` |
| Summary | `Modificar ejecución de Jobs Trigger ge_procesos_det` |
| Status | `Code Review` |
| Labels / Components | Sin labels / Sin components |
| Trazabilidad Ticket vs Cambio | Alineado parcialmente |

**Criterios de aceptacion vs codigo (validacion 1 a 1):**

| # | Criterio | Estado | Evidencia |
|---|---|---|---|
| 1 | Modificar el modo de lanzamiento de jobs para `pra_act_sal_promedio` y `prp_act_fec_solicitudes` desde `TA_GE_PROCESOS_DET`. | Cumple | El trigger ahora llama a `pr_crear_job_dinamico` con `PRA_ACT_SAL_` y `PRP_ACT_FEC_` para `cod_proceso = 10` y `nro_orden in (420)`. |
| 2 | Parametrizar esos datos en `BA_COD_REFERENCIAS` para control de jobs. | Cumple | El script `7000_ins_ba_cod_referencias.sql` inserta registros bajo `DOMINIO = 'JOBS_PARALELOS'` con `VAL_MINIMO`/`VAL_MAXIMO` para los prefijos. |
| 3 | Eliminar `PRP_ACT_DEV_DIARIOS` del post-cierre y llevarlo a trigger con job. | Cumple | El trigger agrega el branch `elsif :new.nro_orden in (998)` y ejecuta `PRP_ACT_DEV_DIARIOS` a traves de `pr_crear_job_dinamico` con prefijo `PRP_ACT_DEV_`. |

**Desvio de alcance (scope creep):** No se observa scope creep significativo. El PR se enfoca en el trigger y sus registros parametrizados. El cambio claramente corresponde al ticket principal y a la eliminacion del proceso `PRP_ACT_DEV_DIARIOS` del post-cierre.

## 3. Semaforo de Severidad

| Severidad | Color | Cantidad | Estado |
|---|---|---:|---|
| Critical Issues | 🔴 | 1 | Bloquea merge |
| Improvements | 🟡 | 2 | Mejoras recomendadas |
| Good Practices | 🟢 | 2 | Mantener |

## 4. Critical Issues

### 🔴 CRITICAL-001: Error de scheduling ocultado en `pr_crear_job_dinamico`

- Objeto afectado: `GESTION_FINANCIERA/Aplicaciones_Principales/Objetos_BD/Triggers/ta_ge_procesos_det.trg`
- Regla validada: manejo de errores del cierre debe dejar trazabilidad al error y no silenciar fallos en la creación/ejecución de jobs.

**ANTES (BKP):**
```plsql
if :new.nro_orden in (420) and :new.cod_proceso = 10 then
  V_SENTENCIA := 'begin begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 3; end; it.pra_act_sal_promedio; end;';
  DBMS_JOB.submit(v_jobs,V_SENTENCIA);

  V_SENTENCIA := 'begin begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 3; end; it.prp_act_fec_solicitudes; commit; end;';
  DBMS_JOB.submit(v_jobs,V_SENTENCIA);
end if;
```

**DESPUES (HEAD):**
```plsql
PROCEDURE pr_crear_job_dinamico(
    p_job_name_base     IN VARCHAR2,
    p_proceso_principal IN VARCHAR2,
    p_fec_proceso       IN DATE
) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  ...
BEGIN
  ...
  DBMS_SCHEDULER.CREATE_JOB (
     job_name   => v_job_name,
     job_type   => 'PLSQL_BLOCK',
     job_action => v_sql_stmt,
     enabled    => TRUE,
     auto_drop  => TRUE
  );
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    null;--Se deja en nulo porque el programa 994 del cierre controla y loguea los estados y errores de los jobs
END pr_crear_job_dinamico;
```

**Riesgo:**
- La falla de creación de job queda silenciada.
- El trigger deja de evidenciar un error de scheduling y la cadena del cierre puede romperse sin trazabilidad.
- El comentario del propio codigo admite que "el programa 994 del cierre controla y loguea los estados y errores", pero en el codigo nuevo no se invoca ningun registro de log ni re-raise.

**Clasificacion:** Critical Issue por ser un cambio introducido en el diff del PR y afectar la gobernanza del cierre.

## 5. Improvements

### 🟡 Item 1 - Script de parametros no idempotente

- Archivo: `GESTION_FINANCIERA/Aplicaciones_Principales/SQL/CIE-1198/7000_ins_ba_cod_referencias.sql`
- Evidencia:

```sql
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('JOBS_PARALELOS', 'Control Job Cierre - PRA_ACT_SAL_PROMEDIO', 'PRA_ACT_SAL_', 'D', '10', 'S');
/
commit;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('JOBS_PARALELOS', 'Control Job Cierre - PRP_ACT_FEC_SOLICITUDES', 'PRP_ACT_FEC_', 'D', '10', 'S');
```

**Riesgo:** Reejecucion del script falla con clave duplicada si los registros ya existen. El pattern requiere `MERGE` o `INSERT ... SELECT ... WHERE NOT EXISTS` para cumplir idempotencia.

### 🟡 Item 2 - Delete directo sobre `GE_PROCESOS_DET` sin validacion de integridad del proceso

- Archivo: `GESTION_FINANCIERA/Aplicaciones_Principales/SQL/CIE-1198/7000_ins_ba_cod_referencias.sql`
- Evidencia:

```sql
delete from ge_procesos_det
  where cod_proceso = 12
    and nro_orden = 31;-- se elimina DEVENGADO DIARIO PRESTAMOS PRP_ACT_DEV_DIARIOS
```

**Riesgo:** El script practica una eliminacion directa de una configuracion de la malla sin verificar el estado previo ni hacer un guard de seguridad para evitar ejecuciones paralelas o re-procesos inconsistentes. Debe documentarse y validarse con una estrategia de control de migracion, no solo con un delete directo.

## 6. Good Practices

### 🟢 Item 1 - Generacion unica de nombre de job con `GENERATE_JOB_NAME`

```plsql
v_job_name := DBMS_SCHEDULER.GENERATE_JOB_NAME(v_job_name_prefix);
```

**Observacion:** La estrategia para evitar colisiones de job y mantener prefijos por dia es una buena practica y ayuda a la trazabilidad del lanzamiento en cierres diarios.

### 🟢 Item 2 - Uso de `DBMS_SCHEDULER` con `auto_drop => TRUE`

```plsql
DBMS_SCHEDULER.CREATE_JOB (
   job_name   => v_job_name,
   job_type   => 'PLSQL_BLOCK',
   job_action => v_sql_stmt,
   enabled    => TRUE,
   auto_drop  => TRUE
);
```

**Observacion:** Mantener limpieza de jobs temporales reduce residuos y mejora la predictibilidad del cierre. Este patron es apropiado para jobs de ejecucion de una sola corrida.

## 7. Impacto Cruzado

| Tabla / Entidad | Programas relacionados | Ciclo | Riesgo |
|---|---|---|---|
| `BA_COD_REFERENCIAS` | `TA_GE_PROCESOS_DET` | General del cierre | 🟡 |
| `GE_PROCESOS_DET` | Malla de cierre / trigger de ejecucion | 7-12 | 🟡 |
| `GE_PROCESOS_DET_HIS` | Historial de cierre | 7-12 | 🟡 |

El cambio afecta la base de control de jobs y la malla de procesos del cierre, por lo que cualquier fallo de programacion o de reejecucion puede reflejarse en la integridad del ciclo. No se detectaron otros consumidores relevantes en el diff del PR, pero el impacto real se concentra en la propia gobernanza del cierre.

## 8. Comentarios de Revisores (GitHub)

| Autor | Solicitud (resumen) | Estado | Evidencia |
|---|---|---|---|
| N/A | No se pudo verificar comentarios de revisores humanos en el PR remoto. | N/A | La revision usa metadata de GitHub y cache del PR; no hubo evidencia adicional de review threads disponible en esta sesion. |

## 9. Supuestos

- El analisis se baso en la metadata remota del PR, el diff del HEAD y el cache `.github/pr-cache/pr-86.*`.
- No se leyó el codigo local de `ueno_core` para construir evidencia tecnica; la fuente valida fue el artefacto remoto del PR.
- El detalle del ticket en Jira se tomo del issue `CIE-1198` y del cuerpo del PR; no hubo criterios de aceptacion formales adicionales en el issue.
- La validacion funcional se enfoca en la implementacion del trigger y la semantica de la malla, no en pruebas de regresion ejecutadas en ambiente.

## Cierre

El PR tiene una intencion funcional correcta y una trazabilidad razonable con la tarea `CIE-1198`, pero la ocultacion de errores en `WHEN OTHERS THEN NULL` dentro del helper de jobs es un riesgo de gobernanza que bloquea el merge. Se recomienda corregir ese punto y hacer idempotente el script de referencia antes del merge.
