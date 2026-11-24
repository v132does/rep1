CREATE OR REPLACE FUNCTION IT.FUE_OBT_DES_OPERACION(P_COD_OPERACION IN BW_TIP_MENSAJES.COD_TIP_MENSAJE%TYPE)
  RETURN VARCHAR2 IS
  V_DESCRIPCION BW_TIP_MENSAJES.DESCRIPCION%TYPE;
Begin
  --Obtiene la descripción de la operación.
  if p_cod_operacion is not null then
    select descripcion
      into v_descripcion
      from bw_tip_mensajes
     where cod_tip_mensaje = p_cod_operacion;
  end if;
  return v_descripcion;
exception
  when no_data_found then
    return('Operación no registrada en el Sistema');
End;
/

