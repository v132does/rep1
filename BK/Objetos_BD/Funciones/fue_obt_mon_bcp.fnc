CREATE OR REPLACE FUNCTION IT.FUE_OBT_MON_BCP
 (P_MONEDA_BCP IN BA_MONEDAS.COD_MON_BCO_CENTRAL%TYPE
 )
 RETURN VARCHAR2
 IS

V_MONEDA_BCP BA_MONEDAS.COD_MONEDA%TYPE;
Begin
    --Obtiene la moneda BCP
    select cod_moneda
    into v_moneda_bcp
    from ba_monedas b
    where b.cod_mon_bco_central = p_moneda_bcp;

    return v_moneda_bcp;

    exception
       when no_data_found then
           return('Moneda no registrada en el Sistema');
End;
/

