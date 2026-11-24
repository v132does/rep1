CREATE OR REPLACE FUNCTION IT.FUB_OBT_SAL_CONSOLIDADO
 (P_RUBRO IN VARCHAR2, P_FECHA IN DATE
 )
 RETURN NUMBER
 IS
V_RESULTADO NUMBER:=0;
BEGIN
   Begin
      select nvl((nvl(d.sal_mon_rub_ant, 0) + (nvl(d.deb_mon_rubro, 0) - nvl(d.cre_mon_rubro, 0))),0)
      into v_RESULTADO
      from cb_sal_consolidados_dia d
      where d.cod_rubro = P_RUBRO
      and   d.fecha = P_FECHA;
  exception
    when no_data_found then
       RETURN(0);
    WHEN OTHERS THEN
       RETURN(0);
    END;
    RETURN(V_RESULTADO);
End;
/

