CREATE OR REPLACE FORCE VIEW IT.VIS_OBT_OPE_MAR_SUPERIORES AS
select
c.fec_apertura,
a.fecha,
pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1) fecha_operacion,
pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1) fecha_vencimiento,
e.cod_persona,
x.nom_completo,
a.cod_oficina,
f.descripcion descripcion_oficina,
b.nro_cuenta,
c.denominacion denominacion_cuenta,
a.cod_modalidad,
g.descripcion descripcion_modalidad,
a.cod_moneda,
b.sal_actual monto,
b.sal_actual monto_moneda_local,
FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)) tasa_nominal,
pas_bcp.fu_obt_tae(FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)), decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)) tasa_efectiva,
                       (fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null),c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)))*150/100 tasa_base,
                       (fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null),c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) tasa_pizarra,
decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null) plazo,
a.cod_rubro,
b.sal_actual/(select abs(c.sal_mon_loc_ant+c.deb_equ_local-c.cre_mon_local) saldo
from cb_sal_consolidados_dia c
where c.cod_rubro='200000000000000'
and c.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)) porcentaje_operacion,
b.sal_actual+b.sal_actual/(select abs(c.sal_mon_loc_ant+c.deb_equ_local-c.cre_mon_local) saldo
from cb_sal_consolidados_dia c
where c.cod_rubro='200000000000000'
and c.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)) monto_porcentaje


from cb_sal_inventarios_his a join cb_sal_inventarios_det_his b
on a.nro_referencia = b.nro_referencia
and a.fecha = b.fecha
join ah_cta_vistas c
on b.nro_cuenta = c.nro_cuenta
join ge_plz_contables d
on a.cod_plazo = d.cod_plazo
join ge_cta_clientes e
on b.nro_cuenta = e.nro_cuenta
and e.relacion = 'P'
join ba_oficinas f
on a.cod_oficina = f.cod_oficina
join ge_modalidades g
on g.cod_modalidad = a.cod_modalidad
join ba_personas x
on x.cod_persona = e.cod_persona
where (substr(a.cod_rubro,6,3) in (102,196,236,292,238)
or (substr(a.cod_rubro,6,3) in (138) and substr(a.cod_rubro,9,2) in (02,03)))
and (fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null),c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)))*150/100 <
                      pas_bcp.fu_obt_tae(FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)), decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null))
and a.cod_modalidad = 31
and a.cod_moneda in ('GS')
and a.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)
and a.tip_saldo = 'C'
and (to_char(c.fec_apertura, 'MM/YYYY') = to_char(pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1), 'MM/YYYY')
OR c.nro_cuenta in (SELECT b.nro_cuenta FROM gv_movimientos b where b.COD_TRANSACCION in (100) and to_char(b.FECHA, 'YYYY/MM') = to_char(pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1), 'MM/YYYY') and b.NRO_CUENTA is not null and b.REVERSADO = 'N'))


UNION ALL

--depositos a la vista usd

select
c.fec_apertura,
a.fecha,
pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1) fecha_operacion,
pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1) fecha_vencimiento,
e.cod_persona,
x.nom_completo,
a.cod_oficina,
f.descripcion descripcion_oficina,
b.nro_cuenta,
c.denominacion denominacion_cuenta,
a.cod_modalidad,
g.descripcion descripcion_modalidad,
a.cod_moneda,
b.sal_actual monto,
b.sal_actual*(pag_gen.fu_obt_cotizacion(a.cod_moneda,pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1))) monto_moneda_local,
FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)) tasa_nominal,
pas_bcp.fu_obt_tae(FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)), decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)) tasa_efectiva,
                      (fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null),c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)))*250/100 tasa_base,
                       (fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null),c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) tasa_pizarra,
decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null) plazo,
a.cod_rubro,

b.sal_actual*(pag_gen.fu_obt_cotizacion(a.cod_moneda,pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)))/(select abs(c.sal_mon_loc_ant+c.deb_equ_local-c.cre_mon_local) saldo
from cb_sal_consolidados_dia c
where c.cod_rubro='200000000000000'
and c.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)) porcentaje_operacion,
b.sal_actual*(pag_gen.fu_obt_cotizacion(a.cod_moneda,pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)))+b.sal_actual*(pag_gen.fu_obt_cotizacion(a.cod_moneda,pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)))/(select abs(c.sal_mon_loc_ant+c.deb_equ_local-c.cre_mon_local) saldo
from cb_sal_consolidados_dia c
where c.cod_rubro='200000000000000'
and c.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)) monto_porcentaje






from cb_sal_inventarios_his a join cb_sal_inventarios_det_his b
on a.nro_referencia = b.nro_referencia
and a.fecha = b.fecha
join ah_cta_vistas c
on b.nro_cuenta = c.nro_cuenta
join ge_plz_contables d
on a.cod_plazo = d.cod_plazo
join ge_cta_clientes e
on b.nro_cuenta = e.nro_cuenta
and e.relacion = 'P'
join ba_oficinas f
on a.cod_oficina = f.cod_oficina
join ge_modalidades g
on g.cod_modalidad = a.cod_modalidad

join ba_personas x
on x.cod_persona = e.cod_persona
where (substr(a.cod_rubro,6,3) in (102,196,236,292,238)
or (substr(a.cod_rubro,6,3) in (138) and substr(a.cod_rubro,9,2) in (02,03)))
and (fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null),c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)))*250/100 <
                      pas_bcp.fu_obt_tae(FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)), decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null))
and a.cod_modalidad = 31
and a.cod_moneda in ('USD')
and a.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)
and a.tip_saldo = 'C'
and (to_char(c.fec_apertura, 'MM/YYYY') = to_char(pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1), 'MM/YYYY')
or c.nro_cuenta in (SELECT b.nro_cuenta FROM gv_movimientos b where b.COD_TRANSACCION in (100) and to_char(b.FECHA, 'YYYY/MM') = to_char(pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1), 'MM/YYYY') and b.NRO_CUENTA is not null and b.REVERSADO = 'N'))

union all

--cda gs
select
c.fec_apertura,
a.fecha,
c.fec_apertura fecha_operacion,
c.fec_vencimiento fecha_vencimiento,
e.cod_persona,
x.nom_completo,
a.cod_oficina,
f.descripcion descripcion_oficina,
b.nro_cuenta,
c.denominacion denominacion_cuenta,
a.cod_modalidad,
g.descripcion descripcion_modalidad,
a.cod_moneda,
b.sal_actual monto,
b.sal_actual monto_moneda_local,
FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)) tasa_nominal,
pas_bcp.fu_obt_tae(FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)), /*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura) tasa_efectiva,
                      (fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,/*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura,c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)))*150/100 tasa_base,
                      fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,/*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura,c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)) tasa_pizarra,
/*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura plazo,
a.cod_rubro,
b.sal_actual/(select abs(ccd.sal_mon_loc_ant+ccd.deb_equ_local-ccd.cre_mon_local) saldo
from cb_sal_consolidados_dia ccd
where ccd.cod_rubro='200000000000000'
and ccd.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)) porcentaje_operacion,
b.sal_actual+b.sal_actual/(select abs(ccd.sal_mon_loc_ant+ccd.deb_equ_local-ccd.cre_mon_local) saldo
from cb_sal_consolidados_dia ccd
where ccd.cod_rubro='200000000000000'
and ccd.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)) monto_porcentaje


from cb_sal_inventarios_his a join cb_sal_inventarios_det_his b
on a.nro_referencia = b.nro_referencia
and a.fecha = b.fecha
join ah_cta_certificados c
on b.nro_cuenta = c.nro_cuenta
join ge_plz_contables d
on a.cod_plazo = d.cod_plazo
join ge_cta_clientes e
on b.nro_cuenta = e.nro_cuenta
and e.relacion = 'P'
join ba_oficinas f
on a.cod_oficina = f.cod_oficina
join ge_modalidades g
on g.cod_modalidad = a.cod_modalidad
join ba_personas x
on x.cod_persona = e.cod_persona
where substr(a.cod_rubro,6,3) in (104,156,298,306)
and ((fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,/*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura,c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)))*150/100) <
                      pas_bcp.fu_obt_tae(FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)),/*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura)
and a.cod_modalidad = 33
and a.cod_moneda in ('GS')
and a.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)
and a.tip_saldo = 'C'
and to_char(c.fec_apertura, 'MM/YYYY') = to_char(pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1), 'MM/YYYY')

UNION ALL

--cda usd

select
c.fec_apertura,
a.fecha,
c.fec_apertura fecha_operacion,
c.fec_vencimiento fecha_vencimiento,
e.cod_persona,
x.nom_completo,
a.cod_oficina,
f.descripcion descripcion_oficina,
b.nro_cuenta,
c.denominacion denominacion_cuenta,
a.cod_modalidad,
g.descripcion descripcion_modalidad,
a.cod_moneda,
b.sal_actual monto,
b.sal_actual monto_moneda_local,
FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)) tasa_nominal,
pas_bcp.fu_obt_tae(FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)),/* decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura) tasa_efectiva,
                      (fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,/*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura,c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)))*250/100 tasa_base,
                      fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,/*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura,c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)) tasa_pizarra,
/*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura plazo,
a.cod_rubro,
b.sal_actual/(select abs(ccd.sal_mon_loc_ant+ccd.deb_equ_local-ccd.cre_mon_local) saldo
from cb_sal_consolidados_dia ccd
where ccd.cod_rubro='200000000000000'
and ccd.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)) porcentaje_operacion,
b.sal_actual+b.sal_actual/(select abs(ccd.sal_mon_loc_ant+ccd.deb_equ_local-ccd.cre_mon_local) saldo
from cb_sal_consolidados_dia ccd
where ccd.cod_rubro='200000000000000'
and ccd.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)) monto_porcentaje


from cb_sal_inventarios_his a join cb_sal_inventarios_det_his b
on a.nro_referencia = b.nro_referencia
and a.fecha = b.fecha
join ah_cta_certificados c
on b.nro_cuenta = c.nro_cuenta
join ge_plz_contables d
on a.cod_plazo = d.cod_plazo
join ge_cta_clientes e
on b.nro_cuenta = e.nro_cuenta
and e.relacion = 'P'
join ba_oficinas f
on a.cod_oficina = f.cod_oficina
join ge_modalidades g
on g.cod_modalidad = a.cod_modalidad
join ba_personas x
on x.cod_persona = e.cod_persona
where substr(a.cod_rubro,6,3) in (104,156,298,306)
and ((fu_obt_tas_efe_pizarra(a.cod_modulo,a.cod_modalidad,a.cod_moneda,b.sal_actual,/*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura,c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)))*250/100)  <
                      pas_bcp.fu_obt_tae(FUG_OBT_VAL_TASA(a.cod_modulo,a.cod_modalidad,
                              a.cod_oficina,b.nro_cuenta,a.cod_moneda,null,c.tas_personalizada,
                              c.cod_tasa,null,(select z.ult_dia_mes from ge_calendarios z where z.cod_modulo = a.cod_modulo)), /*decode(c.tip_capitalizacion,
                    1,
                      30,
                      2,
                      60,
                      3,
                      90,
                      4,
                      120,
                      6,
                      180,
                      12,
                      365,
                      99,
                      d.can_dias,
                      null)*/c.fec_vencimiento - c.fec_apertura)
and a.cod_modalidad = 33
and a.cod_moneda in ('USD')
and a.fecha = pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1)
and a.tip_saldo = 'C'
and to_char(c.fec_apertura, 'MM/YYYY') = to_char(pag_cal.fu_obt_fec_ant_hab((select z.pri_dia_mes from ge_calendarios z where z.cod_modulo = 1),31,1), 'MM/YYYY')
;

