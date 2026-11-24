CREATE OR REPLACE PROCEDURE IT.prm_job_pr_cobros IS

  CURSOR cli IS
    SELECT a.nro_cuenta,
           nro_cuota,
           trunc(fecha) fecha,
           hora,
           trunc(a.fec_vencimiento) fec_vencimiento,
           a.estado,
           sal_capital_pre,
           sal_interes_pre,
           sal_capital_cuo,
           sal_interes_cuo,
           sal_int_documentado,
           trunc(fec_ult_pago) fec_ult_pago,
           dia_mora,
           a.mto_capital,
           mto_interes,
           mto_int_documentado,
           mto_int_moratorio,
           mto_int_mor_interes,
           mto_int_mor_adelantado,
           mto_int_punitorio,
           mto_cargo,
           mto_cargo_iva,
           mto_impuesto,
           a.mto_int_descontado,
           a.nro_documento,
           mto_int_mor_cal,
           mto_int_mor_int_cal,
           mto_int_mor_ade_cal,
           mto_int_pun_cal,
           mto_cargo_cal,
           mto_car_iva_cal,
           mto_impuesto_cal,
           trunc(a.fec_ult_devengado) fec_ult_devengado,
           a.mto_int_mor_des,
           a.mto_int_mor_int_des,
           a.mto_int_mor_ade_des,
           a.mto_int_pun_des,
           a.mto_car_des,
           a.dev_no_cobrado,
           a.dev_suspenso,
           a.dev_acumulado,
           trunc(fec_valor) fec_valor,
           mto_ult_devengado,
           a.nro_cta_renovada,
           a.usu_insercion,
           a.fec_insercion,
           a.usu_modificacion,
           a.fec_modificacion
      FROM it.pr_cobros@uenodesg a, pr_cta_prestamos p
     WHERE a.nro_cuenta = p.nro_cuenta
       and not exists (select 1
              from pr_cobros c
             where c.nro_cuenta = a.nro_cuenta
               and c.nro_cuota = a.nro_cuota
               and c.fecha = a.fecha
               and c.hora = a.hora);

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
  sql_util.ejecute_dml('alter table pr_cobros disable all triggers', v_err);

  IF v_err IS NOT NULL THEN
    raise_application_error(-20000, 'Al desabilitar triggers ' || v_err);
  END IF;

  delete mi_logs where proceso = 'PR_COBROS';
  /*
  sql_util.ejecute_dml('truncate table PR_COBROS', v_err);
  if v_err is not null then
    raise_application_error(-20000,'Al truncar PR_COBROS '||v_err);
  end if;*/

  FOR a IN cli LOOP
    v_cod_mod  := null;
    v_cantidad := v_cantidad + 1;
  
    BEGIN
      INSERT INTO pr_cobros
        (nro_cuenta,
         nro_cuota,
         fecha,
         hora,
         fec_vencimiento,
         estado,
         sal_capital_pre,
         sal_interes_pre,
         sal_capital_cuo,
         sal_interes_cuo,
         sal_int_documentado,
         fec_ult_pago,
         dia_mora,
         mto_capital,
         mto_interes,
         mto_int_documentado,
         mto_int_moratorio,
         mto_int_mor_interes,
         mto_int_mor_adelantado,
         mto_int_punitorio,
         mto_cargo,
         mto_cargo_iva,
         mto_impuesto,
         mto_int_descontado,
         nro_documento,
         mto_int_mor_cal,
         mto_int_mor_int_cal,
         mto_int_mor_ade_cal,
         mto_int_pun_cal,
         mto_cargo_cal,
         mto_car_iva_cal,
         mto_impuesto_cal,
         usu_insercion,
         fec_insercion,
         usu_modificacion,
         fec_modificacion,
         fec_ult_devengado,
         mto_int_mor_des,
         mto_int_mor_int_des,
         mto_int_mor_ade_des,
         mto_int_pun_des,
         mto_car_des,
         dev_no_cobrado,
         dev_suspenso,
         dev_acumulado,
         fec_valor,
         mto_ult_devengado,
         nro_cta_renovada)
      VALUES
        (a.nro_cuenta,
         a.nro_cuota,
         a.fecha,
         a.hora,
         a.fec_vencimiento,
         a.estado,
         a.sal_capital_pre,
         a.sal_interes_pre,
         a.sal_capital_cuo,
         a.sal_interes_cuo,
         a.sal_int_documentado,
         a.fec_ult_pago,
         a.dia_mora,
         a.mto_capital,
         a.mto_interes,
         a.mto_int_documentado,
         a.mto_int_moratorio,
         a.mto_int_mor_interes,
         a.mto_int_mor_adelantado,
         a.mto_int_punitorio,
         a.mto_cargo,
         a.mto_cargo_iva,
         a.mto_impuesto,
         a.mto_int_descontado,
         a.nro_documento,
         a.mto_int_mor_cal,
         a.mto_int_mor_int_cal,
         a.mto_int_mor_ade_cal,
         a.mto_int_pun_cal,
         a.mto_cargo_cal,
         a.mto_car_iva_cal,
         a.mto_impuesto_cal,
         a.usu_insercion,
         a.fec_insercion,
         a.usu_modificacion,
         a.fec_modificacion,
         a.fec_ult_devengado,
         a.mto_int_mor_des,
         a.mto_int_mor_int_des,
         a.mto_int_mor_ade_des,
         a.mto_int_pun_des,
         a.mto_car_des,
         a.dev_no_cobrado,
         a.dev_suspenso,
         a.dev_acumulado,
         a.fec_valor,
         a.mto_ult_devengado,
         a.nro_cta_renovada);
    
    EXCEPTION
      WHEN OTHERS THEN
        v_error := SQLCODE;
        v_ermsj := SQLERRM;
        INSERT INTO mi_logs
          (nro_reg, nro_error, men_error, comentario, proceso, fec_proceso)
        VALUES
          (1, v_error, v_ermsj, a.nro_cuenta, 'PR_COBROS', v_fecha);
    END;
  END LOOP;
  -- actualizo los préstamos de asociaciones, se le asigna nro de linea.
  --Habilitar los triggers
  sql_util.ejecute_dml('alter table pr_cobros enable all triggers', v_err);
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
      (1, v_error, v_ermsj, 'verif_job_pr_cobros', 'PR_COBROS', v_fecha);
    COMMIT;
END;
/

