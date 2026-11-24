CREATE OR REPLACE FUNCTION IT.FUE_OBT_DES_MONEDA
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 )
 RETURN VARCHAR2
 IS

V_DESCRIPCION BA_MONEDAS.DESCRIPCION%TYPE;
Begin
    --Obtiene el Nombre de la moneda
    select descripcion
    into v_descripcion
    from ba_monedas
    where cod_moneda = p_cod_moneda;

    return v_descripcion;

    exception
       when no_data_found then
           return('Moneda no registrada en el Sistema');
End;
/

