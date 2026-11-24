CREATE OR REPLACE FUNCTION IT.FUY_OBT_COT_MONEDA
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE
 )
 RETURN NUMBER
 IS

V_MTO_COTIZACION GE_COTIZACIONES.VAL_CONVERSION%TYPE;
Begin

    -- Obtiene la ultima cotizacion de una moneda

    v_mto_cotizacion := 1;

    select nvl(val_conversion,0)
    into v_mto_cotizacion
    from ge_cotizaciones
    where cod_moneda = p_cod_moneda
    and fecha = (select max(fecha)
                          from ge_cotizaciones
                          where cod_moneda = p_cod_moneda);


    return v_mto_cotizacion;

    exception
    when no_data_found then

       raise_application_error(-20000,
       'No existe cotización para la moneda: '||p_cod_moneda);


End;
/

