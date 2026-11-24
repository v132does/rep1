declare
 v_sql long := 'SELECT w.cod_gru_economico cod_gru_economico,
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
       ov_cta_vencidas   ov,
       ge_est_cuentas    x
 WHERE e.cod_gru_economico = w.cod_gru_economico
   AND p.cod_persona = e.cod_persona
   AND c.cod_persona = p.cod_persona
   AND c.relacion = ''P''
   AND ov.nro_cuenta = c.nro_cuenta
   and ov.cod_modulo= x.cod_modulo
   and ov.cod_modalidad= x.cod_modalidad
   and ov.estado= x.estado
   and x.activo=''S'' 
   AND &'||'P_FILTROS
UNION
SELECT w.cod_gru_economico cod_gru_economico,
       w.descripcion as descripcion,
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
            WHEN (nvl(ta.lin_credito, 0) -(/*nvl(ta.sal_facturar, 0) +*/ nvl(ta.sal_facturado, 0) + nvl(ta.sal_financiado, 0))
              + (nvl(ta.lin_cuotas,0)- nvl(ta.sal_cuo_pendientes,0))) < 0 THEN
             0
            ELSE
              case when  nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) 
                + nvl(ta.sal_cuo_pendientes, 0)<0
            then  (nvl(ta.lin_credito, 0) -(/*nvl(ta.sal_facturar, 0) +*/ nvl(ta.sal_facturado, 0) )
             + (nvl(ta.lin_cuotas,0)- nvl(ta.sal_cuo_pendientes,0)))
             else
               (nvl(ta.lin_credito, 0) -(nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) + nvl(ta.sal_financiado, 0))
             + (nvl(ta.lin_cuotas,0)- nvl(ta.sal_cuo_pendientes,0)))
             end
          END
         ELSE
          pag_gen.fu_con_mon_a_moneda(ta.cod_moneda,pag_gen.fu_obt_mon_local,
                                      CASE
                                        WHEN (nvl(ta.lin_credito, 0) -(/*nvl(ta.sal_facturar, 0) +*/ nvl(ta.sal_facturado, 0) + nvl(ta.sal_financiado, 0))
                                          + (nvl(ta.lin_cuotas,0)- nvl(ta.sal_cuo_pendientes,0))) < 0 THEN
                                         0
                                        ELSE
                                              case when  nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0)<0
                                              then (nvl(ta.lin_credito, 0) -(/*nvl(ta.sal_facturar, 0) + */nvl(ta.sal_facturado, 0) )
                                                 + (nvl(ta.lin_cuotas,0)- nvl(ta.sal_cuo_pendientes,0)))
                                              else
                                               (nvl(ta.lin_credito, 0) -(/*nvl(ta.sal_facturar, 0) +*/ nvl(ta.sal_facturado, 0) +  nvl(ta.sal_financiado, 0))
                                                + (nvl(ta.lin_cuotas,0)- nvl(ta.sal_cuo_pendientes,0)))
                                             end
                                      END)
       END AS tot_deu_contingente,
       CASE ta.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
           case  when nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0)<0
            then 0 else            
            nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0)
            end
         ELSE
           case when pag_gen.fu_con_mon_a_moneda(ta.cod_moneda,pag_gen.fu_obt_mon_local,nvl(ta.sal_facturar, 0) +nvl(ta.sal_facturado, 0) + nvl(ta.sal_financiado, 0) +nvl(ta.sal_cuo_pendientes, 0))
           <0 then 0 else            
              pag_gen.fu_con_mon_a_moneda(ta.cod_moneda,pag_gen.fu_obt_mon_local,nvl(ta.sal_facturar, 0) +nvl(ta.sal_facturado, 0) + nvl(ta.sal_financiado, 0) +nvl(ta.sal_cuo_pendientes, 0))
           end 
       END AS saldo_capital,
       CASE ta.cod_moneda
         WHEN pag_gen.fu_obt_mon_local THEN
           case when (nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0))
           <0 then 0 else 
            (nvl(ta.sal_facturar, 0) + nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0))
           end
         ELSE
          case when   pag_gen.fu_con_mon_a_moneda(ta.cod_moneda,pag_gen.fu_obt_mon_local,(nvl(ta.sal_facturar, 0) +nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0)))
           <0 then 0 else 
             pag_gen.fu_con_mon_a_moneda(ta.cod_moneda,pag_gen.fu_obt_mon_local,(nvl(ta.sal_facturar, 0) +nvl(ta.sal_facturado, 0) +nvl(ta.sal_financiado, 0) + nvl(ta.sal_cuo_pendientes, 0)))
           end
       END AS tot_deu_real,
       
      nvl(case ta.cod_moneda when pag_gen.FU_OBT_MON_LOCAL then
           case when (nvl(ta.LIN_CREDITO,0) - (nvl(ta.sal_facturar,0) + nvl(ta.sal_facturado,0)+ nvl(ta.sal_financiado,0)) 
             + (nvl(ta.lin_cuotas,0)- nvl(ta.sal_cuo_pendientes,0)))<0
             then 0 else
            (nvl(ta.LIN_CREDITO,0) - (nvl(ta.sal_facturar,0) + nvl(ta.sal_facturado,0)+ nvl(ta.sal_financiado,0)) 
            + (nvl(ta.lin_cuotas,0)- nvl(ta.sal_cuo_pendientes,0)))
           end
       else
        pag_gen.FU_CON_MON_A_MONEDA(ta.cod_moneda, pag_gen.FU_OBT_MON_LOCAL,
        case when (nvl(ta.LIN_CREDITO,0) - (nvl(ta.sal_facturar,0) + nvl(ta.sal_facturado,0)+ nvl(ta.sal_financiado,0))
           + (nvl(ta.lin_cuotas,0)- nvl(ta.sal_cuo_pendientes,0)))<0
         then 0 else
           (nvl(ta.LIN_CREDITO,0) - (nvl(ta.sal_facturar,0) + nvl(ta.sal_facturado,0)+ nvl(ta.sal_financiado,0)) 
           + (nvl(ta.lin_cuotas,0)- nvl(ta.sal_cuo_pendientes,0)))
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
       ta_cta_tarjetas   ta,
       ge_est_cuentas    x
 WHERE e.cod_gru_economico = w.cod_gru_economico
   AND p.cod_persona = e.cod_persona
   AND c.cod_persona = p.cod_persona
   AND c.relacion = ''P''
   AND ta.nro_cuenta = c.nro_cuenta
   and ta.cod_modulo= x.cod_modulo
   and ta.cod_modalidad= x.cod_modalidad
   and ta.estado= x.estado
   and x.activo=''S''
   AND &'||'P_FILTROS   
UNION
SELECT w.cod_gru_economico,
       w.descripcion as descripcion,
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
       pr_cta_prestamos  pr,
       ge_est_cuentas    x
 WHERE e.cod_gru_economico = w.cod_gru_economico
   AND p.cod_persona = e.cod_persona
   AND c.cod_persona = p.cod_persona
   AND c.relacion = ''P''
   AND pr.nro_cuenta = c.nro_cuenta
   and pr.cod_modulo= x.cod_modulo
   and pr.cod_modalidad= x.cod_modalidad
   and pr.estado= x.estado
   and x.activo=''S''
   AND &'||'P_FILTROS  
UNION
SELECT w.cod_gru_economico,
       w.descripcion as descripcion,
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
       cc_cta_corrientes cc,
       ge_est_cuentas    x
 WHERE e.cod_gru_economico = w.cod_gru_economico
   AND p.cod_persona = e.cod_persona
   AND c.cod_persona = p.cod_persona
   AND c.relacion = ''P''
   AND cc.nro_cuenta = c.nro_cuenta
   AND cc.sal_total < 0
   and cc.cod_modulo= x.cod_modulo
   and cc.cod_modalidad= x.cod_modalidad
   and cc.estado= x.estado
   and x.activo=''S''
  AND &'||'P_FILTROS
 union
 SELECT w.cod_gru_economico,
       w.descripcion as descripcion,
       p.nro_documento,
       p.nom_completo,
       cc.nro_cuenta,
       cc.cod_moneda,
       c.cod_modulo,
       c.cod_modalidad,
       0 interes,
       case cc.cod_moneda WHEN pag_gen.fu_obt_mon_local THEN
            nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) 
       else
          pag_gen.fu_con_mon_a_moneda(cc.cod_moneda, pag_gen.fu_obt_mon_local,nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) )
       end AS tot_deu_contingente,
       0 AS saldo_capital,
       0 AS tot_deu_real,
       case cc.cod_moneda WHEN pag_gen.fu_obt_mon_local THEN
            nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) 
       else
          pag_gen.fu_con_mon_a_moneda(cc.cod_moneda, pag_gen.fu_obt_mon_local,nvl(fuc_obt_mto_lin_sob(cc.nro_cuenta), 0) )
       end AS total_riesgo
  FROM ge_gru_economicos w,
       ge_clientes       e,
       ba_personas       p,
       ge_cta_clientes   c,
       cc_cta_corrientes cc,
       ge_est_cuentas    x
 WHERE e.cod_gru_economico = w.cod_gru_economico
   AND p.cod_persona = e.cod_persona
   AND c.cod_persona = p.cod_persona
   AND c.relacion = ''P''
   AND cc.nro_cuenta = c.nro_cuenta
   AND (cc.sal_total >= 0 and nvl(FUC_OBT_MTO_LIN_SOB(CC.NRO_CUENTA),0)>0)
   and cc.cod_modulo= x.cod_modulo
   and cc.cod_modalidad= x.cod_modalidad
   and cc.estado= x.estado
   and x.activo=''S''
   AND &'||'P_FILTROS
 ORDER BY 7, 8, 6';
 
begin
  pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
  
  update ba_consultas
  set    det_sql = v_sql
  where  cod_consulta = 'CD_SAL_GRU';
  
  commit;
end;  
