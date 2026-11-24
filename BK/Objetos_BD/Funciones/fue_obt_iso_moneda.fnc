CREATE OR REPLACE FUNCTION IT.FUE_OBT_ISO_MONEDA
 (P_MONEDA_ISO IN BA_MONEDAS.COD_MON_ISO%type
 )
 RETURN VARCHAR2
 IS

V_MONEDA_ITGF BA_MONEDAS.COD_MONEDA%TYPE;
Begin
    --Obtiene la moneda
    select b.cod_moneda
    into v_moneda_itgf
    from ba_monedas b
    where b.cod_mon_iso = P_MONEDA_ISO;

    return v_moneda_itgf;

    exception
       when no_data_found then
           return('Moneda no registrada en el Sistema');
End;
/

