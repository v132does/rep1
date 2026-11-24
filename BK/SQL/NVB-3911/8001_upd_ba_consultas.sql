declare

vsql   long := 'Select  distinct m.tipo Tipo_Cartera, t.cod_moneda, p.nom_completo Entidad,  t.fec_inicio Fecha_Desembolso, t.nro_cuenta,
t.monto, t.mto_interes, t.fec_vencimiento Fecha_Vcto, t.estado, t.cantidad, t.val_tasa, (t.fec_vencimiento - t.fec_inicio) as cant_dias ,
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
case
when t.estado = ''N'' then ''Pagado''
when t.estado = ''C'' then ''Pendiente''
end as Estado_pag,
t.cod_modalidad, m.descripcion Desc_Modalidad,t.fec_ult_pago Fecha_Pago
from it.md_cta_documentos t, it.ge_cta_clientes c, it.ba_personas p, it.ge_modalidades m
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
UNION
Select  distinct m.tipo Tipo_Cartera, t.cod_moneda, p.nom_completo Entidad,  t.fec_apertura Fecha_Desembolso, t.nro_cuenta,
t.sal_total, 0 to_interes, t.fec_vencimiento Fecha_Vcto, t.estado,  0 cantidad, fug_obt_val_tasa(t.cod_modulo, t.cod_modalidad, null, null, t.cod_moneda, null, null, t.cod_tasa, null, t.fec_vencimiento) val_tasa, (t.fec_vencimiento - t.fec_apertura) as cant_dias ,
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
0 Saldo_Interes, 0 Saldo_capital,
0 Saldo_Documento ,
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
case
when t.estado = ''N'' then ''Pagado''
when t.estado = ''C'' then ''Pendiente''
end as Estado_pag,
t.cod_modalidad, m.descripcion Desc_Modalidad,t.fec_ult_movimiento Fecha_Pago
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
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1; end;

update ba_consultas 
set det_sql = vsql
where cod_consulta = 'CD_PRE_BCO';

commit;

end;
