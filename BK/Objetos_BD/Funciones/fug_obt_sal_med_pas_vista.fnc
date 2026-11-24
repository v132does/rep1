CREATE OR REPLACE FUNCTION IT.fug_obt_sal_med_pas_vista(p_cod_persona ba_personas.cod_persona%TYPE)
   RETURN NUMBER IS
   v_fecha       varchar2(6);
   v_sal_ah_ctas ah_sal_mensuales.sal_acu_diario%TYPE := 0;
   v_sal_cc_ctas cc_sal_mensuales.sal_acu_diario%TYPE := 0;
   v_mes         number;
   v_anho        number;
BEGIN

   --Obtener la fecha en formato MMYYYY de 6 meses atrás
   ---CROSCOFI-1 ---Ajustes al Scoring de Personas Físicas - LCabrera -05/2015(se cambia a 1 mes atras)
   v_fecha := to_char(add_months(trunc(pag_cal.fu_obt_fec_actual(1)), -1), 'MMYYYY');
   v_mes   := to_number(to_char(to_date(v_fecha,'MMYYYY'),'MM'));
   v_anho  := to_number(to_char(to_date(v_fecha,'MMYYYY'),'YYYY'));

/*   SELECT to_number(to_char(v_fecha,'MM')), to_number(to_char(v_fecha,'YYYY'))
     INTO v_mes, v_anho
     FROM dual;*/

  ---CROSCOFI-1 ---Ajustes al Scoring de Personas Físicas - LCabrera -05/2015 - Solo debe considerarse Ctas. Ctes.-
 /*  --Ctas de Ahorro
   SELECT nvl(round(SUM(CASE
                           WHEN c.cod_moneda != pag_gen.fu_obt_mon_local THEN
                            a.sal_acu_diario * fug_obt_cotizacion(c.cod_moneda, trunc(a.fec_insercion))
                           ELSE
                            a.sal_acu_diario
                        END) / nvl(MAX(a.can_dia_acumulado), 1)), 0)
     INTO v_sal_ah_ctas
     FROM ah_sal_mensuales a, ge_cta_clientes b, ah_cta_vistas c, ge_est_cuentas d
    WHERE a.nro_cuenta = b.nro_cuenta
      AND b.nro_cuenta = c.nro_cuenta
      AND b.relacion = 'P'
      AND c.cod_modulo = d.cod_modulo
      AND c.cod_modalidad = d.cod_modalidad
      AND c.estado = d.estado
      AND d.activo = 'S'
      AND a.mes || a.ano >= v_fecha
      AND b.cod_persona = p_cod_persona;*/

   --Ctas Corrientes
   SELECT nvl(round(SUM(CASE
                           WHEN c.cod_moneda != pag_gen.fu_obt_mon_local THEN
                            a.sal_acu_diario * fug_obt_cotizacion(c.cod_moneda, trunc(a.fec_insercion))
                           ELSE
                            a.sal_acu_diario
                        END) / nvl(MAX(a.can_dia_acumulado), 1)), 0)
     INTO v_sal_cc_ctas
     FROM cc_sal_mensuales a, ge_cta_clientes b, cc_cta_corrientes c, ge_est_cuentas d
    WHERE a.nro_cuenta = b.nro_cuenta
      AND b.nro_cuenta = c.nro_cuenta
      AND b.relacion = 'P'
      AND c.cod_modulo = d.cod_modulo
      AND c.cod_modalidad = d.cod_modalidad
      AND c.estado = d.estado
      AND d.activo = 'S'
      AND a.mes = v_mes
      AND a.ano = v_anho
      AND b.cod_persona = p_cod_persona;

    ---CROSCOFI-1 ---Ajustes al Scoring de Personas Físicas - LCabrera -05/2015 - Solo considerar Ctas. Ctes.
   ----RETURN v_sal_ah_ctas + v_sal_cc_ctas;
   RETURN v_sal_cc_ctas;

EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,'Obtener Saldo Medio Pasivo Vista del Cliente. ' || SQLERRM);
END;
/

