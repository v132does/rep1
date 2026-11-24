create or replace force view it.ov_per_cob_tarjetas as
select distinct
 z.cod_persona cod_persona,
 xx_dia_atr_prestamo dia_atr_prestamo,
 yy_dia_atr_tarjeta dia_atr_tarjeta
 from ge_cta_clientes z, ge_clientes s,
(
select a.cod_modulo xx_cod_mod_prestamo,
 b.cod_persona xx_cod_per_prestamo,
 nvl(max(a.dia_atraso),0) xx_dia_atr_prestamo
 from pr_cta_prestamos a, ge_cta_clientes b
 where a.estado not in ('N','I')
 and a.cod_modalidad not in (60,650,660)
 and a.dia_atraso between 5 and 30
 and not exists (select 1 from ge_par_dinamicos x
 where x.parametro like 'COD_CAN_%'
 and x.val_parametro = to_char(a.cod_canal))
 and b.nro_cuenta = a.nro_cuenta
 and b.relacion = 'P'
 and not exists (select 1 from ge_cta_dat_adicionales k
 where k.nro_cuenta = a.nro_cuenta
 and k.parametro = 'COD_BANCA'
 and k.val_parametro = '1')
 and not exists (select 1 from pr_cta_prestamos h, ge_cta_clientes i
 where h.estado not in ('N','I')
 and i.nro_cuenta = h.nro_cuenta
 and i.relacion = 'P'
 and i.cod_persona = b.cod_persona
 and h.dia_atraso > 30)
 group by a.cod_modulo, b.cod_persona
),
(
select a.cod_modulo yy_cod_mod_tarjeta,
 b.cod_persona yy_cod_per_tarjeta,
 nvl(max(a.dia_mora),0) yy_dia_atr_tarjeta
 from ta_cta_tarjetas a, ge_cta_clientes b
 where a.dia_mora between 8 and 30
 and nvl(a.mto_mora,0) > 10000
 and a.estado <> 'C'
 and b.nro_cuenta = a.nro_cuenta
 and b.relacion = 'P'
 and not exists (select 1 from ta_cta_tarjetas h, ge_cta_clientes i
 where h.estado <> 'C'
 and i.nro_cuenta = h.nro_cuenta
 and i.relacion = 'P'
 and i.cod_persona = b.cod_persona
 and h.dia_mora > 30)
 group by a.cod_modulo, b.cod_persona
)
where z.relacion = 'P'
 and z.cod_modulo in (5,6)
 and s.cod_persona = z.cod_persona
 and ((exists (select 1 from pr_cta_prestamos a
 where a.estado not in ('N','I')
 and a.cod_modalidad not in (60,650,660)
 and a.dia_atraso between 5 and 30
 and not exists (select 1 from ge_par_dinamicos x
 where x.parametro like 'COD_CAN_%'
 and x.val_parametro = to_char(a.cod_canal))
 and not exists (select 1 from ge_cta_dat_adicionales k
 where k.nro_cuenta = a.nro_cuenta
 and k.parametro = 'COD_BANCA'
 and k.val_parametro = '1')
 and not exists (select 1 from pr_cta_prestamos h, ge_cta_clientes i
 where h.estado <> 'N'
 and i.nro_cuenta = h.nro_cuenta
 and i.relacion = 'P'
 and i.cod_persona = z.cod_persona
 and h.dia_atraso > 30)
 and not exists (select 1 from ta_cta_tarjetas h, ge_cta_clientes i
 where h.estado <> 'C'
 and i.nro_cuenta = h.nro_cuenta
 and i.relacion = 'P'
 and i.cod_persona = z.cod_persona
 and h.dia_mora > 30)
 and a.nro_cuenta = z.nro_cuenta)) or
 (exists (select 1
 from ta_cta_tarjetas a
 where a.dia_mora between 8 and 30
 and nvl(a.mto_mora,0) > 10000
 and a.estado <> 'C'
 and not exists (select 1 from ta_cta_tarjetas h, ge_cta_clientes i
 where h.estado <> 'C'
 and i.nro_cuenta = h.nro_cuenta
 and i.relacion = 'P'
 and i.cod_persona = z.cod_persona
 and h.dia_mora > 30)
 and not exists (select 1 from pr_cta_prestamos h, ge_cta_clientes i
 where h.estado <> 'N'
 and i.nro_cuenta = h.nro_cuenta
 and i.relacion = 'P'
 and i.cod_persona = z.cod_persona
 and h.dia_atraso > 30)
 and a.nro_cuenta = z.nro_cuenta)))
 and xx_cod_per_prestamo(+) = z.cod_persona
 and yy_cod_per_tarjeta(+) = z.cod_persona
 and nvl(yy_dia_atr_tarjeta,0) > nvl(xx_dia_atr_prestamo,0)
 and ((not exists (select 1 from ba_usuarios x where x.cod_persona = z.cod_persona))
 or (s.cod_usu_oficial <> fug_obt_pardinamico('OFICIAL_RRHH',null,null,null,null)))
 /* Si ya se le gestiono por el prestamo y entra la tarjeta no cambiar el gestor */
 and not exists (select 1 from cr_agendas ag
                 where ag.cod_persona = z.cod_persona
                   and ag.cod_campana in (46)
                   and ag.cod_estado in (2,3,4)
                   and ag.fec_actividad >= pag_cal.FU_OBT_FEC_ACTUAL(6) -
nvl(xx_dia_atr_prestamo,0));

