CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_TRANSACCION
 (P_COD_MODULO IN  GE_TRANSACCIONES.COD_MODULO%TYPE,
  P_COD_MODALIDAD IN  GE_TRANSACCIONES.COD_MODALIDAD%TYPE,
  P_COD_TRANSACCION IN  GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 )
 RETURN STRING
 IS
 /* Funcion que retorna la descripcion de la Transaccion */
V_DESCRIPCION  GE_TRANSACCIONES.DESCRIPCION%TYPE;
Begin
    --Obtiene el Nombre de la Transaccion
    select descripcion
    into v_descripcion
    from  ge_transacciones
    where cod_transaccion = p_cod_transaccion
      and cod_modulo = p_cod_modulo
      and cod_modalidad = p_cod_modalidad;
    return v_descripcion;

exception
    when no_data_found then
           return('Transaccion inexistente en el Sistema');
    when others then
           return('ERROR: en fue_obt_des_transaccion '||sqlerrm);    
End;
/

