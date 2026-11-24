CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_MODAL
 (P_COD_MODULO IN GE_MODALIDADES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE
 )
 RETURN VARCHAR2
 IS
v_descripcion ge_modalidades.descripcion%type;
BEGIN
   select descripcion
   into v_descripcion
   from ge_modalidades
   where cod_modulo = p_cod_modulo
   and cod_modalidad = p_cod_modalidad;
   return v_descripcion;
exception
   when no_data_found then
      raise_application_error(-20000,
      'La modalidad '||to_char(p_cod_modalidad)||' del modulo '||
      to_char(p_cod_modulo)||' no existe.');
END;
/

