create or replace force view it.bv_sal_con_comex_his as
select a.fecha,
       s.cod_pais,s.descripcion nom_pais,decode(o.ind_grupo,'S','N','S') grupo,
       substr(a.cod_rubro,1,2)||'.'||substr(a.cod_rubro,3,1)||'.'||substr(a.cod_rubro,4,2)||'.'||substr(a.cod_rubro,6,3)||'.'||
       substr(a.cod_rubro,3,1)||'.'||substr(a.cod_rubro,9,2)||'.'||substr(a.cod_rubro,11,3)||'.'||substr(a.cod_rubro,14,2) rubro_contable,
       b.descripcion nombre_rubro, a.cod_oficina ofi,
       decode(a.cod_modalidad,33,'CDA',34,'TIF') tipo,
       decode(tip_saldo,'C','Capital','I','Interes','A','A Devengar','S','Saldo',tip_saldo) tipo_saldo,
       decode(cod_sec_contable,'F','Financiero','P','Publico','I','Fin/Publico','N','No Financ.') sector,
       cod_tip_deudor deudor,residente res,situacion sit,e.cod_persona, fue_obt_nom_persona(e.cod_persona) nom_persona,
       d.nro_cuenta cuenta,g.denominacion,g.fec_apertura,g.fec_vencimiento, comex.fec_vto_plazo, a.cod_moneda mon,
       d.sal_actual sal_contable,d.sal_anterior sal_anterior
  from ge_cuentas g, cb_sal_inventarios_det_his d, cb_rubros b, cb_sal_inventarios_his a, ge_cta_clientes e,
      (select i.nro_cuenta, i.cod_bco_negociador, i.fec_vto_plazo from cx_cta_importaciones i
       union all select x.nro_cuenta, x.cod_bco_emisor, null fec_vto_plazo from cx_cta_exportaciones x where x.confirmado = 'S'
       union all select f.nro_cuenta, f.cod_banco, null fec_vto_plazo from cx_fianzas f where f.cod_banco is not null) comex, ge_bancos o, ba_personas p, ba_paises s
 where sal_total > 0
   and (d.sal_actual <> 0 or d.sal_anterior <> 0)
   and a.cod_rubro = b.cod_rubro(+)
   and d.nro_referencia = a.nro_referencia
   and d.nro_cuenta = g.nro_cuenta
   and e.nro_cuenta = g.nro_cuenta
   and e.relacion = 'P'
   and comex.nro_cuenta = g.nro_cuenta
   and comex.cod_bco_negociador = o.cod_banco
   and o.cod_persona = p.cod_persona
   and p.cod_pais = s.cod_pais
   and d.fecha = a.fecha
 union all
select a.fecha,
       s.cod_pais,s.descripcion nom_pais,'S' grupo,
       substr(a.cod_rubro,1,2)||'.'||substr(a.cod_rubro,3,1)||'.'||substr(a.cod_rubro,4,2)||'.'||substr(a.cod_rubro,6,3)||'.'||
       substr(a.cod_rubro,3,1)||'.'||substr(a.cod_rubro,9,2)||'.'||substr(a.cod_rubro,11,3)||'.'||substr(a.cod_rubro,14,2) rubro_contable,
       b.descripcion nombre_rubro, a.cod_oficina ofi,
       decode(a.cod_modalidad,33,'CDA',34,'TIF') tipo,
       decode(tip_saldo,'C','Capital','I','Interes','A','A Devengar','S','Saldo',tip_saldo) tipo_saldo,
       decode(cod_sec_contable,'F','Financiero','P','Publico','I','Fin/Publico','N','No Financ.') sector,
       cod_tip_deudor deudor,residente res,situacion sit,e.cod_persona, fue_obt_nom_persona(e.cod_persona) nom_persona,
       d.nro_cuenta cuenta,g.denominacion,g.fec_apertura,g.fec_vencimiento, null fec_vto_plazo, a.cod_moneda mon,
       d.sal_actual sal_contable,d.sal_anterior sal_anterior
  from ge_cuentas g, cb_sal_inventarios_det_his d, cb_rubros b, cb_sal_inventarios_his a, ge_cta_clientes e, cx_fianzas comex, ba_personas p, ba_paises s
 where sal_total > 0
   and (d.sal_actual <> 0 or d.sal_anterior <> 0)
   and a.cod_rubro = b.cod_rubro(+)
   and d.nro_referencia = a.nro_referencia
   and d.nro_cuenta = g.nro_cuenta
   and e.nro_cuenta = g.nro_cuenta
   and e.relacion = 'P'
   and comex.nro_cuenta = g.nro_cuenta
   and comex.cod_per_solicitante = p.cod_persona
   and p.cod_pais = s.cod_pais
   and d.fecha = a.fecha
   and comex.cod_banco is null;

