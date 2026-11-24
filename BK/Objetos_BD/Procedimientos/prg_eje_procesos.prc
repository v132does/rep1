CREATE OR REPLACE PROCEDURE IT.PRG_EJE_PROCESOS
(P_FECHA IN GE_CALENDARIOS.FEC_ACTUAL%TYPE
,P_TIP_PROCESO IN VARCHAR2 := 'I'
,P_COD_PROCESO IN NUMBER := NULL
)
IS
   v_cod_proceso ge_procesos_det.cod_proceso%type;
   v_frecuencia  ge_procesos_det.frecuencia%type;
   v_hor_fin     ge_procesos.hor_fin%type;
   v_descripcion ge_procesos.descripcion%type;
   v_error       varchar2(1000);
   bv_error        BOOLEAN;
   v_pro_pendiente NUMBER;
   v_job_name      VARCHAR2(25);
   v_contexto      VARCHAR2(12); --'SECUENCIAL', 'JOB_PARALELO'
   v_log_level     VARCHAR2(5) := fug_obt_pardinamico('PAG_CIE_LOG_LEVEL'); --'OFF', 'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'
   v_err_pro_paralelo  VARCHAR2(50) := NULL;
   v_modo_lock     VARCHAR2(9) := NVL(fug_obt_pardinamico('PAG_CIE_MODO_LOCK'),'OFF'); --'OFF', 'X_MODE'
   v_pro_lock      VARCHAR2(128):= NVL(fug_obt_pardinamico('PRO_EJE_PROCESOS_LOCK'),'7,10,11,12,320');
   v_lock_desc     VARCHAR2(128);
   v_lock_id       VARCHAR2(128);
   v_candado       INTEGER := -1;

   --- Cursor de procesos a ser ejecutados
   cursor c_procesos is
   select cod_proceso, nro_orden, obligatorio,
          hor_inicio, hor_fin, cod_usuario, tipo
     from ge_procesos
    where hor_fin is null
      and tipo = p_tip_proceso
      and (cod_proceso = p_cod_proceso or p_cod_proceso is null)
    order by nro_orden;
   --- Cursor de procesos detalles
   cursor c_procesos_det is
   select cod_proceso, cod_programa, obligatorio, frecuencia, nro_orden, hor_inicio, error
     from ge_procesos_det
    where cod_proceso = v_cod_proceso
      and hor_fin is null
      and (   frecuencia = v_frecuencia
          or (v_frecuencia = 'M' and frecuencia = 'D'))
      and activo = 'S' --sólo toma los activos
    order by nro_orden;
   v_ult_dia_habil ge_calendarios.ult_dia_mes_habil%type;

BEGIN
   -- Evaluar orquestación externa a Oracle (configuración dinámica de Procesos)
   IF 'SI' = pag_cie.FN_OCO_EN_EJECUCION(p_cod_proceso) THEN
      pag_cie.PR_AT_INS_LOG(
         p_cod_proceso, 0, 'PRG_EJE_PROCESOS',
         'El proceso se encuentra actualmente en orquestación externa a Oracle',
         pag_cie.c_log_DEBUG, 'ORQUESTADOR', pag_cal.FU_OBT_FEC_ACTUAL(1)
      );
      RAISE_APPLICATION_ERROR(-20099, 'El proceso se encuentra actualmente en orquestación externa a Oracle.');
   END IF;

   -- Se nombra el candado lógico
   v_lock_desc := 'CIE$'||'PRG_EJE_PROCESOS_'||p_cod_proceso;

   -- Sólo para los Procesos parametrizados en el parámetro PRO_EJE_PROCESOS_LOCK. 
   -- Se evalúa el uso del mecanismo de exclusión mutua, para el control global de concurrencia
   IF INSTR(','||v_pro_lock||',', ','||NVL(p_cod_proceso, 0)||',') > 0  AND v_modo_lock = 'X_MODE' THEN
      -- Se crea un identificador de bloqueo único
      DBMS_LOCK.ALLOCATE_UNIQUE_AUTONOMOUS(
         lockname        => v_lock_desc, 
         lockhandle      => v_lock_id,
         expiration_secs => (2*24*60*60)  -- 2 días (desde la última operación de bloqueo) antes de ser depurado de SYS.DBMS_LOCK_ALLOCATED
      );

      -- Se intenta adquirir el bloqueo (modo exclusivo, timeout 0 segundos)
      v_candado := DBMS_LOCK.REQUEST(
         lockhandle        => v_lock_id,
         lockmode          => DBMS_LOCK.X_MODE,
         timeout           => 0,
         release_on_commit => FALSE
      );

      IF v_candado = 0 THEN
         pag_cie.PR_AT_INS_LOG(
            p_cod_proceso, 0, 'PRG_EJE_PROCESOS',
            'LOCK exclusivo '||v_lock_desc||' '||pag_cie.FU_OBT_ENTORNO,
            pag_cie.c_log_DEBUG, 'ORQUESTADOR', pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
      ELSE
         pag_cie.PR_AT_INS_LOG(
            p_cod_proceso, 0, 'PRG_EJE_PROCESOS',
            'RECHAZO LOCK exclusivo '||v_lock_desc||' '||pag_cie.FU_OBT_ENTORNO,
            pag_cie.c_log_DEBUG, 'ORQUESTADOR', pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
         -- Ya hay otra sesión ejecutando el SP
         RAISE_APPLICATION_ERROR(-20047, 'Existe otra sesión ejecutando el proceso '||p_cod_proceso||'. No se permite su ejecución concurrente.');
      END IF;
   END IF;

   -- Obtiene la fecha del calendario
   pag_cal.pr_obt_dat_calendar(1);
   v_ult_dia_habil   := pag_cal.G_ULT_DIA_MES_HABIL;
   --- Calcular frecuencia del proceso
   if p_fecha = v_ult_dia_habil then
      v_frecuencia := 'M';
   else
      v_frecuencia := 'D';
   end if;
   for r_pro in c_procesos loop
      v_cod_proceso := r_pro.cod_proceso;
      if nvl(p_tip_proceso,'X') <> 'N' then  -- SINO ES INDEPENDIENTe
          --- Verificar proceso previo
         BEGIN
             select hor_fin, descripcion
               into v_hor_fin, v_descripcion
               from ge_procesos
              where tipo      = r_pro.tipo
                and nro_orden = (select max(nro_orden)
                                   from ge_procesos
                                  where tipo = r_pro.tipo
                                    and nro_orden < r_pro.nro_orden
                                    and obligatorio = 'S')
                and rownum = 1;
             if v_hor_fin is null then
                raise_application_error(-20000,
                'Proceso previo '||v_descripcion||' no ejecutado');
             end if;
          exception
             when no_data_found then
                null;
         END;
      end if;
      --- Actualizar hora inicio del proceso y usuario
      update ge_procesos
         set hor_inicio = to_char(sysdate,'hh24:mi:ss'), cod_usuario = user, error = null
       where cod_proceso = r_pro.cod_proceso
         and hor_inicio is null;
      v_error := null;
      commit;
      BEGIN --- Para poder tomar el raise
         bv_error := false;
         --- Ejecutar el proceso, Obs: No se ejecuta un proceso si el anterior
         --- no se ha finalizado con exito a excepcion de los no obligatorios
         --- Leer sub-procesos
         for r_det in c_procesos_det loop
            v_contexto := pag_cie.c_ctx_SECUENCIAL; --'SECUENCIAL'
            v_job_name := pag_cie.FN_JOB_NOMBRAR(r_det.cod_proceso, r_det.nro_orden);

            --- Previa ejecución de cada Programa, se evalúa si algún Programa Paralelo del Proceso ha finalizado en error.
            v_err_pro_paralelo := pag_cie.FU_OBT_PRO_ERR_PARALELO(r_det.cod_proceso);
            IF v_err_pro_paralelo IS NOT NULL AND r_det.nro_orden != REGEXP_SUBSTR(v_err_pro_paralelo, '\[(.*?)\]', 1, 1, NULL, 1) THEN
               v_error := pag_cie.c_msj_ERR_PRO_PARALELO;
               bv_error := TRUE;
               EXIT;
            END IF;

            --- Se evalúan Dependencias 'F' de FIN DE PROGRAMAS PREVIOS
            IF 'SI' = pag_cie.FN_VER_DEPENDENCIA(r_det.cod_proceso, r_det.cod_programa, 'F') THEN
               --- Verificar que todas las dependencias de Fin de Programa Previo están resueltas
               SELECT COUNT(1)
               INTO v_pro_pendiente
               FROM GE_PROCESOS_DEP dep
               WHERE dep.cod_proceso = r_det.cod_proceso
                 AND dep.cod_programa = r_det.cod_programa
                 AND tipo = 'F'
                 AND EXISTS ( SELECT 1
                              FROM ge_procesos_det pasos
                              WHERE pasos.cod_proceso = dep.cod_proceso_pre
                                AND pasos.cod_programa = dep.cod_programa_pre
                                AND pasos.hor_fin IS NULL
                                AND pasos.activo = 'S'
                                AND ( pasos.frecuencia = v_frecuencia OR (v_frecuencia = 'M' and frecuencia = 'D'))
                 )
                 AND ROWNUM = 1;

               IF v_pro_pendiente != 0 THEN
                  v_error := pag_cie.c_msj_DEP_F_NO_RESUELTA;
                  UPDATE ge_procesos_det
                  SET error = v_error
                  WHERE cod_proceso = r_det.cod_proceso
                    AND nro_orden = r_det.nro_orden;
                  bv_error := TRUE;
                  EXIT;
               END IF;
            END IF;

            --> Hasta el momento, no existe caso de uso con Dependencia 'C' de CONTROL
            --- Se evalúan Dependencias 'C' de CONTROL
            ----IF 'SI' = pag_cie.FN_VER_DEPENDENCIA(r_det.cod_proceso, r_det.cod_programa, 'C') THEN
            ----   --- Se resuelven las Dependencias
            ----   IF 0 != pag_cie.FN_CTR_PROGRAMA(r_det.cod_programa) THEN
            ----      v_error := 'Dependencia de Control no resuelta.';
            ----      UPDATE ge_procesos_det
            ----      SET error = v_error
            ----      WHERE cod_proceso = r_det.cod_proceso
            ----        AND nro_orden = r_det.nro_orden;
            ----      bv_error := TRUE;
            ----      EXIT;
            ----   END IF;
            ----END IF;

            --- Se evalúan Dependencias 'P' de PARALELISMO según PROGRAMAS PREDECESORES
            IF 'SI' = pag_cie.FN_VER_DEPENDENCIA(r_det.cod_proceso, r_det.cod_programa, 'P') THEN
               --- Verificar que todas las dependencias de Paralelismo según Programas Predecesores están resueltas
               SELECT COUNT(1)
               INTO v_pro_pendiente
               FROM GE_PROCESOS_DEP dep
               WHERE dep.cod_proceso = r_det.cod_proceso
                 AND dep.cod_programa = r_det.cod_programa
                 AND tipo = 'P'
                 AND EXISTS ( SELECT 1
                              FROM ge_procesos_det pasos
                              WHERE pasos.cod_proceso = dep.cod_proceso_pre
                                AND pasos.cod_programa = dep.cod_programa_pre
                                AND pasos.hor_fin IS NULL
                                AND pasos.activo = 'S'
                                AND ( pasos.frecuencia = v_frecuencia OR (v_frecuencia = 'M' and frecuencia = 'D'))
                 )
                 AND ROWNUM = 1;

               IF v_pro_pendiente != 0 THEN
                  v_error := 'Dependencia de Paralelismo según Programa Predecesor no resuelta.';
                  UPDATE ge_procesos_det
                  SET error = v_error
                  WHERE cod_proceso = r_det.cod_proceso
                    AND nro_orden = r_det.nro_orden;
                  bv_error := TRUE;
                  EXIT;
               END IF;

               --- Si el Programa se ha iniciado previamente, se debe verificar que su ejecución haya finalizado
               IF r_det.hor_inicio IS NOT NULL THEN
                  IF 'SI' = pag_cie.FN_JOB_EN_EJECUCION(v_job_name) THEN
                     --- Si la ejecución en paralelo aún continúa seguimos iterando Programas. El Proceso puede tener oportunidad de continuar.
                     --- La configuración de una Dependencia 'F' de FIN DE PROGRAMA PREVIO debe controlar aquellos casos que no pueden continuar.
                     pag_cie.PR_AT_INS_LOG(
                        r_det.cod_proceso, 0, 'PRG_EJE_PROCESOS',
                        'Job '||v_job_name||' aún en ejecución. Continúa la iteración de Programas. '||pag_cie.FU_OBT_ENTORNO,
                        pag_cie.c_log_DEBUG, 'ORQUESTADOR', pag_cal.FU_OBT_FEC_ACTUAL(1)
                     );
                     CONTINUE;
                  ELSE
                     pag_cie.PR_AT_INS_LOG(
                        r_det.cod_proceso, 0, 'PRG_EJE_PROCESOS',
                        'Job '||v_job_name||' NO está en ejecución. Se continúa evaluando el contexto de re-ejecución. '||pag_cie.FU_OBT_ENTORNO,
                        pag_cie.c_log_DEBUG, 'ORQUESTADOR', pag_cal.FU_OBT_FEC_ACTUAL(1)
                     );
                  END IF;

                  IF 'NO' = pag_cie.FU_JOB_SIN_PARALELISMO(r_det.cod_proceso, r_det.cod_programa, r_det.error) THEN
                     --- Un Programa se ejecutará como JOB concurrente si:
                     --- * tiene configurada al menos una dependencia 'P'
                     --- * se ejecuta por i-ésima vez, donde su última ejecución registró un error que no desactiva su posibilidad de paralelismo
                     --- * y todas sus dependencias se encuentran resueltas Ok
                     v_contexto := pag_cie.c_ctx_JOB_PARALELO; --'JOB_PARALELO'
                  END IF;
               ELSE
                  --- Un Programa se ejecutará como JOB concurrente si:
                  --- * tiene configurada al menos una dependencia 'P'
                  --- * se ejecuta por primera vez
                  --- * y todas sus dependencias se encuentran resueltas Ok
                  v_contexto := pag_cie.c_ctx_JOB_PARALELO; --'JOB_PARALELO'
               END IF;
            END IF;

            --- Se ejecuta el Programa según modo de ejecución: 'SECUENCIAL' o 'JOB_PARALELO'
            IF v_contexto = pag_cie.c_ctx_JOB_PARALELO THEN
               BEGIN
                  -- Dependencias resueltas, lanzar job
                  DBMS_SCHEDULER.CREATE_JOB (
                     job_name        => v_job_name,
                     start_date      => SYSTIMESTAMP,
                     repeat_interval => NULL,
                     auto_drop       => TRUE,
                     job_type        => 'PLSQL_BLOCK',
                     enabled         => TRUE,
                     job_action      => 'DECLARE v_error VARCHAR2(1000); BEGIN it.pag_cie.PR_EJE_PRO_PROGRAMA('||r_det.cod_proceso||', '||r_det.nro_orden||', '''||r_det.cod_programa||''', '''||v_contexto||''', '''||v_log_level||''', v_error); END;'
                  );

                  --- Se garantiza el inicio del Programa Paralelo antes de continuar
                  --- Se espera máximo 6 segundos. Si no inició, se interrumpe la ejecución
                  FOR i IN 1 .. 6 LOOP
                     DBMS_SESSION.SLEEP(1);

                     SELECT COUNT(1)
                     INTO v_pro_pendiente
                     FROM ge_procesos_det
                     WHERE cod_proceso = r_det.cod_proceso
                       AND nro_orden = r_det.nro_orden
                       AND error = pag_cie.c_msj_PRO_P_EN_EJECUCION;

                     EXIT WHEN v_pro_pendiente != 0;
                  END LOOP;

                  IF v_pro_pendiente = 0 THEN
                     raise_application_error(-20009, 'No se logró validar el inicio del JOB '||v_job_name);
                  END IF;
               EXCEPTION
                  WHEN OTHERS THEN
                     v_error := SQLERRM;
                     UPDATE ge_procesos_det
                     SET --hor_inicio = to_char(sysdate, 'hh24:mi:ss'),
                         error = v_error
                     WHERE cod_proceso = r_det.cod_proceso
                       AND nro_orden = r_det.nro_orden;
                     bv_error := TRUE;
                     EXIT;
               END;
            ELSE --- Ejecución 'SECUENCIAL' en sesión principal
               BEGIN
                  it.pag_cie.PR_EJE_PRO_PROGRAMA (
                     r_det.cod_proceso,
                     r_det.nro_orden,
                     r_det.cod_programa,
                     v_contexto,
                     v_log_level,
                     v_error
                  );
                  IF v_error IS NOT NULL THEN
                     bv_error := TRUE;
                  END IF;
               EXCEPTION
                  WHEN OTHERS THEN
                     bv_error := TRUE;
               END;
            END IF;
            
            --- Si hubo error en el proceso obligatorio salir del loop
            if bv_error then
               exit;
            end if;
         end loop;
         if bv_error then
            update ge_procesos
            set error = v_error
            where cod_proceso = r_pro.cod_proceso;
            commit;
            --if r_pro.obligatorio = 'S' then
               -- Cortar proceso si es obligatorio
               bv_error := true;
               exit;
            --end if;
         end if;
      exception
         when others then
            update ge_procesos
            set error = v_error
            where cod_proceso = r_pro.cod_proceso;
            commit;
            --if r_pro.obligatorio = 'S' then
               -- Cortar proceso si es obligatorio
               bv_error := true;
               exit;
            --end if;
      END;
      --- Si hubo error en el proceso obligatorio terminar la ejecución.
      if bv_error then
         return;
      end if;
      --- Actualizar fecha fin del proceso
      If v_error is null then
         -- Solo si termino con exito le pone la fecha fin.
         update ge_procesos
            set hor_fin = to_char(sysdate,'hh24:mi:ss'), error = v_error
          where cod_proceso = r_pro.cod_proceso;
         commit;
      End if;
   end loop;

   -- Si obtuve el candado, libero el bloqueo
   IF v_candado = 0 THEN
      v_candado := DBMS_LOCK.RELEASE(v_lock_id);
      pag_cie.PR_AT_INS_LOG(
         p_cod_proceso, 0, 'PRG_EJE_PROCESOS',
         'UNLOCK exclusivo '||v_lock_desc||' '||v_candado,
         pag_cie.c_log_DEBUG, 'ORQUESTADOR', pag_cal.FU_OBT_FEC_ACTUAL(1)
      );
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      -- Si obtuve el candado, libero el bloqueo
      IF v_candado = 0 THEN
         v_candado := DBMS_LOCK.RELEASE(v_lock_id);
         pag_cie.PR_AT_INS_LOG(
            p_cod_proceso, 0, 'PRG_EJE_PROCESOS',
            'UNLOCK exclusivo en EXCEPTION '||v_lock_desc||' '||v_candado,
            pag_cie.c_log_DEBUG, 'ORQUESTADOR', pag_cal.FU_OBT_FEC_ACTUAL(1)
         );
      END IF;

      RAISE;
END;
/
