CREATE OR REPLACE PROCEDURE IT.prm_job_pr_cta_prestamos IS

  CURSOR cli IS
    SELECT nro_cuenta,
           dig_verificador,
           cod_modulo,
           cod_modalidad,
           cod_oficina,
           nro_cta_debito,
           nro_cta_renovada,
           fec_cancelacion,
           estado,
           mto_capital,
           sal_capital,
           sal_interes,
           val_int_devengar,
           nro_solicitud,
           est_batch,
           sal_cap_batch,
           sal_int_batch,
           nro_documento,
           est_anterior,
           dev_acumulado,
           tip_documento,
           nro_sol_renovada,
           cob_automatico,
           sal_int_adelantado,
           fec_ult_devengado,
           dev_no_cobrado,
           nro_linea,
           cod_moneda,
           monto,
           fec_inicio,
           fec_vencimiento,
           tipo,
           val_tasa,
           can_cuotas,
           can_cuo_pagadas,
           dia_atraso,
           max_atraso,
           pro_atraso,
           exo_impuestos,
           cod_causa,
           cod_canal,
           cod_campana,
           cod_sec_credito,
           usu_insercion,
           fec_insercion,
           usu_modificacion,
           fec_modificacion,
           descripcion,
           tip_destino,
           tip_renovacion,
           cod_ori_fondo,
           mto_lin_aplicado,
           sal_int_ade_batch,
           per_vto_capital,
           per_vto_interes,
           dev_suspenso,
           tip_interes,
           fec_juicio,
           cod_ent_juicio,
           cat_renovaciones,
           en_juicio,
           cod_banca,
           mto_mora,
           por_ori_fondo,
           fec_ren_tas_orig,
           fec_ren_tas,
           cod_sub_modalidad,
           cod_rub_economico,
           --nro_cta_novada,
           fec_ult_categorizacion,
          -- fec_ini_rrr,
           dia_atr_original,
           dia_atr_3r,
           fec_ini_ori_mora,
           cat_pre_diferida
      FROM it.pr_cta_prestamos@uenodesg x
     WHERE NOT EXISTS (SELECT 1
              FROM pr_cta_prestamos p
             WHERE p.nro_cuenta = x.nro_cuenta);

  v_error    VARCHAR2(500);
  v_err      VARCHAR2(500);
  v_ermsj    VARCHAR2(2000);
  v_fecha    DATE := SYSDATE;
  v_cod_mod  NUMBER;
  v_cantidad number := 0;
  v_fec      date := pag_cal.fu_obt_fec_actual(1);
  -- variables asociación
  /*v_cod_ente  number := 4000;
  v_existe    varchar2(1);
  v_exi_linea varchar2(1);
  v_nro_linea number;
  v_desc_ente varchar2(1000);*/
BEGIN

  BEGIN
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := '1';
  END;

  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table pr_cta_prestamos disable all triggers',
                       v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al desabilitar triggers pr_cta_prestamos ' ||
                            v_err);
  END IF;
  sql_util.ejecute_dml('alter table ge_cuentas disable all triggers',
                       v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al desabilitar triggers ge_cuentas ' || v_err);
  END IF;
  sql_util.ejecute_dml('alter table pr_fondos disable all triggers', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al desabilitar triggers pr_fondos ' || v_err);
  END IF;
  sql_util.ejecute_dml('alter table ge_entes disable all triggers', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al desabilitar triggers ge_entes ' || v_err);
  END IF;
  sql_util.ejecute_dml('alter table pr_cta_prestamos disable constraints FK_PCPRE_NRO_CTA_RENOVADA',
                       v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al desabilitar constraints pr_cta_prestamos ' ||
                            v_err);
  END IF;
  --Habilitar trigger
  sql_util.ejecute_dml('alter trigger ta_pr_cta_prestamos enable', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al habilitar triggers ta_pr_cta_prestamos ' ||
                            v_err);
  END IF;

  --update ba_modulos set fec_implementacion = null where cod_modulo = 31;
  /*
  sql_util.ejecute_dml('truncate table pr_cta_prestamos', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al truncar pr_cta_prestamos ' || v_err);
  END IF;
  if v_err is not null then
    raise_application_error(-20000,'Al truncar CV_VAL_CUS_MOVIMIENTOS '||v_err);
  end if;
  sql_util.ejecute_dml('truncate table CV_VAL_CUSTODIAS', v_err);
  if v_err is not null then
    raise_application_error(-20000,'Al truncar CV_VAL_CUSTODIAS '||v_err);
  end if;*/
  /*
  sql_util.ejecute_dml('alter table ge_cta_clientes disable all triggers', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al desabilitar triggers pr_cta_prestamos ' || v_err);
  END IF;
  sql_util.ejecute_dml('delete ge_cta_clientes where cod_modulo = 6', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al borrar ge_cta_clientes ' || v_err);
  END IF;
  sql_util.ejecute_dml('alter table ge_cta_clientes enable all triggers', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al habilitar triggers ge_cta_clientes ' || v_err);
  END IF;*/
  /*
  sql_util.ejecute_dml('delete GE_CHEQUES_DET d where exists (select 1 from ge_cuentas a where cod_modulo = 6 and d.nro_cuenta = a.nro_cuenta)', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al borrar GE_CHEQUES_DET ' || v_err);
  END IF;
  
  sql_util.ejecute_dml('alter table ge_cuentas disable all triggers', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al desabilitar triggers ge_cuentas ' || v_err);
  END IF;
  sql_util.ejecute_dml('delete ge_cuentas where cod_modulo = 6', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al borrar ge_cuentas ' || v_err);
  END IF;
  sql_util.ejecute_dml('alter table ge_cuentas enable all triggers', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al habilitar triggers ge_cuentas ' || v_err);
  END IF;
  */
  delete mi_logs where proceso = 'PR_CTA_PRESTAMOS';

  FOR a IN cli LOOP
    v_cod_mod  := null;
    v_cantidad := v_cantidad + 1;
  
    BEGIN
      INSERT INTO pr_cta_prestamos
        (nro_cuenta,
         dig_verificador,
         cod_modulo,
         cod_modalidad,
         cod_oficina,
         nro_cta_debito,
         nro_cta_renovada,
         fec_cancelacion,
         estado,
         mto_capital,
         sal_capital,
         sal_interes,
         val_int_devengar,
         nro_solicitud,
         est_batch,
         sal_cap_batch,
         sal_int_batch,
         nro_documento,
         est_anterior,
         dev_acumulado,
         tip_documento,
         nro_sol_renovada,
         cob_automatico,
         sal_int_adelantado,
         fec_ult_devengado,
         dev_no_cobrado,
         nro_linea,
         cod_moneda,
         monto,
         fec_inicio,
         fec_vencimiento,
         tipo,
         val_tasa,
         can_cuotas,
         can_cuo_pagadas,
         dia_atraso,
         max_atraso,
         pro_atraso,
         exo_impuestos,
         cod_causa,
         cod_canal,
         cod_campana,
         cod_sec_credito,
         tip_destino,
         tip_renovacion,
         cod_ori_fondo,
         mto_lin_aplicado,
         sal_int_ade_batch,
         descripcion,
         per_vto_capital,
         per_vto_interes,
         dev_suspenso,
         tip_interes,
         fec_juicio,
         cod_ent_juicio,
         cat_renovaciones,
         en_juicio,
         cod_banca,
         mto_mora,
         por_ori_fondo,
         fec_ren_tas_orig,
         fec_ren_tas,
         cod_rub_economico,
         /*dia_atr_original, dia_atr_3r, fec_ini_ori_mora, cat_pre_diferida,*/
         usu_insercion,
         usu_modificacion,
         fec_insercion,
         fec_modificacion)
      VALUES
        (a.nro_cuenta,
         a.dig_verificador,
         a.cod_modulo,
         a.cod_modalidad,
         a.cod_oficina,
         a.nro_cta_debito,
         a.nro_cta_renovada,
         a.fec_cancelacion,
         a.estado,
         a.mto_capital,
         a.sal_capital,
         a.sal_interes,
         a.val_int_devengar,
         a.nro_solicitud,
         a.estado,
         a.sal_capital,
         a.sal_interes,
         a.nro_documento,
         a.est_anterior,
         a.dev_acumulado,
         a.tip_documento,
         a.nro_sol_renovada,
         a.cob_automatico,
         a.sal_int_adelantado,
         a.fec_ult_devengado,
         a.dev_no_cobrado,
         a.nro_linea,
         a.cod_moneda,
         a.monto,
         a.fec_inicio,
         a.fec_vencimiento,
         a.tipo,
         a.val_tasa,
         a.can_cuotas,
         a.can_cuo_pagadas,
         a.dia_atraso,
         a.max_atraso,
         a.pro_atraso,
         a.exo_impuestos,
         a.cod_causa,
         a.cod_canal,
         a.cod_campana, /*,decode(*/
         a.cod_sec_credito /*,609,607,a.cod_sec_credito)*/,
         a.tip_destino,
         a.tip_renovacion,
         a.cod_ori_fondo,
         a.mto_lin_aplicado,
         a.sal_int_adelantado,
         a.descripcion,
         a.per_vto_capital,
         a.per_vto_interes,
         a.dev_suspenso,
         a.tip_interes,
         a.fec_juicio,
         a.cod_ent_juicio,
         a.cat_renovaciones,
         a.en_juicio,
         a.cod_banca,
         a.mto_mora,
         a.por_ori_fondo,
         a.fec_ren_tas_orig,
         a.fec_ren_tas,
         a.cod_rub_economico,
         /*a.dia_atr_original, a.dia_atr_3r, a.fec_ini_ori_mora, a.cat_pre_diferida,*/
         a.usu_insercion,
         a.usu_modificacion,
         a.fec_insercion,
         a.fec_modificacion);
    
      /*if v_cod_mod = 627 then
       -- Verifica si existe el ENTE de tipo Asociación
        begin
         select distinct 'S'
           into v_existe
           from ge_entes p
          where p.cod_persona = a.cod_persona
            and p.tipo = 'AS';
        exception
         when no_data_found then
          v_existe := null;
        end;
        --Si no existe genera el ente y la línea asociada
        if v_existe is null then
          v_cod_ente := v_cod_ente + 1;
          select substr(j.NOM_COMPLETO,1,60) into v_desc_ente from BA_PERSONAS j where j.cod_persona = a.cod_persona;
          insert into ge_entes
             (cod_ente, descripcion, cod_persona, tipo,usu_insercion, usu_modificacion,fec_insercion, fec_modificacion)
          values
             (v_cod_ente, v_desc_ente, a.cod_persona, 'AS','MIGRA', 'MIGRA',v_fec,v_fec);
          -- insertar parámetros del ente
          insert into GE_PAR_ENTES (COD_ENTE, PARAMETRO, VAL_PARAMETRO)
             values (v_cod_ente, 'ASO_COD_RUB_CONTABLE', '240402600202099');
          insert into GE_PAR_ENTES (COD_ENTE, PARAMETRO, VAL_PARAMETRO)
             values (v_cod_ente, 'ASO_DEB_AUT_RUBRO', 'S');
        elsif v_existe = 'S' then
          begin
           select 'S'
             into v_exi_linea
             from pr_lineas p
            where p.cod_persona = a.cod_persona;
          exception
           when no_data_found then
              -- Inserte PR_LINEAS, para un limite de créditos para cada ente
               v_nro_linea := s_nro_linea.nextval;
               insert into pr_lineas
                 (nro_linea, cod_persona, cod_gru_economico, cod_modulo, cod_modalidad, cod_moneda, monto, fec_vencimiento,
                  fec_otorgamiento, mto_aplicado, descripcion, estado, observacion, niv_aprobacion, cotizacion, fec_aprobacion,
                  nro_acta)
               values
                 (v_nro_linea, a.cod_persona, null, a.cod_modulo, v_cod_mod, 'GS', 500000000,
                  a.fec_vencimiento, a.fec_inicio, 0, 'LIMITE MIGRADO', 'A', null, null, pag_gen.FU_OBT_COTIZACION('USD'),
                  v_fec, null);
              v_exi_linea := null;
          end;
        end if;
      
      end if;*/
    EXCEPTION
      WHEN OTHERS THEN
        v_error := SQLCODE;
        v_ermsj := SQLERRM;
        INSERT INTO mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        VALUES
          (1, v_error, v_ermsj, a.nro_cuenta, 'PR_CTA_PRESTAMOS', v_fecha);
    END;
    /*     if v_cantidad >= 500 then
    commit;
    v_cantidad := 0;
    end if;*/
  END LOOP;
  -- actualizo los préstamos de asociaciones, se le asigna nro de linea.
  update pr_cta_prestamos p
     set p.nro_linea =
         (select L.NRO_LINEA
            from mi_pr_cta_prestamos m, pr_lineas L
           where p.nro_cuenta = m.nro_cuenta
             and fug_obt_cli_principal(m.nro_cuenta) = l.cod_persona)
   where p.estado <> 'N'
     and p.cod_modalidad = 627;
  --actualizar estado de verificación
  update ge_cuentas
     set est_verificacion    = 'V',
         fec_verificacion    = fec_apertura,
         cod_usu_verificador = 'MIGRA',
         usu_insercion       = 'MIGRA',
         usu_modificacion    = 'MIGRA',
         fec_insercion       = v_fec,
         fec_modificacion    = v_fec
   where nvl(est_verificacion, 'N') <> 'V'
     and cod_modulo = 6;
  --Habilitar los triggers
  sql_util.ejecute_dml('alter table pr_cta_prestamos enable all triggers',
                       v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al habilitar triggers pr_cta_prestamos ' ||
                            v_err);
  END IF;
  sql_util.ejecute_dml('alter table ge_cuentas enable all triggers', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al habilitar triggers ge_cuentas ' || v_err);
  END IF;
  sql_util.ejecute_dml('alter table pr_fondos enable all triggers', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al habilitar triggers pr_fondos ' || v_err);
  END IF;
  sql_util.ejecute_dml('alter table ge_entes enable all triggers', v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al habilitar triggers ge_entes ' || v_err);
  END IF;
  sql_util.ejecute_dml('alter table pr_cta_prestamos enable constraints FK_PCPRE_NRO_CTA_RENOVADA',
                       v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000,
                            'Al habilitar constraints FK_PCPRE_NRO_CTA_RENOVADA ' ||
                            v_err);
  END IF;

  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  END IF;

  update ba_modulos
     set fec_implementacion = to_date('30102020', 'ddmmyyyy')
   where cod_modulo = 31;

EXCEPTION
  WHEN OTHERS THEN
    v_error := SQLCODE;
    v_ermsj := nvl(v_err, SQLERRM);
    v_fecha := SYSDATE;
    INSERT INTO mi_logs
      (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
    VALUES
      (1,
       v_error,
       v_ermsj,
       'verif_job_pr_cta_prestamos',
       'PR_CTA_PRESTAMOS',
       v_fecha);
    COMMIT;
END;
/

