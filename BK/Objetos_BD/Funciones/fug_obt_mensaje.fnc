CREATE OR REPLACE FUNCTION IT.FUG_OBT_MENSAJE
 (P_COD_MENSAJE IN GE_MENSAJES.COD_MENSAJE%TYPE
 )
 RETURN VARCHAR2
 IS

V_MENSAJE GE_MENSAJES.MENSAJE%TYPE;
begin
  select MENSAJE
    into v_mensaje
    from ge_mensajes
   where cod_mensaje = p_cod_mensaje;
  return v_mensaje;
exception
   when no_data_found then
        return (NULL);
end;
/

