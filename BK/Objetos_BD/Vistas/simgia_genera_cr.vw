create or replace force view it.simgia_genera_cr as
select case
when t.CAT1 = 'ADMINCENTRAL' then
     990
when t.CAT1 = 'RRHH' then
     991
when t.CAT1 = 'OTROS' then
     992
when f.cod_usuario = 'RRHH' then
     991
else
     to_number(a.cod_oficina)
end cod_oficina,
to_number(c.cod_persona) cod_persona,
t.CAT1,
to_number(sum(
case
when substr(z.cod_rub_externo,5,2) = '94' then
     b.sal_actual * nvl(pag_gen.fu_obt_cotizacion(a.cod_moneda, pag_cal.fu_obt_fec_actual(1)),1)*-1
when substr(z.cod_rub_externo,5,2) = '92' then
     b.sal_actual * nvl(pag_gen.fu_obt_cotizacion(a.cod_moneda, pag_cal.fu_obt_fec_actual(1)),1)*-1
else
     b.sal_actual * nvl(pag_gen.fu_obt_cotizacion(a.cod_moneda, pag_cal.fu_obt_fec_actual(1)),1)
end
)) monto_gs,
e.nom_completo,
case
when t.CAT1 = 'ADMINCENTRAL' then
     'ADMINISTRACION CENTRAL'
when t.CAT1 = 'RRHH' then
     'RECURSOS HUMANOS'
when t.CAT1 = 'OTROS' then
     'OTROS'
when f.cod_usuario = 'RRHH' then
     'RECURSOS HUMANOS'
else
     f.nombre
end nom_gestor,
case
when t.CAT1 = 'ADMINCENTRAL' then
     'ADMINCENTRAL'
when t.CAT1 = 'RRHH' then
     'RRHH'
when t.CAT1 = 'OTROS' then
     'OTROS'
else
     f.cod_usuario
end cod_gestor,
pag_cal.fu_obt_fec_actual(1) fecha
from cb_sal_inventarios a join cb_sal_inventarios_det b on a.nro_referencia = b.nro_referencia
join cb_rubros z on a.cod_rubro = z.cod_rubro
join ge_cta_clientes c on b.nro_cuenta = c.nro_cuenta and c.relacion = 'P'
join ge_clientes d on d.cod_persona = c.cod_persona
join ba_personas e on e.cod_persona = d.cod_persona
join ba_usuarios f on f.cod_usuario = d.cod_usu_oficial
join smg_rubros_crcp t on z.cod_rub_externo = t.cod_rubro
where
t.tipo = 'cartera'
group by a.cod_oficina, c.cod_persona, e.nom_completo, f.nombre, f.cod_usuario,z.cod_rubro,z.cod_rub_externo,z.descripcion,z.naturaleza,CAT1

union all

/*
No inventariado
*/

select 992 cod_oficina,
0 cod_persona,
'OTROS' CAT1,
abs(to_number(sum(
case
when substr(b.cod_rub_externo,5,2) = '94' then
     (decode(b.cod_moneda,'GS',(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)),
(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) * nvl(pag_gen.fu_obt_cotizacion(b.cod_moneda, pag_cal.fu_obt_fec_actual(1) ),1))*-1
when substr(b.cod_rub_externo,5,2) = '92' then
     ABS(decode(b.cod_moneda,'GS',(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)),
(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) * nvl(pag_gen.fu_obt_cotizacion(b.cod_moneda, pag_cal.fu_obt_fec_actual(1)),1))*-1
else
     decode(b.cod_moneda,'GS',(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)),
(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) * nvl(pag_gen.fu_obt_cotizacion(b.cod_moneda, pag_cal.fu_obt_fec_actual(1)),1)
end
)))
monto_gs,
'VARIOS' nom_completo,
'OTROS' NOM_GESTOR,
'OTROS' COD_GESTOR,
pag_cal.fu_obt_fec_actual(1) fecha
from cb_rubros b, cb_sal_consolidados_ayer a, smg_rubros_crcp s
where a.cod_rubro = b.cod_rubro
and substr(a.cod_rubro,1,1) in ('1','2','4','5')
and decode(b.cod_moneda,'GS',(nvl(a.sal_mon_loc_ant,0)+nvl(a.deb_mon_local,0)-nvl(a.cre_mon_local,0)),
(nvl(a.sal_mon_rub_ant,0)+nvl(a.deb_mon_rubro,0)-nvl(a.cre_mon_rubro,0))) <> 0
and s.cod_rubro = b.cod_rub_externo
and s.tipo = 'cartera'
and b.cod_rubro in (select b.cod_rubro
                    from cb_rubros b, cb_sal_consolidados_ayer a
                    left join (select cb.cod_rubro from cb_sal_inventarios cb) c on a.cod_rubro = c.cod_rubro
                    where a.cod_rubro = b.cod_rubro
                    and substr(a.cod_rubro,1,1) in ('1','2','4','5')
                    and c.cod_rubro is null
                    and b.cod_rub_externo is not null);

