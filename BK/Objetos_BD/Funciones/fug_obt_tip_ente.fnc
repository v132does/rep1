CREATE OR REPLACE FUNCTION IT.FUG_OBT_TIP_ENTE
 (P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE
 )
 RETURN VARCHAR2
 IS
v_tipo ge_entes.tipo%type;
BEGIN
   select tipo
   into v_tipo
   from ge_entes
   where cod_ente = p_cod_ente;
   return v_tipo;
exception
   when no_data_found then
      raise_application_error(-20000,
      'El ente '||p_cod_ente||' no registrado');
END;
/

