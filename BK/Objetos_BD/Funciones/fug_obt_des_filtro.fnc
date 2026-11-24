CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_FILTRO
 (P_COD_CAMPO IN GE_FILTROS.COD_CAMPO%TYPE
 )
 RETURN VARCHAR2
 IS
v_descripcion GE_FILTROS.DESCRIPCION%TYPE;

BEGIN
   select descripcion
   into v_descripcion
   from ge_filtros
   where cod_campo = P_COD_CAMPO
   ;
   return v_descripcion;
exception
   when no_data_found then
      raise_application_error(-20000,
      'El campo '||to_char(p_cod_campo)||' no existe.');
END;
/

