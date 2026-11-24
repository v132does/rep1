CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_CANAL
 (p_cod_canal ge_canales.cod_canal%TYPE)
 RETURN varchar2
 IS
V_DESCRIPCION ge_canales.descripcion%TYPE;
Begin
    --Obtiene la descripción del canal
    select descripcion
      into v_descripcion
      from ge_canales
     where cod_canal = p_cod_canal;
    return v_descripcion;
    exception
       when no_data_found then
           return('No posee Canales');
End;
/

