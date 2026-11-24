CREATE OR REPLACE FUNCTION IT.FUG_OBT_UBI_EJECUTABLE
 (p_cod_programa ba_programas.cod_programa%TYPE
 )
 RETURN varchar2
 IS
v_ubicacion ba_programas.ubi_ejecutable%TYPE;
Begin
                    
    select ubi_ejecutable
      into v_ubicacion
      from ba_programas
     where cod_programa = p_cod_programa;
    return v_ubicacion;
    exception
       when no_data_found then
           return('');
End;
/

