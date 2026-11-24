CREATE OR REPLACE FUNCTION IT.FUB_OBT_SAL_CONTABLE
 (P_COD_RUBRO IN VARCHAR2, P_FECHA IN DATE, P_MONEDA IN VARCHAR2
 )
 RETURN NUMBER
 IS

V_RESULTADO NUMBER:=0;
V_MON_LOC NUMBER:=0;
V_MON_EXT NUMBER:=0;
BEGIN
   Begin
      select
       sum(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0))mon_loc,
       sum(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))mon_ext
       into V_MON_LOC,V_MON_EXT
       from cb_sal_oficinas_dia a
       where a.fecha = P_FECHA
       and a.cod_rubro=P_COD_RUBRO
       group by a.cod_rubro;
  exception
    when no_data_found then
       RETURN(0);
    WHEN OTHERS THEN
       RETURN(0);
    END;

    --verifica si se envia el saldo en monto local o extranjero
    if P_MONEDA = 'GS' then
       V_RESULTADO:=nvl(V_MON_LOC,0);
    else
       V_RESULTADO:=nvl(V_MON_EXT,0);
    end if;

    RETURN(V_RESULTADO);
End;
/

