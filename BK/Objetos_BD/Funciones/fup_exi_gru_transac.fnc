CREATE OR REPLACE FUNCTION IT.FUP_EXI_GRU_TRANSAC
 (P_COD_GRU_TRANSACCION IN GE_GRU_TRANSACCIONES.COD_GRU_TRANSACCION%TYPE
 ,P_COD_TRANSACCION IN GE_GRU_TRANSACCIONES_DET.COD_TRANSACCION%TYPE
 ,P_COD_MODULO IN GE_GRU_TRANSACCIONES_DET.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_GRU_TRANSACCIONES_DET.COD_MODALIDAD%TYPE
 )
 RETURN VARCHAR2
 IS
v_existe varchar2(01);
BEGIN
   select 'S' into v_existe
     from ge_gru_transacciones_det
    where cod_gru_transaccion = p_cod_gru_transaccion
      and cod_transaccion = p_cod_transaccion
      and cod_modulo = p_cod_modulo
      and cod_modalidad = p_cod_modalidad;
   return 'S';
exception
   when no_data_found then
      return 'N';
   when too_many_rows then
      return 'S';
END;
/

