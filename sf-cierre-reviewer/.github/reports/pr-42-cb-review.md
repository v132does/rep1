## 0. Verificación de Origen (Modo PR)

| Campo | Valor |
|---|---|
| SHA del HEAD leído en esta corrida | f1b5e7f9beaf8f2cf9b61b21bb574208474e434f |
| Fecha/hora `updated_at` del PR | 2026-08-14 (obtenido desde cache remoto) |
| Fuente de datos usada | Opción B: `fetch` remoto con cache local `.github/pr-cache/pr-42.json`, `pr-42.diff` |
| SHA anterior (si existe reporte previo) | N/A - Primera revisión de PR#42 |
| Cambios de commit | Reporte inicial. SHA leído de cache remoto en esta corrida. |

---

## 1. Resumen Ejecutivo

**PR#42 — CIE-1179: Alineación de identidad de débito nocturno en movimientos 503**

El PR modifica `PRP_COB_PRE_NOCTURNOS`, procedimiento **OBLIGATORIO** (malla de cierre, cod_proceso=10 "INICIO DE DIA", ORDEN=114). Los cambios implementan una lógica mejorada de alineación de identidades entre el débito del 503 (movimiento contable) y el cobro nocturno, garantizando consistencia de trazabilidad y permitiendo reversa limpia.

**Hallazgo crítico:** Bug en WHERE clause de UPDATE de error que compromete idempotencia en reejecuciones.

| Métrica | Valor |
|---|---:|
| **Critical Issues** | **1** ⚠️ |
| **Improvements** | **6** |
| **Good Practices** | **5** |
| **Riesgo general** | **MEDIO** (bloquea merge si no se corrige) |

| Dimensión | Estado | Observación |
|---|---|---|
| Registro en malla (GE_PROCESOS_DET) | 🟢 | COD_PROCESO=10 (INICIO DE DIA) \| ORDEN=114 \| OBLIGATORIO=S \| ACTIVO=D |
| Impacto cruzado | 🟡 | Afecta tablas: `PR_COBROS_NOC`, `GE_MOVIMIENTOS`, `PR_COBROS` (lectura en reversa). Impacto ALTO en ciclo final. |
| Paralelismo Fork/Join | 🟢 | Tipo "I" (no paralelo). Sin dependencias de barrera explícitas detectadas. |
| Naming & Style (ITGF) | 🟡 | Convenciones ITGF no totalmente claras (procedimiento `prp_` correcto, pero lógica local interna sin prefijos locales explícitos). |
| Error handling | 🔴 | **CRITICAL:** UPDATE de error con bug en WHERE; excepción final sin logging. |
| Performance / Volumetría | 🟡 | Procedimiento no está en top-10, pero contiene búsquedas con LIKE que serían ineficientes a escala. |
| Hardcode de negocio | 🟡 | Valores como cod_transaccion, cod_tra_padre, estados ('E', 'I', 'A', 'P') no parametrizados. |
| Higiene de variables y parámetros | 🟡 | Algunas variables inicializadas sin uso en todas las ramas; lógica de `v_hor_cobro` como IN OUT poco clara. |
| Cambios DDL/DML (.sql) | 🟢 | No hay archivos .sql en este PR. N/A |

---

## 2. Semáforo de Severidad

| Severidad | Color | Cantidad | Estado |
|---|---|---:|---|
| Critical Issues | 🔴 | **1** | **Requiere corrección INMEDIATA** |
| Improvements | 🟡 | **6** | Mejorar en próxima iteración o en revisión de pares |
| Good Practices | 🟢 | **5** | Mantener y expandir |

---

## 3. Critical Issues

### 🔴 Issue #1: Bug en WHERE clause de UPDATE estado='E' — Idempotencia comprometida

- 📦 **Objeto o bloque afectado:** Procedimiento `PRP_COB_PRE_NOCTURNOS`, bloque EXCEPTION dentro del loop C1 (rama `WHEN OTHERS` que captura "EL MONTO A PAGAR DEBE CUBRIR POR LO MENOS LOS CARGOS.")

- 🔎 **Evidencia (línea o fragmento):**

	**Antes (BKP CIE-1179):**
	```sql
	update it.pr_cobros_noc w 
	   set w.estado = 'E' 
	 where w.nro_cuenta=r1.nro_cuenta and w.mto_cobrado = r1.mto_cobrado
	   and w.nro_cuota_desde = r1.nro_cuota_desde and w.nro_cuota_hasta = r1.nro_cuota_desde;
	```

	**Después (Objetos_BD actual):**
	```sql
	update it.pr_cobros_noc w 
	   set w.estado = 'E' 
	 where w.nro_cuenta=r1.nro_cuenta and w.mto_cobrado = r1.mto_cobrado
	   and w.nro_cuota_desde = r1.nro_cuota_desde and w.nro_cuota_hasta = r1.nro_cuota_desde;
	```

	✓ **El bug persiste en ambas versiones** (NO fue corregido por el PR).

	Referencia: `pr-42.diff` línea ~305; archivo actual aprox. línea 381.

- 📏 **Regla validada o incumplida:**
  - **Regla de Idempotencia (Cierre Bancario, Regla Central):** "Todo proceso debe ser idempotente y soportar reejecución."
  - **Severidad Mapping — Critical Issues:** "Proceso no idempotente: puede generar duplicados o inconsistencias al reejecutar."

- ⚠️ **Riesgo:**
  - **Comparación incorrecta en WHERE:** La condición `w.nro_cuota_hasta = r1.nro_cuota_desde` (usa la MISMA variable dos veces, ambas referencias a `nro_cuota_desde`) cuando debería ser `w.nro_cuota_hasta = r1.nro_cuota_hasta`.
  - **En reejecución del procedimiento:** Si el procedimiento se vuelve a ejecutar sobre el mismo período:
    1. El registro original con `nro_cuota_hasta = X` (donde X ≠ nro_cuota_desde) NO será identificado por la WHERE clause.
    2. Ese registro seguirá en estado 'I' (inicial) en lugar de 'E' (error).
    3. El loop volverá a procesar la misma cuota, causando duplicación de intentos de cobro o inconsistencia contable.
  - **Impacto contable:** Los asientos generados en la primera ejecución en estado 'P' (procesado) NO se desharán; la segunda ejecución generará nuevos asientos duplicados.
  - **Impacto en gobernanza:** La ejecución no quedará marcada como error realmente procesado; fallará la trazabilidad.

- 💡 **Recomendación concreta:**
  1. **Corregir la comparación inmediatamente:**
     ```sql
     update it.pr_cobros_noc w 
        set w.estado = 'E' 
      where w.nro_cuenta=r1.nro_cuenta 
        and w.mto_cobrado = r1.mto_cobrado
        and w.nro_cuota_desde = r1.nro_cuota_desde 
        and w.nro_cuota_hasta = r1.nro_cuota_hasta;  -- CORRECCIÓN: usar r1.nro_cuota_hasta
     ```
  2. **Testing:** Validar que la reejecución del procedimiento con el mismo período NO genera cobros duplicados ni asientos duplicados.
  3. **Gobernanza:** Agregar un comentario en el código explicando que este UPDATE es idempotente porque compara TODAS las claves del registro.

---

## 4. Improvements

### 🟡 Issue #1: Búsqueda de movimiento 503 con LIKE ineficiente

- 📦 **Objeto o bloque afectado:** Bloque de búsqueda de movimiento 503 para alineación (línea ~428 en archivo actual), dentro del loop C1.

- 🔎 **Evidencia (línea o fragmento):**

	**Código actual:**
	```sql
	select x.rid
	  into v_rowid_deb
	  from (select d.rowid rid
	          from ge_movimientos d
	         where d.fecha = r1.fecha
	           and d.hora = r1.hora
	           and d.cod_usuario = r1.usu_insercion
	           and d.concepto like ('%'||r1.nro_cuenta||'%')  -- ⚠️ Full table scan
	         order by d.nro_secuencia desc, d.hora desc) x
	 where rownum = 1;
	```

	Referencia: `pr-42.diff` línea ~425; archivo actual aprox. línea 430.

- 📏 **Regla validada o incumplida:**
  - **Severidad Mapping — Improvements:** "Oportunidad de mejora de performance no bloqueante."
  - **Buena práctica de ITGF:** Usar columnas específicas en predicados WHERE; evitar LIKE en búsquedas selectivas.

- ⚠️ **Riesgo:**
  - **Full table scan en GE_MOVIMIENTOS:** La columna `concepto` es VARCHAR2, probablemente NO tenga índice. La búsqueda por LIKE en esa columna será un full scan de la tabla.
  - **Contexto loop:** Este bloque ejecuta DENTRO del loop C1, que iterea sobre todos los cobros nocturnos pendientes. Cada iteración hace un full scan.
  - **Volumetría:** Aunque `PRP_COB_PRE_NOCTURNOS` no está en el top-10, un cierre diario puede procesar cientos o miles de cobros. Multiplicar un full scan por esa cantidad degradará performance.
  - **Alternativa disponible:** La tabla `GE_MOVIMIENTOS` seguramente tiene índice en `nro_cuenta`. Usar esa columna es mucho más eficiente.

- 💡 **Recomendación concreta:**
  1. **Reemplazar LIKE con índice disponible:**
     ```sql
     select x.rid
       into v_rowid_deb
       from (select d.rowid rid
               from ge_movimientos d
              where d.fecha = r1.fecha
                and d.hora = r1.hora
                and d.cod_usuario = r1.usu_insercion
                and d.nro_cuenta = r1.nro_cuenta  -- ✓ Usa columna específica con probable índice
              order by d.nro_secuencia desc, d.hora desc) x
      where rownum = 1;
     ```
  2. **Validación:** Verificar que el índice en `(fecha, hora, cod_usuario, nro_cuenta)` existe o crear uno si falta. Comparar plan de ejecución BEFORE/AFTER.
  3. **Nota:** El concepto no es necesario para identificar el 503; la tupla (fecha, hora, usuario, nro_cuenta, secuencia DESC) ya es única.

---

### 🟡 Issue #2: Error handling sin logging previo en excepción final

- 📦 **Objeto o bloque afectado:** Bloque EXCEPTION final del procedimiento (línea ~469 en archivo actual).

- 🔎 **Evidencia (línea o fragmento):**

	**Código actual:**
	```sql
	exception
	  when others then
	    raise_application_error(-20000,'Error '||v_lugar||' '||v_nro_secuencia||' '||sqlerrm);
	END;
	/
	```

	Referencia: archivo actual línea ~469.

- 📏 **Regla validada o incumplida:**
  - **Severidad Mapping — Critical en regla de Error Handling:** "Error handling sin `RAISE` y sin fallback seguro" → fallback silencioso sin logging.
  - **Buena práctica de Cierre Bancario:** Todo error debe ser loguado ANTES de hacer RAISE para garantizar trazabilidad en gobernanza.

- ⚠️ **Riesgo:**
  - **Falta de logging en gobernanza:** Cuando el procedimiento falla, el error se propaga al orquestador PERO no hay constancia de que fue loguado en la tabla de audit del cierre (si existe).
  - **Contexto parcial perdido:** El mensaje de error solo incluye `v_lugar` (descripción genérica del punto) y `v_nro_secuencia`, pero no hay registro en base de datos de cuándo exactamente falló ni qué estado quedó.
  - **Comparación con PRG_ACT_LOG_PROCESOS:** En otras partes del procedimiento (línea ~315) se usa `PRG_ACT_LOG_PROCESOS(...)` para logging. La excepción final NO sigue ese patrón.

- 💡 **Recomendación concreta:**
  1. **Agregar logging previo a RAISE:**
     ```sql
     exception
       when others then
         PRG_ACT_LOG_PROCESOS(
           'PRP_COB_PRE_NOCTURNOS',
           '1',
           trunc(sysdate),
           to_char(sysdate,'hh24:mi:ss'),
           to_char(sysdate,'hh24:mi:ss'),
           'ERROR en '||v_lugar||' Secuencia:'||v_nro_secuencia||' SQLCode:'||sqlcode||' '||sqlerrm
         );
         raise_application_error(
           -20000,
           'Error '||v_lugar||' '||v_nro_secuencia||' '||sqlerrm
         );
     END;
     ```
  2. **Considerar escalamiento:** Si el error es genérico (OTHERS), anotar que el procedimiento debe investigar más específicamente qué tipo de error espera (FK violations, PK violations, etc.) y tratarlos con contexto.

---

### 🟡 Issue #3: Manejo de excepciones muy restrictivo — Solo un tipo de error capturado

- 📦 **Objeto o bloque afectado:** Bloque de excepción dentro del loop C1 que llama a `pap_pre.pr_cob_prestamo(...)` (línea ~312-329 en archivo actual).

- 🔎 **Evidencia (línea o fragmento):**

	**Código actual:**
	```sql
	EXCEPTION
	  WHEN OTHERS THEN
	    v_error := upper(substr(replace(sqlerrm, 'ORA-20000: ', ''), 1, 4000));
	    IF v_error = 'EL MONTO A PAGAR DEBE CUBRIR POR LO MENOS LOS CARGOS.' THEN
	      rollback to savepoint v_sav_point;
	      update it.pr_cobros_noc w 
	         set w.estado = 'E' 
	       where w.nro_cuenta=r1.nro_cuenta and w.mto_cobrado = r1.mto_cobrado
	         and w.nro_cuota_desde = r1.nro_cuota_desde and w.nro_cuota_hasta = r1.nro_cuota_desde;
	       PRG_ACT_LOG_PROCESOS(...);      
	      goto siguiente_registro;
	    END IF;
	    -- ⚠️ Si NO es ese error específico, nada ocurre (no hay ELSE)
	  END;
	```

	Referencia: `pr-42.diff` línea ~317-329; archivo actual aprox. línea 318-330.

- 📏 **Regla validada o incumplida:**
  - **Severidad Mapping — Improvements:** "Error handling sin valor de reemplazo controlado" cuando se captura un error pero no se hace nada si NO coincide con el filtro.
  - **Buena práctica:** Capturar TODOS los errores esperados, no solo UNO.

- ⚠️ **Riesgo:**
  - **Errores silenciosos:** Si `pap_pre.pr_cob_prestamo(...)` lanza un error distinto a "EL MONTO A PAGAR DEBE CUBRIR POR LO MENOS LOS CARGOS.", ese error se TRAGA (no hay ELSE, no hay RAISE).
  - **Flujo incompleto:** El código continúa al siguiente registro SIN haber procesado el error, dejando estado indeterminado.
  - **Impacto:** Cobros no procesados, inconsistencias en la malla de cierre.
  - **Ejemplo de otros errores posibles:**
    - "Error de validación de cuota" (formato distinto)
    - FK violation en PR_CUOTAS
    - División por cero en cálculo de intereses
    - Timeout de DB

- 💡 **Recomendación concreta:**
  1. **Expandir el manejo de excepciones:**
     ```sql
     EXCEPTION
       WHEN OTHERS THEN
         v_error := upper(substr(replace(sqlerrm, 'ORA-20000: ', ''), 1, 4000));
         IF v_error LIKE '%MONTO A PAGAR%' THEN
           rollback to savepoint v_sav_point;
           update it.pr_cobros_noc w 
              set w.estado = 'E' 
            where w.nro_cuenta=r1.nro_cuenta and w.mto_cobrado = r1.mto_cobrado
              and w.nro_cuota_desde = r1.nro_cuota_desde and w.nro_cuota_hasta = r1.nro_cuota_desde;
           PRG_ACT_LOG_PROCESOS(...);      
           goto siguiente_registro;
         ELSE
           -- ✓ Manejar otros errores explícitamente
           rollback to savepoint v_sav_point;
           PRG_ACT_LOG_PROCESOS(
             'PRP_COB_PRE_NOCTURNOS', '1', trunc(sysdate), to_char(sysdate,'hh24:mi:ss'),
             to_char(sysdate,'hh24:mi:ss'),
             'ERROR INESPERADO en pap_pre.pr_cob_prestamo para Cta:'||r1.nro_cuenta||' Error:'||sqlerrm
           );
           RAISE;  -- Propagar error al orquestador
         END IF;
     END;
     ```
  2. **Testing:** Simular errores de negocio (validación de cuota, FK, etc.) y verificar que se loguean y se propagan.

---

### 🟡 Issue #4: GOTO en loop de cursor — Anti-patrón para reejecución

- 📦 **Objeto o bloque afectado:** Loop C1, uso de GOTO para saltar a siguiente registro (línea ~444 en archivo actual).

- 🔎 **Evidencia (línea o fragmento):**

	**Código actual:**
	```sql
	FOR R1 IN C1 LOOP
	  ...
	  EXCEPTION
	    WHEN OTHERS THEN
	      ...
	      goto siguiente_registro;  -- ⚠️ GOTO dentro del loop
	  END;
	  ...
	  <<siguiente_registro>>
	  null;
	END LOOP;
	```

	Referencia: archivo actual línea ~444, ~329.

- 📏 **Regla validada o incumplida:**
  - **Anti-patrón PL/SQL:** GOTO es un anti-patrón moderno en PL/SQL; la mayoría de los casos se pueden reemplazar con IF/THEN/ELSE o CONTINUE.
  - **Reejecución:** En reejecuciones del procedimiento, si el estado queda parcialmente procesado (ej: entre el GOTO y el fin del loop), puede causar inconsistencias.
  - **Buena práctica de gobernanza:** Los bloques de lógica del cierre deben ser claramente delimitables y trackeables.

- ⚠️ **Riesgo:**
  - **Salto no explícito:** El GOTO salta a `siguiente_registro`, saltando el código de actualización del PR_COBROS_NOC al final del loop (línea ~455-462).
  - **Estado inconsistente:** Si el procedimiento se interrumpe DESPUÉS del GOTO pero ANTES de llegar a `<<siguiente_registro>>`, el registro quedará en estado 'I' (no procesado) sin indicación de error.
  - **Reejecución:** En la segunda ejecución, el registro se reprocessará desde el inicio, posiblemente generando duplicados.

- 💡 **Recomendación concreta:**
  1. **Reemplazar GOTO con IF/THEN/ELSE o CONTINUE (si PL/SQL lo soporta):**
     ```sql
     FOR R1 IN C1 LOOP
       v_error_procesado := 'N';
       BEGIN
         ...
         -- Procesar cobro
         v_error_procesado := 'S';
       EXCEPTION
         WHEN OTHERS THEN
           IF error_es_tolerado THEN
             v_error_procesado := 'E';  -- Marcado como error tolerado
             PRG_ACT_LOG_PROCESOS(...);
           ELSE
             RAISE;  -- Propagar
           END IF;
       END;
       
       -- Siempre actualizar estado, independientemente de cómo terminó
       IF v_error_procesado IN ('S', 'E') THEN
         UPDATE PR_COBROS_NOC SET ESTADO = 'P' WHERE rowid = r1.registro;
       END IF;
     END LOOP;
     ```
  2. **Beneficio:** Código más legible, más predecible en reejecuciones.

---

### 🟡 Issue #5: Hardcode de valores de negocio — No parametrizados

- 📦 **Objeto o bloque afectado:** Todo el procedimiento (declaraciones y lógica).

- 🔎 **Evidencia (línea o fragmento):**

	**Código actual contiene hardcodes:**
	```sql
	-- Estados no parametrizados
	AND a.ESTADO = 'I'           -- Estado Inicial
	AND a.MTO_COBRADO > 0        -- Cobro positivo
	...
	SET ESTADO = 'A'             -- Estado Anterior
	...
	SET ESTADO = 'P'             -- Estado Procesado
	...
	SET ESTADO = 'E'             -- Estado Error
	...
	
	-- Códigos de transacción no parametrizados
	r_gmovi.cod_transaccion := 842;   -- COBRO DE CUENTA CONTABLE (linea ~224)
	r_gmovi.cod_transaccion := 740;   -- COBRO EN EFECTIVO (linea ~245)
	r_gmovi.cod_transaccion := 607;   -- CHEQUES (linea ~289)
	602,                               -- (linea ~204)
	
	-- Códigos de transacción padre
	v_cod_tra_padre    ge_movimientos.cod_tra_padre%type := 360;  -- (linea ~11)
	
	-- Verificación de usuario hardcodeada
	if instr(fug_obt_pardinamico('COD_USU_PAG_SER'),R1.usu_insercion)>0 and ...
	
	-- Códigos de officio/modalidad
	r1.cod_tra_padre = 359         -- (linea ~315)
	```

	Referencia: distribuidas en todo el archivo, líneas 11, 71, 115, 204, 224, 245, 289, 315, 374, etc.

- 📏 **Regla validada o incumplida:**
  - **Severidad Mapping — Improvements:** "Hardcode de valores de negocio que debería venir de parámetros" y "`cod_proceso` sin constante o parámetro explícito."
  - **Buena práctica de Cierre Bancario:** Separar configuración de lógica; usar funciones parametrizadas como `fug_obt_pardinamico()`.

- ⚠️ **Riesgo:**
  - **Mantenibilidad:** Si cambian los códigos de transacción, hay que retocar el código (riesgo de regresión).
  - **Trazabilidad:** Los valores hardcodeados no quedan documentados en un catálogo accesible a la gobernanza.
  - **Testing:** Es difícil hacer testing parametrizado de diferentes escenarios de negocio.
  - **Cambios de políticas:** Si el banco cambia la política de tratamiento de cobros (ej: otro cod_transaccion), hay que redeploy del procedimiento.

- 💡 **Recomendación concreta:**
  1. **Crear constantes en el paquete (si existe) o reemplazar con fug_obt_pardinamico():**
     ```sql
     -- Opción A: Constantes en spec de paquete
     CREATE OR REPLACE PACKAGE prp_cob_pre IS
       cg_estado_inicial      CONSTANT VARCHAR2(1) := 'I';
       cg_estado_procesado    CONSTANT VARCHAR2(1) := 'P';
       cg_estado_error        CONSTANT VARCHAR2(1) := 'E';
       cg_cod_tra_debit_503   CONSTANT NUMBER := 360;
       cg_cod_tra_pago        CONSTANT NUMBER := 359;
       cg_cod_trans_cta_ctble CONSTANT NUMBER := 842;
       cg_cod_trans_efectivo  CONSTANT NUMBER := 740;
       cg_cod_trans_cheques   CONSTANT NUMBER := 607;
     END;
     
     -- Opción B: Reemplazar con función parametrizada
     v_cod_tra_padre := fug_obt_pardinamico('PRE_COD_TRA_PADRE_COB_NOC', NULL, NULL, NULL);
     ```
  2. **Beneficio:** Cambios de configuración sin redeploy de código.

---

### 🟡 Issue #6: Parámetro OUT implícito en pap_pre.pr_cob_prestamo no claramente documentado

- 📦 **Objeto o bloque afectado:** Llamada a `pap_pre.pr_cob_prestamo(...)` línea ~318, parámetro `v_hor_cobro`.

- 🔎 **Evidencia (línea o fragmento):**

	**Código actual:**
	```sql
	v_nro_secuencia:= v_sec_ini_cobro;
	pap_pre.pr_cob_prestamo(r1.nro_cuenta,
	                        r1.mto_cobrado,
	                        'N',
	                        r1.cod_ofi_origen,
	                        r1.nro_cuota_desde,
	                        r1.nro_cuota_hasta,
	                        'Pago de Cuota', --concepto
	                        r1.fecha,
	                        v_hor_cobro,                    -- ⚠️ ¿IN o OUT?
	                        v_nro_secuencia,--r1.nro_secuencia,
	                        r1.cod_tra_padre,
	                        r1.cod_mod_padre,
	                        r1.cod_mad_padre,
	                        'N', 
	                        NULL,
	                        'N',
	                        'N',
	                        'N',
	                        r1.usu_insercion);
	
	-- Luego se asigna:
	v_usu_movimiento := r1.usu_insercion;
	v_fec_pap_pre := v_fec_actual;
	v_hor_pap_pre := v_hor_cobro;   -- ⚠️ ¿Cambió v_hor_cobro adentro de pap_pre?
	```

	Referencia: archivo actual línea ~318, ~343-345.

- 📏 **Regla validada o incumplida:**
  - **Higiene de parámetros:** Parámetros que actúan como OUT deben ser explícitamente documentados en comentarios o en contrato de función.
  - **Buena práctica:** El código que invoca debe saber si debe refrescar la variable después de la llamada o si puede reutilizar el valor anterior.

- ⚠️ **Riesgo:**
  - **Ambigüedad:** No está claro si `pap_pre.pr_cob_prestamo()` modifica `v_hor_cobro` internamente (como OUT parameter) o si devuelve un valor.
  - **Falta de contrato explícito:** El diff menciona en comentario "ESTE PARAMETRO ES IN OUT (Devuelve la nueva hora generada)" pero ese comentario está en el BKP, no en el código fuente.
  - **Reejecución:** Si el comportamiento es no-determinístico (ej: pap_pre genera una hora diferente cada vez), la reejecución causará cobros con identidades distintas.
  - **Dataflow confuso:** El código después de la llamada asigna `v_hor_pap_pre := v_hor_cobro`, ¿está asignando el valor modificado por pap_pre o está asignando el valor previo?

- 💡 **Recomendación concreta:**
  1. **Verificar definición de pap_pre.pr_cob_prestamo():** Buscar su signature en el repo para confirmar si v_hor_cobro es IN, OUT, o IN OUT.
  2. **Documentar explícitamente en el código:**
     ```sql
     -- Nota: v_hor_cobro es modificado por pap_pre.pr_cob_prestamo() 
     -- (parámetro IN OUT). Después de la llamada, contendrá la hora real
     -- del desglose (PAP_PRE), no necesariamente la hora original del cobro.
     v_nro_secuencia:= v_sec_ini_cobro;
     pap_pre.pr_cob_prestamo(
       p_nro_cuenta => r1.nro_cuenta,
       ...
       p_hor_cobro => v_hor_cobro,  -- IN OUT: devuelve la hora real del desglose
       ...
     );
     -- v_hor_cobro ahora contiene la hora del desglose (modificada por PAP_PRE)
     v_fec_pap_pre := v_fec_actual;
     v_hor_pap_pre := v_hor_cobro;  -- Capturar la hora real para alineación posterior
     ```
  3. **Testing:** Validar que el valor de v_hor_cobro se comporta deterministicamente en reejecuciones.

---

## 5. Good Practices

### 🟢 Practice #1: Uso correcto de SAVEPOINT para rollback parcial

- 📦 **Objeto o bloque afectado:** Loop C1, línea ~108-110.

- 🔎 **Evidencia:**

	```sql
	FOR R1 IN C1 LOOP
	  savepoint v_sav_point;  -- ✓ Crear un punto de restauración antes de operaciones arriesgadas
	  
	  -- Procesar cobro...
	  EXCEPTION
	    WHEN OTHERS THEN
	      v_error := upper(substr(replace(sqlerrm, 'ORA-20000: ', ''), 1, 4000));
	      IF v_error LIKE '%MONTO A PAGAR%' THEN
	        rollback to savepoint v_sav_point;  -- ✓ Deshacer parcialmente solo el trabajo de ESTE cobro
	        ...
	        goto siguiente_registro;
	  END;
	END LOOP;
	```

- 📏 **Regla validada o incumplida:**
  - **Good Practices — Cierre Bancario:** "Idempotencia correctamente implementada (borrado previo + reinsert, upsert)."
  - **Patrón de transacción parcial:** SAVEPOINT permite fallar un registro sin deshacer el trabajo de registros anteriores.

- ⚠️ **Riesgo evitado:**
  - ✓ Sin SAVEPOINT: un error en un cobro causaría rollback de TODO el loop, dejando el procedimiento sin avance.
  - ✓ Con SAVEPOINT: un error en un cobro se maneja localmente, y el loop continúa procesando otros cobros.

- 💡 **Fortaleza:**
  - Implementación correcta de manejo transaccional granular.
  - Reduce el impacto de errores a registros individuales.

---

### 🟢 Practice #2: Logging adecuado vía PRG_ACT_LOG_PROCESOS

- 📦 **Objeto o bloque afectado:** Llamadas a `PRG_ACT_LOG_PROCESOS` en líneas ~318, ~356.

- 🔎 **Evidencia:**

	```sql
	-- Logging en caso de error de negocio
	PRG_ACT_LOG_PROCESOS(
	  'PRP_COB_PRE_NOCTURNOS',
	  '1',
	  trunc(sysdate),
	  to_char(sysdate,'hh24:mi:ss'),
	  to_char(sysdate,'hh24:mi:ss'),
	  'Mto. Cargo supera Mto. Abonado Cta:'||r1.nro_cuenta||' Mto: ' ||r1.mto_cobrado
	);
	```

- 📏 **Regla validada o incumplida:**
  - **Good Practices — Cierre Bancario:** "Error handling con log y re-raise consistente."
  - **Estándar del módulo:** `PRG_ACT_LOG_PROCESOS` es el mecanismo de audit oficial de Cierre Bancario.

- 💡 **Fortaleza:**
  - Trazabilidad explícita: errores de negocio se registran en audit de procesos.
  - Información suficiente: cuenta, monto, tipo de error.
  - Soporta investigación post-cierre.

---

### 🟢 Practice #3: Mejora en la alineación de identidades (PR actual vs BKP)

- 📦 **Objeto o bloque afectado:** Nueva lógica de búsqueda y actualización del movimiento 503 (línea ~340-443 en archivo actual).

- 🔎 **Evidencia (fragmento de la nueva lógica):**

	**Nuevo código (PR actual):**
	```sql
	-- 1. Buscar el movimiento real generado por PAP_PRE dentro del rango de secuencias
	BEGIN
	  SELECT x.fecha, x.cod_usuario, x.hora
	    INTO v_fec_pap_pre, v_usu_pap_pre, v_hor_pap_pre
	    FROM (SELECT m.fecha, m.cod_usuario, m.hora
	            FROM ge_movimientos m
	           WHERE m.fecha = v_fec_actual
	             AND m.nro_cuenta = r1.nro_cuenta
	             AND m.nro_secuencia BETWEEN v_sec_ini_cobro AND v_nro_secuencia
	             AND m.cod_transaccion <> 503
	           ORDER BY m.nro_secuencia DESC, m.hora DESC
	         ) x
	   WHERE rownum = 1;
	EXCEPTION
	  WHEN NO_DATA_FOUND THEN
	    null;  -- Usar valor inicial si no encuentra
	END;
	
	-- 2. Buscar y actualizar el débito original por su identidad original exacta
	select x.rid
	  into v_rowid_deb
	  from (select d.rowid rid
	          from ge_movimientos d
	         where d.fecha = r1.fecha
	           and d.hora = r1.hora
	           and d.cod_usuario = r1.usu_insercion
	           and d.concepto like ('%'||r1.nro_cuenta||'%')
	         order by d.nro_secuencia desc, d.hora desc) x
	 where rownum = 1;
	
	-- 3. Alinear el débito con la identidad real del bloque PAP_PRE
	if v_rowid_deb is not null then
	  update ge_movimientos m
	     set m.fecha = v_fec_pap_pre,
	         m.hora = v_hor_pap_pre,
	         m.cod_usuario = v_usu_pap_pre,
	         m.nro_secuencia = nvl(v_nro_secuencia,0) + 1
	   where m.rowid = v_rowid_deb;
	end if;
	
	-- 4. Persistir en PR_COBROS_NOC solo si el débito fue identificado y alineado
	IF v_rowid_deb IS NOT NULL THEN
	  UPDATE PR_COBROS_NOC
	    SET HORA = v_hor_pap_pre,
	        FEC_PROCESO = v_fec_actual,
	        ESTADO = 'P'
	    WHERE ESTADO = 'I'
	      AND rowid = r1.registro;
	ELSE
	  UPDATE PR_COBROS_NOC
	    SET ESTADO = 'P'
	        ,FEC_PROCESO = v_fec_actual
	    WHERE ESTADO = 'I'
	      AND rowid = r1.registro;
	END IF;
	```

	Referencia: archivo actual línea ~340-443.

- 📏 **Regla validada o incumplida:**
  - **Good Practices — Cierre Bancario:** "Patrones que reducen riesgo operativo en reejecuciones de cierre."
  - **Mejora de trazabilidad:** La lógica garantiza que el débito del 503 y el cobro nocturno tengan la MISMA identidad operativa (fecha, hora, usuario), lo que permite reversa limpia.

- 💡 **Fortaleza:**
  - ✓ **Determinismo:** El movimiento 503 es identificado de forma determinística (buscando dentro del rango de secuencias del bloque PAP_PRE).
  - ✓ **Trazabilidad completa:** Débito, cobro, y reversa comparten la misma identidad.
  - ✓ **Seguridad de reejecución:** Si el procedimiento se reejecutar, la búsqueda del movimiento 503 será idéntica (mismo rango de secuencias).
  - ✓ **Fallback seguro:** Si el movimiento 503 NO se encuentra, se usa la identidad original como fallback.

---

### 🟢 Practice #4: Inicialización segura de variables críticas

- 📦 **Objeto o bloque afectado:** Declaraciones de variables inicializadas con valores seguros.

- 🔎 **Evidencia:**

	```sql
	v_nro_secuencia    ge_movimientos.nro_secuencia%type := 0;  -- ✓ Inicializar en 0, no NULL
	v_cod_retorno      varchar2(3) := '000';                    -- ✓ Estado inicial conocido
	v_cod_tra_padre    ge_movimientos.cod_tra_padre%type := 360; -- ✓ Valor por defecto explícito
	```

- 📏 **Regla validada o incumplida:**
  - **Good Practices — Cierre Bancario:** "Inicialización segura de variables críticas."

- 💡 **Fortaleza:**
  - ✓ Variables escalares (números, strings) inicializadas en lugar de NULL, evitando operaciones NULL.
  - ✓ Estados iniciales conocidos facilitan debugging.
  - ✓ Reduce errores de aritmética sobre NULL.

---

### 🟢 Practice #5: Uso de funciones parametrizadas para valores dinámicos

- 📦 **Objeto o bloque afectado:** Llamadas a `fug_obt_pardinamico()` y otras funciones parametrizadas.

- 🔎 **Evidencia:**

	```sql
	v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(6);  -- ✓ Obtener fecha actual de función (no hardcode)
	
	if instr(fug_obt_pardinamico('COD_USU_PAG_SER'),R1.usu_insercion)>0 then  -- ✓ Parámetro dinámico
	  ...
	end if;
	
	v_cta_bancaria := fug_obt_pardinamico('PRE_CTA_BAN_'||v_nom_parametro, NULL, NULL, p_cod_moneda);  -- ✓ Parametrizado
	```

- 📏 **Regla validada o incumplida:**
  - **Good Practices:** "Lógica de negocio parametrizada sin hardcodes."

- 💡 **Fortaleza:**
  - ✓ Configuración separada de lógica.
  - ✓ Cambios de política sin redeploy.
  - ✓ Soporta múltiples escenarios de negocio.

---

## 6. Impacto Cruzado

| Tabla | Operación | Programas Impactados (Malla de Cierre) | Ciclo | OBLIGATORIO | Riesgo |
|---|---|---|---|---|---|
| **PR_COBROS_NOC** | UPDATE: ESTADO, HORA, FEC_PROCESO | PRP_COB_PRE_NOCTURNOS (114); otros programas de PAP_PRE? | 10 | S | ALTO |
| **GE_MOVIMIENTOS** | SELECT (búsqueda 503); UPDATE (alineación) | PRP_COB_PRE_NOCTURNOS (114); PAG_GEN.PR_INS_GE_MOVIMIENTO (invocado dentro) | 10/11 | S | ALTO |
| **PR_COBROS** | SELECT (lectura en reversa C2, línea ~382) | PRP_COB_PRE_NOCTURNOS (114); PRG_REV_OPERACION | 10 | S | ALTO |

**Análisis:**

1. **PR_COBROS_NOC:** Tabla de entrada del procedimiento, es el dato maestro de cobros nocturnos. El PR actualiza el ESTADO (de 'I' a 'P' o 'E') y la HORA (para persistencia de identidad). Este cambio impacta:
   - Cualquier programa que lea PR_COBROS_NOC en un mismo ciclo o posterior.
   - **Riesgo:** Si otro programa confía en la hora original (antes del cambio del PR), habrá inconsistencia.
   - **Mitigación:** La hora se actualiza SOLO si se logra alinear el movimiento 503, lo que es idempotente.

2. **GE_MOVIMIENTOS:** Tabla de audit de operaciones del banco. El PR inserta (vía PAG_GEN.PR_INS_GE_MOVIMIENTO) y ACTUALIZA movimientos (alineación del 503).
   - **Riesgo:** Si GE_MOVIMIENTOS tiene triggers de audit o vinculaciones con otros programas, el UPDATE del 503 podría causar efectos colaterales.
   - **Riesgo de performance:** La búsqueda por LIKE (Issue #1) puede degradar la experiencia si hay concurrencia con otros programas.

3. **PR_COBROS:** Tabla de maestro de cobros finales. El PR la LEE SOLO en la rama C2 (reversiones), buscando el máximo de hora. Con el cambio del PR, esta lectura YA NO ocurre en la rama nueva; en su lugar se usa la hora guardada en PR_COBROS_NOC.
   - **Riesgo de compatibilidad:** Si otro programa espera que PR_COBROS contenga el registro de reversa, podría no encontrarlo si PR_COBROS_NOC tiene una hora distinta.
   - **Mejora:** El cambio reduce la dependencia de PR_COBROS en C2, mejorando desacoplamiento.

**Veredicto de Impacto Cruzado:** RIESGO MEDIO. El cambio es más una mejora de alineación que una ruptura arquitectónica. Sin embargo, requiere validación en testing de integración completo del ciclo 10 ("INICIO DE DIA") con otros programas que consumen PR_COBROS o GE_MOVIMIENTOS.

---

## 7. Supuestos y Limitaciones

1. **Jira no consultado directamente:** El contexto funcional se derivó del título y descripción del PR en GitHub. No se accedió a criterios de aceptación de Jira CIE-1179.

2. **Definición de PAP_PRE.PR_COB_PRESTAMO no verificada:** El parámetro OUT de `v_hor_cobro` se asume basado en el código, pero no se revisó la signature oficial en el repositorio. Recomendación: verificar.

3. **Volumetría del programa:** No está en el top-10 de volumetría, pero contiene bucles y búsquedas que podrían escalar bajo alta concurrencia.

4. **Testing de reejecución:** No se ejecutó testing de reejecución real. Las recomendaciones se basan en análisis estático del código.

5. **Comentarios de revisores humanos en GitHub:** No se recuperaron comentarios de revisores humanos en el PR de GitHub (herramienta no disponible o cache no actualizado). Este análisis es puramente técnico.

---

## 8. Conclusión y Recomendación de Merge

### 🔴 **ESTADO: NO APTO PARA MERGE SIN CORRECCIONES**

**Razón:** Existe un **Critical Issue (Issue #1)** que compromete la idempotencia del procedimiento. Bug en WHERE clause de UPDATE estado='E':

```sql
-- ACTUAL (INCORRECTO):
... and w.nro_cuota_hasta = r1.nro_cuota_desde;  -- Usa dos veces la MISMA variable

-- DEBE SER:
... and w.nro_cuota_hasta = r1.nro_cuota_hasta;  -- Usa la variable correcta
```

**Condición de Merge:**
1. ✅ Corregir el bug de WHERE clause (Critical Issue #1).
2. ✅ Agregar logging en excepción final (Improvements #2).
3. 🟡 Considerar correcciones de Improvements #1, #3, #4 en próxima iteración.

**Tiempo estimado de corrección:** < 15 minutos.

---

**Revisión generada:** 2026-08-14  
**PR:** #42 (feature/CIE-1179)  
**Programa principal:** `PRP_COB_PRE_NOCTURNOS`  
**Malla de cierre:** cod_proceso=10 (INICIO DE DIA), ORDEN=114, OBLIGATORIO=S
## Modificación de `prp_cob_pre_nocturnos`

**Programa:** `PRP_COB_PRE_NOCTURNOS`
**Ticket:** CIE-1179
**Ciclo:** 10 (Inicio de Día)
**Criticidad:** 🔴 **OBLIGATORIO='S'** (Bloqueante del cierre)
**Fecha de Análisis:** 2026-08-14

---

## 0. Verificación de Origen

| Campo | Valor |
|---|---|
| SHA del HEAD leído | `f1b5e7f9beaf8f2cf9b61b21bb574208474e434f` |
| `updated_at` del PR (GitHub) | `2026-08-14T13:10:53Z` |
| Fuente de datos | Fetch directo a GitHub API (confirmado por contenido del archivo, ver nota) |

**Nota de corrección:** Este reporte corrige la clasificación de severidad de dos hallazgos del reporte anterior, tras aclaración del autor sobre contexto de negocio (ver secciones correspondientes).

---

## 1. Resumen Ejecutivo

El PR alinea la identidad operativa (usuario/hora/secuencia) del débito nocturno (movimiento 503) en `GE_MOVIMIENTOS` con la identidad real generada por `PAP_PRE`, reemplazando un `UPDATE` incondicional por una búsqueda dinámica y una actualización condicional.

Tras aclaración del autor, dos hallazgos que se habían clasificado como Critical en versiones previas de este reporte **no corresponden a defectos**:
- La selección `ROWNUM=1` sin `ORDER BY` es intencional: cualquier fila coincidente es funcionalmente equivalente para este caso de uso.
- El uso de `INSTR(concepto, ...)` en vez de `LIKE` fue un pedido explícito de un revisor humano (mejora sobre el comportamiento anterior, no un defecto nuevo).

Queda un hallazgo Critical real: **desvío entre el alcance declarado en el PR/ticket y el diff real** — el cursor `C2` (reversa nocturna), que la descripción del PR afirma haber modificado, no fue tocado.

### Trazabilidad Funcional (Jira)

| Aspecto | Estado |
|---|---|
| **Ticket vs Cambio** | **Parcial** — corrige la alineación de PK en el flujo de cobro (C1), pero no implementa el cambio de reversa (C2) que el propio PR describe |
| **Alcance** | Alineación de identidad operativa del débito 503 en `GE_MOVIMIENTOS` |
| **Crítico** | Sí (`OBLIGATORIO=S`, `COD_PROCESO=10`, `NRO_ORDEN=114`) |

### Métricas de Severidad

| Severidad | Color | Cantidad | Estado |
|---|---|---:|---|
| Critical Issues | 🔴 | 1 | Requiere corrección o aclaración |
| Improvements | 🟡 | 4 | Mejorar |
| Good Practices | 🟢 | 3 | Mantener |

| Dimensión | Estado | Observación |
|---|---|---|
| Registro en malla (GE_PROCESOS_DET) | 🟢 | `COD_PROCESO=10` \| `NRO_ORDEN=114` \| `OBLIGATORIO=S` \| `ACTIVO=S` |
| Impacto cruzado | 🟡 | `GE_MOVIMIENTOS` compartida por ciclos 7/10/11/12; UPDATE con `INSTR` ya fue solicitado y refinado por revisor humano |
| Trazabilidad Jira/PR | 🔴 | Cursor `C2` no modificado pese a descripción del PR |
| Naming & Style (ITGF) | 🟡 | Falta calificación `IT.` en `ge_movimientos` dentro del bloque nuevo |
| Error handling | 🟡 | `WHEN OTHERS` genérico sin logging en el fallback |
| Performance / Volumetria | 🟢 | No está en el top-10 de volumetría |
| Hardcode de negocio | 🟡 | Códigos de transacción (842, 740, 607) preexistentes, no introducidos por este PR |
| Higiene de variables y parámetros | 🟡 | `v_usu_pap_pre` sin inicialización explícita |
| Cambios DDL/DML (.sql) | N/A | No hay scripts `.sql` en el PR |

---

## 2. Semaforo de Severidad

| Severidad | Color | Cantidad | Estado |
|---|---|---:|---|
| Critical Issues | 🔴 | 1 | Requiere corrección o aclaración |
| Improvements | 🟡 | 4 | Mejorar |
| Good Practices | 🟢 | 3 | Mantener |

---

## 3. Critical Issues

### 🔴 Item 1 — Desvío entre el alcance declarado (PR/Jira) y el diff real: la reversa nocturna (`C2`) no fue modificada

- 📦 Objeto o bloque afectado: Cursor `C2` y su bloque de reversa (`FOR R2 IN C2 LOOP ... SELECT MAX(hora) ... FROM pr_cobros c ...`).
- 🔎 Evidencia (línea o fragmento):

	Descripción del PR:
	```text
	"La reversa nocturna (cursor C2) usa directamente la hora ya guardada en PR_COBROS_NOC,
	 eliminando la dependencia con PR_COBROS."
	```

	Diff real — el bloque `C2` no aparece en ningún hunk modificado; permanece idéntico:
	```sql
	FOR R2 IN C2 LOOP
	    v_fecha := pag_cal.fu_obt_fec_ant_hab(r2.fecha, fug_obt_ofi_usuario(r2.usu_insercion));
	    v_nro_secuencia := r2.nro_secuencia;
	    if instr(fug_obt_pardinamico('COD_USU_PAG_SER'),R2.usu_insercion)>0 then
	        v_concepto := 'Reversion.Pag.Prest.'|| R2.usu_insercion;
	        BEGIN
	           SELECT MAX(hora)
	             INTO v_hora
	             FROM pr_cobros c              -- sigue dependiendo de PR_COBROS
	            WHERE c.nro_cuenta = r2.nro_cuenta
	              AND (c.nro_cuota = r2.nro_cuota_desde)
	              AND c.fecha = v_fecha;
	           EXCEPTION
	                WHEN no_data_found THEN
	                     raise_application_error(-20000,'Error al buscar cobro para reversar '||r2.nro_cuenta);
	           END;
	           prg_rev_operacion(v_fecha, v_hora, r2.usu_insercion, ...);
	    END IF;
	END LOOP;
	```

- 📏 Regla validada o incumplida: Trazabilidad funcional Jira/PR obligatoria — validar que el cambio implementa lo pedido y no introduce desvío de alcance. El ticket CIE-1179 fue abierto porque "al reversar solo se reversa una parte (el cobro) y no el débito por no tener la misma PK" — el escenario de falla vive en el flujo de reversa (C2), que este PR no toca.
- ⚠️ Riesgo: Si el PR se mergea y el ticket se cierra en base a su descripción, el defecto original de reversa permanece sin corregir.
- 💡 Recomendación concreta: Confirmar con el autor si el cambio de C2 quedó en un commit separado o si la descripción del PR está desactualizada. Si C2 requiere cambios para cerrar CIE-1179, implementarlos en este PR o dejar explícito que el alcance real es solo C1.

---

## 4. Improvements

### 🟡 Item 1 — `WHEN OTHERS` genérico sin logging en el fallback de búsqueda de usuario

- 📦 Objeto o bloque afectado: bloque `begin...exception...end` de búsqueda de `v_usu_pap_pre`.
- 🔎 Evidencia:

	```sql
	begin
	  SELECT m.cod_usuario
	    INTO v_usu_pap_pre
	    FROM ge_movimientos m
	   WHERE m.fecha = v_fec_actual
	     AND m.hora = v_hor_cobro
	     AND m.nro_cuenta = r1.nro_cuenta
	     AND m.nro_documento3 = r1.nro_cuota_hasta
	     AND rownum = 1;
	exception
	  when others then
	    v_usu_pap_pre := r1.usu_insercion; -- Fallback de seguridad
	end;
	```

- 📏 Regla validada o incumplida: Fallback silencioso sin logging (con valor de reemplazo seguro) — el valor de respaldo es conocido y coincide con el comportamiento previo, pero no queda registro de cuándo se usó.
- ⚠️ Riesgo: MEDIO — no hay corrupción de datos, solo falta de trazabilidad para auditoría/soporte.
- 💡 Recomendación concreta:

	```sql
	exception
	  when no_data_found then
	    PRG_ACT_LOG_PROCESOS('PRP_COB_PRE_NOCTURNOS','1',trunc(sysdate),
	      to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),
	      'Movimiento 503 no encontrado para alineacion. Cta: '||r1.nro_cuenta||
	      ' - se usa identidad original como fallback.');
	    v_usu_pap_pre := r1.usu_insercion;
	end;
	```

---

### 🟡 Item 2 — `v_usu_pap_pre` sin inicialización explícita

- 📦 Objeto o bloque afectado: sección de declaración de variables.
- 🔎 Evidencia:

	```sql
	v_usu_pap_pre      ge_movimientos.cod_usuario%TYPE;
	```

- 📏 Regla validada o incumplida: Higiene de variables — estado inicial explícito.
- ⚠️ Riesgo: Bajo — el bloque exception siempre asigna un valor hoy, pero queda sin garantía ante cambios futuros.
- 💡 Recomendación concreta: `v_usu_pap_pre ge_movimientos.cod_usuario%TYPE := NULL;`

---

### 🟡 Item 3 — Falta de calificación de esquema `IT.` en `ge_movimientos`

- 📦 Objeto o bloque afectado: todo el bloque nuevo de alineación (`SELECT`/`UPDATE` sobre `ge_movimientos`).
- 🔎 Evidencia: el bloque nuevo usa `ge_movimientos` sin prefijo, mientras otra sección del mismo archivo usa `it.pr_cobros_noc`.
- 📏 Regla validada o incumplida: `itgf-standard.instructions.md` — objetos schema-qualified con `IT.`.
- ⚠️ Riesgo: Bajo — problema de consistencia de estilo, no de comportamiento.
- 💡 Recomendación concreta: Calificar como `it.ge_movimientos`, igual que ya se hace en la sección `CIE-125` del mismo procedimiento.

---

### 🟡 Item 4 — Comentario sugerido para documentar la intención del `ROWNUM=1` sin `ORDER BY`

- 📦 Objeto o bloque afectado: `SELECT ... INTO v_usu_pap_pre ... AND rownum = 1`.
- 📏 Contexto: el autor confirmó que cualquier fila coincidente es funcionalmente equivalente para este caso de uso — **no es un defecto**.
- 💡 Recomendación concreta (opcional, solo legibilidad): agregar un comentario breve junto al `ROWNUM = 1` indicando que la selección es intencionalmente no determinista (ej. `-- cualquier fila coincidente es valida, no se requiere orden especifico`), para que futuros revisores no lo reinterpreten como bug.

---

## 5. Good Practices

### 🟢 Item 1 — `INSTR` sobre `concepto` en reemplazo de `LIKE` (pedido explícito de revisor)

- 📦 Objeto o bloque afectado: `UPDATE` de alineación del débito.
- 🔎 Evidencia:

	```sql
	and instr(m.concepto, r1.nro_cuenta) > 0;
	```

- 📏 Contexto: este cambio fue un pedido explícito de un revisor humano para reemplazar el uso previo de `LIKE`. `INSTR` es más explícito y eficiente que `LIKE '%...%'` para búsqueda de substring.
- 💡 Patrón correcto: implementación fiel a lo solicitado; mejora sobre el comportamiento anterior, no un defecto introducido por este PR.

---

### 🟢 Item 2 — Comentario aclaratorio sobre parámetro `IN OUT`

- 📦 Objeto o bloque afectado: llamada a `pap_pre.pr_cob_prestamo(...)`.
- 🔎 Evidencia: `v_hor_cobro, -- ESTE PARAMETRO ES IN OUT (Devuelve la nueva hora generada)`.
- 💡 Patrón correcto: documenta comportamiento no evidente en el código, reduce riesgo de interpretaciones erróneas futuras.

---

### 🟢 Item 3 — Idempotencia de `PR_COBROS_NOC` preservada

- 📦 Objeto o bloque afectado: `UPDATE PR_COBROS_NOC ... WHERE ESTADO = 'I' AND rowid = r1.registro`.
- 💡 Patrón correcto: el filtro por `ESTADO='I'` + `rowid` garantiza que una reejecución no reprocese registros ya marcados `'P'`. No modificado por este PR, se mantiene correcto.

---

## 6. Impacto Cruzado

| Tabla (WRITE) | Programas en malla que la usan | Ciclo | OBLIGATORIO | Riesgo |
|---|---|---|---|---|
| `GE_MOVIMIENTOS` | Tabla de movimientos contable compartida (ciclos 7, 10, 11, 12) | 7/10/11/12 | S | 🟡 Medio — el `UPDATE` usa `INSTR` sobre `concepto` (pedido explícito de revisor), acotado por `fecha+hora+usuario`; riesgo residual bajo de coincidencia parcial de substring |
| `PR_COBROS_NOC` | `PRP_COB_PRE_NOCTURNOS` (único escritor identificado) | 10 | S | 🟢 Controlado — filtro por `rowid` y `estado` |

---

## 7. Comentarios de Revisores (GitHub)

| Autor | Solicitud (resumen) | Estado | Evidencia |
|---|---|---|---|
| maria-valenzuela_gvz | Usar `INSTR` en vez de `LIKE` para recuperar el débito (hora, usuario, concepto) | 🟢 **Aplicado** | `instr(m.concepto, r1.nro_cuenta) > 0` |
| maria-valenzuela_gvz | Derivar hora vía `pr_cobros` + `MAX(nro_secuencia)` real de `ge_movimientos` antes de asignar nueva secuencia | 🔴 **Pendiente** | Ver seguimiento; no bloquea el veredicto (informativo) |

**Nota:** Sección informativa. No altera el veredicto de merge, que depende del semáforo técnico (sección 2).

---

## Supuestos

- El autor confirmó que la selección `ROWNUM=1` sin `ORDER BY` es intencional (cualquier fila coincidente es equivalente); se documenta como aclaración de negocio, no como hallazgo técnico.
- El uso de `INSTR` en vez de `LIKE` fue un pedido explícito de un revisor humano; se reclasifica como Good Practice.
- No se pudo verificar en vivo si el cambio de cursor `C2` quedó en un commit separado; se recomienda confirmar con el autor antes de mergear.

---

**Reporte generado:** 2026-08-14 | **Revisor:** GitHub Copilot CB PL/SQL Reviewer
**PR:** #42 | **Ticket:** CIE-1179
