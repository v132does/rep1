CREATE OR REPLACE FUNCTION IT.FUE_OBT_DES_BARRIO
 (P_COD_PAIS IN BA_BARRIOS.COD_PAIS%TYPE
 ,P_COD_CIUDAD IN BA_BARRIOS.COD_CIUDAD%TYPE
 ,P_COD_BARRIO IN BA_BARRIOS.COD_BARRIO%TYPE
 )
 RETURN STRING
 IS

V_DESCRIPCION BA_BARRIOS.DESCRIPCION%TYPE;
Begin
    --Obtiene el Nombre del Barrio
    select descripcion
    into v_descripcion
    from ba_barrios
    where cod_pais = p_cod_pais
    and cod_ciudad = p_cod_ciudad
    and cod_barrio = p_cod_barrio;

    return v_descripcion;

    exception
       when no_data_found then
           return('Barrio no registrado en el Sistema');
End;
/

