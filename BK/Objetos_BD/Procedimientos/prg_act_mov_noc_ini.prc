CREATE OR REPLACE PROCEDURE IT.PRG_ACT_MOV_NOC_INI IS
   v_lugar      VARCHAR2(300);
   v_fec_actual ge_calendarios.fec_actual%TYPE;
   v_parametro ge_par_dinamicos.val_parametro%type:= nvl(fug_obt_pardinamico('NRO_CTA_EXC_VER_INI'), '0');
   v_error     varchar2(4000);
   v_tra_modo       ge_par_dinamicos.val_parametro%TYPE := NVL(fug_obt_pardinamico('PRG_ACT_MOV_INI_PARALLEL'),'NORMAL');
   v_tam_fragmento  ge_par_dinamicos.val_parametro%TYPE := NVL(fug_obt_pardinamico('PRG_ACT_MOV_INI_TAM_FRAG'),'25000');
   v_job_cant       ge_par_dinamicos.val_parametro%TYPE := NVL(fug_obt_pardinamico('PRG_ACT_MOV_INI_JOB_CANT'),'6');
   v_tarea       VARCHAR2(128) := 'PRG_ACT_MOV_INI_PARALELO';
  
   cursor c_cta_ahorros is
    select a.*
      from ah_cta_vistas a
    WHERE instr(v_parametro, a.nro_cuenta) = 0
      and EXISTS (SELECT 1
             FROM ah_cta_vistas_noc c
            WHERE c.nro_cuenta = a.nro_cuenta
              AND (nvl(c.mto_deb_pendientes, 0) <> 0 OR nvl(c.mto_cre_a_confirmar, 0) > 0 OR
                  nvl(c.mto_cre_pendientes, 0) <> 0));

   cursor c_cta_corrientes is
    select a.*
      from cc_cta_corrientes a
    WHERE instr(v_parametro, a.nro_cuenta) = 0
      and EXISTS (SELECT 1
             FROM cc_cta_corrientes_noc c
            WHERE c.nro_cuenta = a.nro_cuenta
              AND (nvl(c.mto_deb_pendientes, 0) <> 0 OR nvl(c.mto_cre_a_confirmar, 0) > 0 OR
                  nvl(c.mto_cre_pendientes, 0) <> 0));

/* DYDMR-2411 Se modifica el modulo al estado anterior, en caso de que ocurra un error
   para no bloquear el servicio de atm, en caso de que se tenga que corregir el mismo durante el cierre */
procedure pr_rev_est_modulo is
  PRAGMA AUTONOMOUS_TRANSACTION;
begin
  UPDATE ba_modulos SET estado = 1 WHERE cod_modulo =3;
  COMMIT;
end;
procedure pr_eli_ge_movimientos is
  PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    delete from it.ge_movimientos t
     where exists (select 1
              from ge_movimientos_noc te
             where t.fecha = te.fecha
               and t.cod_usuario = te.cod_usuario
               and t.hora = te.hora
               and t.nro_secuencia = te.nro_secuencia);
    COMMIT;
end;

BEGIN
   v_lugar := 'Pone estado del modulo en inhabilitado para ATM';
   UPDATE ba_modulos SET estado = 6 WHERE cod_modulo =3;
   COMMIT;
   IF 'PARALLEL_EXECUTE' = v_tra_modo THEN
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
    DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(v_tarea,'IT','GE_MOVIMIENTOS_NOC',true,TO_NUMBER(v_tam_fragmento));
    DBMS_PARALLEL_EXECUTE.run_task(task_name      => v_tarea,
                                   sql_stmt       => 'DECLARE
       v_info  VARCHAR2(512);
       v_cant  PLS_INTEGER;
       BEGIN
          begin
			   pre_ini_aplicacion;
			   pae_cnf.g_cod_modulo := 1;
			   pae_cnf.G_PROGRAMA := ''GPPROFIN'';
		   end;
		   
           pag_cie.PR_SET_PARAMETROS(10, 86, ''PRG_ACT_MOV_NOC_INI'', ''CHUNK'', pag_cie.c_log_TRACE);

           SELECT ''{job:''||job_name||'' chid:''||chunk_id||''}''
           INTO v_info
           FROM user_parallel_execute_chunks
           WHERE task_name = ''PRG_ACT_MOV_INI_PARALELO''
             AND start_rowid = :start_id
             AND end_rowid = :end_id;

           pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] '', pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');

           SELECT COUNT(1)
           INTO v_cant
           FROM user_parallel_execute_chunks
           WHERE task_name = ''PRG_ACT_MOV_INI_PARALELO''
             AND status = ''PROCESSED_WITH_ERROR''
             AND rownum = 1;

           IF v_cant > 0 THEN
              raise_application_error(-20015, ''Falló un Fragmento de la Tarea. Fin por Interrupción temprana.'');
           END IF;
           INSERT INTO ge_movimientos
            (fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto, nro_cuenta, cod_moneda,
             cod_oficina, cod_error, cod_retencion, fec_fin_retencion, est_cuenta, estado, cod_causa,
             cod_banco, cod_ofi_origen, concepto, cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado,
             cod_usu_reversion, hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
             cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja, cotizacion,
             cod_bco_central, nro_documento, nro_documento2, nro_documento3, nro_documento4, protegido,
             cod_autorizacion, cod_usu_autorizador, usu_insercion, fec_insercion, usu_modificacion,
             fec_modificacion, tip_mov_rubro, cod_tip_ope_cambio, referencia, cod_persona, cod_sit_contable, nro_conciliacion)
              SELECT fecha,
               hora,
               cod_usuario,
               nro_secuencia,
               fec_valor,
               monto,
               nro_cuenta,
               cod_moneda,
               cod_oficina,
               cod_error,
               cod_retencion,
               fec_fin_retencion,
               est_cuenta,
               estado,
               cod_causa,
               cod_banco,
               cod_ofi_origen,
               concepto,
               cod_tasa,
               val_tasa,
               cod_rubro,
               cod_ref_cambio,
               reversado,
               cod_usu_reversion,
               hor_reversion,
               emi_aviso,
               cod_tra_padre,
               cod_mod_padre,
               cod_mad_padre,
               cod_transaccion,
               cod_modulo,
               cod_modalidad,
               mto_equ_local,
               nro_caja,
               cotizacion,
               cod_bco_central,
               nro_documento,
               nro_documento2,
               nro_documento3,
               nro_documento4,
               protegido,
               cod_autorizacion,
               cod_usu_autorizador,
               usu_insercion,
               fec_insercion,
               usu_modificacion,
               fec_modificacion,
               tip_mov_rubro,
               cod_tip_ope_cambio,
               referencia,
               cod_persona,
               cod_sit_contable,
               nro_conciliacion
          FROM ge_movimientos_noc a
            WHERE   a.rowid BETWEEN :start_id AND :end_id;
        EXCEPTION
           WHEN OTHERS THEN
              pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] EXCEPTION: ''||SQLERRM, pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');
              RAISE;
        END;',
       language_flag  => DBMS_SQL.NATIVE,
       parallel_level => TO_NUMBER(v_job_cant));

    --Verificar el estatus de la ejecucion
    IF DBMS_PARALLEL_EXECUTE.FINISHED !=DBMS_PARALLEL_EXECUTE.TASK_STATUS(v_tarea) THEN
      raise_application_error(-20000,'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ' ||v_tarea);
    END IF;
  ELSE
     v_lugar := 'Inserta en GE_MOVIMIENTOS los movimientos de GE_MOVIMIENTOS_NOC';
     INSERT INTO ge_movimientos
        (fecha, hora, cod_usuario, nro_secuencia, fec_valor, monto, nro_cuenta, cod_moneda,
         cod_oficina, cod_error, cod_retencion, fec_fin_retencion, est_cuenta, estado, cod_causa,
         cod_banco, cod_ofi_origen, concepto, cod_tasa, val_tasa, cod_rubro, cod_ref_cambio, reversado,
         cod_usu_reversion, hor_reversion, emi_aviso, cod_tra_padre, cod_mod_padre, cod_mad_padre,
         cod_transaccion, cod_modulo, cod_modalidad, mto_equ_local, nro_caja, cotizacion,
         cod_bco_central, nro_documento, nro_documento2, nro_documento3, nro_documento4, protegido,
         cod_autorizacion, cod_usu_autorizador, usu_insercion, fec_insercion, usu_modificacion,
         fec_modificacion, tip_mov_rubro, cod_tip_ope_cambio, referencia, cod_persona, cod_sit_contable, nro_conciliacion)
        SELECT fecha,
               hora,
               cod_usuario,
               nro_secuencia,
               fec_valor,
               monto,
               nro_cuenta,
               cod_moneda,
               cod_oficina,
               cod_error,
               cod_retencion,
               fec_fin_retencion,
               est_cuenta,
               estado,
               cod_causa,
               cod_banco,
               cod_ofi_origen,
               concepto,
               cod_tasa,
               val_tasa,
               cod_rubro,
               cod_ref_cambio,
               reversado,
               cod_usu_reversion,
               hor_reversion,
               emi_aviso,
               cod_tra_padre,
               cod_mod_padre,
               cod_mad_padre,
               cod_transaccion,
               cod_modulo,
               cod_modalidad,
               mto_equ_local,
               nro_caja,
               cotizacion,
               cod_bco_central,
               nro_documento,
               nro_documento2,
               nro_documento3,
               nro_documento4,
               protegido,
               cod_autorizacion,
               cod_usu_autorizador,
               usu_insercion,
               fec_insercion,
               usu_modificacion,
               fec_modificacion,
               tip_mov_rubro,
               cod_tip_ope_cambio,
               referencia,
               cod_persona,
               cod_sit_contable,
               nro_conciliacion
          FROM ge_movimientos_noc a;
     it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '01-INS_GE_MOVIMIENTOS', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
  END IF;
   v_lugar := 'Inserta en CJ_MOVIMIENTOS los movimientos de CJ_MOVIMIENTOS_NOC';
   INSERT INTO cj_movimientos
      SELECT * FROM cj_movimientos_noc;
   it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '02-INS_CJ_MOVIMIENTOS', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);

   -- cero los debitos y creditos pendientes de los maestros normales
   v_lugar := 'Cera campos de debito y credito en maestros originales';
   UPDATE cc_cta_corrientes
      SET mto_deb_pendientes  = 0,
          mto_cre_a_confirmar = 0,
          mto_cre_pendientes  = 0
    WHERE mto_deb_pendientes != 0
       OR mto_cre_a_confirmar != 0
       OR mto_cre_pendientes != 0;
   it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '03-UPD_CC_CTA_CORRIENTES', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);

   v_lugar := 'Cera campos ah_cta_vistas';
   UPDATE ah_cta_vistas
      SET mto_deb_pendientes  = 0,
          mto_cre_a_confirmar = 0,
          mto_cre_pendientes  = 0
    WHERE mto_deb_pendientes != 0
       OR mto_cre_a_confirmar != 0
       OR mto_cre_pendientes != 0;
   it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '04-UPD_CC_CTA_VISTAS', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);


   -- actualiza los maestros
   v_lugar      := 'Actualiza maestro de cuentas corrientes';
   v_fec_actual := pag_cal.fu_obt_fec_actual(1);
   for cte in c_cta_corrientes loop
      begin
           UPDATE cc_cta_corrientes a
          SET (a.sal_total, a.sal_retenido) =
              (SELECT (nvl(a.sal_total, 0) - nvl(b.mto_deb_pendientes, 0) +
                      nvl(b.mto_cre_a_confirmar, 0) + nvl(b.mto_cre_pendientes, 0)),
                      (nvl(a.sal_retenido, 0) + nvl(b.mto_cre_a_confirmar, 0))
                 FROM cc_cta_corrientes_noc b
                WHERE b.nro_cuenta = a.nro_cuenta
                  and b.nro_cuenta = cte.nro_cuenta),
              a.fec_ult_movimiento = v_fec_actual
        WHERE a.nro_cuenta = cte.nro_cuenta;
       exception
         when others then
              ROLLBACK;
               pr_rev_est_modulo;
               raise_application_error(-20000, v_lugar || '-Cta#: ' ||cte.nro_cuenta||'-'|| SQLERRM);
       end;
   end loop;
   it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '05-LOOP_UPD_MAESTRO_CC_CTA_CORRIENTES', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
   v_lugar      := 'Actualiza maestro de cuentas bancarias';
   UPDATE cc_cta_bancarias a
      SET (a.sal_total) =
          (SELECT (nvl(a.sal_total, 0) - nvl(b.mto_deb_pendientes, 0) + nvl(b.mto_cre_pendientes, 0))
             FROM cc_cta_bancarias_noc b
            WHERE b.nro_cuenta = a.nro_cuenta),
          a.fec_ult_movimiento = v_fec_actual
    WHERE EXISTS
    (SELECT 1
             FROM cc_cta_bancarias_noc c
            WHERE c.nro_cuenta = a.nro_cuenta
              AND (nvl(c.mto_deb_pendientes, 0) <> 0 OR nvl(c.mto_cre_pendientes, 0) <> 0));

   it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '06-UPD_MAESTRO_CC_CTA_BANCARIAS', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);

   v_lugar := 'Actualiza estado de cuentas corrientes';
   UPDATE cc_cta_corrientes
      SET estado         = 'N',
          fec_cam_estado = v_fec_actual,
          fec_apertura   = decode(estado, 'A', v_fec_actual, fec_apertura)
    WHERE (nro_cuenta) IN (SELECT nro_cuenta
                             FROM ge_movimientos
                            WHERE cod_transaccion = 425
                              AND cod_modulo = 4)
      AND estado IN ('A', 'I');
   it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '07-UPD_EST_CC_CTA_CORRIENTES', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
   v_lugar := 'Actualiza maestro de ahorro a la vista';
   for cta in c_cta_ahorros loop
      begin
          UPDATE ah_cta_vistas a
          SET (a.sal_total, a.sal_retenido) =
              (SELECT (nvl(a.sal_total, 0) - nvl(b.mto_deb_pendientes, 0) +
                      nvl(b.mto_cre_a_confirmar, 0) + nvl(b.mto_cre_pendientes, 0)),
                      (nvl(a.sal_retenido, 0) + nvl(b.mto_cre_a_confirmar, 0))
                 FROM ah_cta_vistas_noc b
                WHERE b.nro_cuenta = a.nro_cuenta
                  and b.nro_cuenta = cta.nro_cuenta),
              a.fec_ult_movimiento = v_fec_actual
        WHERE a.nro_cuenta = cta.nro_cuenta;

       exception
         when others then
              v_error:= substr(sqlerrm,1,4000);
              if instr(v_error,'CK_ACVIS_SAL_TOTAL_PEN')>0 then
                prg_ins_log_errores('PRG_ACT_MOV_NOC_INI',v_error,'NRO_CUENTA', cta.nro_cuenta);
              else
                ROLLBACK;
                pr_rev_est_modulo;
                raise_application_error(-20000, v_lugar || '-Cta#: ' ||cta.nro_cuenta||'-'|| SQLERRM);
              end if;
       end;
   end loop;
   it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '08-LOOP_UPD_CUR_AH_CTA_VISTAS', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);

   v_lugar := 'Actualiza estado de ahorro a la vista';
   UPDATE ah_cta_vistas
      SET estado         = 'N',
          fec_cam_estado = v_fec_actual,
          fec_apertura   = decode(estado, 'A', v_fec_actual, fec_apertura)
    WHERE (nro_cuenta) IN (SELECT nro_cuenta
                             FROM ge_movimientos
                            WHERE cod_transaccion = 425
                              AND cod_modulo = 3
                              AND cod_modalidad in (31, 334))
      AND estado IN ('A', 'I');
   it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '09-UPD_EST_AH_CTA_VISTAS', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);


  v_lugar := 'Actualiza el estado de Plazo Fijo con los ' || 'deposito fuera de hora';
   UPDATE ah_cta_plazos
      SET estado         = 'N',
          fec_cam_estado = v_fec_actual
    WHERE (nro_cuenta) IN (SELECT nro_cuenta
                             FROM ge_movimientos
                            WHERE cod_tra_padre = 425
                              AND cod_transaccion = 425
                              AND cod_modulo = 3
                              AND cod_modalidad in (32,37,38))
      AND estado = 'A';
   it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '10-UPD_EST_AH_CTA_PLAZOS', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);

   v_lugar:='Cera cc_cta_bancarias';
   UPDATE cc_cta_bancarias
      SET mto_deb_pendientes = 0,
          mto_cre_pendientes = 0
    WHERE mto_deb_pendientes != 0
       OR mto_cre_pendientes != 0;
   it.pag_cie.PR_AT_INS_LOG(10,86,'PRG_ACT_MOV_NOC_INI', '11-CERA_CC_CTA_BANCARIAS', it.pag_cie.c_log_TRACE,'OUT',SYSDATE);
    -- fin del proceso

EXCEPTION
   WHEN OTHERS THEN
   v_lugar := 'Rehabilitar estado del modulo si hay error para ATM';
   ROLLBACK;
   pr_rev_est_modulo;
   IF 'PARALLEL_EXECUTE' = v_tra_modo THEN
      pr_eli_ge_movimientos;
  END IF; 
  raise_application_error(-20000, v_lugar || ' ' || SQLERRM);
END;
/
