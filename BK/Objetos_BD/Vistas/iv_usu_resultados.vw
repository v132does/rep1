create or replace force view it.iv_usu_resultados as
select x."COEFICIENTE",x."COD_PERIODO",x."COD_OFICIAL",x."SAL_BASE",x."COD_MONEDA",x."REM_REFERENCIAL",x."COD_UNIDAD",x."COD_CONCEPTO",x."COD_SUB_CONCEPTO",x."PONDERACION",x."TIP_LOGRO",x."MTO_META",x."LOGRO",x."SUPERADO",x."POR_SUPERADO",x."ADICIONAL",x."VAL_BASE",x."VAL_ADICIONAL", nvl(val_base,0) + nvl(val_adicional,0) val_a_cobrar
from (
select t.*, decode(sign(t.superado),-1,0, round(nvl(rem_referencial,0) * ponderacion / 100)) val_base,
       nvl(decode(sign(t.superado-por_superado),-1,0,
           round((round(nvl(rem_referencial,0) * ponderacion / 100) * adicional)/100,0)),0) val_adicional
from (
-- resultados por oficial
select p.coeficiente,
       p.cod_periodo,
       oun.cod_oficial,
       rh.sal_base,
       rh.cod_moneda,
       round(rh.sal_base * p.coeficiente) rem_referencial,
       oun.cod_unidad,
       oun.cod_concepto ,
       oun.cod_sub_concepto,
       ico.ponderacion,
       ico.tip_logro,
       nvl(oun.mto_meta,0) mto_meta,
       (nvl(oun.logro,0)) logro,
       ((decode(ico.tip_logro,'N',-1,1) * ((nvl(oun.logro,0)) - (nvl(oun.mto_meta,0))))  * 100) /  decode(nvl(oun.mto_meta,0),0,1,oun.mto_meta) superado,
       ico.por_superado,
       ico.adicional
  from ig_parametros p,
       rh_empleados rh,
       ba_usuarios u,
       ig_par_conceptos ico,
       ig_ofi_metas oun
  where u.cod_persona = rh.cod_persona
  and oun.cod_periodo = ico.cod_periodo
  and oun.cod_concepto = ico.cod_concepto
  and ((oun.cod_sub_concepto is null and ico.cod_sub_concepto is null) or
       (oun.cod_sub_concepto is not null and ico.cod_sub_concepto = oun.cod_sub_concepto ))
  and oun.cod_oficial = u.cod_usuario
  and oun.cod_periodo(+) = p.cod_periodo
  and not exists (select 0 from ig_uni_negocios x
                   where x.cod_usu_responsable = u.cod_usuario)
  and not exists (select 0 from ba_gru_oficinas x
                   where x.cod_usu_encargado = u.cod_usuario)
  and u.estado = 'A'
  and ico.ponderacion > 0
  union
-- resultados por unidad de negocios
select p.coeficiente,
       p.cod_periodo,
       uni.cod_usu_responsable cod_oficial,
       rh.sal_base,
       rh.cod_moneda,
       round(rh.sal_base * p.coeficiente) rem_referencial,
       oun.cod_unidad,
       oun.cod_concepto ,
       oun.cod_sub_concepto,
       ico.ponderacion,
       ico.tip_logro,
       nvl(oun.mto_meta,0) mto_meta,
       (nvl(oun.logro,0)) logro,
       ((decode(ico.tip_logro,'N',-1,1) * ((nvl(oun.logro,0)) - (nvl(oun.mto_meta,0))))  * 100) /  decode(nvl(oun.mto_meta,0),0,1,oun.mto_meta) superado,
       ico.por_superado,
       ico.adicional
  from ig_parametros p,
       rh_empleados rh,
       ba_usuarios u,
       ig_par_conceptos ico,
       ig_uni_negocios uni,
       ig_uni_neg_metas oun
  where u.cod_persona = rh.cod_persona
  and oun.cod_periodo = ico.cod_periodo
  and oun.cod_concepto = ico.cod_concepto
  and uni.cod_unidad = oun.cod_unidad
  and ((oun.cod_sub_concepto is null and ico.cod_sub_concepto is null) or
       (oun.cod_sub_concepto is not null and ico.cod_sub_concepto = oun.cod_sub_concepto ))
  and uni.cod_usu_responsable = u.cod_usuario
  and oun.cod_periodo(+) = p.cod_periodo
  and not exists (select 0 from ba_gru_oficinas x
                   where x.cod_usu_encargado = u.cod_usuario)
  and u.estado = 'A'
  and ico.ponderacion > 0
union
-- resultados por regional
select p.coeficiente,
       p.cod_periodo,
       gru.cod_usu_encargado cod_oficial,
       rh.sal_base,
       rh.cod_moneda,
       round(rh.sal_base * p.coeficiente) rem_referencial,
       to_number(oun.cod_unidad) ,
       oun.cod_concepto ,
       oun.cod_sub_concepto,
       ico.ponderacion,
       ico.tip_logro,
       sum(nvl(oun.mto_meta,0)) mto_meta,
       sum((nvl(oun.logro,0))) logro,
       ((decode(ico.tip_logro,'N',-1,1) * ((nvl(sum(oun.logro),0)) - (nvl(sum(oun.mto_meta),0))))  * 100) /  decode(nvl(sum(oun.mto_meta),0),0,1,sum(oun.mto_meta)) superado,
       ico.por_superado,
       ico.adicional
  from ig_parametros p,
       rh_empleados rh,
       ba_usuarios u,
       ig_par_conceptos ico,
       ba_gru_oficinas gru,
       iv_reg_resultados oun
  where u.cod_persona = rh.cod_persona
  and oun.cod_periodo = ico.cod_periodo
  and oun.cod_concepto = ico.cod_concepto
  and gru.cod_gru_oficina = oun.cod_gru_oficina
  and ((oun.cod_sub_concepto is null and ico.cod_sub_concepto is null) or
       (oun.cod_sub_concepto is not null and ico.cod_sub_concepto = oun.cod_sub_concepto ))
  and gru.cod_usu_encargado = u.cod_usuario
  and oun.cod_periodo = p.cod_periodo
  and u.categoria not in ('SC','GC')
  and u.estado = 'A'
  and ico.ponderacion > 0
 group by  p.coeficiente,
       p.cod_periodo,
       gru.cod_usu_encargado,
       rh.sal_base,
       rh.cod_moneda,
       round(rh.sal_base * p.coeficiente),
       oun.cod_concepto ,
       oun.cod_sub_concepto,
       ico.ponderacion,
       ico.tip_logro,
       ico.por_superado,
       ico.adicional,
       oun.cod_unidad
 -- resultados por entidad
 union
 select p.coeficiente,
       p.cod_periodo,
       u.cod_usuario cod_oficial,
       rh.sal_base,
       rh.cod_moneda,
       round(rh.sal_base * p.coeficiente) rem_referencial,
       1 cod_unidad,
       oun.cod_concepto ,
       oun.cod_sub_concepto,
       ico.ponderacion,
       ico.tip_logro,
       nvl(oun.meta,0) mto_meta,
       (nvl(oun.logro,0)) logro,
       ((decode(ico.tip_logro,'N',-1,1) * ((nvl(oun.logro,0)) - (nvl(oun.meta,0))))  * 100) /  decode(nvl(oun.meta,0),0,1,oun.meta) superado,
       ico.por_superado,
       ico.adicional
  from ig_parametros p,
       rh_empleados rh,
       ba_usuarios u,
       ig_par_conceptos ico,
       ig_ent_metas oun
  where u.cod_persona = rh.cod_persona
  and oun.cod_periodo = ico.cod_periodo
  and oun.cod_concepto = ico.cod_concepto
  and ((oun.cod_sub_concepto is null and ico.cod_sub_concepto is null) or
       (oun.cod_sub_concepto is not null and ico.cod_sub_concepto = oun.cod_sub_concepto ))
  and u.categoria in ('SC','GC')
  and u.estado = 'A'
  and ico.ponderacion > 0
  and oun.cod_periodo(+) = p.cod_periodo
  ) t
  ) x
;

