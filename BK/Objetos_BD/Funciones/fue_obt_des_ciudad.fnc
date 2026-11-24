CREATE OR REPLACE FUNCTION IT.FUE_OBT_DES_CIUDAD
 (P_COD_PAIS IN BA_CIUDADES.COD_PAIS%TYPE
 ,P_COD_CIUDAD IN BA_CIUDADES.COD_CIUDAD%TYPE
 )
 RETURN STRING
 IS

V_DESCRIPCION BA_CIUDADES.DESCRIPCION%TYPE;
Begin
    --Obtiene el Nombre de la Ciudad
    select descripcion
    into v_descripcion
    from ba_ciudades
    where cod_pais = p_cod_pais
    and cod_ciudad = p_cod_ciudad;

    return v_descripcion;

    exception
       when no_data_found then
           return('Ciudad no registrada en el Sistema');
End;
/

