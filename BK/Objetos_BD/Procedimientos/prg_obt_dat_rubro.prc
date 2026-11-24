create or replace procedure it.prg_obt_dat_rubro(p_cod_modulo       IN NUMBER,
                                              p_cod_modalidad    IN NUMBER,
                                              p_cod_transaccion  IN NUMBER,
                                              p_cod_moneda       IN VARCHAR2,
                                              p_cod_sec_contable IN VARCHAR2,
                                              p_cod_tip_deudor   IN NUMBER,
                                              p_residente        IN VARCHAR2,
                                              p_cod_plazo        IN VARCHAR2,
                                              p_tip_movimiento   IN VARCHAR2,
                                              p_cod_rubro        IN OUT VARCHAR2,
                                              p_est_cuenta       IN VARCHAR2,
                                              p_tip_renovacion   IN VARCHAR2,
                                              p_cat_automatica   IN NUMBER,
                                              p_tip_interes      IN VARCHAR2,
                                              p_tip_cuenta       IN VARCHAR2,
                                              p_cod_sec_credito  IN NUMBER,
                                              p_des_rubro        OUT VARCHAR2,
                                              p_fec_actual       DATE default null) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  -- CROMEEXO-1 Proceso de obtencion de datos de rubros y cache en tabla temporal - 02/2019 NAF
  -- El procedimiento busca el rubro en la tabla temporal GE_VAL_RUBROS_TMP.
  -- En caso de no existir, obtiene el rubro utilizando pab_inv.fu_obt_cod_rubro, y lo almacena en la tabla temporal.
  -- En caso de si existir, recupera el dato desde la tabla, disminuyendo así el uso del procedimiento pab_inv.fu_obt_cod_rubro.
  V_FEC_ACTUAL GE_CALENDARIOS.FEC_ACTUAL%TYPE;
BEGIN
  IF P_FEC_ACTUAL is null then
    V_FEC_ACTUAL := pag_cal.fu_obt_fec_actual(3);
  ELSE
    V_FEC_ACTUAL := P_FEC_ACTUAL;
  END IF;

  SELECT t.cod_rubro, t.des_rubro
    Into p_cod_rubro, p_des_rubro
    from GE_VAL_RUBROS_TMP t
   where FECHA = V_FEC_ACTUAL
     and t.cod_modulo = p_cod_modulo
     and t.cod_modalidad = p_cod_modalidad
     and t.cod_transaccion = p_cod_transaccion
     and t.cod_moneda = p_cod_moneda
     and t.cod_sec_contable = p_cod_sec_contable
     and t.cod_tideudor = p_cod_tip_deudor
     and t.residente = p_residente
     and t.cod_plazo = p_cod_plazo
     and t.timovimiento = p_tip_movimiento
     and t.est_cuenta = p_est_cuenta
     and t.tirenovacion = p_tip_renovacion
     and t.cat_automatica = nvl(p_cat_automatica, cat_automatica)
     and t.tiinteres = nvl(p_tip_interes, tiinteres)
     and t.ticuenta = nvl(p_tip_cuenta, ticuenta)
     and decode(nvl(p_cod_sec_credito, -1), -1, -1, t.cod_sec_credito) =
         decode(nvl(p_cod_sec_credito, -1), -1, -1, p_cod_sec_credito)
     and rownum = 1;
EXCEPTION
  when others then
    -- obtiene datos del rubro
    pab_inv.fu_obt_cod_rubro(p_cod_modulo,
                             p_cod_modalidad,
                             p_cod_transaccion,
                             p_cod_moneda,
                             p_cod_sec_contable,
                             p_cod_tip_deudor,
                             p_residente,
                             p_cod_plazo,
                             p_tip_movimiento,
                             p_cod_rubro,
                             p_est_cuenta,
                             p_tip_renovacion,
                             p_cat_automatica,
                             p_tip_interes,
                             p_tip_cuenta,
                             p_cod_sec_credito);
    /*
    || Descripción Rubro del Balance.
    || Se obtiene de CB_RUBROS.DESCRIPCION, a partir del COD_RUBRO.
    */
    IF p_cod_rubro IS NOT NULL THEN
      BEGIN
        p_des_rubro := fub_obt_des_cta_contable(p_cod_rubro);
      EXCEPTION
        WHEN no_data_found THEN
          p_des_rubro := NULL;
        WHEN OTHERS THEN
          raise_application_error('-20000',
                                  'Al Obt.Descripcion del Rubro: ' ||
                                  SQLERRM);
      END;
    END IF;
    -- registra en cache
    insert into GE_VAL_RUBROS_TMP
    values
      (v_fec_actual,
       p_cod_modulo,
       p_cod_modalidad,
       p_cod_transaccion,
       p_cod_moneda,
       p_cod_sec_contable,
       p_cod_tip_deudor,
       p_residente,
       p_cod_plazo,
       p_tip_movimiento,
       p_cod_rubro,
       p_est_cuenta,
       p_tip_renovacion,
       p_cat_automatica,
       p_tip_interes,
       p_tip_cuenta,
       p_cod_sec_credito,
       p_des_rubro);
    commit;
END;
/

