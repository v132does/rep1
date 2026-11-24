CREATE OR REPLACE PROCEDURE IT.PRA_TRA_ATM
 IS
   v_msj  varchar2(250);
   v_espera number := 10;
   v_bloqueado number:=0;
   v_rol_referencia varchar2(15) := 'inicio';
   v_est_cta_corriente ba_modulos.estado%type;
   v_tra_ah_modo    ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PRA_TRA_ATM_PARALLEL'), 'NORMAL');
   v_tam_fragmento  ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PRA_TRA_ATM_TAM_FRAG'), '25000');
   v_job_cant       ge_par_dinamicos.val_parametro%TYPE:= NVL(fug_obt_pardinamico('PRA_TRA_ATM_JOB_CANT'), '6');
   v_tarea          VARCHAR2(128) := 'pra_tra_atm_AH_PARALELO';

   procedure pr_rev_est_modulo is
    begin
      prg_rol_savepoint(v_rol_referencia);
      UPDATE ba_modulos SET estado = 2 WHERE cod_modulo in (3,4);
      COMMIT;
    end;
BEGIN
   -- control de bloqueo
   v_bloqueado := it.fug_con_blo_session('''CC_CTA_CORRIENTES'', ''AH_CTA_VISTAS'', ''CC_CTA_BANCARIAS'', ''CC_CTA_CORRIENTES_NOC'', ''AH_CTA_VISTAS_NOC'', ''CC_CTA_BANCARIAS_NOC''',v_espera);
   if nvl(v_bloqueado,0)=0 then
   -- Realiza copias de archivos para proceso ATM
   v_msj := 'Actualizando modulo 4 estado=6';
   UPDATE BA_MODULOS
      SET ESTADO = 6
    WHERE COD_MODULO = 3;
   commit;
   prg_cre_savepoint(v_rol_referencia);
   --'Borrando archivos de ATM';
   v_msj := null;
   sql_util.ejecute_dml('TRUNCATE TABLE CC_CTA_CORRIENTES_NOC', v_msj);
   if v_msj is not null then
      raise_application_error(-20000, v_msj);
   end if;
   v_msj := null;
   sql_util.ejecute_dml('TRUNCATE TABLE AH_CTA_VISTAS_NOC', v_msj);
   if v_msj is not null then
      raise_application_error(-20000, v_msj);
   end if;
   v_msj := null;
   sql_util.ejecute_dml('TRUNCATE TABLE CC_CTA_BANCARIAS_NOC', v_msj);
   if v_msj is not null then
      raise_application_error(-20000, v_msj);
   end if;
   -- Inserta nuevos datos
   v_msj := 'Copiando CC_CTA_CORRIENTES para ATM';
   INSERT INTO CC_CTA_CORRIENTES_NOC
        (COD_MODULO,COD_MODALIDAD,COD_OFICINA,NRO_CUENTA,DIG_VERIFICADOR,COD_MONEDA,
         DENOMINACION,CAN_FIR_REQUERIDAS,CAN_FIR_REGISTRADAS,FEC_APERTURA,RET_PERSONALIZADA,
         TAS_PERSONALIZADA,SAL_MINIMO,AUT_PENDIENTE,ACU_SOBREGIRO,TRA_PROHIBIDA,
         CTA_COMBINADA,COD_USU_PROMOTOR,EST_BATCH,ESTADO,FEC_ULT_EXTRACTO,SAL_ULT_EXTRACTO,
         NRO_FOLIO,FEC_CAM_ESTADO,FEC_ULT_MOVIMIENTO,HOR_ULT_MOVIMIENTO,SAL_RET_BATCH,
         SAL_RETENIDO,SAL_BLO_BATCH,SAL_BLOQUEADO,SAL_TOT_BATCH,SAL_TOTAL,NOM_CHEQUERA,
         MTO_APERTURA,COD_CANAL,COD_CAMPANA,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,
         FEC_MODIFICACION,FRE_EXTRACTO,MTO_CRE_PENDIENTES,MTO_CRE_A_CONFIRMAR,COD_ENTE,
         MTO_DEB_PENDIENTES,REG_FIRMA,COD_SUB_MODALIDAD)
         (SELECT COD_MODULO,COD_MODALIDAD,COD_OFICINA,NRO_CUENTA,DIG_VERIFICADOR,COD_MONEDA,
         DENOMINACION,CAN_FIR_REQUERIDAS,CAN_FIR_REGISTRADAS,FEC_APERTURA,RET_PERSONALIZADA,
         TAS_PERSONALIZADA,SAL_MINIMO,AUT_PENDIENTE,ACU_SOBREGIRO,TRA_PROHIBIDA,
         CTA_COMBINADA,COD_USU_PROMOTOR,EST_BATCH,ESTADO,FEC_ULT_EXTRACTO,SAL_ULT_EXTRACTO,
         NRO_FOLIO,FEC_CAM_ESTADO,FEC_ULT_MOVIMIENTO,HOR_ULT_MOVIMIENTO,SAL_RET_BATCH,
         SAL_RETENIDO,SAL_BLO_BATCH,SAL_BLOQUEADO,SAL_TOT_BATCH,SAL_TOTAL,NOM_CHEQUERA,
         MTO_APERTURA,COD_CANAL,COD_CAMPANA,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,
         FEC_MODIFICACION,FRE_EXTRACTO,MTO_CRE_PENDIENTES,MTO_CRE_A_CONFIRMAR,COD_ENTE,
         MTO_DEB_PENDIENTES,REG_FIRMA,COD_SUB_MODALIDAD
         FROM CC_CTA_CORRIENTES);
   COMMIT;
    v_msj := 'Copiando AH_CTA_VISTAS para ATM';
    IF 'PARALLEL_EXECUTE' = v_tra_ah_modo THEN
       BEGIN
          -- Eliminar la tarea y los fragmentos relacionados
          DBMS_PARALLEL_EXECUTE.DROP_TASK(v_tarea);
       EXCEPTION
          WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
             NULL;
       END;
       -- Crear la tarea
       DBMS_PARALLEL_EXECUTE.create_task(v_tarea);
    
       -- Dividir la tabla por ROWID en intervalos
       DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(v_tarea, 'IT', 'AH_CTA_VISTAS', true, TO_NUMBER(v_tam_fragmento));
    
       -- Ejecutar el DML en paralelo
       DBMS_PARALLEL_EXECUTE.run_task(task_name      => v_tarea,
                                      sql_stmt       =>
'DECLARE
   v_info  VARCHAR2(512);
   v_cant  PLS_INTEGER;
BEGIN
   pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 1;

   pag_cie.PR_SET_PARAMETROS(11, 150, ''PRA_TRA_ATM'', ''CHUNK'', pag_cie.c_log_TRACE);

   SELECT ''{job:''||job_name||'' chid:''||chunk_id||''}''
   INTO v_info
   FROM user_parallel_execute_chunks
   WHERE task_name = ''pra_tra_atm_AH_PARALELO''
     AND start_rowid = :start_id
     AND end_rowid = :end_id;

   pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] '', pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');

   SELECT COUNT(1)
   INTO v_cant
   FROM user_parallel_execute_chunks
   WHERE task_name = ''pra_tra_atm_AH_PARALELO''
     AND status = ''PROCESSED_WITH_ERROR''
     AND rownum = 1;

   IF v_cant > 0 THEN
      raise_application_error(-20015, ''Falló un Fragmento de la Tarea. Fin por Interrupción temparana.'');
   END IF;

   INSERT INTO AH_CTA_VISTAS_NOC
      (NRO_CUENTA,DIG_VERIFICADOR,COD_MODULO,COD_MODALIDAD,COD_OFICINA,COD_MONEDA,
       DENOMINACION,FRE_EXTRACTO,CAN_FIR_REQUERIDAS,CAN_FIR_REGISTRADAS,FEC_APERTURA,
       TIP_CAPITALIZACION,TAS_PERSONALIZADA,COD_TASA,RET_PERSONALIZADA,SAL_MINIMO,
       COD_USU_PROMOTOR,EST_BATCH,ESTADO,NRO_FOLIO,FEC_ULT_EXTRACTO,SAL_ULT_EXTRACTO,
       FEC_CAM_ESTADO,FEC_ULT_MOVIMIENTO,HOR_ULT_MOVIMIENTO,FEC_ULT_CAPITALIZACION,
       SAL_ULT_CAPITALIZACION,SAL_RET_BATCH,SAL_RETENIDO,SAL_BLO_BATCH,SAL_BLOQUEADO,
       SAL_TOT_BATCH,SAL_TOTAL,TRA_PROHIBIDA,CTA_COMBINADA,AUT_PENDIENTE,MTO_DEB_PENDIENTES,
       MTO_CRE_PENDIENTES,MTO_CRE_A_CONFIRMAR,COD_ENTE,MTO_APERTURA,COD_CANAL,COD_CAMPANA,
       REG_FIRMA,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,COD_SUB_MODALIDAD)
      (SELECT NRO_CUENTA,DIG_VERIFICADOR,COD_MODULO,COD_MODALIDAD,COD_OFICINA,COD_MONEDA,
       DENOMINACION,FRE_EXTRACTO,CAN_FIR_REQUERIDAS,CAN_FIR_REGISTRADAS,FEC_APERTURA,
       TIP_CAPITALIZACION,TAS_PERSONALIZADA,COD_TASA,RET_PERSONALIZADA,SAL_MINIMO,
       COD_USU_PROMOTOR,EST_BATCH,ESTADO,NRO_FOLIO,FEC_ULT_EXTRACTO,SAL_ULT_EXTRACTO,
       FEC_CAM_ESTADO,FEC_ULT_MOVIMIENTO,HOR_ULT_MOVIMIENTO,FEC_ULT_CAPITALIZACION,
       SAL_ULT_CAPITALIZACION,SAL_RET_BATCH,SAL_RETENIDO,SAL_BLO_BATCH,SAL_BLOQUEADO,
       SAL_TOT_BATCH,SAL_TOTAL,TRA_PROHIBIDA,CTA_COMBINADA,AUT_PENDIENTE,MTO_DEB_PENDIENTES,
       MTO_CRE_PENDIENTES,MTO_CRE_A_CONFIRMAR,COD_ENTE,MTO_APERTURA,COD_CANAL,COD_CAMPANA,
       REG_FIRMA,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,COD_SUB_MODALIDAD
       FROM AH_CTA_VISTAS
       WHERE rowid BETWEEN :start_id AND :end_id);

   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] EXCEPTION: ''||SQLERRM, pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');
      RAISE;
END;',
                                     language_flag  => DBMS_SQL.NATIVE,
                                     parallel_level => TO_NUMBER(v_job_cant));
    
       --Verificar el estatus de la ejecucion
       IF DBMS_PARALLEL_EXECUTE.FINISHED != DBMS_PARALLEL_EXECUTE.TASK_STATUS(v_tarea) THEN
          raise_application_error(-20000, 'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ' || v_tarea);
       END IF;
    ELSE
       INSERT INTO AH_CTA_VISTAS_NOC
          (NRO_CUENTA,DIG_VERIFICADOR,COD_MODULO,COD_MODALIDAD,COD_OFICINA,COD_MONEDA,
           DENOMINACION,FRE_EXTRACTO,CAN_FIR_REQUERIDAS,CAN_FIR_REGISTRADAS,FEC_APERTURA,
           TIP_CAPITALIZACION,TAS_PERSONALIZADA,COD_TASA,RET_PERSONALIZADA,SAL_MINIMO,
           COD_USU_PROMOTOR,EST_BATCH,ESTADO,NRO_FOLIO,FEC_ULT_EXTRACTO,SAL_ULT_EXTRACTO,
           FEC_CAM_ESTADO,FEC_ULT_MOVIMIENTO,HOR_ULT_MOVIMIENTO,FEC_ULT_CAPITALIZACION,
           SAL_ULT_CAPITALIZACION,SAL_RET_BATCH,SAL_RETENIDO,SAL_BLO_BATCH,SAL_BLOQUEADO,
           SAL_TOT_BATCH,SAL_TOTAL,TRA_PROHIBIDA,CTA_COMBINADA,AUT_PENDIENTE,MTO_DEB_PENDIENTES,
           MTO_CRE_PENDIENTES,MTO_CRE_A_CONFIRMAR,COD_ENTE,MTO_APERTURA,COD_CANAL,COD_CAMPANA,
           REG_FIRMA,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,COD_SUB_MODALIDAD)
          (SELECT NRO_CUENTA,DIG_VERIFICADOR,COD_MODULO,COD_MODALIDAD,COD_OFICINA,COD_MONEDA,
           DENOMINACION,FRE_EXTRACTO,CAN_FIR_REQUERIDAS,CAN_FIR_REGISTRADAS,FEC_APERTURA,
           TIP_CAPITALIZACION,TAS_PERSONALIZADA,COD_TASA,RET_PERSONALIZADA,SAL_MINIMO,
           COD_USU_PROMOTOR,EST_BATCH,ESTADO,NRO_FOLIO,FEC_ULT_EXTRACTO,SAL_ULT_EXTRACTO,
           FEC_CAM_ESTADO,FEC_ULT_MOVIMIENTO,HOR_ULT_MOVIMIENTO,FEC_ULT_CAPITALIZACION,
           SAL_ULT_CAPITALIZACION,SAL_RET_BATCH,SAL_RETENIDO,SAL_BLO_BATCH,SAL_BLOQUEADO,
           SAL_TOT_BATCH,SAL_TOTAL,TRA_PROHIBIDA,CTA_COMBINADA,AUT_PENDIENTE,MTO_DEB_PENDIENTES,
           MTO_CRE_PENDIENTES,MTO_CRE_A_CONFIRMAR,COD_ENTE,MTO_APERTURA,COD_CANAL,COD_CAMPANA,
           REG_FIRMA,USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION,COD_SUB_MODALIDAD
           FROM AH_CTA_VISTAS);
    END IF;
    COMMIT;
    v_msj := 'Copiando CC_CTA_BANCARIAS para ATM';
   INSERT INTO CC_CTA_BANCARIAS_NOC
        (nro_cuenta,cod_modulo, cod_modalidad, cod_oficina, dig_verificador, cod_moneda,
        denominacion, fec_apertura, sal_minimo, mto_acuerdo, est_batch, estado, fec_ult_conciliacion,
        sal_ult_conciliacion, nro_folio, fec_cam_estado, fec_ult_movimiento, hor_ult_movimiento,
        sal_ret_batch, sal_retenido, sal_blo_batch, sal_bloqueado, sal_tot_batch, sal_total,
        cod_banco, nro_cta_bancaria, cod_programa, cod_rubro, fec_ult_extracto, sal_ult_extracto,
        fre_extracto, mto_deb_pendientes, mto_cre_pendientes,
        USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION)
   SELECT nro_cuenta,cod_modulo, cod_modalidad, cod_oficina, dig_verificador, cod_moneda,
        denominacion, fec_apertura, sal_minimo, mto_acuerdo, est_batch, estado, fec_ult_conciliacion,
        sal_ult_conciliacion, nro_folio, fec_cam_estado, fec_ult_movimiento, hor_ult_movimiento,
        sal_ret_batch, sal_retenido, sal_blo_batch, sal_bloqueado, sal_tot_batch, sal_total,
        cod_banco, nro_cta_bancaria, cod_programa, cod_rubro, fec_ult_extracto, sal_ult_extracto,
        fre_extracto, mto_deb_pendientes, mto_cre_pendientes,
        USU_INSERCION,FEC_INSERCION,USU_MODIFICACION,FEC_MODIFICACION
    FROM CC_CTA_BANCARIAS;
    
    --Cambiar estado de ahorros a 3 (en cierre)
    BEGIN
       UPDATE ba_modulos
          set estado = 3
        where cod_modulo = 3;
       if sql%notfound then
          pr_rev_est_modulo;
          raise_application_error(-20000, 'Módulo de ahorros no encontrado');
       end if;
    END;
    
    --Cambiar estado de cuentas corrientes a 3 (en cierre)
    BEGIN
       Select estado
         into v_est_cta_corriente
         from ba_modulos
        where cod_modulo = 4;
       if nvl(v_est_cta_corriente,0)  not in (2) then
          pr_rev_est_modulo;
          raise_application_error(-20000,'Estado del Modulo de Cta.Cte. incorrecto');
       end if;
       UPDATE ba_modulos
          set estado = 3
        where cod_modulo = 4;
       if sql%notfound then
          pr_rev_est_modulo;
          raise_application_error(-20000, 'Módulo Cta.Cte. no encontrado');
       end if;
    END;

    commit;
  ELSE
   raise_application_error(-20000,'Recursos ocupados o bloqueados');
  END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      pr_rev_est_modulo;
      raise_application_error(-20000,'No existe registro de modalidad 10 en BA_MODULOS');
   WHEN TOO_MANY_ROWS THEN
      pr_rev_est_modulo;
      raise_application_error(-20000,'Hay varios registros modalidad 10 en BA_MODULOS');
   WHEN OTHERS THEN
      pr_rev_est_modulo;
      raise_application_error(-20000,v_msj||' '||sqlerrm);
END;
/
