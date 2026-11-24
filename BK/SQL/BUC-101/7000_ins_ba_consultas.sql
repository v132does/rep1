Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
DECLARE
V_SQL long := 'SELECT w.cod_gru_economico cod_gru_economico,
       w.descripcion descripcion,
       p.nro_documento nro_documento,
       p.nom_completo nom_completo,
       ov.nro_cuenta nro_cuenta,
       ov.cod_moneda cod_moneda,
       c.cod_modulo cod_modulo,
       c.cod_modalidad cod_modalidad,
       0 interes,
       0 tot_deu_contingente,
       CASE ov.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          abs(nvl((ov.sal_total), 0))
         ELSE
          pag_gen.fu_con_mon_a_moneda(ov.cod_moneda,
                                      pag_gen.fu_obt_mon_local,
                                      abs(nvl((ov.sal_total), 0)))
       END AS saldo_capital,
       CASE ov.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          abs(nvl((ov.sal_total), 0))
         ELSE
          pag_gen.fu_con_mon_a_moneda(ov.cod_moneda,
                                      pag_gen.fu_obt_mon_local,
                                      abs(nvl((ov.sal_total), 0)))
       END AS tot_deu_real,
       nvl(CASE ov.cod_moneda
             WHEN pag_gen.fu_obt_mon_local THEN
              abs(nvl((ov.sal_total), 0))
             ELSE
              pag_gen.fu_con_mon_a_moneda(ov.cod_moneda,
                                          pag_gen.fu_obt_mon_local,
                                          abs(nvl((ov.sal_total), 0)))
           END,
           0) AS total_riesgo
  FROM ge_gru_economicos w,
       ge_clientes       e,
       ba_personas       p,
       ge_cta_clientes   c,
       ov_cta_vencidas   ov
 WHERE e.cod_gru_economico = w.cod_gru_economico
   AND p.cod_persona = e.cod_persona
   AND c.cod_persona = p.cod_persona
   AND c.relacion = ''P''
   AND ov.nro_cuenta = c.nro_cuenta
   AND &'||'P_FILTROS
UNION   
SELECT w.cod_gru_economico cod_gru_economico,
       descripcion,
       p.nro_documento nro_documento,
       p.nom_completo nom_completo,
       ta.nro_cuenta nro_cuenta,
       ta.cod_moneda cod_moneda,
       c.cod_modulo cod_modulo,
       c.cod_modalidad cod_modalidad,
       0 interes,
       CASE ta.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          CASE
            WHEN (nvl(ta.lin_credito, 0) -(nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0))) < 0 THEN
             0
            ELSE
             (nvl(ta.lin_credito, 0) -(nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0)))
          END
         ELSE
          pag_gen.fu_con_mon_a_moneda(ta.cod_moneda,pag_gen.fu_obt_mon_local,
                                      CASE
                                        WHEN (nvl(ta.lin_credito, 0) -(nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0))) < 0 THEN
                                         0
                                        ELSE
                                         (nvl(ta.lin_credito, 0) -(nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) + nvl(ta.sal_financiado, 0)))
                                      END)
       END AS tot_deu_contingente,
       CASE ta.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0)
         ELSE
          pag_gen.fu_con_mon_a_moneda(ta.cod_moneda,pag_gen.fu_obt_mon_local,nvl(ta.sal_facturar, 0) +nvl(ta.sal_facturado, 0) + nvl(ta.sal_financiado, 0) +nvl(ta.sal_cuo_pendientes, 0))
       END AS saldo_capital,
       CASE ta.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          (nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0))
         ELSE
          pag_gen.fu_con_mon_a_moneda(ta.cod_moneda,pag_gen.fu_obt_mon_local,(nvl(ta.sal_facturar, 0) +nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0)))
       END AS tot_deu_real,
      nvl(case ta.cod_moneda when pag_gen.FU_OBT_MON_LOCAL then
           case when (nvl(ta.LIN_CREDITO,0) - (nvl(ta.sal_facturar,0) + nvl(ta.sal_facturado,0)+ nvl(ta.sal_financiado,0)))<0
             then 0 else
            (nvl(ta.LIN_CREDITO,0) - (nvl(ta.sal_facturar,0) + nvl(ta.sal_facturado,0)+ nvl(ta.sal_financiado,0)))    
           end
       else
        pag_gen.FU_CON_MON_A_MONEDA(ta.cod_moneda, pag_gen.FU_OBT_MON_LOCAL, 
        case when (nvl(ta.LIN_CREDITO,0) - (nvl(ta.sal_facturar,0) + nvl(ta.sal_facturado,0)+ nvl(ta.sal_financiado,0)))<0
         then 0 else
           (nvl(ta.LIN_CREDITO,0) - (nvl(ta.sal_facturar,0) + nvl(ta.sal_facturado,0)+ nvl(ta.sal_financiado,0)))    
         end) end,0) +
        nvl(case ta.cod_moneda when pag_gen.FU_OBT_MON_LOCAL then 
         nvl(ta.sal_facturar,0) + nvl(ta.sal_facturado,0)+ nvl(ta.sal_financiado,0) + nvl(ta.sal_cuo_pendientes,0)
       else
        pag_gen.FU_CON_MON_A_MONEDA(ta.cod_moneda, pag_gen.FU_OBT_MON_LOCAL,   
         nvl(ta.sal_facturar,0) + nvl(ta.sal_facturado,0)+ nvl(ta.sal_financiado,0) + nvl(ta.sal_cuo_pendientes,0)) 
         end,0) total_riesgo
  FROM ge_gru_economicos w,
       ge_clientes       e,
       ba_personas       p,
       ge_cta_clientes   c,
       ta_cta_tarjetas   ta
 WHERE e.cod_gru_economico = w.cod_gru_economico
   AND p.cod_persona = e.cod_persona
   AND c.cod_persona = p.cod_persona
   AND c.relacion = ''P''
   AND ta.nro_cuenta = c.nro_cuenta
   AND &'||'P_FILTROS
UNION
SELECT w.cod_gru_economico,
       w.descripcion,
       p.nro_documento,
       p.nom_completo,
       pr.nro_cuenta,
       pr.cod_moneda,
       c.cod_modulo,
       c.cod_modalidad,
       CASE pr.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          nvl(pr.dev_no_cobrado, 0)
         ELSE
          pag_gen.fu_con_mon_a_moneda(pr.cod_moneda,
                                      pag_gen.fu_obt_mon_local,
                                      nvl(pr.dev_no_cobrado, 0))
       END AS interes,
       0 tot_deu_contingente,
       CASE pr.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          nvl(pr.sal_capital, 0)
         ELSE
          pag_gen.fu_con_mon_a_moneda(pr.cod_moneda,
                                      pag_gen.fu_obt_mon_local,
                                      nvl(pr.sal_capital, 0))
       END AS saldo_capital,
       CASE pr.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          nvl(pr.sal_capital, 0) + nvl(pr.dev_no_cobrado, 0)
         ELSE
          pag_gen.fu_con_mon_a_moneda(pr.cod_moneda,
                                      pag_gen.fu_obt_mon_local,
                                      nvl(pr.sal_capital, 0) +
                                      nvl(pr.dev_no_cobrado, 0))
       END AS tot_deu_real,
       nvl(CASE pr.cod_moneda
             WHEN pag_gen.fu_obt_mon_local THEN
              nvl(pr.sal_capital, 0)
             ELSE
              pag_gen.fu_con_mon_a_moneda(pr.cod_moneda,
                                          pag_gen.fu_obt_mon_local,
                                          nvl(pr.sal_capital, 0))
           END,
           0) + nvl(CASE pr.cod_moneda
                      WHEN pag_gen.fu_obt_mon_local THEN
                       nvl(pr.dev_no_cobrado, 0)
                      ELSE
                       pag_gen.fu_con_mon_a_moneda(pr.cod_moneda,
                                                   pag_gen.fu_obt_mon_local,
                                                   nvl(pr.dev_no_cobrado, 0))
                    END,
                    0) AS total_riesgo
  FROM ge_gru_economicos w,
       ge_clientes       e,
       ba_personas       p,
       ge_cta_clientes   c,
       pr_cta_prestamos  pr
 WHERE e.cod_gru_economico = w.cod_gru_economico
   AND p.cod_persona = e.cod_persona
   AND c.cod_persona = p.cod_persona
   AND c.relacion = ''P''
   AND pr.nro_cuenta = c.nro_cuenta
   AND &'||'P_FILTROS
UNION
SELECT w.cod_gru_economico,
       w.descripcion,
       p.nro_documento,
       p.nom_completo,
       cc.nro_cuenta,
       cc.cod_moneda,
       c.cod_modulo,
       c.cod_modalidad,
       0 interes,
       CASE cc.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          CASE
            WHEN nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) = 0 THEN
             0
            ELSE
             (nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) -
             ((cc.sal_total * -1)))
          END
         ELSE
          pag_gen.fu_con_mon_a_moneda(cc.cod_moneda,
                                      pag_gen.fu_obt_mon_local,
                                      CASE
                                        WHEN nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) = 0 THEN
                                         0
                                        ELSE
                                         (nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) -
                                         ((cc.sal_total * -1)))
                                      END)
       END AS tot_deu_contingente,
       CASE cc.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          abs(nvl((cc.sal_total), 0))
         ELSE
          pag_gen.fu_con_mon_a_moneda(cc.cod_moneda,
                                      pag_gen.fu_obt_mon_local,
                                      abs(nvl((cc.sal_total), 0)))
       END AS saldo_capital,
       CASE cc.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
          abs(nvl((cc.sal_total), 0))
         ELSE
          pag_gen.fu_con_mon_a_moneda(cc.cod_moneda,
                                      pag_gen.fu_obt_mon_local,
                                      abs(nvl((cc.sal_total), 0)))
       END AS tot_deu_real,
       nvl(CASE cc.cod_moneda
             WHEN pag_gen.fu_obt_mon_local THEN
              CASE
                WHEN nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) = 0 THEN
                 0
                ELSE
                 (nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) -
                 ((cc.sal_total * -1)))
              END
             ELSE
              pag_gen.fu_con_mon_a_moneda(cc.cod_moneda,
                                          pag_gen.fu_obt_mon_local,
                                          CASE
                                            WHEN nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) = 0 THEN
                                             0
                                            ELSE
                                             (nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) -
                                             ((cc.sal_total * -1)))
                                          END)
           END,
           0) + nvl(CASE cc.cod_moneda
                      WHEN pag_gen.fu_obt_mon_local THEN
                       abs(nvl((cc.sal_total), 0))
                      ELSE
                       pag_gen.fu_con_mon_a_moneda(cc.cod_moneda,
                                                   pag_gen.fu_obt_mon_local,
                                                   abs(nvl((cc.sal_total), 0)))
                    END,
                    0) AS total_riesgo
  FROM ge_gru_economicos w,
       ge_clientes       e,
       ba_personas       p,
       ge_cta_clientes   c,
       cc_cta_corrientes cc
 WHERE e.cod_gru_economico = w.cod_gru_economico
   AND p.cod_persona = e.cod_persona
   AND c.cod_persona = p.cod_persona
   AND c.relacion = ''P''
   AND cc.nro_cuenta = c.nro_cuenta
   AND cc.sal_total < 0
   AND &'||'P_FILTROS
 ORDER BY 7, 8, 6';

BEGIN   
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL)
values ('CD_SAL_GRU', 'CONSULTA SALDO GRUPOS ECONOMICOS', NULL, 'P', 'FIELCO_AUDITORIA-AUDITORIA INTERNA ó UENO_AUDITINT-AUDITORIA INTERNA ó UENO_JEFERIESGOFMP-JEFE RIESGO FINAN. MERC. PORT. ó UENO_SRANALISTRFMP-ANALISTA SR RIESGO F.M.P', 
'Consulta de Saldos por Grupo Economico', V_SQL);

commit;
END;
