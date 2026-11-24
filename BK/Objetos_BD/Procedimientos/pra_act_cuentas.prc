CREATE OR REPLACE PROCEDURE IT.PRA_ACT_CUENTAS
 IS
 /* Proceso de Actualizacion de saldos y estados batch de Cuentas. Este proceso, en primer lugar genera los
    movimientos resumidos por cuenta, para luego actualizar los datos batch de las cuentas, lo cual permite
    que el bloqueo de las cuentas permanezcan bloqueadas un minimo de tiempo.
 */
V_COD_MODULO      GE_MOVIMIENTOS.COD_MODULO%TYPE;
V_COD_MODALIDAD   GE_MOVIMIENTOS.COD_MODALIDAD%TYPE;
V_SENTENCIA       VARCHAR2(240);
V_COD_TRANSACCION GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_COD_MONEDA      GE_MOVIMIENTOS.COD_MONEDA%TYPE;
V_AFECTA          GE_TRANSACCIONES.AFECTA%TYPE;
V_NOM_RUTINA1     VARCHAR2(1000);
V_DETALLE         GE_TRANSACCIONES.TIPO%TYPE;
V_MSJ_ERROR       VARCHAR2(1000);
V_COD_OFICINA     GE_MOVIMIENTOS.COD_OFICINA%TYPE;
V_NRO_CUENTA      GE_MOVIMIENTOS.NRO_CUENTA%TYPE;
V_MONTO           GE_MOVIMIENTOS.MONTO%TYPE;
V_EST_CUENTA      GE_MOVIMIENTOS.EST_CUENTA%TYPE;
V_FEC_VALOR       GE_MOVIMIENTOS.FEC_VALOR%TYPE;
V_REVERSADO       GE_MOVIMIENTOS.REVERSADO%TYPE;
V_ROWID            VARCHAR2(1000);
--DYDMR-10076 Incidencia SAU - ITGF - Error Cierre
v_val_parametro   ge_par_dinamicos.val_parametro%type:= nvl(fug_obt_pardinamico('NRO_CTA_EXC_ACTUALIZACION'),'0');
v_act_sal_modo    ge_par_dinamicos.val_parametro%type:= nvl(fug_obt_pardinamico('ACT_SALDOS_PARALLEL'), 'NORMAL');
v_tam_fragmento   ge_par_dinamicos.val_parametro%type:= nvl(fug_obt_pardinamico('ACT_SALDOS_TAM_FRAG'), '25000');
v_job_cant        ge_par_dinamicos.val_parametro%type:= nvl(fug_obt_pardinamico('ACT_SALDOS_JOB_CANT'), '6');
v_tarea           VARCHAR2(128) := 'act_sal_batch_PARALELO';
v_ree_tarea       VARCHAR2(10) := 'REENGANCHE';
v_est_tarea       PLS_INTEGER;
v_can_pro_frag    PLS_INTEGER;
-- BSEVOCORE-274 Optimización de tiempos de procesamiento - PRA_ACT_CUENTAS NAF 2019/11
v_horIni          varchar(10);
v_horFin          varchar(10);
v_nro_seq         number(12);
v_men_error       varchar2(400);
v_log_detallado   varchar2(1) := 'N';
v_procesar        varchar2(1); --PDSB-464
v_can_reg         number(10):=0;--PDSB-464
v_can_mov         number(10):=0;
v_can_pro         number(10):=0;
v_cont_bloqueos   number := 0; --contador de registros bloqueados
v_max_bloqueos    number := 10;--cantidad de bloqueos permitidos

-- Cursor2: Resumen de movimientos por Cuenta
CURSOR CURSOR2 IS
   SELECT COD_MODULO, COD_MODALIDAD, COD_OFICINA, NRO_CUENTA, nvl(MONTO,0) monto,
          EST_CUENTA, FEC_VALOR,  REVERSADO, COD_TRANSACCION, COD_MONEDA,RUTINA1,TIPO,AFECTA, ROWID
     FROM GE_MOVIMIENTOS_RES
   WHERE  instr(v_val_parametro, nro_cuenta) = 0 --DYDMR-10076
    AND  PROCESADO='N'  --PDSB-464
    AND RUTINA1 != 'PRA_ACT_SAL_BATCH'
    ORDER BY NRO_CUENTA, FEC_MAX_INSERCION;

TYPE cursor2_type IS TABLE OF CURSOR2%ROWTYPE;
              reg2 cursor2_type;
--PDSB-464
procedure pr_act_est_movimiento is
   PRAGMA AUTONOMOUS_TRANSACTION;
begin
   UPDATE GE_MOVIMIENTOS_RES
         SET PROCESADO='S'
       WHERE ROWID = v_rowid;
       commit;
exception
    when others then
        null;
end;

   PROCEDURE lp_gen_fragmentos IS
   BEGIN
      -- Creamos la tarea. Si existe, la eliminamos junto con todos sus fragmentos
      BEGIN
         DBMS_PARALLEL_EXECUTE.DROP_TASK(task_name => v_tarea);
      EXCEPTION
         WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
            NULL;
      END;
      DBMS_PARALLEL_EXECUTE.create_task(task_name => v_tarea);

      -- Fragmentamos la Tarea asegurando que un mismo NRO_CUENTA no aparecerá en más de un fragmento
      DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_SQL(
         task_name => v_tarea,
         by_rowid  => true,
         sql_stmt  => 'WITH distinct_nro_cuenta AS (
                          SELECT DISTINCT nro_cuenta
                          FROM ge_movimientos_res
                       ),
                       cte_numerada AS (
                          SELECT nro_cuenta,
                                 FLOOR((ROW_NUMBER() OVER (ORDER BY nro_cuenta) - 1) / '||v_tam_fragmento||') + 1 AS fragmento
                          FROM distinct_nro_cuenta
                       ),
                       cte_fragmentos AS (
                          SELECT MIN(nro_cuenta) AS min_nro_cuenta,
                                 MAX(nro_cuenta) AS max_nro_cuenta
                          FROM cte_numerada
                          GROUP BY fragmento
                       )
                       SELECT (SELECT ROWID FROM ge_movimientos_res WHERE nro_cuenta = min_nro_cuenta AND ROWNUM = 1) AS start_rowid,
                              (SELECT ROWID FROM ge_movimientos_res WHERE nro_cuenta = max_nro_cuenta AND ROWNUM = 1) AS end_rowid
                       FROM cte_fragmentos'
      );
   END lp_gen_fragmentos;
   ---mensaje de errores---
   FUNCTION lf_error_bloqueos(p_mensaje VARCHAR2) RETURN BOOLEAN IS
        v_mensaje VARCHAR2(4000);
    BEGIN
        v_mensaje := UPPER(p_mensaje);
        
        IF (INSTR(v_mensaje, 'BLOQUEADO') > 0) OR
           (INSTR(v_mensaje, 'RECURSO OCUPADO') > 0) OR
           (INSTR(v_mensaje, 'INTERBLOQUEO') > 0) OR
           (INSTR(v_mensaje, 'DEADLOCK') > 0) OR 
           (INSTR(v_mensaje, 'TIMEOUT') > 0) THEN           
           RETURN TRUE;
        END IF;        
        RETURN FALSE;
    END;
BEGIN
  v_nro_seq := nvl(v_nro_seq,0) + 1;
  ---
  v_msj_error   := ' ';

  v_nro_seq := nvl(v_nro_seq,0) + 1;
  v_horIni := to_char(sysdate,'hh24:mi:ss');
  --
  --conteo de ge_movimientos 
  SELECT COUNT(*)
    into v_can_mov
    FROM (
        SELECT 1
        FROM GE_MOVIMIENTOS A
        INNER JOIN GE_TRANSACCIONES T
            ON A.COD_TRANSACCION = T.COD_TRANSACCION
            AND A.COD_MODULO = T.COD_MODULO
            AND A.COD_MODALIDAD = T.COD_MODALIDAD
        WHERE A.COD_TRANSACCION > 0
          AND A.ESTADO = 'N'
          AND A.NRO_CUENTA IS NOT NULL
          AND INSTR(v_val_parametro, A.NRO_CUENTA) = 0
          AND T.RUTINA1 IS NOT NULL
        GROUP BY A.FEC_VALOR, A.NRO_CUENTA, A.REVERSADO, A.COD_TRANSACCION, A.COD_MONEDA, T.RUTINA1, T.TIPO, T.AFECTA);
  --conteo de ge_movimientos_res
  select count(*)
  into v_can_reg
  from GE_MOVIMIENTOS_RES
  where procesado='N';
  
  ---conteo si hay registros procesados
  select count(*)
  into v_can_pro
  from GE_MOVIMIENTOS_RES
  where procesado='S';
  
   IF 'PARALLEL_EXECUTE' = v_act_sal_modo THEN
      BEGIN
         v_est_tarea := DBMS_PARALLEL_EXECUTE.TASK_STATUS(v_tarea);
         
         SELECT COUNT(1)
         INTO v_can_pro_frag
         FROM user_parallel_execute_chunks
         WHERE task_name = v_tarea
           AND status = 'PROCESSED';
      EXCEPTION
         WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
            v_can_pro_frag := 0;
            v_est_tarea := DBMS_PARALLEL_EXECUTE.FINISHED;
      END;

      ---sumo/resto los fragmentos de RUTINA1 procesados con DBMS_PARALLEL_EXECUTE
      IF DBMS_PARALLEL_EXECUTE.FINISHED != v_est_tarea THEN
         v_can_pro := v_can_pro + v_can_pro_frag;
         v_can_reg := v_can_reg - v_can_pro_frag;
      END IF;
      IF DBMS_PARALLEL_EXECUTE.FINISHED = v_est_tarea AND v_can_reg > 0 THEN
         v_can_pro := v_can_pro + v_can_pro_frag;
         v_can_reg := v_can_reg - v_can_pro_frag;
         v_ree_tarea := 'FIN';
      END IF;
   END IF;

  if v_can_reg = v_can_mov or v_can_pro > 0 then
     v_procesar:='S';
  else
    it.prg_gen_mov_resumen; --reprocesar
    v_procesar:='S';

   IF 'PARALLEL_EXECUTE' = v_act_sal_modo THEN
      BEGIN
         -- Se crea la tarea, y sus fragmentos, para el uso de DBMS_PARALLEL_EXECUTE
         lp_gen_fragmentos;
         v_ree_tarea := 'INICIO';
      EXCEPTION
         WHEN OTHERS THEN
            pag_cie.PR_INS_LOG('El parámetro dinámico ACT_SALDOS_PARALLEL cambia a ''NORMAL'' para no interrumpir la ejecución', pag_cie.c_log_INFO, 'AUTONOMOUS_TRANSACTION');

            -- Ante cualquier error, se desactiva el uso de DBMS_PARALLEL_EXECUTE
            UPDATE ge_par_dinamicos
            SET val_parametro = 'NORMAL'
            WHERE parametro = 'ACT_SALDOS_PARALLEL';

            COMMIT;
            v_act_sal_modo := 'NORMAL';
      END;
   END IF;
  end if;

  BEGIN 
      v_nro_seq := nvl(v_nro_seq,0) + 1;
      PRG_ACT_LOG_PROCESOS('PRA_ACT_CUENTAS',v_nro_seq,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),'Lanza PRG_ACT_SAL_BATCH. '||
                           'Modo '||CASE WHEN v_act_sal_modo = 'PARALLEL_EXECUTE' THEN 'PARALLEL_EXECUTE en '||v_ree_tarea ELSE v_act_sal_modo END);

      IF 'PARALLEL_EXECUTE' = v_act_sal_modo THEN
         -- Actualizamos los saldos batch en Paralelo
         IF v_ree_tarea = 'REENGANCHE' THEN
            DBMS_PARALLEL_EXECUTE.resume_task(
               task_name      => v_tarea
            );
         ELSIF v_ree_tarea = 'INICIO' THEN
            DBMS_PARALLEL_EXECUTE.run_task(
               task_name      => v_tarea,
               sql_stmt       => 'DECLARE
                                     min_nro_cuenta  ge_movimientos_res.NRO_CUENTA%TYPE;
                                     max_nro_cuenta  ge_movimientos_res.NRO_CUENTA%TYPE;
                                     v_info          VARCHAR2(512);
                                  BEGIN
                                     pag_cie.PR_SET_PARAMETROS(11, 368, ''PRA_ACT_CUENTAS'', ''CHUNK'', pag_cie.c_log_TRACE);

                                     SELECT nro_cuenta
                                     INTO min_nro_cuenta
                                     FROM ge_movimientos_res
                                     WHERE ROWID = :start_id;

                                     SELECT nro_cuenta
                                     INTO max_nro_cuenta
                                     FROM ge_movimientos_res
                                     WHERE ROWID = :end_id;

                                     SELECT ''{job:''||job_name||'' chid:''||chunk_id||''}''
                                     INTO v_info
                                     FROM user_parallel_execute_chunks
                                     WHERE start_rowid = :start_id
                                     AND end_rowid = :end_id;

                                     pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] [ ''||min_nro_cuenta||'' ; ''||max_nro_cuenta||'' ]'', pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');

                                     PRG_ACT_SAL_BATCH(min_nro_cuenta, max_nro_cuenta);

                                  EXCEPTION
                                     WHEN OTHERS THEN
                                        pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] [ ''||min_nro_cuenta||'' ; ''||max_nro_cuenta||'' ] EXCEPTION: ''||SQLERRM, pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');
                                        RAISE;
                                  END;',
               language_flag  => DBMS_SQL.NATIVE,
               parallel_level => TO_NUMBER(v_job_cant)
            );
         ELSE
            --FIN Rutina1
            NULL;
         END IF;

         IF DBMS_PARALLEL_EXECUTE.FINISHED != DBMS_PARALLEL_EXECUTE.TASK_STATUS(v_tarea) THEN
            raise_application_error(-20000, 'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ' || v_tarea);
         END IF;
      ELSE
         --Actualizamos los saldos batch
         PRG_ACT_SAL_BATCH;
      END IF;
      
      v_nro_seq := nvl(v_nro_seq,0) + 1;    
      PRG_ACT_LOG_PROCESOS('PRA_ACT_CUENTAS',v_nro_seq,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),'Finalizó PRG_ACT_SAL_BATCH');

  END;
  
   --logueo
   v_nro_seq := nvl(v_nro_seq,0) + 1;
   PRG_ACT_LOG_PROCESOS('PRA_ACT_CUENTAS',v_nro_seq,trunc(sysdate),to_char(sysdate,'hh24:mi:ss'), to_char(sysdate,'hh24:mi:ss'),'7-Inicia Cursor 2');

  ---5.- Leyendo el resumen de movimientos GE_MOVIMIENTOS_RES para que el bloqueo dure menos
  if v_procesar ='S' then
   IF CURSOR2%ISOPEN THEN
      CLOSE CURSOR2;
   END IF;
      OPEN CURSOR2;
      LOOP
       FETCH CURSOR2 BULK COLLECT
            INTO reg2 LIMIT 1000000;

       EXIT WHEN reg2.COUNT = 0;
      FOR i IN 1 .. reg2.count LOOP
        -- Asignacion
        v_cod_modulo := reg2(i).cod_modulo;
        v_cod_modalidad := reg2(i).cod_modalidad;
        v_cod_oficina := reg2(i).cod_oficina;
        v_nro_cuenta := reg2(i).nro_cuenta;
        v_monto := reg2(i).monto;
        v_est_cuenta := reg2(i).est_cuenta;
        v_fec_valor := reg2(i).fec_valor;
        v_reversado := reg2(i).reversado;
        v_cod_transaccion := reg2(i).cod_transaccion;
        v_cod_moneda := reg2(i).cod_moneda;
        v_rowid  := reg2(i).rowid;
        v_nom_rutina1  := reg2(i).rutina1;
        v_afecta := reg2(i).afecta;
        v_detalle  := reg2(i).tipo;
        
        --
        v_nro_seq := nvl(v_nro_seq,0) + 1;
        v_horIni := to_char(sysdate,'hh24:mi:ss');
        --
       if v_nom_rutina1 = 'PRA_ACT_EST_BATCH' then
             -- esto se hace para acelerar más el proceso de actualización batch
             begin
                PRA_ACT_EST_BATCH(v_fec_valor,v_cod_oficina,v_nro_cuenta,v_cod_modalidad,v_monto,
                                  v_est_cuenta,v_reversado,v_detalle,v_afecta);

                if v_log_detallado = 'S' then
                  --- logueo
                  v_horFin := to_char(sysdate,'hh24:mi:ss');
                  PRG_ACT_LOG_PROCESOS('PRA_ACT_CUENTAS',v_nro_seq,trunc(sysdate),v_horIni, v_horFin,'9-PRA_ACT_EST_BATCH. Cta:'||v_nro_cuenta||'-Trx.'||v_cod_transaccion||'-Mto.'||v_monto||'-Est.'||v_est_cuenta);
                  ---
                end if;
             EXCEPTION
                WHEN OTHERS THEN
                    v_men_error := SQLERRM;
                    IF lf_error_bloqueos(v_men_error) THEN
                        v_cont_bloqueos := v_cont_bloqueos + 1;
                        pag_cie.PR_INS_LOG(v_men_error, it.pag_cie.c_log_WARN, 'AUTONOMOUS_TRANSACTION');
                        IF v_cont_bloqueos > v_max_bloqueos THEN
                            RAISE_APPLICATION_ERROR(-20000, 
                                'Abortado: Demasiados bloqueos acumulados ('||v_max_bloqueos||'). Último en Cta '||v_nro_cuenta);
                        END IF;
                    ELSE
                        RAISE_APPLICATION_ERROR(-20000, 
                            'Error CRITICO en PRA_ACT_EST_BATCH Cta ' || v_nro_cuenta || '-' || v_men_error);
                    END IF;
            END;

          else
            v_sentencia := '(to_date('||chr(39)||to_char(v_fec_valor,'DDMMYYYY')||chr(39)||','||chr(39)||'DDMMYYYY'||chr(39)||'),'
                            ||'to_number('||chr(39)||v_cod_oficina||chr(39)||'),'
                            ||chr(39)||v_nro_cuenta||chr(39)||','
                            ||'to_number('||chr(39)||v_cod_modalidad||chr(39)||'),'
                            ||'to_number('||chr(39)||v_monto||chr(39)||'),'
                            ||chr(39)||v_est_cuenta||chr(39)||','
                            ||chr(39)||v_reversado||chr(39)||','
                            ||chr(39)||v_detalle||chr(39)||','||''''||v_afecta||''''||')';
            v_nom_rutina1 := 'BEGIN '||v_nom_rutina1||v_sentencia||'; END;';
            sql_util.ejecute_dml(v_nom_rutina1,v_msj_error);
            ---Manejo de errores CIE-790 RZ
            if v_msj_error is not null then
               if lf_error_bloqueos(v_msj_error) then
                  v_cont_bloqueos := v_cont_bloqueos + 1;
                  ---INSERTA LOS ERRORES POR BLOQUEOS EN LA TABLA GE_PRO_PROGRAMAS_LOG---
                  pag_cie.PR_INS_LOG(v_msj_error, it.pag_cie.c_log_WARN, 'AUTONOMOUS_TRANSACTION');
                  if v_cont_bloqueos > v_max_bloqueos then
                    RAISE_APPLICATION_ERROR(-20001, 
                       'Abortado: Se detectaron demasiados bloqueos ('||v_max_bloqueos||') concurrentes.');
                  end if;
                else
                  raise_application_error(-20000,'Ejec.Rutina '||v_msj_error);
               end if;
               v_msj_error:= null;
            end if;
            if v_log_detallado = 'S' then
               --- logueo
                v_horFin := to_char(sysdate,'hh24:mi:ss');
                PRG_ACT_LOG_PROCESOS('PRA_ACT_CUENTAS',v_nro_seq,trunc(sysdate),v_horIni, v_horFin,'10-Concat v_sentencia. Cta:'||v_nro_cuenta||'-Trx.'||v_cod_transaccion||'-Mto.'||v_monto);
                ---
            end if;
          end if;
          commit; --PDSB-464
          pr_act_est_movimiento;--PDSB-464
   END LOOP;
   EXIT WHEN CURSOR2%NOTFOUND;
   END LOOP;
   CLOSE CURSOR2;
  end if;
   -- logueo
   v_horFin := to_char(sysdate,'hh24:mi:ss');
   v_nro_seq := nvl(v_nro_seq,0) + 1;
   PRG_ACT_LOG_PROCESOS('PRA_ACT_CUENTAS',v_nro_seq,trunc(sysdate),v_horIni, v_horFin,'11-Fin cursor 2');
   ---
   --- Fin del proceso de actualizacion batch de cuentas
    execute immediate 'truncate table GE_MOVIMIENTOS_RES'; --PDSB-464
exception
   when others then
      v_men_error := substr(sqlerrm,1,399);
      v_nro_seq := nvl(v_nro_seq,0) + 1;
      v_horFin := to_char(sysdate,'hh24:mi:ss');
      PRG_ACT_LOG_PROCESOS('PRA_ACT_CUENTAS',v_nro_seq,trunc(sysdate),v_horIni, v_horFin, v_men_error);
      raise_application_error(-20000,'Error PRA_ACT_CUENTAS-Cta:'||v_nro_cuenta||' Tra:'||to_char(V_COD_TRANSACCION)||
                           'Mto:'||to_char(v_monto)||' Excluir Cta. de Parametro NRO_CTA_EXC_ACTUALIZACION.'||v_men_error);
END;
/
