CREATE OR REPLACE FUNCTION IT.FUG_OBT_PER_ENTE
 (P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE
 )
 RETURN VARCHAR2
 IS
v_cod_persona ge_entes.cod_persona%type;
BEGIN
   select cod_persona
   into v_cod_persona
   from ge_entes
   where cod_ente = p_cod_ente;
   return v_cod_persona;
exception
   when no_data_found then
      raise_application_error(-20000,
      'Ente '||p_cod_ente||' no registrado');
END;
/

