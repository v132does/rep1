create or replace procedure it.prg_obt_dat_cargos(P_COD_OFI_ORIGEN   IN GE_CUENTAS.COD_OFICINA%TYPE,
                                               P_NRO_CUENTA       IN GE_CUENTAS.NRO_CUENTA%TYPE,
                                               P_COD_MONEDA       IN GE_CUENTAS.COD_MONEDA%TYPE,
                                               P_COD_MODULO       IN GE_CUENTAS.COD_MODULO%TYPE,
                                               P_COD_MODALIDAD    IN GE_CUENTAS.COD_MODALIDAD%TYPE,
                                               P_COD_TRA_CARGO    IN GE_MOVIMIENTOS.COD_TRANSACCION%TYPE,
                                               P_COD_TAS_CARGO    OUT GE_MOVIMIENTOS.COD_TASA%TYPE,
                                               P_VAL_TAS_CARGO    OUT GE_MOVIMIENTOS.VAL_TASA%TYPE,
                                               P_VAL_CARGO        OUT GE_MOVIMIENTOS.VAL_TASA%TYPE,
                                               P_COD_TRA_IMPUESTO OUT GE_MOVIMIENTOS.COD_TRANSACCION%TYPE,
                                               P_COD_TAS_IMPUESTO OUT GE_MOVIMIENTOS.COD_TASA%TYPE,
                                               P_VAL_TAS_IMPUESTO OUT GE_MOVIMIENTOS.VAL_TASA%TYPE,
                                               P_VAL_IMPUESTO     OUT GE_MOVIMIENTOS.VAL_TASA%TYPE,
                                               P_FEC_ACTUAL       IN GE_CALENDARIOS.FEC_ACTUAL%TYPE default NULL) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  -- CROMEEXO-1 Proceso de obtencion de datos de cargos y cache en tabla temporal - 02/2019 NAF
  -- El procedimiento busca el cargo en la tabla temporal GE_VAL_CARGOS_TMP.
  -- En caso de no existir, obtiene el cargo utilizando prg_obt_cargos, y lo almacena en la tabla temporal.
  -- En caso de si existir, recupera el dato desde la tabla, disminuyendo así el uso del procedimiento prg_obt_cargos.
  V_FEC_ACTUAL GE_CALENDARIOS.FEC_ACTUAL%TYPE;
BEGIN
  IF P_FEC_ACTUAL is null then
    V_FEC_ACTUAL := pag_cal.fu_obt_fec_actual(3);
  ELSE
    V_FEC_ACTUAL := P_FEC_ACTUAL;
  END IF;

  SELECT COD_TAS_CARGO,
         VAL_TAS_CARGO,
         VAL_CARGO,
         COD_TRA_IMPUESTO,
         VAL_TAS_IMPUESTO,
         VAL_IMPUESTO
    Into P_COD_TAS_CARGO,
         p_val_tas_cargo,
         p_val_cargo,
         p_cod_tra_impuesto,
         p_val_tas_impuesto,
         p_val_impuesto
    from GE_VAL_CARGOS_TMP
   where FECHA = V_FEC_ACTUAL
     and COD_MONEDA = P_COD_MONEDA
     and COD_MODULO = P_COD_MODULO
     and COD_MODALIDAD = P_COD_MODALIDAD
     and COD_TRANSACCION = P_COD_TRA_CARGO
     and COD_OFICINA = P_COD_OFI_ORIGEN
     and rownum = 1;
EXCEPTION
  when others then
    -- obtiene el cargo
    prg_obt_cargos(P_COD_OFI_ORIGEN,
                   NULL,
                   P_COD_MONEDA,
                   NULL,
                   P_COD_MODULO,
                   P_COD_MODALIDAD,
                   P_COD_TRA_CARGO,
                   P_COD_TAS_CARGO,
                   P_VAL_TAS_CARGO,
                   P_VAL_CARGO,
                   P_COD_TRA_IMPUESTO,
                   P_COD_TAS_IMPUESTO,
                   P_VAL_TAS_IMPUESTO,
                   P_VAL_IMPUESTO);
    -- registra en cache
    insert into GE_VAL_CARGOS_TMP
    values
      (V_FEC_ACTUAL,
       P_COD_OFI_ORIGEN,
       P_COD_MONEDA,
       P_COD_MODULO,
       P_COD_MODALIDAD,
       P_COD_TRA_CARGO,
       P_COD_TAS_CARGO,
       P_VAL_TAS_CARGO,
       P_VAL_CARGO,
       P_COD_TRA_IMPUESTO,
       P_COD_TAS_IMPUESTO,
       P_VAL_TAS_IMPUESTO,
       P_VAL_IMPUESTO);
    commit;
END;
/

