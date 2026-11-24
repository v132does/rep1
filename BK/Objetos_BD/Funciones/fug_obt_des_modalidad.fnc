CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_MODALIDAD
 (P_COD_MODALIDAD IN GE_MODALIDADES.COD_MODALIDAD%TYPE)
 RETURN VARCHAR2
 IS
v_descripcion ge_modalidades.descripcion%type;
BEGIN
--Obtiene la descripción de la modalidad
   select descripcion
   into v_descripcion
   from ge_modalidades
   where cod_modalidad = p_cod_modalidad;
   return v_descripcion;
exception
   when no_data_found then
           return('Cod_Modalidad no corresponde');
END;
/

