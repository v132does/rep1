CREATE OR REPLACE FUNCTION IT.FUE_OBT_CIU_COD_POSTAL
 (P_COD_PAIS IN BA_CIUDADES.COD_PAIS%TYPE
 ,P_COD_CIUDAD IN BA_CIUDADES.COD_CIUDAD%TYPE
 )
 RETURN varchar2
 IS

v_cod_postal BA_CIUDADES.COD_POSTAL%TYPE;
Begin
    --Obtiene el código postal de la Ciudad
    select cod_postal
    into v_cod_postal
    from ba_ciudades
    where cod_pais = p_cod_pais
    and cod_ciudad = p_cod_ciudad;

    return v_cod_postal;

    exception
       when no_data_found then
           return('Ciudad no registrada en el Sistema');
End;
/

