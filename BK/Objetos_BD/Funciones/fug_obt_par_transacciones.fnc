CREATE OR REPLACE FUNCTION IT.FUG_OBT_PAR_TRANSACCIONES
 (P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE,
  P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE,
  P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE,
  P_PARAMETRO IN GE_PAR_CAUSALES.PARAMETRO%TYPE
 )
 RETURN VARCHAR2
 IS

V_VAL_PARAMETRO GE_PAR_TRANSACCIONES.VAL_PARAMETRO%TYPE;
v_parametro GE_PAR_TRANSACCIONES.parametro%type;
BEGIN
   if p_cod_transaccion is not null and p_cod_modulo is not null and p_cod_modalidad is not null and p_parametro is not null then
      v_parametro :=trim(p_parametro);
      select val_parametro
        into v_val_parametro
        from ge_par_transacciones
       where cod_transaccion = p_cod_transaccion
         and cod_modulo = p_cod_modulo
         and cod_modalidad = p_cod_modalidad
         and parametro = v_parametro;
   end if;
   return v_val_parametro;
   exception
      when no_data_found then  RETURN NULL;
END;
/

