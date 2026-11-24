CREATE OR REPLACE FORCE VIEW IT.SV_CRC_PER_CLASIFICACIONES AS
SELECT a.fecha,
       a.cod_persona,
       a.tot_tr tot_tr_per,
       b.tot_tr tot_tr_cla,
       (a.tot_tr - b.tot_tr) dif_tr,
       a.tot_dr tot_dr_per,
       b.tot_dr tot_dr_cla,
       (a.tot_dr - b.tot_dr) dif_dr,
       a.tot_er tot_er_per,
       b.tot_er tot_er_cla,
       (a.tot_er - b.tot_er) dif_er,
       a.tot_sr tot_sr_per,
       b.tot_sr tot_sr_cla,
       (a.tot_sr - b.tot_sr) dif_sr,
       a.tot_tc tot_tc_per,
       b.tot_tc tot_tc_cla,
       (a.tot_tc - b.tot_tc) dif_tc,
       a.tot_dc tot_dc_per,
       b.tot_dc tot_dc_cla,
       (a.tot_dc - b.tot_dc) dif_dc
  FROM sb_personas_crc_det a, sb_crc_clasificaciones_det b
 WHERE a.cod_persona = b.cod_persona
   AND a.fecha = b.fecha
   AND (a.tot_tr <> b.tot_tr
    OR a.tot_dr <> b.tot_dr
    OR a.tot_er <> b.tot_er
    OR a.tot_sr <> b.tot_sr
    OR a.tot_tc <> b.tot_tc
    OR a.tot_dc <> b.tot_dc);

