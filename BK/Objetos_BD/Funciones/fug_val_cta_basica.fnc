CREATE OR REPLACE FUNCTION IT.fug_val_cta_basica(p_nro_cuenta      IN ge_movimientos.nro_cuenta%TYPE,
                                              p_cod_tra_padre   IN ge_movimientos.cod_transaccion%TYPE,
                                              p_cod_mod_padre   IN ge_movimientos.cod_modulo%TYPE,
                                              p_cod_mad_padre   IN ge_movimientos.cod_modalidad%TYPE,
                                              p_cod_transaccion IN ge_movimientos.cod_transaccion%TYPE,
                                              p_cod_modulo      IN ge_movimientos.cod_modulo%TYPE,
                                              p_cod_modalidad   IN ge_movimientos.cod_modalidad%TYPE,
                                              p_monto           IN ge_movimientos.monto%TYPE,
                                              p_cod_moneda      IN ge_movimientos.cod_moneda%TYPE)
  RETURN NUMBER IS
  v_exc_transaccion        VARCHAR2(1);
  v_per_cta_basica         VARCHAR2(1);
  v_tipo                   ge_transacciones.tipo%TYPE;
  v_pri_dia_mes            ge_movimientos.fecha%type;
  v_tot_cre_mes            NUMBER;
  v_mto_sal_lim_cta_basica NUMBER;
  v_fecha                  ge_movimientos.fecha%TYPE := pag_cal.fu_obt_fec_actual(9);
BEGIN
  IF nvl(fug_obt_pardinamico('ACT_VAL_CTA_BASICA'), 'N') = 'N' THEN
    --ACTIVA VALIDACIONES DE CUENTA BASICA
    RETURN 0; -- validacion de cta. basica inactiva
  END IF;
  v_per_cta_basica := fua_es_cta_basica(p_nro_cuenta);
  IF v_per_cta_basica = 'N' THEN
    RETURN 0;
  END IF;

  BEGIN
    select 'S'
      into v_exc_transaccion
      from ge_gru_transacciones_det t
     where cod_gru_transaccion = 91
       and cod_modulo = p_cod_mod_padre
       and cod_modalidad = p_cod_mad_padre
       and cod_transaccion = p_cod_tra_padre;
  EXCEPTION
    WHEN OTHERS THEN
      v_exc_transaccion := 'N';
  END;

  IF nvl(v_exc_transaccion, 'N') = 'N' THEN
    BEGIN
      select 'S'
        into v_exc_transaccion
        from ge_gru_transacciones_det t
       where cod_gru_transaccion = 91
         and cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad
         and cod_transaccion = p_cod_transaccion;
    EXCEPTION
      WHEN OTHERS THEN
        v_exc_transaccion := 'N';
    END;
  END IF;
  IF nvl(v_exc_transaccion, 'N') = 'N' THEN
    --Verificar si es un credito--         
    BEGIN
      select b.tipo
        into v_tipo
        from ge_transacciones b
       where b.cod_modulo = p_cod_modulo
         and b.cod_modalidad = p_cod_modalidad
         and b.cod_transaccion = p_cod_transaccion;
    EXCEPTION
      WHEN OTHERS THEN
        v_tipo := 'X';
    END;
    --Buscar el saldo de la cuenta--
    IF nvl(v_tipo, 'X') = 'C' THEN
      BEGIN
        v_pri_dia_mes := (trunc(pag_cal.FU_OBT_FEC_HABIL(v_fecha, 1, 1), 'mm'));
        select sum(monto)
          into v_tot_cre_mes
          from ge_mov_cre_cta_bas
         where fecha between v_pri_dia_mes and v_fecha
           and nro_cuenta = p_nro_cuenta;
      EXCEPTION
        WHEN OTHERS THEN
          v_tot_cre_mes := 0;
      END;
      --Buscar el limite de la cuenta basica--
      v_mto_sal_lim_cta_basica := NVL(fug_obt_pardinamico('MTO_MAX_AHO_CTA_BASICA',
                                                          NULL,
                                                          NULL,
                                                          p_cod_moneda),
                                      0);
      IF (nvl(v_tot_cre_mes, 0) + nvl(p_monto, 0)) >
         nvl(v_mto_sal_lim_cta_basica, 0) THEN
        RETURN - 1;
      END IF;
    END IF;
  END IF;
  RETURN 0;
end fug_val_cta_basica;
/

