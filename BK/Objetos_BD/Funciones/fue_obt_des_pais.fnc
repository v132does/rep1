CREATE OR REPLACE FUNCTION IT.FUE_OBT_DES_PAIS
 (P_COD_PAIS IN BA_PAISES.COD_PAIS%TYPE
 )
 RETURN STRING
 IS

V_DESCRIPCION BA_PAISES.DESCRIPCION%TYPE;
Begin
    --Obtiene el Nombre del País
    select descripcion
    into v_descripcion
    from ba_paises
    where cod_pais = p_cod_pais;

    return v_descripcion;

    exception
       when no_data_found then
           return('País no registrado en el Sistema');
End;
/

