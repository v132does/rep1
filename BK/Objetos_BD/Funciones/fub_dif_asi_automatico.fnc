CREATE OR REPLACE FUNCTION IT.FUB_DIF_ASI_AUTOMATICO
(p_fecha in date, p_cod_oficina in number, p_nro_asiento in number)
RETURN number is
v_retorno number := 0;
BEGIN
select  sum(decode(tip_movimiento, 'D', mto_mon_local, 0)) -
       sum(decode(tip_movimiento, 'C', mto_mon_local, 0))
  into v_retorno      
from cb_asi_automaticos_det t
where t.fecha = p_fecha
  and t.cod_oficina = p_cod_oficina
  and t.nro_asiento = p_nro_asiento
group by nro_asiento;
  return v_retorno;
EXCEPTION
  when others then
     return v_retorno;
END;
/

