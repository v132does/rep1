CREATE OR REPLACE PROCEDURE IT.prm_job_pr_cobros_rrr IS

  CURSOR cli IS
    SELECT a.cod_persona,
           a.nro_cuenta,
           a.fec_valor,
           a.sal_capital,
           a.sal_interes,
           a.mto_capital,
           a.mto_interes,
           a.mto_int_documentado,
           a.mto_int_moratorio,
           a.mto_int_mor_interes,
           a.mto_int_mor_adelantado,
           a.mto_int_punitorio,
           a.mto_cargo,
           a.mto_impuesto,
           a.cod_moneda,
           a.dia_atraso,
           a.usu_insercion,
           a.fec_insercion,
           a.usu_modificacion,
           a.fec_modificacion,
           a.nro_cuo_desde,
           a.nro_cuo_hasta,
           a.mto_pagado,
           a.nro_cta_renovada,
           a.mto_iva_devuelto,
           a.nro_sol_renovada
      FROM it.pr_cobros_rrr@uenodesg a, pr_cta_prestamos p
     WHERE a.nro_cuenta = p.nro_cuenta
       and not exists (select 1
              from mi_pr_cobros_rrr c
             where c.cod_persona = a.cod_persona
               and c.nro_cuenta = a.nro_cuenta
               and c.fec_valor = a.fec_valor);

  v_error    VARCHAR2(500);
  v_err      VARCHAR2(500);
  v_ermsj    VARCHAR2(2000);
  v_fecha    DATE := SYSDATE;
  v_cod_mod  NUMBER;
  v_cantidad number := 0;
  v_fec      date := pag_cal.fu_obt_fec_actual(1);
  -- variables asociación
  v_cod_ente  number := 4000;
  v_existe    varchar2(1);
  v_exi_linea varchar2(1);
  v_nro_linea number;
  v_desc_ente varchar2(1000);
BEGIN

  BEGIN
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := '1';
  END;

  --Desabilitar los triggers
  sql_util.ejecute_dml('alter table pr_cobros_rrr disable all triggers',
                       v_err);

  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  END IF;

  delete mi_logs where proceso = 'PR_COBROS_RRR';
  --delete pr_cobros_rrr;

  FOR a IN cli LOOP
    v_cod_mod  := null;
    v_cantidad := v_cantidad + 1;
  
    BEGIN
      INSERT INTO pr_cobros_rrr
        (cod_persona,
         nro_cuenta,
         fec_valor,
         sal_capital,
         sal_interes,
         mto_capital,
         mto_interes,
         mto_int_documentado,
         mto_int_moratorio,
         mto_int_mor_interes,
         mto_int_mor_adelantado,
         mto_int_punitorio,
         mto_cargo,
         mto_impuesto,
         cod_moneda,
         dia_atraso,
         nro_cuo_desde,
         nro_cuo_hasta,
         mto_pagado,
         nro_cta_renovada,
         usu_insercion,
         fec_insercion,
         usu_modificacion,
         fec_modificacion)
      VALUES
        (a.cod_persona,
         a.nro_cuenta,
         a.fec_valor,
         a.sal_capital,
         a.sal_interes,
         a.mto_capital,
         a.mto_interes,
         a.mto_int_documentado,
         a.mto_int_moratorio,
         a.mto_int_mor_interes,
         a.mto_int_mor_adelantado,
         a.mto_int_punitorio,
         a.mto_cargo,
         a.mto_impuesto,
         a.cod_moneda,
         a.dia_atraso,
         a.nro_cuo_desde,
         a.nro_cuo_hasta,
         a.mto_pagado,
         a.nro_cta_renovada,
         a.usu_insercion,
         a.fec_insercion,
         a.usu_modificacion,
         a.fec_modificacion);
    
    EXCEPTION
      WHEN OTHERS THEN
        v_error := SQLCODE;
        v_ermsj := SQLERRM;
        INSERT INTO mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        VALUES
          (1, v_error, v_ermsj, a.nro_cuenta, 'PR_COBROS_RRR', v_fecha);
    END;
  END LOOP;
  -- actualizo los préstamos de asociaciones, se le asigna nro de linea.
  --Habilitar los triggers
  sql_util.ejecute_dml('alter table pr_cobros_rrr enable all triggers',
                       v_err);
  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al habilitar triggers ' || v_err);
  END IF;
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
       'verif_job_pr_cobros_rrr',
       'PR_COBROS_RRR',
       v_fecha);
    COMMIT;
END;
/

