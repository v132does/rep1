CREATE OR REPLACE PROCEDURE IT.PRB_CON_TRA_HIS IS
  v_nom_tarea       CONSTANT VARCHAR2(100) := 'GE_CON_TRA_HIS_TASK';
  v_fec_aux         VARCHAR2(10)  := to_char(pag_cal.fu_obt_fec_actual(1), 'DD/MM/YYYY');
  v_tam_lote        number        := nvl(to_number(fug_obt_pardinamico('PRA_GEN_TRAHIS_TAM_FRAG')), 50000);
  v_niv_paralelismo number        := nvl(to_number(fug_obt_pardinamico('PRA_GEN_TRAHIS_JOB_CANT')), 7);
  v_paralelo        varchar2(30)  := nvl((fug_obt_pardinamico('PRA_GEN_TRAHIS_PARALLEL')), 'NORMAL');
  v_cant_proc       number        := 0;
  v_cant_tot        number        := 0;
  v_msj             VARCHAR2(250);
  v_hor_ini         varchar2(8);
  v_hor_fin         varchar2(8);
  v_sen_paralelismo CLOB; --Setencia dml que usamos en el dbms_parallel_execute
  v_tru_gtc_table   varchar2(30)  := nvl((fug_obt_pardinamico('TRU_REG_GCT_TRANSACCIONES')), 'N');

BEGIN
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  IF v_paralelo = 'PARALLEL_EXECUTE' THEN
    v_hor_ini := to_char(sysdate, 'hh24:mi:ss');
    -- 1. Limpieza de Tareas
    BEGIN
      dbms_parallel_execute.drop_task(v_nom_tarea);
    EXCEPTION
      WHEN dbms_parallel_execute.task_not_found THEN
        NULL;
    END;
    -- 2. Definición de la sentencia
    v_sen_paralelismo := '
            DECLARE
                  v_info          VARCHAR2(512); 
                  v_cant          PLS_INTEGER; 
                  v_fec_proceso date := to_date(''' || v_fec_aux || ''',''dd/mm/yyyy'');
                  v_nom_tarea   varchar2(35):= ''' || v_nom_tarea || ''';
            BEGIN
                  -- Inicialización de la aplicacion
                  pre_ini_aplicacion;
                  pae_cnf.g_cod_modulo := 1;
                  
                  pag_cie.PR_SET_PARAMETROS(10, 101, ''PRB_CON_TRA_HIS'', ''CHUNK'', pag_cie.c_log_TRACE);

                  -- Obtener la info del chunk para logging
                  SELECT ''{job:''||job_name||'' chid:''||chunk_id||''}''
                  INTO v_info
                  FROM user_parallel_execute_chunks
                  WHERE task_name = v_nom_tarea
                    AND start_rowid = :start_id
                    AND end_rowid = :end_id;        
                    
                  pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] '', pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');  

                  SELECT COUNT(1)
                    INTO v_cant
                    FROM user_parallel_execute_chunks
                   WHERE task_name =v_nom_tarea
                     AND status = ''PROCESSED_WITH_ERROR''
                     AND rownum = 1;

                   IF v_cant > 0 THEN
                      raise_application_error(-20015, ''Fall  un Fragmento de la Tarea. Fin por Interrupcion temparana.'');
                   END IF;
                  
                  insert into ge_con_transacciones_his select ge_con_transacciones.*
                                                         from ge_con_transacciones ge_con_transacciones
                                                        where ge_con_transacciones.fecha = pag_cal.FU_OBT_FEC_ANTERIOR(1)
                                                          AND ge_con_transacciones.rowid BETWEEN :start_id AND :end_id;
                
                    COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                  pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] EXCEPTION: ''||SQLERRM, pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');
                  RAISE; -- Re-lanza el error para marcar el chunk como fallido.
            END;';
  
    -- 3. Crear Tarea
    dbms_parallel_execute.create_task(task_name => v_nom_tarea);

    -- 4. Segmentar por ROWID
    dbms_parallel_execute.create_chunks_by_rowid(v_nom_tarea,
                                                 'IT',
                                                 'GE_CON_TRANSACCIONES',
                                                 TRUE,
                                                 v_tam_lote);
  
    -- 5. Ejecutar la tarea
    dbms_parallel_execute.run_task(task_name      => v_nom_tarea,
                                   sql_stmt       => v_sen_paralelismo,
                                   language_flag  => dbms_sql.native,
                                   parallel_level => v_niv_paralelismo);
  
    -- 6. Comprobar Fallo
    IF dbms_parallel_execute.finished !=
       dbms_parallel_execute.task_status(v_nom_tarea) THEN
      raise_application_error(-20000,
                              'ERROR DBMS_PARALLEL_EXECUTE. Tarea fallida: ' ||
                              v_nom_tarea);
    END IF;
  
    COMMIT;
    v_hor_fin := to_char(sysdate, 'hh24:mi:ss');
    pag_cie.PR_INS_LOG('1. PRB_CON_TRA_HIS_PARALLEL Ejecutado con dbms_parallel_execute '||v_hor_ini ||' '||v_hor_fin, it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
  ELSE
    v_hor_ini := to_char(sysdate, 'hh24:mi:ss');
    insert into ge_con_transacciones_his
      (fecha,
       cod_mod_padre,
       cod_mad_padre,
       cod_ofi_origen,
       cod_oficina,
       cod_moneda,
       cod_modulo,
       cod_modalidad,
       cod_transaccion,
       cod_sector,
       cod_tip_deudor,
       residente,
       cod_plazo,
       cantidad,
       total,
       tot_mon_local,
       nro_referencia,
       est_cuenta,
       tip_cuenta,
       tip_interes,
       tip_renovacion,
       cat_automatica,
       fec_valor,
       cod_tra_padre,
       cod_sit_contable,
       nro_cuenta,
       concepto,
       cod_sec_rubro,
       reversado)
      select a.fecha,
             a.cod_mod_padre,
             a.cod_mad_padre,
             a.cod_ofi_origen,
             a.cod_oficina,
             a.cod_moneda,
             a.cod_modulo,
             a.cod_modalidad,
             a.cod_transaccion,
             a.cod_sector,
             a.cod_tip_deudor,
             a.residente,
             a.cod_plazo,
             a.cantidad,
             a.total,
             a.tot_mon_local,
             a.nro_referencia,
             a.est_cuenta,
             a.tip_cuenta,
             a.tip_interes,
             a.tip_renovacion,
             a.cat_automatica,
             a.fec_valor,
             a.cod_tra_padre,
             a.cod_sit_contable,
             a.nro_cuenta,
             a.concepto,
             a.cod_sec_rubro,
             a.reversado
        from ge_con_transacciones a
       where a.fecha = pag_cal.FU_OBT_FEC_ANTERIOR(1);
    commit;
    v_hor_fin := to_char(sysdate, 'hh24:mi:ss');
    pag_cie.PR_INS_LOG('2. PRB_CON_TRA_HIS_NORMAL Ejecutado en modo normal(sin parallel) '||v_hor_ini ||' '||v_hor_fin, it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
  END IF;
IF NVL(v_tru_gtc_table, 'N') = 'S' THEN -- Parametro para truncar la tabla
  --cantidad de registros que debe procesar 
  select count(1)
    into v_cant_tot
    from ge_con_transacciones a
   where a.fecha = pag_cal.FU_OBT_FEC_ANTERIOR(1);
  --cantidad de registros que proceso 
  select count(1)
    into v_cant_proc
    from ge_con_transacciones_his a
   where a.fecha = pag_cal.FU_OBT_FEC_ANTERIOR(1);

  if v_cant_tot = v_cant_proc then
    v_hor_ini := to_char(sysdate, 'hh24:mi:ss');
    sql_util.ejecute_dml('TRUNCATE TABLE GE_CON_TRANSACCIONES', v_msj);
    IF v_msj IS NOT NULL THEN
      raise_application_error(-20000, v_msj);
    END IF;
    v_hor_fin := to_char(sysdate, 'hh24:mi:ss');
    pag_cie.PR_INS_LOG('3. PRB_CON_TRA_HIS_TRUNCADO TRUNCADO EXITOSO '||v_hor_ini || ' ' ||v_hor_fin, it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
  else
    v_hor_ini := to_char(sysdate, 'hh24:mi:ss');
    v_hor_fin := to_char(sysdate, 'hh24:mi:ss');
    pag_cie.PR_INS_LOG('4. PRB_CON_TRA_HIS_NO-TRUNCADO NO SE TRUNCO cantidades diferentes, a traspasar: '||v_hor_ini || ' '|| v_hor_fin, it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
  end if;
END IF;   
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE <= -20000 THEN
      RAISE;
      raise_application_error(-20000,
                              'ERROR. En traspaso a historico de GE_CON_TRANSACCIONES_HIS.' ||
                              sqlerrm);
    END IF;
END;
/
