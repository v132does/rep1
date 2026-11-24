create or replace force view it.simgia_auxlistdatg as
select
nvl(fup_obt_categoria(gc.cat_automatica,gc.cat_subjetiva),1) as ALCATEG,
decode(gc.tipo, 'R', 1, 'M', 1, 'G', 1, 'N', 2, 'C', 2, 'P', 3, 'T', 4, 'V', 5,0) as ALCLASE,
gc.cod_persona as ALRIESGO,
gc.cod_oficina as ALSUCURSAL,
pai_int.FU_SIM_NORM_CADENA(nvl(bp.nom_completo,''),40) as ALTITULAR,
nvl(sum(nvl(gco.tot_deu_real,0)),0) ALRIETOT,
nvl(sum(nvl(gco.tot_gar_computables,0)),0) ALCUBIERTO,
0 ALINDICUB,
to_char(pag_cal.fu_obt_fec_actual(1) - max(gco.dia_atraso), 'YYYYMMDD') ALVMINIMO,
nvl(sum(nvl(gco.tot_prevision,0)),0) ALPREVI,
nvl((select sum(nvl(a.tot_deu_real,0)) from ge_cla_operaciones_his a where a.fecha = gco.fecha and a.cod_persona = gc.cod_persona and a.cod_modalidad = 41),0) ALSOBREGI,
--sum(PAP_CAT.FU_CON_A_GUARANIES(gco.cod_moneda, gco.tot_deu_contingente)) ALCONTING,
nvl(sum(nvl(gco.tot_deu_contingente,0)),0) ALCONTING,
nvl((select sum(nvl(a.tot_deu_real,0)) from ge_cla_operaciones_his a where a.fecha = gco.fecha and a.cod_persona = gc.cod_persona and (a.cod_modalidad = 41 or a.cod_estado in ('M','G','B')) and a.dia_atraso > 60),0) ALGESTION,
nvl((select sum(nvl(b.sal_interes,0)) + sum(nvl(b.sal_int_adelantado,0)) from pr_cta_prestamos b, ge_cta_clientes c where b.nro_cuenta = c.nro_cuenta and c.relacion = 'P' and c.cod_persona = gc.cod_persona),0) ALINTERES,
nvl((select sum(nvl(b.val_int_devengar,0)) from pr_cta_prestamos b, ge_cta_clientes c where b.nro_cuenta = c.nro_cuenta and c.relacion = 'P' and c.cod_persona = gc.cod_persona),0) ALADEV,
nvl((select sum(nvl(a.tot_deu_real,0)) from ge_cla_operaciones_his a where a.fecha = gco.fecha and a.cod_persona = gc.cod_persona and (a.cod_modalidad = 41 or a.cod_estado in ('M','G','B')) and a.dia_atraso > 0),0)  ALVENCICO
,gco.fecha
from ge_cla_operaciones_his gco, ge_clientes gc,  ba_personas bp
where gc.cod_persona = bp.cod_persona
and gco.cod_persona = gc.cod_persona
and gco.fecha = (select max(h.fecha) from ge_cla_operaciones_his h where h.cod_persona = gco.cod_persona)
--and gco.fecha < to_date('01/12/2010','DD/MM/YYYY')
group by gc.tipo, gc.cod_persona, gc.cod_oficina, bp.nom_completo, gco.fecha, gc.cat_automatica, gc.cat_subjetiva
;

