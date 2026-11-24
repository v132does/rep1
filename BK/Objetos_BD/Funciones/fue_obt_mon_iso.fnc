CREATE OR REPLACE FUNCTION IT.FUE_OBT_MON_ISO
 (P_COD_MONEDA IN BA_MONEDAS.COD_MONEDA%TYPE,
  P_DESCRIPCION IN BA_MONEDAS.DESCRIPCION%TYPE
 )
 RETURN VARCHAR2
 IS

V_MON_ISO BA_MONEDAS.COD_MON_ISO%TYPE;
Begin
    --Obtiene el Nombre de la moneda
    select m.cod_mon_iso
    into v_mon_iso
    from ba_monedas m
    where (cod_moneda = replace(replace(replace(UPPER(p_cod_moneda),'.',''),')',''),'(','')
      or descripcion = p_descripcion);

    return v_mon_iso;

    exception
       when no_data_found then
           return('Moneda no registrada en el Sistema');
End;
/

