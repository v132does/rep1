CREATE OR REPLACE FUNCTION IT.FUY_OBT_VAL_NUM
 (P_COD_PARAMETRO IN AP_PARAMETROS.COD_PARAMETRO%TYPE
 )
 RETURN NUMBER
 IS

V_VAL_NUMERICO NUMBER(18, 2) := 0;
BEGIN
--Obtiene el valor numerico dado un parámetro
   select nvl(val_numerico,0)
   into v_val_numerico
   from ap_parametros
   where cod_parametro = p_cod_parametro;

   return v_val_numerico;
exception
    when no_data_found then
          raise_application_error(-2000,
          'El valor '|| p_cod_parametro || ' no existe en Parametros');

END;
/

