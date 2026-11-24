CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_AFINIDAD
 (P_COD_AFINIDAD  IN BA_COD_REFERENCIAS.VAL_MINIMO%TYPE
 )
 RETURN VARCHAR2
 IS
v_descripcion ba_cod_referencias.significado%type;
BEGIN
   select significado
   into v_descripcion
   from ba_cod_referencias
   where dominio = 'AFINIDAD'
   and val_minimo  = p_cod_afinidad;
   return v_descripcion;
exception
   when no_data_found then
      return 'La afinidad '||to_char(p_cod_afinidad)||' no existe' ;
   when others then
      raise_application_error(-20000,
      'Error al obtener afinidad '||to_char(p_cod_afinidad)||' en FUG_OBT_DES_AFINIDAD');
END;
/

