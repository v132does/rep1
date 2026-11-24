CREATE OR REPLACE PROCEDURE IT.prt_ins_mae_cue_gp IS
v_lugar           VARCHAR2(50);
v_fecha           DATE := trunc(SYSDATE);
r_log             ta_logs_gp%ROWTYPE;
v_fec_actual      ge_calendarios.fec_actual%TYPE;
v_can_reg_tmp     NUMBER;
v_can_registros   NUMBER;

PROCEDURE lp_val_imp_archivo IS
begin

  --Se limpia la tabla maestra
  BEGIN
    execute immediate 'truncate table it.ta_det_mae_cue_dia_gp';
  EXCEPTION
    WHEN OTHERS THEN
      r_log.comentario := 'Error : ' || r_log.nom_proceso || '-' ||
                               v_lugar || '-' ||
                               to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                               SQLERRM;
       pat_igp.pr_ins_log(r_log);
    END;
  v_lugar := 'LP_VAL_IMP_ARCHIVO-INSERT TABLE';
  --se inserta segun los registros de la tabla temporal
  begin
    INSERT INTO it.ta_det_mae_cue_dia_gp
      (tip_registro,
       marca,
       entidad,
       sucursal,
       nro_cuenta,
       fec_alt_sistema,
       est_cuenta,
       fec_est_cuenta,
       gru_afinidad,
       gru_cta_cte,
       fec_alta,
       nro_tarjeta,
       est_tarjeta,
       fec_cam_estado,
       fec_ven_tarjeta,
       nombre,
       apellido,
       lin_credito,
       fec_cie_anterior,
       fec_cie_actual,
       fec_cie_proximo,
       fec_vto_pag_min_anterior,
       fec_ven_pag_min_actual,
       fec_vto_pag_min_proximo,
       sal_cie_ant_total,
       mto_pag_min_actual,
       mto_pag_mes,
       sal_pag_minimo,
       tas_dia_punitorio,
       porc_pag_minimo,
       fec_ult_pago,
       mto_mora,
       cod_com_seg_vida,
       des_comp_seg_vida,
       tas_int_moratorio,
       tas_int_financiacion,
       dia_mora,
       sal_facturar,
       sal_facturado,
       sal_financiado,
       sal_cuo_pendientes,
       sal_deu_total,
       tip_cobro,
       fec_ult_compra,
       fec_ult_operacion,
       nro_documento,
       adicional,
       int_cor_suspenso,
       int_mor_suspenso,
       int_pun_suspenso,
       filler,
       fec_ult_proceso,
       usu_modificacion,
       mto_car_suspenso,
       iva_int_suspenso,
       iva_car_suspenso,
       tot_car_suspenso) --COLUMNAS
      (SELECT tip_registro,
              marca,
              entidad,
              sucursal,
              nro_cuenta,
              to_date(to_char(t.fec_alt_sistema), 'yyyy/mm/dd') fec_alt_sistema,
              est_cuenta,
              to_date(to_char(t.fec_est_cuenta), 'yyyy/mm/dd') fec_est_cuenta,
              gru_afinidad,
              gru_cta_cte,
              to_date(to_char(t.fec_alta), 'yyyy/mm/dd') fec_alta,
              nro_tarjeta,
              est_tarjeta,
              to_date(to_char(t.fec_cam_estado), 'yyyy/mm/dd') fec_cam_estado,
              to_date(to_char(t.fec_ven_tarjeta), 'yyyy/mm/dd') fec_ven_tarjeta,
              nombre,
              apellido,
              trunc(lin_credito) lin_credito,
              to_date(to_char(t.fec_cie_anterior), 'yyyy/mm/dd') fec_cie_anterior,
              to_date(to_char(t.fec_cie_actual), 'yyyy/mm/dd') fec_cie_actual,
              to_date(to_char(t.fec_cie_proximo), 'yyyy/mm/dd') fec_cie_proximo,
              to_date(to_char(t.fec_vto_pag_min_anterior), 'yyyy/mm/dd') fec_vto_pag_min_anterior,
              to_date(to_char(t.fec_ven_pag_min_actual), 'yyyy/mm/dd') fec_ven_pag_min_actual,
              to_date(to_char(t.fec_vto_pag_min_proximo), 'yyyy/mm/dd') fec_vto_pag_min_proximo,
              trunc(sal_cie_ant_total) sal_cie_ant_total,
              trunc(mto_pag_min_actual) mto_pag_min_actual,
              trunc(mto_pag_mes) mto_pag_mes,
              trunc(sal_pag_minimo) sal_pag_minimo,
              tas_dia_punitorio,
              porc_pag_minimo,
              to_date(to_char(t.fec_ult_pago), 'yyyy/mm/dd') fec_ult_pago,
              trunc(mto_mora) mto_mora,
              cod_com_seg_vida,
              des_comp_seg_vida,
              tas_int_moratorio,
              tas_int_financiacion,
              dia_mora,
              trunc(sal_facturar) sal_facturar,
              trunc(sal_facturado) sal_facturado,
              trunc(sal_financiado) sal_financiado,
              trunc(sal_cuo_pendientes) sal_cuo_pendientes,
              trunc(sal_deu_total) sal_deu_total,
              tip_cobro,
              to_date(to_char(t.fec_ult_compra), 'yyyy/mm/dd') fec_ult_compra,
              to_date(to_char(t.fec_ult_operacion), 'yyyy/mm/dd') fec_ult_operacion,
              nro_documento,
              adicional,
              trunc(int_cor_suspenso) int_cor_suspenso,
              trunc(int_mor_suspenso) int_mor_suspenso,
              trunc(int_pun_suspenso) int_pun_suspenso,
              filler,
              SYSDATE,
              USER,
              trunc(mto_car_suspenso) mto_car_suspenso,
              trunc(iva_int_suspenso) iva_int_suspenso,
              trunc(iva_car_suspenso) iva_car_suspenso,
              trunc(tot_car_suspenso) tot_car_suspenso
         FROM it.ta_det_mae_cue_dia_gp_tmp t
        WHERE EXISTS (SELECT 1
                 FROM ta_cta_tarjetas tc
                WHERE tc.nro_cuenta = t.nro_cuenta)
          and t.adicional = 0);
          commit;
  exception
    when others then
       r_log.comentario := 'Error : ' || r_log.nom_proceso || '-' ||
                               v_lugar || '-' ||
                               to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                               SQLERRM;
       pat_igp.pr_ins_log(r_log);
       raise_application_error(-20000, 'Error al insertar ta_det_mae_cue_dia_gp-'||to_char(v_fecha, 'dd/mm/yyyy'));
  end;
END;

PROCEDURE pr_trg_activar(p_accion in number) is
  v_mensaje varchar2(500);
  v_aud_activa varchar2(1):=nvl(fug_obt_pardinamico('TAR_ACT_TRI_AUDITORIA'),'N');
begin
  --Accion
  --0 Desactivar
  --1 Activar
    if p_accion=0 then
     if v_aud_activa = 'S' then 
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CTA_TARJETAS DISABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CTA_TARJETAS DISABLE', v_mensaje);
     end if;
      sql_util.ejecute_dml('ALTER TRIGGER TB_TA_CTA_TARJETAS DISABLE', v_mensaje);
    elsif p_accion=1 then
     if v_aud_activa = 'S' then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CTA_TARJETAS ENABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CTA_TARJETAS ENABLE', v_mensaje);
     end if;
      sql_util.ejecute_dml('ALTER TRIGGER TB_TA_CTA_TARJETAS ENABLE', v_mensaje);
    end if;
    if v_mensaje is not null then
      r_log.comentario:=v_mensaje;
      pat_igp.pr_ins_log(r_log);
    end if;
exception
  when others then
     if v_aud_activa = 'S' then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_CTA_TARJETAS ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_CTA_TARJETAS ENABLE', r_log.comentario);
     end if; 
      sql_util.ejecute_dml('ALTER TRIGGER TB_TA_CTA_TARJETAS ENABLE', r_log.comentario);
      pat_igp.pr_ins_log(r_log);
end;
PROCEDURE pr_trg_activar_cierre(p_accion in number) is
  v_mensaje varchar2(500);
begin
  --Accion
  --0 Desactivar
  --1 Activar
    if p_accion=0 then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_SAL_CIERRES DISABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_SAL_CIERRES DISABLE', v_mensaje);
    elsif p_accion=1 then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_SAL_CIERRES ENABLE', v_mensaje);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_SAL_CIERRES ENABLE', v_mensaje);
    end if;
    if v_mensaje is not null then
      r_log.comentario:=v_mensaje;
      pat_igp.pr_ins_log(r_log);
    end if;
exception
  when others then
      sql_util.ejecute_dml('ALTER TRIGGER AA_TA_SAL_CIERRES ENABLE', r_log.comentario);
      sql_util.ejecute_dml('ALTER TRIGGER AB_TA_SAL_CIERRES ENABLE', r_log.comentario);
      pat_igp.pr_ins_log(r_log);
end;

PROCEDURE pr_obt_cierre(p_can_dia_espera IN VARCHAR2,
                        p_exi_cierre     OUT VARCHAR2,
                        p_fec_cierre     OUT VARCHAR2) IS
v_fec_actual ta_cal_cierres.fec_cierre%TYPE := trunc(SYSDATE);
v_ent_global ge_par_dinamicos.val_parametro%TYPE := fug_obt_pardinamico('COD_ENT_GLOBAL');

BEGIN
  BEGIN
    SELECT 'S', cie.fec_cierre
      INTO p_exi_cierre, p_fec_cierre
      FROM ta_cal_cierres cie
     WHERE cie.fec_cierre = v_fec_actual - p_can_dia_espera
       AND cie.cod_ent_procesadora = v_ent_global
       AND rownum = 1;
  EXCEPTION
    WHEN no_data_found THEN
      p_exi_cierre := 'N';
    WHEN OTHERS THEN
      p_exi_cierre     := 'N';
      r_log.comentario := substr('Error al recuperar cierre:' ||
                                 r_log.nom_proceso || '-' || v_lugar || '-' ||
                                 to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                 SQLERRM,
                                 1,
                                 500);
      pat_igp.pr_ins_log(r_log);
  END;
END;

procedure pr_ins_sal_cierres IS
v_fec_cierre     ta_cal_cierres.fec_cierre%TYPE;
v_exi_cierre     VARCHAR2(1) := 'N';
v_can_dia_espera VARCHAR2(5) := nvl(fug_obt_pardinamico('CAN_DIA_SAL_CIE_GP'),2);

begin
  pr_obt_cierre(v_can_dia_espera, v_exi_cierre, v_fec_cierre);
    IF v_exi_cierre = 'S' THEN
      IF v_fec_cierre IS NOT NULL THEN
        pr_trg_activar_cierre(0);
        BEGIN
          MERGE INTO ta_sal_cierres s
          USING ta_det_mae_cue_dia_gp a
             ON (s.nro_cuenta = a.nro_cuenta AND s.fec_cierre = a.fec_cie_anterior)
           WHEN NOT MATCHED THEN
            INSERT
                  (nro_cuenta,
                   fec_cierre,
                   sal_financiado,
                   sal_facturado,
                   sal_facturar,
                   lin_credito,
                   mto_pag_minimo,
                   fec_vto_pago,
                   lin_cuotas,
                   sal_cuo_pendientes,
                   dia_atraso,
                   lin_especial)
                VALUES
                  (a.nro_cuenta,
                   v_fec_cierre,
                   a.sal_cie_ant_total,
                   0,
                   0,
                   a.lin_credito,
                   a.mto_pag_min_actual,
                   a.fec_vto_pag_min_anterior,
                   0,
                   0,
                   a.dia_mora,
                   0)
                   WHERE a.fec_cie_anterior = v_fec_cierre
                     AND a.fec_vto_pag_min_anterior IS NOT NULL
            WHEN MATCHED THEN
              UPDATE
                 SET sal_financiado      =  a.sal_cie_ant_total,
                     sal_facturado       =  0,
                     sal_facturar        =  0,
                     lin_credito         =  a.lin_credito,
                     mto_pag_minimo      =  a.mto_pag_min_actual,
                     fec_vto_pago        =  a.fec_vto_pag_min_anterior,
                     lin_cuotas          =  0,
                     sal_cuo_pendientes  =  0,
                     dia_atraso          =  a.dia_mora,
                     lin_especial        =  0;
          EXCEPTION
            WHEN OTHERS THEN
               r_log.comentario := substr('Error en proceso, merge ins cierre:' || r_log.nom_proceso || '-' ||
                                       v_lugar || '-' ||
                                       to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                       SQLERRM,1,500);
               pat_igp.pr_ins_log(r_log);
          END;
          COMMIT;
          pr_trg_activar_cierre(1);
        END IF;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        pr_trg_activar_cierre(1);
        r_log.comentario := substr('Error en proceso ins cierre: ' || r_log.nom_proceso || '-' ||
                                   v_lugar || '-' ||
                                   to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||
                                   SQLERRM,1,500);
        pat_igp.pr_ins_log(r_log);
END;
/*Procedimiento que actualiza TA_CTA_TARJETAS*/
procedure pr_pro_cta_tar IS
  v_lugar           varchar2(50) := 'PR_PRO_CTA_TAR';
  v_tarea           varchar2(100) := 'procesar_maestro_gp'; -- Nombre de la tarea
  v_niv_paralelismo number := nvl(to_number(fug_obt_pardinamico('TAR_VAL_NIV_PAR_MAESTRO')),6);--nivel paralelismo
  v_act_paralelismo varchar2(1) := nvl(fug_obt_pardinamico('TAR_ACT_PAR_MAESTRO'),'N');
BEGIN               
  pr_trg_activar(0);
      -- Si el parametro de paralelismo esta activo, ejecutar la actualizacion de este modo
  IF v_act_paralelismo = 'S' THEN
      r_log.comentario := '*** INICIO PARALELISMO Merge ta_det_mae_cue_dia_gp ***';
      pat_igp.pr_ins_log(r_log, FALSE);
      BEGIN
      -- Eliminar la tarea y los bloques relacionados
        DBMS_PARALLEL_EXECUTE.DROP_TASK(v_tarea);
      EXCEPTION
        WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
          NULL;
      END;
      -- Crear la tarea
      DBMS_PARALLEL_EXECUTE.create_task(v_tarea);
      -- Dividir la tabla por ROWID en intervalos de 50000
      DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(v_tarea,
                                                   'IT',
                                                   'TA_DET_MAE_CUE_DIA_GP',
                                                   true,
                                                   50000);
      -- Ejecutar el DML en paralelo
      DBMS_PARALLEL_EXECUTE.run_task(task_name      => v_tarea,
                                     sql_stmt       => 'BEGIN
                  pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1;
                  merge into ta_cta_tarjetas tc
                  using ta_det_mae_cue_dia_gp c
                  on
                  (
                  tc.nro_cuenta=c.nro_cuenta
                  and c.rowid BETWEEN :start_id AND :end_id
                  )
                  when matched then
                    update
                    SET tc.lin_credito = CASE
                                    WHEN (c.lin_credito >= 0 AND nvl(it.fue_obt_val_max_refcodes(''EST_CUE_TC_GP'',c.est_cuenta),''X'')=''C'')
                                      THEN  c.lin_credito
                                    WHEN (c.lin_credito > 0 AND  nvl(it.fue_obt_val_max_refcodes(''EST_CUE_TC_GP'',c.est_cuenta),''X'')<>''C'')
                                      THEN c.lin_credito
                                    ELSE tc.lin_credito END,
                 tc.sal_facturar = 0,
                 tc.sal_facturado = 0,
                 tc.sal_financiado = c.sal_deu_total,
                 tc.sal_ult_extracto = c.sal_cie_ant_total,
                 tc.sal_cuo_pendientes = 0,
                 tc.mto_pag_minimo = c.mto_pag_min_actual,
                 tc.sal_pag_minimo = c.sal_pag_minimo,
                 tc.mto_mora = c.mto_mora,
                 tc.dia_mora = c.dia_mora,
                 tc.mar_mora = DECODE(GREATEST(c.dia_mora,0),0,''N'',''S''),
                 tc.max_atraso = DECODE(GREATEST(tc.max_atraso, c.dia_mora),c.dia_mora,c.dia_mora,tc.max_atraso),
                 tc.mto_pag_mes = c.mto_pag_mes,
                 tc.estado = nvl((SELECT cod.val_maximo
                                FROM ba_cod_referencias cod
                               WHERE cod.dominio = ''EST_CUE_TC_GP''
                                 AND cod.val_minimo = c.est_cuenta),tc.estado),
                 --tc.fec_apertura = c.fec_alt_sistema,
                 tc.fec_ult_pago = nvl(c.fec_ult_pago,tc.fec_ult_pago),----si viene null no actualizar
                 tc.fec_ult_compra = c.fec_ult_compra,
                 tc.fec_ult_operacion = c.fec_ult_operacion,
                 tc.fec_ult_cierre = c.fec_cie_actual, --Fecha de Cierre Actual
                 tc.fec_vct_ult_cierre = c.fec_vto_pag_min_anterior,--nvl(it.pat_imp.fu_obt_fec_vencim(v_ent_global,tc.cod_modalidad,fue_obt_val_max_refcodes(''GRU_CIERRE_GP'',c.gru_cta_cte)),tc.fec_vct_ult_cierre),--c.fec_ven_pag_min_actual, --Fec Vto Pago Min Act
                 tc.fec_ult_extracto = c.fec_cie_actual, --Fecha de Cierre Actual
                 tc.tip_cierre = nvl(fue_obt_val_max_refcodes(''GRU_CIERRE_GP'', c.gru_cta_cte), tc.tip_cierre),
                 tc.cod_tip_cierre     = nvl(fue_obt_val_max_refcodes(''GRU_CIERRE_GP'', c.gru_cta_cte), tc.tip_cierre),
                 tc.tas_financiacion = c.tas_int_financiacion,
                 tc.tas_mora = c.tas_int_moratorio,
                 tc.por_pag_minimo = c.porc_pag_minimo,
                 tc.ind_seg_vida = decode(c.cod_com_seg_vida, NULL, ''N'', ''S'');
                 end;',
                                     language_flag  => DBMS_SQL.NATIVE,
                                     parallel_level => v_niv_paralelismo);
      --Verificar el estatus de la ejecucion
      IF DBMS_PARALLEL_EXECUTE.FINISHED !=
         DBMS_PARALLEL_EXECUTE.TASK_STATUS(v_tarea) THEN
        r_log.comentario := 'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ' ||v_tarea;
        pat_igp.pr_ins_log(r_log);
        raise_application_error(-20000,
                                'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ' ||
                                v_tarea);
      END IF;
      r_log.comentario := '*** FIN PARALELISMO Merge ta_det_mae_cue_dia_gp ***';
      pat_igp.pr_ins_log(r_log, FALSE);
  ELSE
                merge into ta_cta_tarjetas tc
                using ta_det_mae_cue_dia_gp c
                on
                (
                tc.nro_cuenta=c.nro_cuenta
                )
                when matched then
                  update
                  SET tc.lin_credito = CASE
                                      WHEN (c.lin_credito >= 0 AND nvl(it.fue_obt_val_max_refcodes('EST_CUE_TC_GP',c.est_cuenta),'X')='C')
                                        THEN  c.lin_credito
                                      WHEN (c.lin_credito > 0 AND  nvl(it.fue_obt_val_max_refcodes('EST_CUE_TC_GP',c.est_cuenta),'X')<>'C')
                                        THEN c.lin_credito
                                      ELSE tc.lin_credito END,
                   tc.sal_facturar = 0,
                   tc.sal_facturado = 0,
                   tc.sal_financiado = c.sal_deu_total,
                   tc.sal_ult_extracto = c.sal_cie_ant_total,
                   tc.sal_cuo_pendientes = 0,
                   tc.mto_pag_minimo = c.mto_pag_min_actual,
                   tc.sal_pag_minimo = c.sal_pag_minimo,
                   tc.mto_mora = c.mto_mora,
                   tc.dia_mora = c.dia_mora,
                   tc.mar_mora = DECODE(GREATEST(c.dia_mora,0),0,'N','S'),
                   tc.max_atraso = DECODE(GREATEST(tc.max_atraso, c.dia_mora),c.dia_mora,c.dia_mora,tc.max_atraso),
                   tc.mto_pag_mes = c.mto_pag_mes,
                   tc.estado = nvl((SELECT cod.val_maximo
                                  FROM ba_cod_referencias cod
                                 WHERE cod.dominio = 'EST_CUE_TC_GP'
                                   AND cod.val_minimo = c.est_cuenta),tc.estado),
                   --tc.fec_apertura = c.fec_alt_sistema,
                   tc.fec_ult_pago = nvl(c.fec_ult_pago,tc.fec_ult_pago),----si viene null no actualizar
                   tc.fec_ult_compra = c.fec_ult_compra,
                   tc.fec_ult_operacion = c.fec_ult_operacion,
                   tc.fec_ult_cierre = c.fec_cie_actual, --Fecha de Cierre Actual
                   tc.fec_vct_ult_cierre = c.fec_vto_pag_min_anterior,--nvl(it.pat_imp.fu_obt_fec_vencim(v_ent_global,tc.cod_modalidad,fue_obt_val_max_refcodes('GRU_CIERRE_GP',c.gru_cta_cte)),tc.fec_vct_ult_cierre),--c.fec_ven_pag_min_actual, --Fec Vto Pago Min Act
                   tc.fec_ult_extracto = c.fec_cie_actual, --Fecha de Cierre Actual
                   tc.tip_cierre = nvl(fue_obt_val_max_refcodes('GRU_CIERRE_GP', c.gru_cta_cte), tc.tip_cierre),
                   tc.cod_tip_cierre     = nvl(fue_obt_val_max_refcodes('GRU_CIERRE_GP', c.gru_cta_cte), tc.tip_cierre),
                   tc.tas_financiacion = c.tas_int_financiacion,
                   tc.tas_mora = c.tas_int_moratorio,
                   tc.por_pag_minimo = c.porc_pag_minimo,
                   tc.ind_seg_vida = decode(c.cod_com_seg_vida, NULL, 'N', 'S');
                   COMMIT;    
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    pr_trg_activar(1);
    r_log.comentario := 'Error al actualizar : ' || r_log.nom_proceso || '-' ||
                             v_lugar || '-' ||
                             to_char(v_fecha, 'dd/mm/yyyy') || ' - ' ||SQLERRM;
                             pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000, 'Error al actualizar ta_cta_tarjetas-'||to_char(v_fecha, 'dd/mm/yyyy'));
END;

BEGIN
  /*Setear valores-llamar procedimiento de ta_logs de inicio de proceso*/
  IT.PRE_INI_APLICACION;
  v_fec_actual := pag_cal.fu_obt_fec_actual(5);
  pae_cnf.g_cod_modulo := 1;
  r_log.nom_proceso    := 'PRT_INS_MAE_CUE_GP';
  r_log.fec_hor_ini    := SYSDATE;
  r_log.comentario     := '*** Inicio proceso de maestro de cuentas GP ***';
  pat_igp.pr_ins_log(r_log, FALSE);

  /*Validaciones para la importacion de registros*/
  /*Recuperamos la cantidad de registros del detalle del temporal*/
  BEGIN
    SELECT COUNT(*)
      INTO v_can_reg_tmp
      FROM ta_det_mae_cue_dia_gp_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      v_can_reg_tmp := 0;
  END;
  /*Recuperamos la cantidad de registros situada en la cabecera del temporal*/
  BEGIN
    SELECT c.can_registros
      INTO v_can_registros
      FROM ta_cab_mae_cue_dia_gp_tmp c;
  EXCEPTION
    WHEN OTHERS THEN
      r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'Error al buscar el resumen del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            SQLERRM;
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000,'Error al recuperar la cantidad de registros de la cabecera. '||sqlerrm);
  END;
  /*Validamos que coincidan la cantidad de registros*/
  IF nvl(v_can_registros, 0) <> nvl(v_can_reg_tmp, 0) THEN
    r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||'Cantidad de Detalle no coincide con la cabecera'||' - '||
                         to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                         SQLERRM;
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000, 'Cantidad de Detalle no coincide con la cabecera.');
  END IF;
  /*Se realiza la importacion del temporal al maestro*/
  lp_val_imp_archivo();

  /*Se realiza la actualizacion de datos de cuentas de tc*/
  pr_pro_cta_tar();

  /*Verificacion de insercion de saldos de cierres*/
  pr_ins_sal_cierres;

  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Finaliza proceso de maestro de cuentas GP ***';
  pat_igp.pr_ins_log(r_log, FALSE);
  pr_trg_activar(1);
  pr_trg_activar_cierre(1);
EXCEPTION
  WHEN OTHERS THEN
    r_log.comentario := 'Error en proceso : ' || r_log.nom_proceso || ' - '||
                         to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                         SQLERRM;
   pat_igp.pr_ins_log(r_log);
   prg_ins_log_programas('PRT_INS_MAE_CUE_GP',substr(SQLERRM,1,4000));
   pr_trg_activar(1);
   pr_trg_activar_cierre(1);
   raise_application_error(-20000, 'Error en proceso '|| r_log.nom_proceso ||'-'||to_char(v_fecha, 'dd/mm/yyyy'));
END;
/
