create or replace force view it.bv_deu_cli_historico_crc as
select a.fecha fecha_cierre,
       b.cod_persona cod_persona,
       bt.abreviatura  as cod_tip_documentos,
       bp.nro_documento as nro_documento,
       fue_obt_nom_persona(b.cod_persona) nombre_apellido,
       nvl(b.cat_sistema,1) cat_sist,
       decode(cla_rie_entidad, '1.1', '1A', '1.2', '1B', cla_rie_entidad)  cat_crc,
       to_char(a.tot_tc,'999G999G999G999') as r_directo_bbva,
       to_char(b.tot_deu_sistema,'999G999G999G999') as r_directo_sistema,
       to_char(a.tot_er,'999G999G999G999') as contig_bbva,
       to_char(b.tot_deu_con_sistema,'999G999G999G999') as contig_sistema,
       to_char(nvl(a.tot_tc, 0) + nvl(b.tot_deu_sistema, 0) +
       nvl(a.tot_er, 0) + nvl(b.tot_deu_con_sistema, 0),'999G999G999G999') as riesgo_directo_total,
       trunc(((nvl(b.tot_deu_real, 0) + nvl(b.tot_deu_contingente, 0)) /
       decode(nvl(b.tot_deu_real, 0) + nvl(b.tot_deu_sistema, 0) +
       nvl(b.tot_deu_contingente, 0) + nvl(b.tot_deu_con_sistema, 0),0,1,
       (nvl(b.tot_deu_real, 0) + nvl(b.tot_deu_sistema, 0) +
       nvl(b.tot_deu_contingente, 0) + nvl(b.tot_deu_con_sistema, 0)))) * 100)||'%'   PARTICIPACION_BBVA,
       to_char(nvl(a.tot_sr, 0),'999G999G999G999') as code_bbva,
       to_char(nvl(b.tot_deu_cod_sistema, 0),'999G999G999G999') as code_sistema,
       to_char((nvl(a.tot_tc, 0) + nvl(b.tot_deu_sistema, 0) +
       nvl(a.tot_er, 0) + nvl(b.tot_deu_con_sistema, 0) +
       nvl(a.tot_sr, 0) + nvl(b.tot_deu_cod_sistema, 0)),'999G999G999G999') as riesgo_total
  from sb_personas_crc_det a, ge_clientes_his b, ba_cod_referencias r, ba_personas bp, ba_tip_documentos bt
 where a.cod_persona = b.cod_persona
   and bp.cod_persona = a.cod_persona
   and bp.cod_tip_documento = bt.cod_tip_documento
   and r.dominio = 'CAT_RIESGO'
   and b.cat_riesgo = r.val_minimo
   and to_char(a.fecha, 'mmyyyy') = to_char(b.fec_ult_cla_sistema, 'mmyyyy')
   and b.fecha =  ( select min(bb.fecha)
                from sb_personas_crc_det aa,
                     ge_clientes_his     bb
               where aa.cod_persona = bb.cod_persona
                 and to_char(aa.fecha, 'mmyyyy') = to_char(bb.fec_ult_cla_sistema, 'mmyyyy')
                 and aa.fecha = a.fecha
                 and aa.cod_persona = a.cod_persona )
    order by 1;

