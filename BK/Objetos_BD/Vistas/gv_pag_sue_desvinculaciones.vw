create or replace force view it.gv_pag_sue_desvinculaciones as
Select cc.cod_ente, cc.nro_cuenta Nro_cta_nomina, pr.nro_cuenta Nro_Cta_Mora, pr.cod_modulo, gc.cod_persona
from ah_cta_vistas cc, ge_cta_clientes gc,
      (Select c.cod_persona, c.nro_cuenta, c.cod_modulo
      from pr_cta_prestamos p, ge_cta_clientes c
      where c.nro_cuenta    = p.nro_cuenta
        and c.cod_modalidad = p.cod_modalidad
        and c.relacion = 'P'
        and p.cob_automatico <> 'S'
        and p.dia_atraso > 0
        and p.estado in ('C', 'V', 'M', 'G')) PR
where cc.nro_cuenta    = gc.nro_cuenta
  and cc.cod_modulo    = gc.cod_modulo
  and cc.cod_modalidad = gc.cod_modalidad
  and gc.cod_persona   = pr.cod_persona
  and gc.relacion      = 'P'
  and cc.estado not in ('C', 'P')

union all

Select cc.cod_ente, cc.nro_cuenta Nro_cta_nomina, pr.nro_cuenta Nro_Cta_Mora, pr.cod_modulo, gc.cod_persona
from cc_cta_corrientes cc, ge_cta_clientes gc,
      (Select c.cod_persona, c.nro_cuenta, c.cod_modulo
      from pr_cta_prestamos p, ge_cta_clientes c
      where c.nro_cuenta    = p.nro_cuenta
        and c.cod_modalidad = p.cod_modalidad
        and c.relacion = 'P'
        and p.cob_automatico <> 'S'
        and p.estado in ('C', 'V', 'M', 'G')
        and p.dia_atraso > 0) PR
where cc.nro_cuenta    = gc.nro_cuenta
  and cc.cod_modulo    = gc.cod_modulo
  and cc.cod_modalidad = gc.cod_modalidad
  and gc.cod_persona   = pr.cod_persona
  and gc.relacion      = 'P'
  and cc.estado <> 'C'

union all

Select cc.cod_ente, cc.nro_cuenta Nro_cta_nomina, pr.nro_cuenta Nro_Cta_Mora, pr.cod_modulo, gc.cod_persona
from ah_cta_vistas cc, ge_cta_clientes gc,
      (Select c.cod_persona, c.nro_cuenta, c.cod_modulo
      from ta_cta_tarjetas t, ge_cta_clientes c
      where c.nro_cuenta    = t.nro_cuenta
        and c.cod_modalidad = t.cod_modalidad
        and c.relacion = 'P'
        and t.deb_automatico <> 'S'
        and t.estado NOT IN ('C')
        and t.dia_mora > 0) PR
where cc.nro_cuenta    = gc.nro_cuenta
  and cc.cod_modulo    = gc.cod_modulo
  and cc.cod_modalidad = gc.cod_modalidad
  and gc.cod_persona   = pr.cod_persona
  and gc.relacion      = 'P'
  and cc.estado not in ('C', 'P')

union all

Select cc.cod_ente, cc.nro_cuenta Nro_cta_nomina, pr.nro_cuenta Nro_Cta_Mora, pr.cod_modulo, gc.cod_persona
from cc_cta_corrientes cc, ge_cta_clientes gc,
      (Select c.cod_persona, c.nro_cuenta, c.cod_modulo
      from ta_cta_tarjetas t, ge_cta_clientes c
      where c.nro_cuenta    = t.nro_cuenta
        and c.cod_modalidad = t.cod_modalidad
        and c.relacion = 'P'
        and t.deb_automatico <> 'S'
        and t.estado NOT IN ('C')
        and t.dia_mora > 0) PR
where cc.nro_cuenta    = gc.nro_cuenta
  and cc.cod_modulo    = gc.cod_modulo
  and cc.cod_modalidad = gc.cod_modalidad
  and gc.cod_persona   = pr.cod_persona
  and gc.relacion      = 'P'
  and cc.estado not in ('C');

