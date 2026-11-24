create or replace force view it.gv_reg_ext_click as
select decode(t.tip_novedad, 'A', 'Alta', 'Baja') tip_novedad,
       t.canal, t.fecha, t.motivo, r.abreviatura desc_motivo,
       'Cuenta Tarjeta' producto,
       t.cod_persona, p.nom_completo,ta.nro_cuenta, ta.nro_tarjeta,
       decode(t.canal, 'WEB', decode(t.ret_tarjeta, 'S', decode(t.nro_cuenta, null, 'S', 'N'),'N'), 'N') todas_tarjetas,
       t.fec_insercion fec_insercion,
       5 cod_modulo
  from ge_reg_tip_extracto t, ba_cod_referencias r, ta_cta_tarjetas c, ta_tarjetas ta, ba_personas p
 where r.dominio(+) = 'MOT_RET_EXTRACTO'
   and r.val_minimo(+) = t.motivo
   and ta.cod_persona = t.cod_persona(+)
   and c.nro_cuenta= ta.nro_cuenta
   and not exists (select 1 from ge_par_dinamicos
                    WHERE parametro = 'EXC_NOT_EXT_TAR'
                      AND cod_modulo = c.cod_modulo
                      AND cod_modalidad = c.cod_modalidad)
   and ((ta.nro_cuenta = t.nro_cuenta) or (t.canal ='WEB' and t.nro_cuenta is null))
   and ta.vigente(+) = 'S'
   and t.ret_tarjeta = 'S'
   and t.cod_persona = p.cod_persona
union all
select decode(t.tip_novedad, 'A', 'Alta', 'Baja') tip_novedad,
       t.canal, t.fecha, t.motivo, r.abreviatura desc_motivo,
       'Cuenta Tarjeta' producto,
       t.cod_persona, p.nom_completo, null, null,
       'N' todas_tarjetas, t.fec_insercion,
       5 cod_modulo
  from ge_reg_tip_extracto t, ba_cod_referencias r, ba_personas p
 where r.dominio(+) = 'MOT_RET_EXTRACTO'
   and r.val_minimo(+) = t.motivo
   and t.canal ='ITGF'
   and t.nro_cuenta is null
   and t.ret_tarjeta = 'S'
   and t.cod_persona = p.cod_persona
union all
select decode(t.tip_novedad, 'A', 'Alta', 'Baja') tip_novedad,
       t.canal, t.fecha, t.motivo, r.abreviatura desc_motivo,
       'Cuentas Corrientes' producto,
       t.cod_persona, p.nom_completo,cl.nro_cuenta, null,
       'N', t.fec_insercion, cc.cod_modulo
  from ge_reg_tip_extracto t, ba_cod_referencias r, ba_personas p, ge_cta_clientes cl, cc_cta_corrientes cc
 where r.dominio(+) = 'MOT_RET_EXTRACTO'
   and r.val_minimo(+) = t.motivo
   and ((cl.nro_cuenta = t.nro_cuenta) or (t.nro_cuenta is null and cc.estado = 'N'))
   and cl.cod_persona = t.cod_persona
   and cl.relacion = 'P'
   and t.cod_persona = p.cod_persona
   and t.ret_cuenta = 'S'
   and cl.nro_cuenta = cc.nro_cuenta
UNION ALL
select decode(t.tip_novedad, 'A', 'Alta', 'Baja') tip_novedad,
       t.canal, t.fecha, t.motivo, r.abreviatura desc_motivo,
       'Ahorros a la Vista' producto,
       t.cod_persona, p.nom_completo,cl.nro_cuenta, null,
       'N', t.fec_insercion, cc.cod_modulo
  from ge_reg_tip_extracto t, ba_cod_referencias r, ba_personas p, ge_cta_clientes cl, ah_cta_vistas cc
 where r.dominio(+) = 'MOT_RET_EXTRACTO'
   and r.val_minimo(+) = t.motivo
   and ((cl.nro_cuenta = t.nro_cuenta) or (t.nro_cuenta is null and cc.estado = 'N'))
   and cl.cod_persona = t.cod_persona
   and cl.relacion = 'P'
   and t.cod_persona = p.cod_persona
   and t.ret_cuenta = 'S'
   and cl.nro_cuenta = cc.nro_cuenta
 ORDER BY 3, 12;

