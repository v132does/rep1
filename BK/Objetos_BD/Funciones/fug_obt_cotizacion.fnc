create or replace function it.FUG_OBT_COTIZACION
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 ,P_FEC_TRANSACCION IN DATE default pag_cal.FU_OBT_FEC_ACTUAL(1)
 )
 RETURN NUMBER
 IS

V_VAL_CONVERSION GE_COTIZACIONES.VAL_CONVERSION%TYPE;
BEGIN
   SELECT  val_conversion
   INTO  v_val_conversion
   FROM  ge_cotizaciones a
   WHERE  fecha  = (SELECT max(fecha)
                          FROM ge_cotizaciones
                         WHERE cod_moneda = p_cod_moneda
                           AND fecha <= P_FEC_TRANSACCION)
   AND  cod_moneda = p_cod_moneda;
   Return v_val_conversion;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      v_val_conversion := NULL;
      Return v_val_conversion;
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20000,SQLERRM||'ERROR. Al buscar Cotizacion ');
END;
/

