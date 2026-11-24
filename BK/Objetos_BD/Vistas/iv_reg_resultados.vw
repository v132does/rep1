create or replace force view it.iv_reg_resultados as
select cod_gru_oficina, cod_concepto, cod_sub_concepto, cod_periodo,
       round(sum(por_meta)/count(*),2) por_meta,
       decode(tip_meta,'P',sum(mto_meta)/count(*),sum(mto_meta)) mto_meta,
       decode(tip_meta,'P',sum(logro)/count(*), sum(logro)) logro,
       min(cod_unidad) cod_unidad
  from
(
select gru.cod_gru_oficina cod_gru_oficina,
       to_char(oun.cod_unidad) cod_unidad,
       oun.cod_concepto ,
       oun.cod_sub_concepto,
       p.cod_periodo cod_periodo,
       oun.por_meta,
       oun.mto_meta,
       oun.logro,
       ico.tip_meta
  from ig_parametros p,
       rh_empleados rh,
       ba_usuarios u,
       ig_par_conceptos ico,
       ba_gru_oficinas gru,
       ba_oficinas ofi,
       ig_uni_negocios uni,
       ig_uni_neg_metas oun
  where u.cod_persona = rh.cod_persona
  and oun.cod_periodo = ico.cod_periodo
  and oun.cod_concepto = ico.cod_concepto
  and uni.cod_unidad = oun.cod_unidad
  and ofi.cod_oficina(+) = uni.cod_oficina
  and ofi.cod_gru_oficina = gru.cod_gru_oficina
  and ((oun.cod_sub_concepto is null and ico.cod_sub_concepto is null) or
       (oun.cod_sub_concepto is not null and ico.cod_sub_concepto = oun.cod_sub_concepto ))
  and gru.cod_usu_encargado = u.cod_usuario
  and oun.cod_periodo(+) = p.cod_periodo
  and u.categoria not in ('SC','GC')
  and u.estado = 'A'
  union all
  select gru.cod_gru_oficina cod_gru_oficina,
       oun.cod_oficial,
       oun.cod_concepto ,
       oun.cod_sub_concepto,
       p.cod_periodo cod_periodo,
       oun.por_meta,
       oun.mto_meta,
       oun.logro,
       ico.tip_meta
  from ig_parametros p,
       rh_empleados rh,
       ba_usuarios u,
       ig_par_conceptos ico,
       ba_gru_oficinas gru,
       ba_oficinas ofi,
       ig_uni_negocios uni,
       ig_ofi_metas oun
  where u.cod_persona = rh.cod_persona
  and oun.cod_periodo = ico.cod_periodo
  and oun.cod_concepto = ico.cod_concepto
  and uni.cod_unidad = oun.cod_unidad
  and uni.cod_banca is not null
  and u.cod_usuario = oun.cod_oficial
  and u.cod_oficina = ofi.cod_oficina
  and ofi.cod_gru_oficina = gru.cod_gru_oficina
  and ((oun.cod_sub_concepto is null and ico.cod_sub_concepto is null) or
       (oun.cod_sub_concepto is not null and ico.cod_sub_concepto = oun.cod_sub_concepto ))
  and oun.cod_periodo = p.cod_periodo
  and u.categoria not in ('SC','GC')
  and u.estado = 'A'
)
group by cod_gru_oficina, cod_concepto, cod_sub_concepto, cod_periodo, tip_meta;

