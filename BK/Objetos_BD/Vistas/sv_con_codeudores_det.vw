CREATE OR REPLACE FORCE VIEW IT.SV_CON_CODEUDORES_DET AS
SELECT cod_persona, p.nro_cuenta, relacion, p.nro_cuenta nro_operacion,
       nvl(pag_gen.fu_con_mon_a_moneda(p.cod_moneda, pag_gen.fu_obt_mon_local,
                                           decode (p.estado,'I',(nvl(p.sal_cap_batch, 0)  + nvl(p.sal_int_batch, 0) + nvl(p.sal_int_ade_batch, 0)), (nvl(sal_cap_batch, 0))), NULL), 0) sal_capital,
       nvl(pag_gen.fu_con_mon_a_moneda(p.cod_moneda, pag_gen.fu_obt_mon_local,
                                           decode (p.estado,'I',0, nvl(dev_no_cobrado, 0)), NULL), 0) dev_no_cobrado,
       'N' afe_cheque, null fec_vencimiento
  FROM pr_cta_prestamos p, ge_cta_clientes b
 WHERE p.nro_cuenta = b.nro_cuenta
   AND relacion <> 'P'
   AND p.cod_modulo = 6
   AND (p.est_batch not IN ('N','I') or (p.est_batch = 'I' AND
       (SELECT TRUNC((months_between((SELECT ult_dia_mes FROM ge_calendarios WHERE cod_modulo = 15),
                                 n.fecha) / 12))
            FROM ge_cuentas_nov n
           WHERE n.nro_cuenta = p.nro_cuenta
             AND n.est_actual = 'I'
             AND n.fecha = (SELECT MIN(c.fecha)
                              FROM ge_cuentas_nov c
                             WHERE c.nro_cuenta = p.nro_cuenta
                               AND c.est_actual = 'I')) <= (select /*+ RULE */ val_parametro
                                                              from ge_par_dinamicos
                                                             where parametro = 'CAN_ANO_CRC_INCOBRABLES')))
UNION ALL
SELECT cod_persona, p.nro_cuenta, relacion, p.nro_cuenta nro_operacion,
       nvl(pag_gen.fu_con_mon_a_moneda(p.cod_moneda, pag_gen.fu_obt_mon_local,
                                           nvl(sal_facturar, 0) + nvl(sal_facturado, 0) +
                                            nvl(sal_financiado, 0) + nvl(sal_cuo_pendientes, 0), NULL),
           0) sal_capital, 0 dev_no_cobrado,
       'N' afe_cheque, null  fec_vencimiento
  FROM ta_cta_tarjetas p, ge_cta_clientes b
 WHERE p.nro_cuenta = b.nro_cuenta
   AND relacion NOT IN ('P','A')
   AND p.cod_modulo = 5
   AND p.estado <> 'C'
UNION ALL
SELECT b.cod_persona, p.nro_cuenta, b.relacion, p.nro_cuenta nro_operacion,
       nvl(pag_gen.fu_con_mon_a_moneda(p.cod_moneda, pag_gen.fu_obt_mon_local,
                                           abs(nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) -
                                            nvl(sal_blo_batch, 0)), NULL), 0) sal_capital,
       0 dev_no_cobrado,'N' afe_cheque, null fec_vencimiento
  FROM cc_cta_corrientes p, ge_cta_clientes b, ge_cta_clientes d, ba_personas c
 WHERE p.nro_cuenta = b.nro_cuenta
   AND p.nro_cuenta = d.nro_cuenta
   AND d.relacion = 'P'
   AND c.cod_persona = d.cod_persona
   AND c.tipo = 'F'
   AND b.relacion <> 'P'
   AND p.cod_modulo = 4
   AND nvl(sal_tot_batch, 0) - nvl(sal_ret_batch, 0) - nvl(sal_blo_batch, 0) < 0
   AND p.est_batch <> 'C'
   AND fug_obt_pardinamico('CRC_FIR_SOBREGIROS')='S'
UNION ALL
SELECT b.cod_persona, p.nro_cuenta, relacion, p.nro_cuenta nro_operacion,
       nvl(pag_gen.fu_con_mon_a_moneda(p.cod_moneda, pag_gen.fu_obt_mon_local,
                                           nvl(sal_capital, 0) + nvl(sal_interes, 0), NULL), 0) sal_capital,
       0 dev_no_cobrado,'N' afe_cheque, null fec_vencimiento
  FROM md_cta_documentos p, ge_cta_clientes b
 WHERE p.nro_cuenta = b.nro_cuenta
   AND relacion <> 'P'
   AND p.cod_modulo = 10
   AND p.estado <> 'N'
UNION ALL
SELECT b.cod_persona, p.nro_cuenta, b.relacion, p.nro_cuenta nro_operacion,
       nvl(pag_gen.fu_con_mon_a_moneda(p.cod_moneda, pag_gen.fu_obt_mon_local,
                                           nvl(sal_tot_batch, 0), NULL), 0) sal_capital,
       0 dev_no_cobrado,'N' afe_cheque, null fec_vencimiento
  FROM ov_cta_vencidas p, ge_cta_clientes b, ge_cta_clientes d, ba_personas c
 WHERE p.nro_cuenta = b.nro_cuenta
   AND p.nro_cuenta = d.nro_cuenta
   AND d.relacion = 'P'
   AND c.cod_persona = d.cod_persona
   AND c.tipo = 'F'
   AND b.relacion <> 'P'
   AND p.cod_modulo = 15
   AND (p.estado not in ('C','I') or (p.estado  = 'I' AND
       (SELECT TRUNC((months_between((SELECT ult_dia_mes FROM ge_calendarios WHERE cod_modulo = 15),
                                 n.fecha) / 12))
            FROM ge_cuentas_nov n
           WHERE n.nro_cuenta = p.nro_cuenta
             AND n.est_actual = 'I'
             AND n.fecha = (SELECT MIN(c.fecha)
                              FROM ge_cuentas_nov c
                             WHERE c.nro_cuenta = p.nro_cuenta
                               AND c.est_actual = 'I')) <= (select /*+ RULE */ val_parametro
                                                              from ge_par_dinamicos
                                                             where parametro = 'CAN_ANO_CRC_INCOBRABLES')))
   AND (p.cod_modalidad=152 AND fug_obt_pardinamico('CRC_FIR_SOBREGIROS')='S' OR p.cod_modalidad=151)
 UNION ALL
 ---libradores de cheques
SELECT z.cod_persona, pr.nro_cuenta, 'L', p.nro_cuenta||'#'||p.nro_cuota||'#'||t.nro_cheque nro_operacion,
       nvl((pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,
       nvl(/*t.monto*/p.sal_capital, 0), NULL)), 0) sal_capital,--Debe ser reportado la deuda a la fecha no el total del cheque.-
       nvl((pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,
       nvl(p.dev_no_cobrado, 0), NULL)), 0) dev_no_cobrado,
       'S' afe_cheque, p.fec_vencimiento fec_vencimiento
 FROM ge_che_custodias   t,
      pr_rel_chq_lib     x,
      pr_chq_libradores  y,
      ba_personas        z,
      pr_cta_prestamos   pr,
      pr_cuotas          p
WHERE x.cod_banco = t.cod_banco
  AND x.nro_cheque = t.nro_cheque
  AND x.cta_libradora = t.cta_libradora
  AND t.estado in ('C','A','B') -- a = en compensación / b = devuelto / c = custodio --INCLUIR LOS DEVUELTOS.-
  AND y.nro_documento = x.nro_documento
  AND y.cod_tip_documento = x.cod_tip_documento
  AND z.nro_documento = x.nro_documento
  AND z.cod_tip_documento = x.cod_tip_documento
  AND t.nro_referencia = pr.nro_cuenta
  AND p.estado <> 'N'
  AND (pr.est_batch not in ('N','I') or (pr.est_batch = 'I' AND
       (SELECT TRUNC((months_between((SELECT ult_dia_mes FROM ge_calendarios WHERE cod_modulo = 15),
                                 n.fecha) / 12))
            FROM ge_cuentas_nov n
           WHERE n.nro_cuenta = pr.nro_cuenta
             AND n.est_actual = 'I'
             AND n.fecha = (SELECT MIN(c.fecha)
                              FROM ge_cuentas_nov c
                             WHERE c.nro_cuenta = pr.nro_cuenta
                               AND c.est_actual = 'I')) <= (select /*+ RULE */ val_parametro
                                                              from ge_par_dinamicos
                                                             where parametro = 'CAN_ANO_CRC_INCOBRABLES')))
  AND t.nro_cuota = p.nro_cuota
  AND p.nro_cuenta = pr.nro_cuenta
  AND fug_obt_pardinamico('SIB_CRC_INC_CLA_EMISORES') = 'S'
UNION ALL
SELECT cod_persona, pr.nro_cuenta, 'L', decode(pr.cod_modalidad, 613, c.nro_cuenta, c.nro_cuenta||'#'||d.nro_cuota||'#'||d.nro_documento) nro_operacion,
       nvl((pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,
       nvl(c.sal_capital, 0), NULL)), 0) sal_capital,--Debe ser reportado la deuda a la fecha no el total del documento.-
       nvl((pag_gen.fu_con_mon_a_moneda(pr.cod_moneda, pag_gen.fu_obt_mon_local,
       nvl(c.dev_no_cobrado, 0), NULL)), 0) dev_no_cobrado,
       decode(pr.cod_modalidad, 613, 'N', 'S'), c.fec_vencimiento fec_vencimiento
 FROM pr_documentos d, ba_personas p, pr_cta_prestamos pr, pr_cuotas c
WHERE d.estado = 'C'
  AND p.cod_tip_documento = d.cod_tip_documento
  AND p.nro_documento  = d.nro_documento
  AND d.nro_referencia = pr.nro_cuenta
  AND pr.est_batch <> 'N'
  AND c.estado<>'N'
  AND fug_obt_pardinamico('SIB_CRC_INC_CLA_EMISORES') = 'S'
  AND c.nro_cuota = d.nro_cuota
  AND pr.nro_cuenta = c.nro_cuenta
  AND (pr.est_batch not in ('N','I') or (pr.est_batch = 'I' AND
       (SELECT TRUNC((months_between((SELECT ult_dia_mes FROM ge_calendarios WHERE cod_modulo = 15),
                                 n.fecha) / 12))
            FROM ge_cuentas_nov n
           WHERE n.nro_cuenta = pr.nro_cuenta
             AND n.est_actual = 'I'
             AND n.fecha = (SELECT MIN(c.fecha)
                              FROM ge_cuentas_nov c
                             WHERE c.nro_cuenta = pr.nro_cuenta
                               AND c.est_actual = 'I')) <= (select /*+ RULE */ val_parametro
                                                              from ge_par_dinamicos
                                                             where parametro = 'CAN_ANO_CRC_INCOBRABLES')))
;

