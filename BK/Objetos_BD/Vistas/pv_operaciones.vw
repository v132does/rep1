CREATE OR REPLACE FORCE VIEW IT.PV_OPERACIONES AS
SELECT 0 NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       P.MTO_CAPITAL+nvl(cu_int_adelantado,0) monto,
       P.FEC_INICIO,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       nvl(SAL_CAPITAL,0)+ nvl(SAL_INT_ADELANTADO,0) SALDO,
       nvl(SAL_INTERES,0) SAL_INTERES,
       P.FEC_VENCIMIENTO,
       0 cotizacion,
       nvl(P.SAL_CAPITAL,0)/*+ nvl(P.DEV_NO_COBRADO,0)*/ SAL_APLICADO, --BBVASOP950
       x.cod_gru_economico
  FROM GE_EST_CUENTAS B,
       (Select nro_cuenta cu_cuenta, sum(mto_int_documentado) cu_int_adelantado
                             from pr_cuotas
                            where nro_cuota > 0
                            Group by nro_cuenta),
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       PR_CTA_GARANTIAS G,
       PR_CTA_PRESTAMOS P,
       GE_CLIENTES X
 WHERE cu_cuenta = p.nro_cuenta
   and P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NULL
   AND P.ESTADO <> 'N'
   and p.nro_sol_renovada is null --se tienen en cuenta las operaciones nuevas de RRR
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
   AND x.cod_persona(+) = c.cod_persona
   and (g.nro_garantia = (Select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, pr_cta_garantias x
                          where x.nro_cuenta = p.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (SELECT MAX(PRI_APLICACION)
                             FROM PR_GAR_TIPOS TIP,
                                  PR_CTA_GARANTIAS GAR
                            --WHERE GAR.NRO_CUENTA = x.NRO_CUENTA
                             --AND TIP.COD_GARANTIA = y.COD_GARANTIA)) or
                            where tip.cod_garantia = gar.cod_garantia
                              and gar.nro_cuenta = x.nro_cuenta)) or
         (g.nro_garantia is null
           AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                     FROM PR_GAR_TIPOS TIP,
                                          PR_CTA_GARANTIAS GAR
                                    WHERE GAR.NRO_CUENTA = P.NRO_CUENTA
                                      AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
SELECT DISTINCT S.NRO_LINEA,
       0 NRO_SEC_PADRE,
       S.COD_PERSONA,
       S.COD_MODALIDAD,
       S.COD_MODULO,
       'Prop.Nro. '||to_char(S.NRO_SOLICITUD) NRO_CUENTA,
       S.COD_MONEDA,
       S.TOT_PRESTAMO monto,
       S.FEC_INICIO,
       InitCap(B.SIGNIFICADO) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       0 SALDO,
       0,
       S.FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM BA_COD_REFERENCIAS B,
       PR_GAR_TIPOS T,
       PR_SOL_GARANTIAS G,
       PR_SOLICITUDES S,
       ge_clientes x
   WHERE S.NRO_LINEA IS NULL
     AND S.ESTADO NOT IN  ('A','N','R', 'E')
     AND S.NRO_SOLICITUD = G.NRO_SOLICITUD
     AND S.ESTADO = B.VAL_MINIMO
     AND B.DOMINIO = 'EST_SOLICITUD'
     AND G.COD_GARANTIA = T.COD_GARANTIA
     and x.cod_persona(+) = s.cod_persona
     AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                               FROM PR_GAR_TIPOS TIP,
                                    PR_SOL_GARANTIAS GAR
                              WHERE GAR.NRO_SOLICITUD = S.NRO_SOLICITUD
                                AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)
UNION ALL
SELECT 0 NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       P.MONTO monto,
       P.FEC_SOLICITUD,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       P.SALDO,
       0,
       P.FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_CTA_IMPORTACIONES P,
       ge_clientes x
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NULL
   AND P.ESTADO not in ('C','G')
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
   AND x.cod_persona(+) = c.cod_persona
   and (g.nro_garantia = (Select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, cX_cta_garantias x
                          where x.nro_cuenta = p.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (SELECT MAX(PRI_APLICACION)
                             FROM PR_GAR_TIPOS TIP,
                                  CX_CTA_GARANTIAS GAR
                            --WHERE GAR.NRO_CUENTA = x.NRO_CUENTA
                             --AND TIP.COD_GARANTIA = y.COD_GARANTIA)) or
                              where tip.cod_garantia = gar.cod_garantia
                                and gar.nro_cuenta = x.nro_cuenta))  or
         (g.nro_garantia is null
           AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                     FROM PR_GAR_TIPOS TIP,
                                          CX_CTA_GARANTIAS GAR
                                    WHERE GAR.NRO_CUENTA = P.NRO_CUENTA
                                      AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
SELECT 0 NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       P.MONTO monto,
       P.FEC_SOLICITUD,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       P.SALDO,
       0,
       P.FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_Cta_Exportaciones P,
       ge_clientes x
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NULL
   AND P.ESTADO not in ('C','G')
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
   AND x.cod_persona(+) = c.cod_persona
   and (g.nro_garantia = (Select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, cX_cta_garantias x
                          where x.nro_cuenta = p.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (SELECT MAX(PRI_APLICACION)
                             FROM PR_GAR_TIPOS TIP,
                                  CX_CTA_GARANTIAS GAR
                            --WHERE GAR.NRO_CUENTA = x.NRO_CUENTA
                             --AND TIP.COD_GARANTIA = y.COD_GARANTIA)) or
                             where tip.cod_garantia = gar.cod_garantia
                               and gar.nro_cuenta = x.nro_cuenta))  or
         (g.nro_garantia is null
          AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                    FROM PR_GAR_TIPOS TIP,
                                         CX_CTA_GARANTIAS GAR
                                   WHERE GAR.NRO_CUENTA = P.NRO_CUENTA
                                     AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
SELECT 0 NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       P.MONTO monto,
       P.FEC_CONCESION,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       P.MONTO SALDO,
       0,
       P.FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_FIANZAS P,
       ge_clientes x
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NULL
   AND P.ESTADO <> 'C'
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
   AND x.cod_persona(+) = c.cod_persona
   and (g.nro_garantia = (Select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, cX_cta_garantias x
                          where x.nro_cuenta = p.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (SELECT MAX(PRI_APLICACION)
                             FROM PR_GAR_TIPOS TIP,
                                  CX_CTA_GARANTIAS GAR
                            --WHERE GAR.NRO_CUENTA = x.NRO_CUENTA
                             --AND TIP.COD_GARANTIA = y.COD_GARANTIA)) or
                              where tip.cod_garantia = gar.cod_garantia
                                and gar.nro_cuenta = x.nro_cuenta))  or
         (g.nro_garantia is null
           AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                     FROM PR_GAR_TIPOS TIP,
                                          CX_CTA_GARANTIAS GAR
                                    WHERE GAR.NRO_CUENTA = P.NRO_CUENTA
                                     AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
SELECT DISTINCT 0 NRO_LINEA,
       SOB.NRO_SEC_PADRE,
       CLI.COD_PERSONA,
       CTA.COD_MODALIDAD,
       CTA.COD_MODULO,
       SOB.NRO_CUENTA,
       SOB.COD_MONEDA,
       SOB.MONTO,
       --decode(greatest(fuc_obt_mto_lin_sob(cta.nro_cuenta),(nvl(CTA.SAL_TOTAL,0)-nvl(CTA.SAL_RETENIDO,0))*-1),
       --fuc_obt_mto_lin_sob(cta.nro_cuenta), sob.monto, (nvl(CTA.SAL_TOTAL,0)-nvl(CTA.SAL_RETENIDO,0))*-1) monto,
       SOB.FEC_INICIO,
       InitCap(REF.SIGNIFICADO) ESTADO,
       TIP.DESCRIPCION TIPO_GAR,
       nvl(CTA.SAL_TOTAL,0)-nvl(CTA.SAL_RETENIDO,0) SALDO,
       0,
       LIN.FEC_VENCIMIENTO,
       sob.cotizacion cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM BA_COD_REFERENCIAS REF,
       PR_GAR_TIPOS TIP,
       CC_CTA_CORRIENTES CTA,
       GE_CTA_CLIENTES CLI,
       CC_LIN_SOB_GARANTIAS GAR,
       CC_LIN_SOBREGIROS LIN,
       CC_LIN_SOBREGIROS SOB,
       ge_clientes x
  WHERE LIN.NRO_SECUENCIA = SOB.NRO_SEC_PADRE
    AND SOB.TIPO = 'T'
    AND SOB.ESTADO = 'A'
    AND SOB.NRO_SEC_PADRE = GAR.NRO_SECUENCIA
    AND SOB.ESTADO = REF.VAL_MINIMO
    AND SOB.NRO_CUENTA = CTA.NRO_CUENTA
    AND SOB.NRO_CUENTA = CLI.NRO_CUENTA
    AND CLI.RELACION = 'P'
    AND REF.DOMINIO = 'EST_LIN_SOBREGIRO'
    AND SOB.NRO_LINEA IS NULL
    AND GAR.COD_GARANTIA = TIP.COD_GARANTIA
    AND x.cod_persona(+) = cli.cod_persona
    AND TIP.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                FROM PR_GAR_TIPOS T,
                                     CC_LIN_SOB_GARANTIAS G
                               WHERE G.NRO_SECUENCIA = GAR.NRO_SECUENCIA
                                 AND T.COD_GARANTIA = G.COD_GARANTIA)
union all
SELECT 0 NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       NVL(P.LIN_CREDITO,0)+nvl(p.lin_cuotas,0) monto,
       P.FEC_APERTURA FEC_INICIO,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       nvl(P.sal_facturar,0)+nvl(P.sal_facturado,0)+nvl(P.sal_financiado,0) SALDO,
       0,
       TO_DATE(NULL) FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       TA_CTA_GARANTIAS G,
       TA_CTA_TARJETAS P,
       ge_clientes x
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NULL
   AND P.ESTADO <> 'C'
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
   AND x.cod_persona(+) = c.cod_persona
   and (g.nro_garantia = (Select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, ta_cta_garantias x
                          where x.nro_cuenta = p.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (SELECT MAX(PRI_APLICACION)
                             FROM PR_GAR_TIPOS TIP,
                                  TA_CTA_GARANTIAS GAR
                            WHERE GAR.NRO_CUENTA = x.NRO_CUENTA
                             AND TIP.COD_GARANTIA = y.COD_GARANTIA)) or
         (g.nro_garantia is null
           AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                     FROM PR_GAR_TIPOS TIP,
                                          TA_CTA_GARANTIAS GAR
                                    WHERE GAR.NRO_CUENTA = P.NRO_CUENTA
                                      AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
union all
SELECT 0 NRO_LINEA,
       0 NRO_SEC_PADRE,
       A.COD_PERSONA,
       B.COD_MODALIDAD,
       B.COD_MODULO,
       B.NRO_CUENTA,
       B.COD_MONEDA,
       B.MTO_APERTURA MONTO,
       B.FEC_APERTURA FEC_INICIO,
       InitCap(C.DESCRIPCION) ESTADO,
       NULL TIPO_GAR,
       nvl(B.SAL_TOTAL,0)+nvl(B.MTO_CRE_A_CONFIRMAR,0)-(nvl(B.SAL_BLOQUEADO,0)+nvl(B.SAL_RETENIDO,0)+nvl(B.MTO_DEB_PENDIENTES,0)) SALDO,
       0,
       TO_DATE(NULL) FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
    from ge_est_cuentas c,
         ge_cta_clientes a,
         cc_cta_corrientes b,
         ge_clientes x
   where b.nro_cuenta = a.nro_cuenta
     and a.relacion = 'P'
     and b.sal_total-b.sal_retenido < 0
     and b.estado = c.estado
     and b.cod_modulo = c.cod_modulo
     and b.cod_modalidad = c.cod_modalidad
     AND x.cod_persona(+) = a.cod_persona
     and not exists (select 0 from cc_lin_sobregiros x
                      where x.nro_cuenta = a.nro_cuenta
                        and x.estado = 'A')
UNION ALL
SELECT P.NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       P.MTO_CAPITAL+nvl(cu_int_adelantado,0) monto,
       P.FEC_INICIO,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       nvl(SAL_CAPITAL,0)+ nvl(SAL_INT_ADELANTADO,0) SALDO,
       nvl(SAL_INTERES,0) SAL_INTERES,
       P.FEC_VENCIMIENTO,
       0 cotizacion,
       nvl(P.SAL_CAPITAL,0)/*+ nvl(P.DEV_NO_COBRADO,0)*/ SAL_APLICADO,
       x.cod_gru_economico
  FROM GE_EST_CUENTAS B,
       (Select nro_cuenta cu_cuenta, sum(mto_int_documentado) cu_int_adelantado
                             from pr_cuotas
                            where nro_cuota > 0
                            Group by nro_cuenta),
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       PR_CTA_GARANTIAS G,
       PR_CTA_PRESTAMOS P,
       ge_clientes x
 WHERE cu_cuenta = p.nro_cuenta
   and P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NOT NULL
   AND P.ESTADO <> 'N'
   and p.nro_sol_renovada is null --se tienen en cuenta las operaciones nuevas de RRR
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
   AND x.cod_persona(+) = c.cod_persona
   and (g.nro_garantia = (Select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, pr_cta_garantias x
                          where x.nro_cuenta = p.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (SELECT MAX(PRI_APLICACION)
                             FROM PR_GAR_TIPOS TIP,
                                  PR_CTA_GARANTIAS GAR
                            --WHERE GAR.NRO_CUENTA = x.NRO_CUENTA
                             --AND TIP.COD_GARANTIA = y.COD_GARANTIA)) or
                            where tip.cod_garantia = gar.cod_garantia
                              and gar.nro_cuenta = x.nro_cuenta)) or
         (g.nro_garantia is null
           AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                     FROM PR_GAR_TIPOS TIP,
                                          PR_CTA_GARANTIAS GAR
                                    WHERE GAR.NRO_CUENTA = P.NRO_CUENTA
                                      AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
SELECT DISTINCT S.NRO_LINEA,
       0 NRO_SEC_PADRE,
       S.COD_PERSONA,
       S.COD_MODALIDAD,
       S.COD_MODULO,
       'Prop.Nro. '||to_char(S.NRO_SOLICITUD) NRO_CUENTA,
       S.COD_MONEDA,
       S.TOT_PRESTAMO monto,
       S.FEC_INICIO,
       InitCap(B.SIGNIFICADO) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       0 SALDO,
       0,
       S.FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM BA_COD_REFERENCIAS B,
       PR_GAR_TIPOS T,
       PR_SOL_GARANTIAS G,
       PR_SOLICITUDES S,
       ge_clientes x
   WHERE S.NRO_LINEA IS NOT NULL
     AND S.ESTADO NOT IN  ('A','N','R', 'E')
     AND S.NRO_SOLICITUD = G.NRO_SOLICITUD
     AND S.ESTADO = B.VAL_MINIMO
     AND B.DOMINIO = 'EST_SOLICITUD'
     AND G.COD_GARANTIA = T.COD_GARANTIA
     AND x.cod_persona(+) = s.cod_persona
     AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                               FROM PR_GAR_TIPOS TIP,
                                    PR_SOL_GARANTIAS GAR
                              WHERE GAR.NRO_SOLICITUD = S.NRO_SOLICITUD
                                AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)
/* agregado para solicitudes de tarjetas de credito */
UNION ALL
SELECT S.NRO_LINEA,
       0 NRO_SEC_PADRE,
       S.COD_PERSONA,
       S.COD_MODALIDAD,
       S.COD_MODULO,
       'Sol.Nro. '||to_char(S.NRO_SOLICITUD) NRO_CUENTA,
       S.COD_MONEDA,
       S.MONTO monto,
       S.FEC_SOLICITUD,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       0 SALDO,
       0,
       NULL FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM GE_SOL_ESTADOS B,
       PR_GAR_TIPOS T,
       TA_SOL_GARANTIAS G,
       TA_SOLICITUDES S,
       ge_clientes x
   WHERE/* S.NRO_LINEA IS NULL --NOT NULL
     AND*/ S.COD_ESTADO IN ('PAN','APR')
     AND S.NRO_SOLICITUD = G.NRO_SOLICITUD
     AND S.COD_ESTADO = B.COD_ESTADO
     AND G.COD_GARANTIA = T.COD_GARANTIA
     AND x.cod_persona(+) = s.cod_persona
     AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                               FROM PR_GAR_TIPOS TIP,
                                    TA_SOL_GARANTIAS GAR
                              WHERE GAR.NRO_SOLICITUD = S.NRO_SOLICITUD
                                AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)
/* fin de tarjetas de credito solicitudes */
UNION ALL
SELECT DISTINCT LIN.NRO_LINEA,
       SOB.NRO_SEC_PADRE,
       CLI.COD_PERSONA,
       CTA.COD_MODALIDAD,
       CTA.COD_MODULO,
       SOB.NRO_CUENTA,
       SOB.COD_MONEDA,
       decode(greatest(fuc_obt_mto_lin_sob(cta.nro_cuenta),(nvl(CTA.SAL_TOTAL,0)-nvl(CTA.SAL_RETENIDO,0))*-1),
       fuc_obt_mto_lin_sob(cta.nro_cuenta), sob.monto, (nvl(CTA.SAL_TOTAL,0)-nvl(CTA.SAL_RETENIDO,0))*-1) monto,
       SOB.FEC_INICIO,
       InitCap(REF.SIGNIFICADO) ESTADO,
       TIP.DESCRIPCION TIPO_GAR,
       nvl(CTA.SAL_TOTAL,0)-nvl(CTA.SAL_RETENIDO,0) SALDO,
       0,
       LIN.FEC_VENCIMIENTO,
       sob.cotizacion cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM BA_COD_REFERENCIAS REF,
       PR_GAR_TIPOS TIP,
       GE_CTA_CLIENTES CLI,
       CC_CTA_CORRIENTES CTA,
       CC_LIN_SOBREGIROS LIN,
       CC_LIN_SOBREGIROS SOB,
       CC_LIN_SOB_GARANTIAS GAR,
       ge_clientes x
  WHERE LIN.NRO_SECUENCIA = SOB.NRO_SEC_PADRE
    AND SOB.TIPO = 'P'
    AND SOB.ESTADO = 'A'
    AND SOB.NRO_SEC_PADRE = GAR.NRO_SECUENCIA
    AND SOB.ESTADO = REF.VAL_MINIMO
    AND SOB.NRO_CUENTA = CTA.NRO_CUENTA
    AND SOB.NRO_CUENTA = CLI.NRO_CUENTA
    AND CLI.RELACION = 'P'
    AND REF.DOMINIO = 'EST_LIN_SOBREGIRO'
    AND SOB.NRO_LINEA IS NOT NULL
    AND GAR.COD_GARANTIA = TIP.COD_GARANTIA
    AND x.cod_persona(+) = cli.cod_persona
    AND TIP.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                FROM PR_GAR_TIPOS T,
                                     CC_LIN_SOB_GARANTIAS G
                               WHERE G.NRO_SECUENCIA = GAR.NRO_SECUENCIA
                                 AND T.COD_GARANTIA = G.COD_GARANTIA)
UNION ALL
SELECT P.NRO_LINEA NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       NVL(P.LIN_CREDITO,0)+nvl(p.lin_cuotas,0) monto,
       P.FEC_APERTURA FEC_INICIO,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       nvl(P.sal_facturar,0)+nvl(P.sal_facturado,0)+nvl(P.sal_financiado,0) SALDO,
       0,
       TO_DATE(NULL) FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       TA_CTA_GARANTIAS G,
       TA_CTA_TARJETAS P,
       ge_clientes x
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NOT NULL
   AND P.ESTADO <> 'C'
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
   AND x.cod_persona(+) = c.cod_persona
   and (g.nro_garantia = (Select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, ta_cta_garantias x
                          where x.nro_cuenta = p.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (SELECT MAX(PRI_APLICACION)
                             FROM PR_GAR_TIPOS TIP,
                                  TA_CTA_GARANTIAS GAR
                            WHERE GAR.NRO_CUENTA = x.NRO_CUENTA
                             AND TIP.COD_GARANTIA = y.COD_GARANTIA)) or
         (g.nro_garantia is null
           AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                     FROM PR_GAR_TIPOS TIP,
                                          TA_CTA_GARANTIAS GAR
                                    WHERE GAR.NRO_CUENTA = P.NRO_CUENTA
                                      AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
SELECT NRO_LINEA NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       P.MONTO monto,
       P.FEC_SOLICITUD,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       P.SALDO,
       0,
       P.FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_CTA_IMPORTACIONES P,
       ge_clientes x
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NOT NULL
   AND P.ESTADO not in ('C','G')
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
   AND x.cod_persona(+) = c.cod_persona
   and (g.nro_garantia = (Select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, cX_cta_garantias x
                          where x.nro_cuenta = p.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (SELECT MAX(PRI_APLICACION)
                             FROM PR_GAR_TIPOS TIP,
                                  CX_CTA_GARANTIAS GAR
                            --WHERE GAR.NRO_CUENTA = x.NRO_CUENTA
                             --AND TIP.COD_GARANTIA = y.COD_GARANTIA)) or
                              where tip.cod_garantia = gar.cod_garantia
                                and gar.nro_cuenta = x.nro_cuenta))  or
         (g.nro_garantia is null
           AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                     FROM PR_GAR_TIPOS TIP,
                                          CX_CTA_GARANTIAS GAR
                                    WHERE GAR.NRO_CUENTA = P.NRO_CUENTA
                                     AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
SELECT NRO_LINEA NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       P.MONTO monto,
       P.FEC_SOLICITUD,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       P.SALDO,
       0,
       P.FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_Cta_Exportaciones P,
       ge_clientes x
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NOT NULL
   AND P.ESTADO not in ('C','G')
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
   AND x.cod_persona(+) = c.cod_persona
   and (g.nro_garantia = (Select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, cX_cta_garantias x
                          where x.nro_cuenta = p.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (SELECT MAX(PRI_APLICACION)
                             FROM PR_GAR_TIPOS TIP,
                                  CX_CTA_GARANTIAS GAR
                            --WHERE GAR.NRO_CUENTA = x.NRO_CUENTA
                             --AND TIP.COD_GARANTIA = y.COD_GARANTIA)) or
                             where tip.cod_garantia = gar.cod_garantia
                               and gar.nro_cuenta = x.nro_cuenta))  or
         (g.nro_garantia is null
           AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                     FROM PR_GAR_TIPOS TIP,
                                          CX_CTA_GARANTIAS GAR
                                    WHERE GAR.NRO_CUENTA = P.NRO_CUENTA
                                     AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
SELECT NRO_LINEA NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       P.MONTO monto,
       P.FEC_CONCESION,
       InitCap(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION TIPO_GAR,
       P.MONTO SALDO,
       0,
       P.FEC_VENCIMIENTO,
       0 cotizacion,
       0 SAL_APLICADO,
       x.cod_gru_economico
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_FIANZAS P,
       ge_clientes x
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NOT NULL
   AND P.ESTADO <> 'C'
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
   AND x.cod_persona(+) = c.cod_persona
   and (g.nro_garantia = (Select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, cX_cta_garantias x
                          where x.nro_cuenta = p.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (SELECT MAX(PRI_APLICACION)
                             FROM PR_GAR_TIPOS TIP,
                                  CX_CTA_GARANTIAS GAR
                            --WHERE GAR.NRO_CUENTA = x.NRO_CUENTA
                             --AND TIP.COD_GARANTIA = y.COD_GARANTIA)) or
                             where tip.cod_garantia = gar.cod_garantia
                               and gar.nro_cuenta = x.nro_cuenta))  or
         (g.nro_garantia is null
           AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                     FROM PR_GAR_TIPOS TIP,
                                          CX_CTA_GARANTIAS GAR
                                    WHERE GAR.NRO_CUENTA = P.NRO_CUENTA
                                     AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
union
select a.nro_linea,
       0 nro_sec_padre,
       a.cod_persona,
       a.cod_modalidad,
       a.cod_modulo,
       a.nro_cuenta,
       a.cod_moneda,
       a.monto,
       a.fec_inicio,
       Initcap(c.descripcion),
       t.descripcion tipo_gar,
       a.monto as saldo,
       g.monto,
       a.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       a.monto*nvl(pag_gen.fu_obt_cotizacion( a.cod_moneda, pag_cal.FU_OBT_FEC_ACTUAL(1)),1) as sal_aplicado,
       x.cod_gru_economico
  from ge_est_cuentas    c,
       pr_gar_tipos      t,
       ge_cta_clientes   b,
       md_cta_documentos a,
       md_garantias      g,
       ge_clientes x
 where b.nro_cuenta = a.nro_cuenta
   and t.cod_garantia(+) = g.cod_garantia
   and b.relacion = 'P'
   and a.estado = c.estado
   and c.activo = 'S'
   and a.cod_modulo = c.cod_modulo
   and a.cod_modalidad = c.cod_modalidad
   and g.nro_cuenta(+) = a.nro_cuenta
   and a.nro_linea is null
   AND x.cod_persona(+) = b.cod_persona
   --SDCAMBENFI-1 - Op de Cambios con Entidades Financieras
/*   and (g.nro_garantia = (select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, md_garantias x
                          where x.nro_cuenta = a.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (select max(pri_aplicacion)
                             from pr_gar_tipos tip,
                                  md_garantias gar
                            where gar.nro_cuenta = x.nro_cuenta
                             and tip.cod_garantia = y.cod_garantia)) or
         (g.nro_garantia is null
           and t.pri_aplicacion = (select max(pri_aplicacion)
                                     from pr_gar_tipos tip,
                                          md_garantias gar
                                    where gar.nro_cuenta = a.nro_cuenta
                                     and tip.cod_garantia = gar.cod_garantia)))*/
 union
 select a.nro_linea,
       0 nro_sec_padre,
       a.cod_persona,
       a.cod_modalidad,
       a.cod_modulo,
       a.nro_cuenta,
       a.cod_moneda,
       a.monto,
       a.fec_inicio,
       Initcap(c.descripcion),
       t.descripcion tipo_gar,
       a.monto as saldo,
       g.monto,
       a.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       a.monto*nvl(pag_gen.fu_obt_cotizacion( a.cod_moneda, pag_cal.FU_OBT_FEC_ACTUAL(1)),1) as sal_aplicado,
       x.cod_gru_economico
  from ge_est_cuentas    c,
       pr_gar_tipos      t,
       ge_cta_clientes   b,
       md_cta_documentos a,
       md_garantias      g,
       ge_clientes       x
 where b.nro_cuenta = a.nro_cuenta
   and t.cod_garantia(+) = g.cod_garantia
   and b.relacion = 'P'
   and a.estado = c.estado
   and c.activo = 'S'
   and a.cod_modulo = c.cod_modulo
   and a.cod_modalidad = c.cod_modalidad
   and g.nro_cuenta(+) = a.nro_cuenta
   and a.nro_linea is not null
   and x.cod_persona(+) = b.cod_persona
   and (g.nro_garantia = (select min(nvl(x.nro_garantia,0))
                           from pr_gar_tipos y, md_garantias x
                          where x.nro_cuenta = a.nro_cuenta
                            and y.cod_garantia = x.cod_garantia
                            and y.pri_aplicacion = (select max(pri_aplicacion)
                             from pr_gar_tipos tip,
                                  md_garantias gar
                            where gar.nro_cuenta = x.nro_cuenta
                             and tip.cod_garantia = y.cod_garantia)) or
         (g.nro_garantia is null
           and t.pri_aplicacion = (select max(pri_aplicacion)
                                     from pr_gar_tipos tip,
                                          md_garantias gar
                                    where gar.nro_cuenta = a.nro_cuenta
                                     and tip.cod_garantia = gar.cod_garantia)))
union
select lc.nro_linea,
       0 nro_sec_padre,
       b.cod_persona,
       lc.cod_modalidad,
       lc.cod_modulo,
       lc.nro_cuenta,
       lc.cod_moneda,
       lc.mto_limite monto,
       lc.fec_apertura fec_inicio,
       Initcap(c.descripcion),
       'SOLA FIRMA' tipo_gar,
       nvl(lc.mto_limite,0) saldo,
       nvl(lc.mto_limite,0) monto,
       lc.fec_vencimiento fec_vencimiento,
       0 cotizacion,
       nvl(lc.mto_limite,0) Sal_aplicado,
       x.cod_gru_economico
  from lc_cta_cambios    lc,
       ge_cta_clientes   b,
       ge_clientes x,
       ge_est_cuentas c
 where lc.nro_cuenta = b.nro_cuenta
   and b.cod_modulo = c.cod_modulo
   and b.cod_modalidad = c.cod_modalidad
   and lc.estado = c.estado
   and b.relacion = 'P'
   and b.cod_persona = x.cod_persona
;

