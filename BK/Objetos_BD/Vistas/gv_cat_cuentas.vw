create or replace force view it.gv_cat_cuentas as
select
     cc.cod_modulo,
     cc.cod_modalidad,
     cc.nro_cuenta,
     cu.cod_persona,
     p.nom_completo,
     c.cat_automatica,
     c.cat_anterior,
     c.cat_subjetiva,
     cc.cod_moneda,
     cc.sal_total,
     c.cod_oficina,
     c.cod_usu_oficial,
     u.nombre nom_oficial,
     (CASE WHEN abs(NVL(cat_automatica,1)-nvl(cat_anterior,1)) > 1 THEN 'S'
             ELSE 'N'
             END) diferencia
from ge_clientes c,
     ge_cta_clientes cu,
     cc_cta_corrientes cc,
     ba_usuarios u,
     ba_personas p
where
  c.cod_persona = cu.cod_persona
  and cu.relacion = 'P'
  and cu.nro_cuenta = cc.nro_cuenta
  and c.cod_usu_oficial = u.cod_usuario
  and cu.cod_persona = p.cod_persona
  AND cc.estado not in ('A','C','X')
union all
select
     cc.cod_modulo,
     cc.cod_modalidad,
     cc.nro_cuenta,
     cu.cod_persona,
     p.nom_completo,
     c.cat_automatica,
     c.cat_anterior,
     c.cat_subjetiva,
     cc.cod_moneda,
     cc.sal_capital,
     c.cod_oficina,
     c.cod_usu_oficial,
     u.nombre nom_oficial,
     (CASE WHEN abs(NVL(cat_automatica,1)-nvl(cat_anterior,1)) > 1 THEN 'S'
             ELSE 'N'
             END) diferencia
from
     ge_clientes c,
     ge_cta_clientes cu,
     pr_cta_prestamos cc,
     ba_usuarios u,
     ba_personas p
where
  c.cod_persona = cu.cod_persona
  and cu.relacion = 'P'
  and cu.nro_cuenta = cc.nro_cuenta
  and c.cod_usu_oficial = u.cod_usuario
  and cu.cod_persona = p.cod_persona
  and cc.estado NOT IN ('N','I')
union all

select
  cc.cod_modulo,
  cc.cod_modalidad,
  cc.nro_cuenta,
  cu.cod_persona,
  p.nom_completo,
  c.cat_automatica,
  c.cat_anterior,
  c.cat_subjetiva,
  cc.cod_moneda,
  cc.sal_total,
  c.cod_oficina,
  c.cod_usu_oficial,
  u.nombre nom_oficial,
 (CASE WHEN abs(NVL(cat_automatica,1)-nvl(cat_anterior,1)) > 1 THEN 'S'
             ELSE 'N'
             END) diferencia

from
  ge_clientes c,
  ge_cta_clientes cu,
  ov_cta_vencidas cc,
  ba_usuarios u,
  ba_personas p
where
  c.cod_persona = cu.cod_persona
  and cu.relacion = 'P'
  and cu.nro_cuenta = cc.nro_cuenta
  and c.cod_usu_oficial = u.cod_usuario
  and cu.cod_persona = p.cod_persona
  and cc.estado NOT IN ('C','I')
union all
select
  cx.cod_modulo,
  cx.cod_modalidad,
  cx.nro_cuenta,
  cu.cod_persona,
  p.nom_completo,
  c.cat_automatica,
  c.cat_anterior,
  c.cat_subjetiva,
  cx.cod_moneda,
  cx.saldo,
  c.cod_oficina,
  c.cod_usu_oficial,
  u.nombre nom_oficial,
  (CASE WHEN abs(NVL(cat_automatica,1)-nvl(cat_anterior,1)) > 1 THEN 'S'
             ELSE 'N'
             END) diferencia

from
  ge_clientes c,
  ge_cta_clientes
  cu,
  cx_cta_importaciones cx,
  ba_usuarios u,
  ba_personas p
where
  c.cod_persona = cu.cod_persona
  and cu.relacion = 'P'
  and cu.nro_cuenta = cx.nro_cuenta
  and c.cod_usu_oficial = u.cod_usuario
  and cu.cod_persona = p.cod_persona
  and cx.estado NOT IN ('C', 'S') -- cancelada y solicitada
  --AND a.saldo > 0 --DYDMR-3072-Modulo de LC Import Prepagas-SC-25603.-
  and (case when (cx.mto_prepago > cx.mto_utilizado) then
            cx.saldo - (cx.mto_prepago - cx.mto_utilizado)
            else cx.saldo end) > 0
union all
select
  md.cod_modulo,
  md.cod_modalidad,
  md.nro_cuenta,
  cu.cod_persona,
  p.nom_completo,
  c.cat_automatica,
  c.cat_anterior,
  c.cat_subjetiva,
  md.cod_moneda,
  md.sal_capital,
  c.cod_oficina,
  c.cod_usu_oficial,
  u.nombre nom_oficial,
  (CASE WHEN abs(NVL(cat_automatica,1)-nvl(cat_anterior,1)) > 1 THEN 'S'
             ELSE 'N'
             END) diferencia

from
  ge_clientes c,
  ge_cta_clientes cu,
  md_cta_documentos md,
  ba_usuarios u,
  ba_personas p
where
  c.cod_persona = cu.cod_persona
  and cu.relacion = 'P'
  and cu.nro_cuenta = md.nro_cuenta
  and c.cod_usu_oficial = u.cod_usuario
  and cu.cod_persona = p.cod_persona
  AND md.cod_modalidad IN (104, 124, 142, 125, 110, 116, 146) -- ICL 22/03/12 Mail HB: Incluir Call Money
  AND md.estado = 'C'
  AND cu.cod_persona <> '89603'  -- No se informa el código de persona de BCP. -- Requerimiento: CNFAIRUNO-3.
union all

select
  ta.cod_modulo,
  ta.cod_modalidad,
  ta.nro_cuenta,
  cu.cod_persona,
  p.nom_completo,
  c.cat_automatica,
  c.cat_anterior,
  c.cat_subjetiva,
  ta.cod_moneda,
  (CASE WHEN NVL(ta.sal_procesadora,0) < 0 THEN 0
             ELSE NVL(ta.sal_procesadora,0)
             END) saldo,
  c.cod_oficina,
  c.cod_usu_oficial,
  u.nombre nom_oficial,
  (CASE WHEN abs(NVL(c.cat_automatica,1)-nvl(cat_anterior,1)) > 1 THEN 'S'
             ELSE 'N'
             END) diferencia

from
  ge_clientes c,
  ge_cta_clientes cu,
  ta_cta_tarjetas ta,
  ba_usuarios u,
  ba_personas p
where
  c.cod_persona = cu.cod_persona
  and cu.relacion = 'P'
  and cu.nro_cuenta = ta.nro_cuenta
  and c.cod_usu_oficial = u.cod_usuario
  and cu.cod_persona = p.cod_persona
  AND ta.estado <> 'C'
  AND ta.cod_modalidad != 55
;

