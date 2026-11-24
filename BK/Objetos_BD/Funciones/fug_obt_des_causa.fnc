CREATE OR REPLACE FUNCTION IT.FUG_OBT_DES_CAUSA
 (p_cod_causa ge_causales.cod_causa%TYPE
 )
 RETURN varchar2
 IS
V_DESCRIPCION ge_causales.descripcion%TYPE;
Begin
    --Obtiene la descripción de la Causa
    select descripcion
      into v_descripcion
      from ge_causales
     where cod_causa = p_cod_causa;
    return v_descripcion;
    exception
       when no_data_found then
           return('Causa no registrada en el Sistema');
End;
/

