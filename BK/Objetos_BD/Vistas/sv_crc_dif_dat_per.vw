CREATE OR REPLACE FORCE VIEW IT.SV_CRC_DIF_DAT_PER AS
SELECT a.cod_persona,
       SUM(a.tot_prevision) tot_prevision,
       SUM(b.tot_prevision) tot_prevision_res37,
       (SUM(a.tot_prevision) - SUM(b.tot_prevision)) dif_prevision,
       SUM(a.tot_deu_real) tot_deuda,
       SUM(b.tot_deu_real) tot_deu_res37,
       (SUM(a.tot_deu_real) - SUM(b.tot_deu_real)) dif_deu_real,
       SUM(a.tot_deu_contingente) tot_deu_contingente,
       SUM(b.tot_deu_contingente) tot_deu_contingente_res37,
       (SUM(a.tot_deu_contingente) - SUM(b.tot_deu_contingente)) dif_deu_contingente,
       SUM(a.tot_gar_computables) tot_gar_computables,
       SUM(b.tot_gar_computables) tot_gar_computables_res37,
       (SUM(a.tot_gar_computables) - SUM(b.tot_gar_computables)) dif_tot_gar_computables,
       SUM(a.tot_cap_pri_prevision) tot_cap_pri_prevision,
       SUM(b.tot_cap_pri_prevision) tot_cap_pri_prevision_res37,
       (SUM(a.tot_cap_pri_prevision) - SUM(b.tot_cap_pri_prevision)) dif_tot_cap_pri_prevision,
       SUM(a.tot_int_pri_prevision) tot_int_pri_prevision,
       SUM(b.tot_int_pri_prevision) tot_int_pri_prevision_res37,
       (SUM(a.tot_int_pri_prevision) - SUM(b.tot_int_pri_prevision)) dif_tot_int_pri_prevision,
       SUM(a.tot_cap_seg_prevision) tot_cap_seg_prevision,
       SUM(b.tot_cap_seg_prevision) tot_cap_seg_prevision_res37,
       (SUM(a.tot_cap_seg_prevision) - SUM(b.tot_cap_seg_prevision)) dif_tot_cap_seg_prevision,
       SUM(a.tot_int_seg_prevision) tot_int_seg_prevision,
       SUM(b.tot_int_seg_prevision) tot_int_seg_prevision_res37,
       (SUM(a.tot_int_seg_prevision) - SUM(b.tot_int_seg_prevision)) dif_tot_int_seg_prevision
  FROM gv_cla_operaciones a, ge_cla_operaciones b
 WHERE a.cod_persona = b.cod_persona (+)
   AND a.nro_cuenta = b.nro_cuenta(+)
 GROUP BY a.cod_persona;

