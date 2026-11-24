DECLARE
  --Query de la consulta
  V_SQL long := '-- RESUMEN
Select  distinct m.tipo Tipo_Cartera, t.cod_moneda, p.nom_completo Entidad,  t.fec_inicio Fecha_Desembolso, t.nro_cuenta,
t.monto, t.mto_interes, t.fec_vencimiento Fecha_Vcto, t.cantidad cant_cuotas, t.val_tasa, (t.fec_vencimiento - t.fec_inicio) as cant_dias ,
to_char(t.fec_vencimiento,''DD'') dia,
to_char(t.fec_vencimiento,''MM'') mes,
to_char(t.fec_vencimiento,''YYYY'') año,
case
When to_char(t.fec_vencimiento,''MM'') = ''01'' then ''Enero''
When to_char(t.fec_vencimiento,''MM'') = ''02'' then ''Febrero''
When to_char(t.fec_vencimiento,''MM'') = ''03'' then ''Marzo''
When to_char(t.fec_vencimiento,''MM'') = ''04'' then ''Abril''
When to_char(t.fec_vencimiento,''MM'') = ''05'' then ''Mayo''
When to_char(t.fec_vencimiento,''MM'') = ''06'' then ''Junio''
When to_char(t.fec_vencimiento,''MM'') = ''07'' then ''Julio''
When to_char(t.fec_vencimiento,''MM'') = ''08'' then ''Agosto''
When to_char(t.fec_vencimiento,''MM'') = ''09'' then ''Setiembre''
When to_char(t.fec_vencimiento,''MM'') = ''10'' then ''Octubre''
When to_char(t.fec_vencimiento,''MM'') = ''11'' then ''Noviembre''
When to_char(t.fec_vencimiento,''MM'') = ''12'' then ''Diciembre''
end as Descr_MES,
nvl(t.sal_interes,0) Saldo_Interes, nvl(t.sal_capital,0) Saldo_capital,
nvl(t.sal_capital,0)+nvl(t.sal_interes,0) Saldo_Documento ,
((round(sysdate - t.fec_vencimiento, 0)) * -1) Dias_p_Vcto,
case
when round(sysdate - t.fec_vencimiento, 0) > 0 then                      ''Vencido''
when round(sysdate - t.fec_vencimiento, 0) = 0 then                      '' 0 Dias''
when round(sysdate - t.fec_vencimiento, 0) between - 30  and - 1   then  ''AV. De 1 a 30 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 60  and - 31  then  ''AV. De 31 a 60 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 90  and - 61  then  ''AV. De 61 a 90 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 120 and - 91  then  ''AV. De 91 a 120 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 150 and - 121 then  ''AV. De 121 a 150 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 180 and - 151 then  ''AV. De 151 a 180 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 360 and - 181 then  ''AV. De 181 a 360 dias''
when round(sysdate - t.fec_vencimiento, 0) < -360 then                   ''AV. Mas de 360 dias''
end as Tramos,
t.cod_modalidad, m.descripcion Desc_Modalidad,t.fec_ult_pago Fecha_Pago, t.fec_vencimiento - t.fec_inicio plazo,
t.fec_vencimiento - trunc(sysdate) residual,
case
when round(sysdate - t.fec_vencimiento, 0) <= 0 and nvl(t.sal_capital,0)+nvl(t.sal_interes,0) > 0  then  ''PENDIENTE''
when round(sysdate - t.fec_vencimiento, 0) > 0 and  nvl(t.sal_capital,0)+nvl(t.sal_interes,0) > 0  then ''VENCIDO''
when round(sysdate - t.fec_vencimiento, 0) > 0 and  nvl(t.sal_capital,0)+nvl(t.sal_interes,0) = 0 then ''PAGADO''
    else null end est_pago,sum(gg.mto_cuota) mto_garantia, gg.nro_cuenta nro_garantia,
t.observacion obs_garantia
from it.md_cta_documentos t, it.ge_cta_clientes c, it.ba_personas p, it.ge_modalidades m, md_cuo_instrumentos gg
where t.nro_cuenta  = t.nro_cuenta
and   t.nro_cuenta  = c.nro_cuenta
and   c.relacion    = ''P''
and   c.cod_persona = p.cod_persona
and   t.cod_modulo    = 10
and   t.cod_modulo    = m.cod_modulo
and   t.cod_modalidad = m.cod_modalidad
and   t.cod_modalidad <> 119
and   t.val_tasa = t.val_tasa
and   t.cantidad = t.cantidad
--
and gg.nro_cta_repo(+) = t.nro_cuenta
group by  m.tipo, t.cod_moneda, p.nom_completo ,  t.fec_inicio , t.nro_cuenta,
t.monto, t.mto_interes, t.fec_vencimiento , t.cantidad , t.val_tasa,  t.sal_interes,
t.sal_capital, t.cod_modalidad, m.descripcion, t.fec_ult_pago, gg.nro_cuenta,
t.observacion
UNION
Select  distinct m.tipo Tipo_Cartera, t.cod_moneda, p.nom_completo Entidad,  t.fec_apertura Fecha_Desembolso, t.nro_cuenta,
t.sal_total, (select sum(cu.mto_interes) from ah_cupones cu where cu.nro_cuenta = t.nro_cuenta) to_interes,
t.fec_vencimiento Fecha_Vcto,  0 cant_cuotas, fug_obt_val_tasa(t.cod_modulo, t.cod_modalidad, null, null, t.cod_moneda, null, null, t.cod_tasa, null, t.fec_vencimiento) val_tasa, (t.fec_vencimiento - t.fec_apertura) as cant_dias ,
to_char(t.fec_vencimiento,''DD'') dia,
to_char(t.fec_vencimiento,''MM'') mes,
to_char(t.fec_vencimiento,''YYYY'') año,
case
When to_char(t.fec_vencimiento,''MM'') = ''01'' then ''Enero''
When to_char(t.fec_vencimiento,''MM'') = ''02'' then ''Febrero''
When to_char(t.fec_vencimiento,''MM'') = ''03'' then ''Marzo''
When to_char(t.fec_vencimiento,''MM'') = ''04'' then ''Abril''
When to_char(t.fec_vencimiento,''MM'') = ''05'' then ''Mayo''
When to_char(t.fec_vencimiento,''MM'') = ''06'' then ''Junio''
When to_char(t.fec_vencimiento,''MM'') = ''07'' then ''Julio''
When to_char(t.fec_vencimiento,''MM'') = ''08'' then ''Agosto''
When to_char(t.fec_vencimiento,''MM'') = ''09'' then ''Setiembre''
When to_char(t.fec_vencimiento,''MM'') = ''10'' then ''Octubre''
When to_char(t.fec_vencimiento,''MM'') = ''11'' then ''Noviembre''
When to_char(t.fec_vencimiento,''MM'') = ''12'' then ''Diciembre''
end as Descr_MES,
(select sum(cu.mto_interes) from ah_cupones cu where cu.nro_cuenta = t.nro_cuenta and cu.estado = ''E'') Saldo_Interes,
t.capital Saldo_capital,
(select sum(cu.mto_interes) from ah_cupones cu where cu.nro_cuenta = t.nro_cuenta and cu.estado = ''E'') + t.capital Saldo_Documento ,
((round(sysdate - t.fec_vencimiento, 0)) * -1) Dias_p_Vcto,
case
when round(sysdate - t.fec_vencimiento, 0) > 0 then                      ''Vencido''
when round(sysdate - t.fec_vencimiento, 0) = 0 then                      '' 0 Dias''
when round(sysdate - t.fec_vencimiento, 0) between - 30  and - 1   then  ''AV. De 1 a 30 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 60  and - 31  then  ''AV. De 31 a 60 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 90  and - 61  then  ''AV. De 61 a 90 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 120 and - 91  then  ''AV. De 91 a 120 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 150 and - 121 then  ''AV. De 121 a 150 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 180 and - 151 then  ''AV. De 151 a 180 dias''
when round(sysdate - t.fec_vencimiento, 0) between - 360 and - 181 then  ''AV. De 181 a 360 dias''
when round(sysdate - t.fec_vencimiento, 0) < -360 then                   ''AV. Mas de 360 dias''
end as Tramos,
t.cod_modalidad, m.descripcion Desc_Modalidad,t.fec_ult_movimiento Fecha_Pago, t.fec_vencimiento - t.fec_apertura plazo,
t.fec_vencimiento - trunc(sysdate) residual,
case
when round(sysdate - t.fec_vencimiento, 0) < 0 and nvl(t.sal_total,0)  > 0 then  ''PENDIENTE''
when round(sysdate - t.fec_vencimiento, 0) > 0 and nvl(t.sal_total,0)  > 0 then  ''VENCIDO''
when round(sysdate - t.fec_vencimiento, 0) > 0 and nvl(t.sal_total,0)  = 0 then  ''PAGADO''
    else null end est_pago,
 null mto_garantia,
null nro_garantia,
null obs_garantia
from it.ah_cta_certificados t, it.ge_cta_clientes c, it.ba_personas p, it.ge_modalidades m
where t.nro_cuenta  = t.nro_cuenta
and   t.nro_cuenta  = c.nro_cuenta
and   c.relacion    = ''P''
and   c.cod_persona = p.cod_persona
and   t.cod_modulo    = 3
and   t.cod_modulo    = m.cod_modulo
and   t.cod_modalidad = m.cod_modalidad
and   t.cod_modalidad = 36
and   t.cod_tasa = t.cod_tasa
order by  1, 2, 4, 5';  
  
BEGIN
  BEGIN
     pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
  END;
  
  
  UPDATE BA_CONSULTAS A
     SET A.DET_SQL = V_SQL
   WHERE A.COD_CONSULTA = 'CD_PRE_BCO';
  
END;
