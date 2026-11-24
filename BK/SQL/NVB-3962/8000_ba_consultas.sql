DECLARE
  --Query de la consulta
  V_SQL long := 'Select  p.nom_completo Entidad,t.observacion,t.denominacion, t.cod_moneda, d.nro_cuenta, d.nro_cuota,
d.fec_vencimiento Fecha_Vcto, t.fec_inicio, t.fec_cam_estado,t.val_tasa,
to_char(d.fec_vencimiento,''DD'') dia,
to_char(d.fec_vencimiento,''MM'') mes,
to_char(d.fec_vencimiento,''YYYY'') año,
case
When to_char(d.fec_vencimiento,''MM'') = ''01'' then ''Enero''
When to_char(d.fec_vencimiento,''MM'') = ''02'' then ''Febrero''
When to_char(d.fec_vencimiento,''MM'') = ''03'' then ''Marzo''
When to_char(d.fec_vencimiento,''MM'') = ''04'' then ''Abril''
When to_char(d.fec_vencimiento,''MM'') = ''05'' then ''Mayo''
When to_char(d.fec_vencimiento,''MM'') = ''06'' then ''Junio''
When to_char(d.fec_vencimiento,''MM'') = ''07'' then ''Julio''
When to_char(d.fec_vencimiento,''MM'') = ''08'' then ''Agosto''
When to_char(d.fec_vencimiento,''MM'') = ''09'' then ''Setiembre''
When to_char(d.fec_vencimiento,''MM'') = ''10'' then ''Octubre''
When to_char(d.fec_vencimiento,''MM'') = ''11'' then ''Noviembre''
When to_char(d.fec_vencimiento,''MM'') = ''12'' then ''Diciembre''
end as Descr_MES,
nvl(d.mto_capital,0)+nvl(d.mto_interes,0) Monto_Documento ,
nvl(d.sal_interes,0) Saldo_Interes, nvl(d.sal_capital,0) Saldo_capital,
nvl(d.sal_capital,0)+nvl(d.sal_interes,0) Saldo_Documento ,
((round(sysdate - d.fec_vencimiento, 0)) * -1) Dias_p_Vcto,
case
when round(sysdate - d.fec_vencimiento, 0) > 0 then                      ''Vencido''
when round(sysdate - d.fec_vencimiento, 0) = 0 then                      '' 0 Dias''
when round(sysdate - d.fec_vencimiento, 0) between - 30  and - 1   then  ''AV. De 1 a 30 dias''
when round(sysdate - d.fec_vencimiento, 0) between - 60  and - 31  then  ''AV. De 31 a 60 dias''
when round(sysdate - d.fec_vencimiento, 0) between - 90  and - 61  then  ''AV. De 61 a 90 dias''
when round(sysdate - d.fec_vencimiento, 0) between - 120 and - 91  then  ''AV. De 91 a 120 dias''
when round(sysdate - d.fec_vencimiento, 0) between - 150 and - 121 then  ''AV. De 121 a 150 dias''
when round(sysdate - d.fec_vencimiento, 0) between - 180 and - 151 then  ''AV. De 151 a 180 dias''
when round(sysdate - d.fec_vencimiento, 0) between - 360 and - 181 then  ''AV. De 181 a 360 dias''
when round(sysdate - d.fec_vencimiento, 0) < -360 then                   ''AV. Mas de 360 dias''
end as Tramos,
  nvl(d.mto_interes,0)- nvl(d.sal_interes,0) Interes_pagado,
  nvl(d.mto_capital,0)- nvl(d.sal_capital,0) Capital_pagado,
case
when d.estado = ''N'' then ''Pagado''
when d.estado = ''C'' then ''Pendiente''
end as Estado,
t.cod_modalidad, m.descripcion Desc_Modalidad,t.fec_ult_pago Fecha_Pago
from it.md_cta_documentos t, it.md_doc_detalles d, it.ge_cta_clientes c, it.ba_personas p, it.ge_modalidades m
where t.nro_cuenta  = d.nro_cuenta
and   t.nro_cuenta  = c.nro_cuenta
and   c.relacion    = ''P''
and   c.cod_persona = p.cod_persona
and   d.estado not in(''N'',''I'')
and   t.cod_modulo    = 10
and   t.cod_modulo    = m.cod_modulo
and   t.cod_modalidad = m.cod_modalidad
and   t.cod_modalidad <> 119

UNION
Select  p.nom_completo Entidad,null observacion,t.denominacion, t.cod_moneda, dd.nro_cuenta, dd.nro_cupon,
dd.fec_vencimiento Fecha_Vcto, t.fec_apertura, t.fec_cam_estado,fug_obt_val_tasa(t.cod_modulo, t.cod_modalidad, null, null, t.cod_moneda, null, null, t.cod_tasa, null, t.fec_vencimiento) val_tasa,
to_char(dd.fec_vencimiento,''DD'') dia,
to_char(dd.fec_vencimiento,''MM'') mes,
to_char(dd.fec_vencimiento,''YYYY'') año,
case
When to_char(dd.fec_vencimiento,''MM'') = ''01'' then ''Enero''
When to_char(dd.fec_vencimiento,''MM'') = ''02'' then ''Febrero''
When to_char(dd.fec_vencimiento,''MM'') = ''03'' then ''Marzo''
When to_char(dd.fec_vencimiento,''MM'') = ''04'' then ''Abril''
When to_char(dd.fec_vencimiento,''MM'') = ''05'' then ''Mayo''
When to_char(dd.fec_vencimiento,''MM'') = ''06'' then ''Junio''
When to_char(dd.fec_vencimiento,''MM'') = ''07'' then ''Julio''
When to_char(dd.fec_vencimiento,''MM'') = ''08'' then ''Agosto''
When to_char(dd.fec_vencimiento,''MM'') = ''09'' then ''Setiembre''
When to_char(dd.fec_vencimiento,''MM'') = ''10'' then ''Octubre''
When to_char(dd.fec_vencimiento,''MM'') = ''11'' then ''Noviembre''
When to_char(dd.fec_vencimiento,''MM'') = ''12'' then ''Diciembre''
end as Descr_MES,
nvl(dd.mto_interes,0) Monto_Documento ,
0 Saldo_Interes,
0 Saldo_capital,
0 Saldo_Documento ,
((round(sysdate - dd.fec_vencimiento, 0)) * -1) Dias_p_Vcto,
case
when round(sysdate - dd.fec_vencimiento, 0) > 0 then                      ''Vencido''
when round(sysdate - dd.fec_vencimiento, 0) = 0 then                      '' 0 Dias''
when round(sysdate - dd.fec_vencimiento, 0) between - 30  and - 1   then  ''AV. De 1 a 30 dias''
when round(sysdate - dd.fec_vencimiento, 0) between - 60  and - 31  then  ''AV. De 31 a 60 dias''
when round(sysdate - dd.fec_vencimiento, 0) between - 90  and - 61  then  ''AV. De 61 a 90 dias''
when round(sysdate - dd.fec_vencimiento, 0) between - 120 and - 91  then  ''AV. De 91 a 120 dias''
when round(sysdate - dd.fec_vencimiento, 0) between - 150 and - 121 then  ''AV. De 121 a 150 dias''
when round(sysdate - dd.fec_vencimiento, 0) between - 180 and - 151 then  ''AV. De 151 a 180 dias''
when round(sysdate - dd.fec_vencimiento, 0) between - 360 and - 181 then  ''AV. De 181 a 360 dias''
when round(sysdate - dd.fec_vencimiento, 0) < -360 then                   ''AV. Mas de 360 dias''
end as Tramos,
  nvl(dd.mto_interes,0) Interes_pagado,
  0 Capital_pagado,
case
when dd.estado = ''P'' then ''Pagado''
when dd.estado = ''E'' then ''Pendiente''
end as Estado,
t.cod_modalidad, m.descripcion Desc_Modalidad,t.fec_ult_movimiento Fecha_Pago
from it.ah_cta_certificados t, it.ah_cupones dd, it.ge_cta_clientes c, it.ba_personas p, it.ge_modalidades m
where t.nro_cuenta  = dd.nro_cuenta
and   t.nro_cuenta  = c.nro_cuenta
and   c.relacion    = ''P''
and   c.cod_persona = p.cod_persona
and   dd.estado not in (''N'',''I'')
and   t.cod_modulo    = 3
and   t.cod_modulo    = m.cod_modulo
and   t.cod_modalidad = m.cod_modalidad
and   t.cod_modalidad = 36
UNION
Select  p.nom_completo Entidad,t.observacion,t.denominacion, t.cod_moneda, d.Nro_Cta_Repo, d.nro_cuota,
t.fec_vencimiento Fecha_Vcto, t.fec_inicio, t.fec_cam_estado,t.val_tasa,
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
nvl(d.mto_interes,0) Monto_Documento ,
nvl(d.mto_interes,0) Saldo_Interes, 
nvl(round(nvl(d.mto_presente,0) * ((100 - nvl(d.val_tas_porcentaje,0)) / 100), nvl(fug_obt_pardinamico(''VAL_RED_MON_EXTRANJERA'', 10, t.cod_modalidad, t.cod_moneda ),0)),0) Saldo_capital,
nvl(round(nvl(d.mto_presente,0) * ((100 - nvl(d.val_tas_porcentaje,0)) / 100), nvl(fug_obt_pardinamico(''VAL_RED_MON_EXTRANJERA'', 10, t.cod_modalidad, t.cod_moneda ),0)),0) + nvl(d.mto_interes,0) Saldo_documento,
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
  nvl(d.mto_interes,0) Interes_pagado,
  0 Capital_pagado,
case
when d.estado = ''N'' then ''Pagado''
when d.estado = ''C'' then ''Pendiente''
end as Estado,
t.cod_modalidad, m.descripcion Desc_Modalidad,t.fec_ult_pago Fecha_Pago
from it.md_cta_documentos t, it.md_cuo_instrumentos d, it.ge_cta_clientes c, it.ba_personas p, it.ge_modalidades m
where t.nro_cuenta  = d.nro_cta_repo
and   t.nro_cuenta  = c.nro_cuenta
and   c.relacion    = ''P''
and   c.cod_persona = p.cod_persona
and   d.estado not in (''N'',''I'')
and   t.cod_modulo    = 10
and   t.cod_modulo    = m.cod_modulo
and   t.cod_modalidad = m.cod_modalidad
and   t.cod_modalidad = 127
order by 4,5,6'
;  
  
BEGIN
  BEGIN
     pre_ini_aplicacion;
     pae_cnf.g_cod_modulo := 1;
  END;
  
  
  UPDATE BA_CONSULTAS A
     SET A.DET_SQL = V_SQL
   WHERE A.COD_CONSULTA = 'CD_PDE_BCO';
  
END;
