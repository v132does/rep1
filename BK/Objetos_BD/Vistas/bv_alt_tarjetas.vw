create or replace force view it.bv_alt_tarjetas as
select "NRO_PERSONA","FECHA","GESTOR","NRO_CUENTA","NRO_TARJETA","MODALIDAD","COD_AFINIDAD","AFINIDAD","COD_OFICINA","DES_OFIC","OBSERVACION","RELACION" from (
select gc.cod_persona Nro_persona,
tj.fec_emision fecha,
fue_obt_nom_usuario(gc.cod_usu_oficial) Gestor,
ta.nro_cuenta,
tj.nro_tarjeta,
fug_obt_des_modal(ta.cod_modulo, ta.cod_modalidad) Modalidad,
ta.afinidad cod_afinidad,
ba.significado afinidad,
ta.cod_oficina,
fue_obt_des_oficina(ta.cod_oficina) Des_Ofic,
substr(ts.observacion,1,200) observacion,
bb.significado relacion

from ge_clientes gc, ta_cta_tarjetas ta, ge_cta_clientes cli, ta_tarjetas tj, ba_cod_referencias ba,
  ba_cod_referencias bb, ta_solicitudes ts, Ta_Tar_Cuentas_Tmp x
 where gc.cod_persona=cli.cod_persona
   and tj.cod_persona=cli.cod_persona
   and ta.nro_cuenta=cli.nro_cuenta
   and cli.relacion='P'
   and ta.nro_cuenta=tj.nro_cuenta

   and x.NRO_CUENTA(+) = tj.nro_cuenta
   and trim(x.NRO_TARJETA(+)) = tj.nro_tarjeta
   and x.tip_ult_embozado='E'

   and ta.afinidad=ba.val_minimo
   and ba.dominio='AFINIDAD'
   and bb.val_minimo=cli.relacion
   and bb.dominio='RELACION'
   and ts.nro_solicitud=ta.nro_solicitud
   and ts.fec_solicitud=tj.fec_solicitud
   and ta.cod_modalidad<>55
   and not exists (select count(1),tt.nro_cuenta,tt.cod_persona from ta_tarjetas tt, ge_cta_clientes g
                  where tt.nro_cuenta=g.nro_cuenta and tt.nro_cuenta=ta.nro_cuenta and tt.cod_persona=tj.cod_persona
                  and tt.cod_persona=g.cod_persona
                  and g.relacion='P'
                  group by tt.nro_cuenta,tt.cod_persona having count(1)>1)

union all
select gc.cod_persona Nro_persona,
tj.fec_emision fecha,
fue_obt_nom_usuario(gc.cod_usu_oficial) Gestor,
ta.nro_cuenta,
tj.nro_tarjeta,
fug_obt_des_modal(ta.cod_modulo, ta.cod_modalidad) Modalidad,
ta.afinidad cod_afinidad,
ba.significado afinidad,
ta.cod_oficina,
fue_obt_des_oficina(ta.cod_oficina) Des_Ofic,
substr(ts.observacion,1,200) observacion,
bb.significado relacion
  from ge_clientes gc, ta_cta_tarjetas ta, ge_cta_clientes cli, ta_tarjetas tj, ba_cod_referencias ba,
  ba_cod_referencias bb, ta_solicitudes ts, Ta_Tar_Cuentas_Tmp x
 where gc.cod_persona=cli.cod_persona
   and tj.cod_persona=cli.cod_persona

   and x.NRO_CUENTA(+) = tj.nro_cuenta
   and trim(x.NRO_TARJETA(+)) = tj.nro_tarjeta
   and x.tip_ult_embozado='E'

   and ta.nro_cuenta=cli.nro_cuenta
   and cli.relacion<>'P'
   and ta.nro_cuenta=tj.nro_cuenta
   and ta.afinidad=ba.val_minimo
   and ba.dominio='AFINIDAD'
   and bb.val_minimo=cli.relacion
   and bb.dominio='RELACION'
   and ts.nro_solicitud=ta.nro_solicitud
   and ts.fec_solicitud=tj.fec_solicitud
   and ta.cod_modalidad<>55
   and not exists (select count(1),tt.nro_cuenta,tt.cod_persona from ta_tarjetas tt, ge_cta_clientes g
                  where tt.nro_cuenta=g.nro_cuenta and tt.nro_cuenta=ta.nro_cuenta and tt.cod_persona=tj.cod_persona
                  and tt.cod_persona=g.cod_persona
                  and g.relacion<>'P'
                  group by tt.nro_cuenta,tt.cod_persona having count(1)>1)
union all
select gc.cod_persona Nro_persona,
tj.fec_emision fecha,
fue_obt_nom_usuario(gc.cod_usu_oficial) Gestor,
ta.nro_cuenta,
tj.nro_tarjeta,
fug_obt_des_modal(ta.cod_modulo, ta.cod_modalidad) Modalidad,
ta.afinidad cod_afinidad,
ba.significado afinidad,
ta.cod_oficina,
fue_obt_des_oficina(ta.cod_oficina) Des_Ofic,
null,
bb.significado relacion
  from ge_clientes gc, ta_cta_tarjetas ta, ge_cta_clientes cli, ta_tarjetas tj, ba_cod_referencias ba,
  ba_cod_referencias bb, Ta_Tar_Cuentas_Tmp x
 where gc.cod_persona=cli.cod_persona
   and tj.cod_persona=cli.cod_persona
   and ta.nro_cuenta=cli.nro_cuenta
   and cli.relacion='P'

   and x.NRO_CUENTA(+) = tj.nro_cuenta
   and trim(x.NRO_TARJETA(+)) = tj.nro_tarjeta
   and x.tip_ult_embozado='E'

   and ta.nro_cuenta=tj.nro_cuenta
   and ta.afinidad=ba.val_minimo
   and ba.dominio='AFINIDAD'
   and bb.val_minimo=cli.relacion
   and bb.dominio='RELACION'
   and ta.cod_modalidad<>55
   and ta.afinidad=010601
   and not exists (select count(1),tt.nro_cuenta,tt.cod_persona from ta_tarjetas tt, ge_cta_clientes g
                  where tt.nro_cuenta=g.nro_cuenta and tt.nro_cuenta=ta.nro_cuenta and tt.cod_persona=tj.cod_persona
                  and tt.cod_persona=g.cod_persona
                  and g.relacion='P'
                  group by tt.nro_cuenta,tt.cod_persona having count(1)>1)
union all
select gc.cod_persona Nro_persona,
tj.fec_emision fecha,
fue_obt_nom_usuario(gc.cod_usu_oficial) Gestor,
ta.nro_cuenta,
tj.nro_tarjeta,
fug_obt_des_modal(ta.cod_modulo, ta.cod_modalidad) Modalidad,
ta.afinidad cod_afinidad,
ba.significado afinidad,
ta.cod_oficina,
fue_obt_des_oficina(ta.cod_oficina) Des_Ofic,
null,
bb.significado relacion
  from ge_clientes gc, ta_cta_tarjetas ta, ge_cta_clientes cli, ta_tarjetas tj, ba_cod_referencias ba,
  ba_cod_referencias bb, Ta_Tar_Cuentas_Tmp x
 where gc.cod_persona=cli.cod_persona
   and tj.cod_persona=cli.cod_persona
   and ta.nro_cuenta=cli.nro_cuenta
   and cli.relacion<>'P'
   and ta.nro_cuenta=tj.nro_cuenta
   and ta.afinidad=ba.val_minimo

   and x.NRO_CUENTA(+) = tj.nro_cuenta
   and trim(x.NRO_TARJETA(+)) = tj.nro_tarjeta
   and x.tip_ult_embozado='E'

   and ba.dominio='AFINIDAD'
   and bb.val_minimo=cli.relacion
   and bb.dominio='RELACION'
   and ta.cod_modalidad<>55
   and ta.afinidad=010601
   and not exists (select count(1),tt.nro_cuenta,tt.cod_persona from ta_tarjetas tt, ge_cta_clientes g
                  where tt.nro_cuenta=g.nro_cuenta and tt.nro_cuenta=ta.nro_cuenta and tt.cod_persona=tj.cod_persona
                  and tt.cod_persona=g.cod_persona
                  and g.relacion<>'P'
                  group by tt.nro_cuenta,tt.cod_persona having count(1)>1)
                 )x;

