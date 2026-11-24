CREATE OR REPLACE PROCEDURE it.prp_act_ori_fondos IS
  v_cod_moneda    pr_fondos.cod_moneda%type;
  v_mto_utilizado pr_fondos.mto_utilizado%type;
  v_cot_original  ge_cotizaciones.val_conversion%type;
  v_cot_destino   ge_cotizaciones.val_conversion%type;
  v_fec_anterior  date;
  v_hor_inicio  ge_procesos_det.hor_inicio%type;
  v_hor_fin     ge_procesos_det.hor_fin%type;
  v_error       ge_procesos_det.error%type;

  CURSOR C_DESEMBOLSOS IS
    SELECT SUM(nvl(pr_cta_prestamos.mto_capital, 0)) tot_desembolso,
           pr_cta_prestamos.cod_ori_fondo,
           pr_cta_prestamos.cod_moneda
      FROM pr_cta_prestamos pr_cta_prestamos
     WHERE pr_cta_prestamos.estado <> 'N'
       AND pr_cta_prestamos.cod_ori_fondo is not null
       AND pr_cta_prestamos.fec_inicio = v_fec_anterior
     GROUP BY pr_cta_prestamos.cod_ori_fondo, pr_cta_prestamos.cod_moneda;

  CURSOR C_REV_DESEMBOLSOS IS
   SELECT sum(distinct pr.mto_capital) tot_rev_desembolso,
         pr.cod_ori_fondo,
         pr.cod_moneda
    FROM ge_movimientos_ant t, pr_cta_prestamos pr
   WHERE t.cod_modulo = pr.cod_modulo
     AND t.cod_modalidad = pr.cod_modalidad
     AND t.nro_cuenta = pr.nro_cuenta
     AND pr.cod_ori_fondo is not null
     AND t.cod_modulo = 6
     AND t.cod_tra_padre =358
     AND t.reversado = 'S'
     AND t.monto < 0
   AND pr.fec_inicio < v_fec_anterior
   group by pr.cod_moneda, pr.cod_ori_fondo;

  CURSOR C_COBROS IS
    SELECT SUM(nvl(cob.mto_capital, 0)) tot_cob_capital,
           pr.cod_ori_fondo,
           pr.cod_moneda
      FROM pr_cobros cob, pr_cta_prestamos pr
     WHERE cob.nro_cuenta = pr.nro_cuenta
       AND cob.fecha = v_fec_anterior
       AND pr.cod_ori_fondo is not null
     GROUP BY pr.cod_ori_fondo, pr.cod_moneda;

  CURSOR C_COB_REVERSADOS IS
     SELECT nvl(sum(t.monto),0) tot_cuo_reversado, pr.cod_ori_fondo, pr.cod_moneda
     FROM ge_movimientos_ant t, pr_cta_prestamos pr
    WHERE t.nro_cuenta = pr.nro_cuenta
      AND pr.cod_ori_fondo is not null
      AND t.cod_transaccion =  pap_pre.fu_obt_tra_concepto('CA',pr.estado,pr.tipo,pr.tip_interes,pr.tip_renovacion)
      AND t.cod_modulo = 6
      AND t.reversado = 'S'
      AND EXISTS (SELECT 1
             FROM pr_movimientos_his ph
            WHERE ph.nro_cuenta = t.nro_cuenta
              AND ph.nro_documento3 = t.nro_documento3
              AND reversado = 'S'
              AND ph.fecha = t.fec_valor)
      AND NOT EXISTS
    (SELECT 1
             FROM ge_movimientos_ant tc, pr_cta_prestamos prc
            WHERE tc.nro_cuenta = prc.nro_cuenta
              AND tc.cod_transaccion = pap_pre.fu_obt_tra_concepto('CA',prc.estado,prc.tipo,prc.tip_interes,prc.tip_renovacion)
              AND tc.cod_modulo = 6
              AND tc.reversado = 'N'
              AND tc.nro_cuenta = t.nro_cuenta
              AND tc.nro_documento3 = t.nro_documento3)
    GROUP BY pr.cod_moneda, pr.cod_ori_fondo;



  PROCEDURE LP_ACT_ORI_FONDOS(P_COD_ORI_FONDO IN PR_FONDOS.COD_ORI_FONDO%TYPE,
                              P_COD_MONEDA    IN PR_FONDOS.COD_MONEDA%TYPE,
                              P_MONTO         IN PR_FONDOS.MTO_UTILIZADO%TYPE);

  /* Actualizar origen de fondos. */
  PROCEDURE LP_ACT_ORI_FONDOS(P_COD_ORI_FONDO IN PR_FONDOS.COD_ORI_FONDO%TYPE,
                              P_COD_MONEDA    IN PR_FONDOS.COD_MONEDA%TYPE,
                              P_MONTO         IN PR_FONDOS.MTO_UTILIZADO%TYPE) IS
    v_cod_moneda    pr_fondos.cod_moneda%type;
    v_mto_utilizado pr_fondos.mto_utilizado%type;
    v_cot_original  ge_cotizaciones.val_conversion%type;
    v_cot_destino   ge_cotizaciones.val_conversion%type;
  begin
    select cod_moneda
      into v_cod_moneda
      from pr_fondos
     where cod_ori_fondo = p_cod_ori_fondo;
     if p_cod_moneda != v_cod_moneda then
    --- Convertir a moneda del fondo
       pag_gen.pr_con_mon_a_moneda(p_cod_moneda,v_cod_moneda,p_monto,v_mto_utilizado,v_cot_original,v_cot_destino);
     else
        v_mto_utilizado := p_monto;
     end if;
   --- Actualizar
    UPDATE pr_fondos
       SET mto_utilizado = nvl(mto_utilizado, 0) + nvl(v_mto_utilizado, 0)
     WHERE cod_ori_fondo = p_cod_ori_fondo;
  EXCEPTION
    WHEN OTHERS THEN
      if sqlcode = -54 then
        raise_application_error(-20000,'Registro de origen de fondos ' || p_cod_ori_fondo || ' bloqueado por otro usuario.');
      else
        raise;
      end if;
  END;
BEGIN
 BEGIN
  select d.hor_inicio, d.hor_fin,d.error
   into  v_hor_inicio, v_hor_fin,v_error
   from ge_procesos_det d 
   where d.cod_proceso = 10 
    and cod_programa = 'PRP_ACT_ORI_FONDOS';
  EXCEPTION
  when others then
    v_error := null;
    v_hor_inicio :=null;
    v_hor_fin := null;
 END;
 If (v_hor_inicio is not null and v_hor_fin is null)    --inicio de dia
    or (v_hor_inicio is not null and v_hor_fin is not null and v_error is not null)--proceso independiente
    then
    v_fec_anterior:= pag_cal.FU_OBT_FEC_ANTERIOR(6);
    BEGIN
      pre_ini_aplicacion;
      pae_cnf.G_COD_MODULO := 1;
    END;
    FOR reg in c_desembolsos LOOP
      BEGIN
        lp_act_ori_fondos(reg.cod_ori_fondo,reg.cod_moneda,reg.tot_desembolso * -1);
      EXCEPTION
        WHEN OTHERS THEN
          prg_ins_log_errores('PRP_ACT_ORI_FONDOS','Error al actualizar origen de fondos-desembolso','ORIGEN DE FONDOS',reg.cod_ori_fondo,'FEC_PROCESO',v_fec_anterior,'MONTO', reg.tot_desembolso);
          RAISE_APPLICATION_ERROR(-20000,'Error al actualizar origen de fondos-desembolso.');
      END;
    END LOOP;
    FOR reg in c_rev_desembolsos LOOP
      BEGIN
        lp_act_ori_fondos(reg.cod_ori_fondo,reg.cod_moneda,reg.tot_rev_desembolso);
      EXCEPTION
        WHEN OTHERS THEN
          prg_ins_log_errores('PRP_ACT_ORI_FONDOS','Error al actualizar origen de fondos-rev-desembolso','ORIGEN DE FONDOS',reg.cod_ori_fondo,'FEC_PROCESO',v_fec_anterior,'MONTO', reg.tot_rev_desembolso);
          RAISE_APPLICATION_ERROR(-20001,'Error al actualizar origen de fondos-rev-desembolso.');
      END;
    END LOOP;
    FOR reg in c_cobros loop
      BEGIN
        lp_act_ori_fondos(reg.cod_ori_fondo,reg.cod_moneda,reg.tot_cob_capital);
      EXCEPTION
        WHEN OTHERS THEN
          prg_ins_log_errores('PRP_ACT_ORI_FONDOS','Error al actualizar origen de fondos-cobro', 'ORIGEN DE FONDOS',reg.cod_ori_fondo,'FEC_PROCESO',v_fec_anterior,'MONTO',reg.tot_cob_capital);
          RAISE_APPLICATION_ERROR(-20002,'Error al actualizar origen de fondos-cobro.');
      END;
    END LOOP;
    FOR reg in c_cob_reversados loop
      BEGIN
        lp_act_ori_fondos(reg.cod_ori_fondo,reg.cod_moneda,reg.tot_cuo_reversado);
      EXCEPTION
        WHEN OTHERS THEN
          prg_ins_log_errores('PRP_ACT_ORI_FONDOS','Error al actualizar origen de fondos rev-cobro', 'ORIGEN DE FONDOS',reg.cod_ori_fondo,'FEC_PROCESO',v_fec_anterior,'MONTO',reg.tot_cuo_reversado);
          RAISE_APPLICATION_ERROR(-20003,'Error al actualizar origen de fondos rev-cobro');
      END;
    END LOOP;
    COMMIT;
  ELSE
    RAISE_APPLICATION_ERROR(-20004,'Este proceso ya fue ejecutado.');
  END IF;
END;
