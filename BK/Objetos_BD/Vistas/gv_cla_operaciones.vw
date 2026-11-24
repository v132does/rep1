CREATE OR REPLACE FORCE VIEW IT.GV_CLA_OPERACIONES AS
SELECT a.cod_persona cod_persona,
       a.cod_modalidad cod_modalidad,
       a.cod_modulo,
       a.nro_cuenta,
       a.cod_estado,
       nvl(a.dev_no_cobrado,0) dev_no_cobrado,
       nvl(a.tot_prevision,0) tot_prevision ,
       nvl(a.tot_deu_real,0) tot_deu_real,
       nvl(a.tot_deu_real,0) + nvl(a.tot_deu_contingente,0) tot_deu_total,
       nvl(a.tot_deu_contingente,0) tot_deu_contingente,
       nvl(a.tot_gar_computables,0) tot_gar_computables,
       nvl(a.tot_cap_pri_prevision,0) tot_cap_pri_prevision,
       nvl(a.tot_int_pri_prevision,0) tot_int_pri_prevision,
       nvl(a.tot_cap_seg_prevision,0) tot_cap_seg_prevision,
       nvl(a.tot_int_seg_prevision,0) tot_int_seg_prevision,
       'N' incobrable
  FROM ge_cla_operaciones a
 WHERE NOT EXISTS (SELECT 1
          FROM ge_par_dinamicos s
         WHERE s.parametro = 'SIB_CRC_MAD_EXC_ARCHIVO'
           AND s.cod_modalidad = a.cod_modalidad
           AND nvl(s.val_parametro, 'N') = 'S')
    AND ((a.cod_modulo=5 and ((a.cod_estado='B' AND (nvl(a.tot_deu_real,0) + nvl(a.tot_deu_contingente,0))<>0) or (a.cod_estado<>'B')))
         or (a.cod_modulo = 10 and fug_obt_pardinamico('SIB_CRC_MAD_BON_CLASIFICA', a.cod_modulo, a.cod_modalidad) = 'S')
         or a.cod_modulo not in (5,10))
UNION ALL
SELECT c.cod_persona cod_persona,
       b.cod_modalidad cod_modalidad,
       b.cod_modulo,
       b.nro_cuenta,
       b.estado,
       nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, pag_gen.fu_obt_mon_local,nvl(b.dev_no_cobrado,0),
                                               NULL), 0) dev_no_cobrado,
       0 tot_prevision,
       nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, pag_gen.fu_obt_mon_local, nvl(b.sal_cap_batch, 0)  + nvl(b.sal_int_batch, 0) + nvl(b.sal_int_ade_batch, 0) +
                                                                               nvl(b.val_int_devengar, 0) + nvl(b.dev_no_cobrado, 0), NULL), 0) tot_deu_real,
       nvl(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, pag_gen.fu_obt_mon_local, nvl(b.sal_cap_batch, 0)  + nvl(b.sal_int_batch, 0) + nvl(b.sal_int_ade_batch, 0) +
                                                                               nvl(b.val_int_devengar, 0) + nvl(b.dev_no_cobrado, 0), NULL), 0) tot_deu_total,
       0 tot_deu_contingente,
       0 tot_gar_computables,
       0 tot_cap_pri_prevision,
       0 tot_int_pri_prevision,
       0 tot_cap_seg_prevision,
       0 tot_int_seg_prevision,
       'S'
  FROM pr_cta_prestamos b, ge_cta_clientes c
 WHERE b.nro_cuenta = c.nro_cuenta
   AND c.relacion = 'P'
   AND ((b.est_batch = 'I' AND
       (SELECT TRUNC((months_between((SELECT ult_dia_mes FROM ge_calendarios WHERE cod_modulo = 6),
                                 n.fecha) / 12))
            FROM ge_cuentas_nov n
           WHERE n.nro_cuenta = b.nro_cuenta
             AND n.est_actual = 'I'
             AND n.fecha = (SELECT MIN(c.fecha)
                              FROM ge_cuentas_nov c
                             WHERE c.nro_cuenta = b.nro_cuenta
                               AND c.est_actual = 'I')) <= (SELECT /*+ RULE */ val_parametro
                                                              FROM ge_par_dinamicos
                                                             WHERE parametro = 'CAN_ANO_CRC_INCOBRABLES')))
UNION ALL
SELECT e.cod_persona cod_persona,
       d.cod_modalidad cod_modalidad,
       d.cod_modulo,
       d.nro_cuenta,
       d.estado,
       0 dev_no_cobrado,
       0 tot_prevision,
       nvl(pag_gen.fu_con_mon_a_moneda(d.cod_moneda, pag_gen.fu_obt_mon_local,nvl(d.sal_total,0),
                                               NULL), 0) tot_deu_real,
       nvl(pag_gen.fu_con_mon_a_moneda(d.cod_moneda, pag_gen.fu_obt_mon_local,nvl(d.sal_total,0),
                                               NULL), 0) tot_deu_total,
       0 tot_deu_contingente,
       0 tot_gar_computables,
       0 tot_cap_pri_prevision,
       0 tot_int_pri_prevision,
       0 tot_cap_seg_prevision,
       0 tot_int_seg_prevision,
       'S'
  FROM ov_cta_vencidas d, ge_cta_clientes e
 WHERE d.nro_cuenta = e.nro_cuenta
   AND e.relacion = 'P'
   AND ((d.est_batch = 'I' AND
       (SELECT TRUNC((months_between((SELECT ult_dia_mes FROM ge_calendarios WHERE cod_modulo = 15),
                                 n.fecha) / 12))
            FROM ge_cuentas_nov n
           WHERE n.nro_cuenta = d.nro_cuenta
             AND n.est_actual = 'I'
             AND n.fecha = (SELECT MIN(c.fecha)
                              FROM ge_cuentas_nov c
                             WHERE c.nro_cuenta = d.nro_cuenta
                               AND c.est_actual = 'I')) <= (select /*+ RULE */ val_parametro
                                                              from ge_par_dinamicos
                                                             where parametro = 'CAN_ANO_CRC_INCOBRABLES')))
UNION ALL
SELECT ba.cod_persona cod_persona,
       a.cod_modalidad cod_modalidad,
       a.cod_modulo,
       a.nro_cuenta,
       a.estado,
       0 dev_no_cobrado,
       0 tot_prevision,
       abs(nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, pag_gen.fu_obt_mon_local, nvl(a.sal_tot_batch, 0)  - nvl(a.sal_ret_batch, 0) - nvl(a.sal_blo_batch, 0),
                                               NULL), 0)) tot_deu_real,
       abs(nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, pag_gen.fu_obt_mon_local, nvl(a.sal_tot_batch, 0)  + nvl(a.sal_ret_batch, 0) + nvl(a.sal_blo_batch, 0),
                                               NULL), 0)) tot_deu_total,
       0 tot_deu_contingente,
       0 tot_gar_computables,
       0 tot_cap_pri_prevision,
       0 tot_int_pri_prevision,
       0 tot_cap_seg_prevision,
       0 tot_int_seg_prevision,
       'N'
 FROM cc_cta_bancarias a, ge_cta_clientes ba, ge_est_cuentas d
    WHERE ba.nro_cuenta=a.nro_cuenta
    AND ba.relacion='P'
    AND d.cod_modulo = a.cod_modulo
    AND d.cod_modalidad = a.cod_modalidad
    AND d.estado = a.estado
    AND nvl(a.sal_tot_batch, 0) - nvl(a.sal_ret_batch, 0) - nvl(a.sal_blo_batch, 0) < 0
    AND ba.cod_persona <> 0
    AND d.activo = 'S'
    and ba.cod_persona<>fug_obt_per_entidad
ORDER BY COD_PERSONA;

