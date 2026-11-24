create or replace force view it.gv_per_fatca as
select /*+ index(p PK_BA_PERSONAS) index(g PK_GE_CLIENTES)  index(f PK_BA_PER_FATCA)+*/
       p.cod_persona cod_persona,
       p.nom_completo nom_persona,
       p.tipo tip_persona,
       p.nro_documento nro_documento,
       g.cod_gru_economico cod_gru_economico,
       u.descripcion gru_economico,
       g.cod_usu_oficial cod_usu_oficial,
       fue_obt_nom_usuario(g.cod_usu_oficial) nom_usu_oficial,
       g.usu_insercion cod_usu_alt_cliente,
       fue_obt_nom_usuario(g.usu_insercion) nom_usu_alt_cliente,
       g.fec_insercion fec_alt_cliente,
       nvl(f.fec_ult_act_estado, f.fec_modificacion) fec_ult_act_est_fatca,
       fug_obt_relacion(p.cod_persona) relacion,
       fue_obt_des_refcodes('CAT_EST_DOCUMENTO',fug_obt_est_doc_catastro(p.cod_persona)) est_catastro,
       f.est_anterior est_ant_fatca,
       an.descripcion des_est_ant_fatca,
       f.estado est_act_fatca,
       ac.descripcion des_est_act_fatca,
       f.tip_indicio tip_indicio,
       f.observacion det_indicio,
       t.tip_ind_actual tip_ind_actual,
       t.det_ind_actual det_ind_actual,
       f.nro_identificador nro_identificador,
       f.fec_caducidad fec_caducidad,
       f.fec_vencimiento fec_vto_est_fatca,
       t.sal_agr_julio sal_agr_julio,
       t.sal_agregado sal_agregado,
       t.sal_agr_tarjeta sal_agr_tarjeta,
       t.sal_agr_tar_julio sal_agr_tar_julio,
       t.fec_sal_agregado
  from ba_personas p, ge_clientes g, ba_per_fatca f, ge_per_fatca_tmp t, ge_est_fatca an, ge_est_fatca ac,
       ge_gru_economicos u
 where p.cod_persona = g.cod_persona
   and p.cod_persona = f.cod_persona (+)
   and p.cod_persona = t.cod_persona
   and f.estado= ac.est_fatca(+)
   and f.est_anterior = an.est_fatca(+)
   and g.cod_gru_economico = u.cod_gru_economico(+);

