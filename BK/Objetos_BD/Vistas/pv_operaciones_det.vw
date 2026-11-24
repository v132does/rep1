CREATE OR REPLACE FORCE VIEW IT.PV_OPERACIONES_DET AS
SELECT 0 NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       P.MTO_CAPITAL+nvl(cu_int_adelantado,0) monto,
       P.FEC_INICIO,
       B.DESCRIPCION ESTADO,
       T.DESCRIPCION TIPO_GAR,
       nvl(SAL_CAPITAL,0)+nvl(SAL_INT_ADELANTADO,0) SALDO,
       g.cod_garantia,
       G.MTO_APLICADO,
       /*case --> Verifica si existe dos tipos de garantias, si no existe, controla que sea el de menor prioridad entre las existentes.-
            when g.cod_garantia = (select ax.cod_garantia
                                     from pr_gar_tipos ax
                                    where ax.pri_aplicacion = (select min(ce.pri_aplicacion) prioridad
                                                                 from pr_cta_prestamos ae, pr_cta_garantias be, pr_gar_tipos ce
                                                                where ae.nro_cuenta   = be.nro_cuenta
                                                                  and be.cod_garantia = ce.cod_garantia
                                                                  and be.mto_aplicado > 0
                                                                  and ae.nro_cuenta   = p.nro_cuenta))
                                      and 1 = (Select distinct(1)
                                                    From pr_cta_garantias gp
                                                   Where gp.cod_garantia != g.cod_garantia
                                                     and gp.nro_cuenta    = p.nro_cuenta
                                                     and gp.mto_aplicado  > 0) then
                 nvl(g.mto_aplicado,0)
            --> Verifica si existe dos tipos de garantías, SI EXISTE, Toma solo del de menor Número de Garantia y con Monto Aplicado mayor a Cero.-
            When (Select count(*)
                    from pr_cta_garantias cn
                   where cn.nro_cuenta        = p.nro_cuenta
                     and cn.cod_garantia      = g.cod_garantia
                     and cn.mto_aplicado > 0) > 1
                     and (Select min(mi.nro_garantia)
                            from pr_cta_garantias mi
                           where mi.nro_cuenta   = p.nro_cuenta
                             and mi.mto_aplicado > 0
                             and mi.cod_garantia = g.cod_garantia) = g.nro_garantia then
                  (nvl(g.mto_aplicado,0) - nvl(p.dev_no_cobrado,0))
            --> Verifica si existe dos tipos de garantías, SI EXISTE y Número de Garantia NO es el de menor númer y con Monto Aplicado NO DESAFECTA.-
            When (Select count(*)
                    from pr_cta_garantias cn
                   where cn.nro_cuenta        = p.nro_cuenta
                     and cn.cod_garantia      = g.cod_garantia
                     and cn.mto_aplicado > 0) > 1
                     and (Select min(mi.nro_garantia)
                            from pr_cta_garantias mi
                           where mi.nro_cuenta   = p.nro_cuenta
                             and mi.mto_aplicado > 0
                             and mi.cod_garantia = g.cod_garantia) != g.nro_garantia then
                   nvl(g.mto_aplicado,0)
            Else

                 case when g.mto_aplicado > 0 then
                           (nvl(g.mto_aplicado,0) - nvl(p.dev_no_cobrado,0))
                      else
                           0
                 end

       End mto_aplicado,*/
       P.COD_MONEDA COD_MON_APL,
       p.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM (Select cu.nro_cuenta cu_cuenta, sum(cu.mto_int_documentado) cu_int_adelantado
                             from pr_cuotas cu
                            where cu.nro_cuota > 0
                            Group by cu.nro_cuenta),
       GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       PR_CTA_GARANTIAS G,
       PR_CTA_PRESTAMOS P
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
UNION ALL
SELECT S.NRO_LINEA,
       0 NRO_SEC_PADRE,
       S.COD_PERSONA,
       S.COD_MODALIDAD,
       S.COD_MODULO,
       'Prop.Nro. '||to_char(S.NRO_SOLICITUD) NRO_CUENTA,
       S.COD_MONEDA,
       S.TOT_PRESTAMO monto,
       S.FEC_INICIO,
       B.SIGNIFICADO ESTADO,
       T.DESCRIPCION TIPO_GAR,
       0 SALDO,
       g.cod_garantia,
       g.mto_aplicado,
       S.COD_MONEDA COD_MON_APL,
       s.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM BA_COD_REFERENCIAS B,
       PR_GAR_TIPOS T,
       PR_SOL_GARANTIAS G,
       PR_SOLICITUDES S
   WHERE S.NRO_LINEA IS NULL
     AND S.ESTADO NOT IN  ('A','N','R')
     AND S.NRO_SOLICITUD = G.NRO_SOLICITUD
     AND S.ESTADO = B.VAL_MINIMO
     AND B.DOMINIO = 'EST_SOLICITUD'
     AND G.COD_GARANTIA = T.COD_GARANTIA
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
       g.cod_garantia,
       G.MTO_APLICADO,
       P.COD_MONEDA COD_MON_APL,
       p.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_CTA_IMPORTACIONES P
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NULL
   AND P.ESTADO not in ('C','G')
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
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
       g.cod_garantia,
       G.MTO_APLICADO,
       P.COD_MONEDA COD_MON_APL,
       p.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_Cta_Exportaciones P
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NULL
   AND P.ESTADO not in ('C','G')
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
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
       g.cod_garantia,
       G.MTO_APLICADO,
       P.COD_MONEDA COD_MON_APL,
       p.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_FIANZAS P
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NULL
   AND P.ESTADO <> 'C'
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
UNION ALL
SELECT 0 NRO_LINEA,
       SOB.NRO_SEC_PADRE,
       CLI.COD_PERSONA,
       CTA.COD_MODALIDAD,
       CTA.COD_MODULO,
       SOB.NRO_CUENTA,
       SOB.COD_MONEDA,
       greatest(SOB.MONTO,(nvl(CTA.SAL_TOTAL,0)-nvl(CTA.SAL_RETENIDO,0))*-1) monto,
       SOB.FEC_INICIO,
       REF.SIGNIFICADO ESTADO,
       TIP.DESCRIPCION TIPO_GAR,
       nvl(CTA.SAL_TOTAL,0)-nvl(CTA.SAL_RETENIDO,0) SALDO,
       gar.cod_garantia,
       pag_gen.FU_CON_MON_A_MONEDA(sob.cod_moneda,lin.cod_moneda,sob.monto,sob.cotizacion)/lin.monto*gar.mto_aplicado mto_aplicado,
       --gar.mto_aplicado,
       LIN.COD_MONEDA COD_MON_APL,
       sob.fec_vencimiento fec_vencimiento,
       sob.cotizacion cotizacion,
       gar.nro_garantia
  FROM BA_COD_REFERENCIAS REF,
       GE_CTA_CLIENTES CLI,
       PR_GAR_TIPOS TIP,
       CC_CTA_CORRIENTES CTA,
       CC_LIN_SOB_GARANTIAS GAR,
       CC_LIN_SOBREGIROS LIN,
       CC_LIN_SOBREGIROS SOB
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
 --   and sob.nro_cuenta = (Select min(nro_cuenta)
 --                           from cc_lin_sobregiros x
 --                          where x.nro_sec_padre = lin.nro_secuencia)
UNION ALL
SELECT 0 NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       NVL(P.LIN_CREDITO,0)+nvl(p.lin_cuotas,0) monto,
       P.FEC_APERTURA FEC_INICIO,
       B.DESCRIPCION ESTADO,
       T.DESCRIPCION TIPO_GAR,
       nvl(P.sal_facturar,0)+nvl(P.sal_facturado,0)+nvl(P.sal_financiado,0) SALDO,
       g.cod_garantia,
       g.mto_aplicado,
       P.COD_MONEDA COD_MON_APL,
       to_date(null) fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       TA_CTA_GARANTIAS G,
       TA_CTA_TARJETAS P
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NULL
   AND P.ESTADO <> 'C'
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
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
       C.DESCRIPCION ESTADO,
       NULL TIPO_GAR,
       nvl(B.SAL_TOTAL,0)+nvl(B.MTO_CRE_A_CONFIRMAR,0)-(nvl(B.SAL_BLOQUEADO,0)+nvl(B.SAL_RETENIDO,0)+nvl(B.MTO_DEB_PENDIENTES,0)) SALDO,
       to_number(null),
       0,
       B.COD_MONEDA COD_MON_APL,
       to_date(null) fec_vencimiento,
       to_number(null) cotizacion,
       to_number(null) --g.nro_garantia
    from ge_est_cuentas c,
         ge_cta_clientes a,
         cc_cta_corrientes b
   where b.nro_cuenta = a.nro_cuenta
     and a.relacion = 'P'
     and b.sal_total-b.sal_retenido < 0
     and b.estado = c.estado
     and b.cod_modulo = c.cod_modulo
     and b.cod_modalidad = c.cod_modalidad
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
       B.DESCRIPCION ESTADO,
       T.DESCRIPCION TIPO_GAR,
       nvl(SAL_CAPITAL,0)+nvl(SAL_INT_ADELANTADO,0) SALDO,
       g.cod_garantia,
       g.mto_aplicado,
       /*case --> Verifica si existe dos tipos de garantias, si no existe, controla que sea el de menor prioridad entre las existentes.-
            when g.cod_garantia = (select ax.cod_garantia
                                     from pr_gar_tipos ax
                                    where ax.pri_aplicacion = (select min(ce.pri_aplicacion) prioridad
                                                                 from pr_cta_prestamos ae, pr_cta_garantias be, pr_gar_tipos ce
                                                                where ae.nro_cuenta   = be.nro_cuenta
                                                                  and be.cod_garantia = ce.cod_garantia
                                                                  and be.mto_aplicado > 0
                                                                  and ae.nro_cuenta   = p.nro_cuenta))
                                      and 1 = (Select distinct(1)
                                                    From pr_cta_garantias gp
                                                   Where gp.cod_garantia != g.cod_garantia
                                                     and gp.nro_cuenta    = p.nro_cuenta
                                                     and gp.mto_aplicado  > 0) then
                 nvl(g.mto_aplicado,0)
            --> Verifica si existe dos tipos de garantías, SI EXISTE, Toma solo del de menor Número de Garantia y con Monto Aplicado mayor a Cero.-
            When (Select count(*)
                    from pr_cta_garantias cn
                   where cn.nro_cuenta        = p.nro_cuenta
                     and cn.cod_garantia      = g.cod_garantia
                     and cn.mto_aplicado > 0) > 1
                     and (Select min(mi.nro_garantia)
                            from pr_cta_garantias mi
                           where mi.nro_cuenta   = p.nro_cuenta
                             and mi.mto_aplicado > 0
                             and mi.cod_garantia = g.cod_garantia) = g.nro_garantia then
                  (nvl(g.mto_aplicado,0) - nvl(p.dev_no_cobrado,0))
            --> Verifica si existe dos tipos de garantías, SI EXISTE y Número de Garantia NO es el de menor númer y con Monto Aplicado NO DESAFECTA.-
            When (Select count(*)
                    from pr_cta_garantias cn
                   where cn.nro_cuenta        = p.nro_cuenta
                     and cn.cod_garantia      = g.cod_garantia
                     and cn.mto_aplicado > 0) > 1
                     and (Select min(mi.nro_garantia)
                            from pr_cta_garantias mi
                           where mi.nro_cuenta   = p.nro_cuenta
                             and mi.mto_aplicado > 0
                             and mi.cod_garantia = g.cod_garantia) != g.nro_garantia then
                   nvl(g.mto_aplicado,0)
            Else

                 case when g.mto_aplicado > 0 then
                           (nvl(g.mto_aplicado,0) - nvl(p.dev_no_cobrado,0))
                      else
                           0
                 end

       End mto_aplicado,*/
       P.COD_MONEDA COD_MON_APL,
       p.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM (Select nro_cuenta cu_cuenta, sum(mto_int_documentado) cu_int_adelantado
                             from pr_cuotas
                            where nro_cuota > 0
                            Group by nro_cuenta),
       GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       PR_CTA_GARANTIAS G,
       PR_CTA_PRESTAMOS P
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
UNION ALL
SELECT S.NRO_LINEA,
       0 NRO_SEC_PADRE,
       S.COD_PERSONA,
       S.COD_MODALIDAD,
       S.COD_MODULO,
       'Prop.Nro. '||to_char(S.NRO_SOLICITUD) NRO_CUENTA,
       S.COD_MONEDA,
       S.TOT_PRESTAMO monto,
       S.FEC_INICIO,
       B.SIGNIFICADO ESTADO,
       T.DESCRIPCION TIPO_GAR,
       0 SALDO,
       g.cod_garantia,
       g.mto_aplicado,
       S.COD_MONEDA COD_MON_APL,
       s.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM BA_COD_REFERENCIAS B,
       PR_GAR_TIPOS T,
       PR_SOL_GARANTIAS G,
       PR_SOLICITUDES S
   WHERE S.NRO_LINEA IS NOT NULL
     AND S.ESTADO NOT IN  ('A','N','R')
     AND S.NRO_SOLICITUD = G.NRO_SOLICITUD
     AND S.ESTADO = B.VAL_MINIMO
     AND B.DOMINIO = 'EST_SOLICITUD'
     AND G.COD_GARANTIA = T.COD_GARANTIA
/* solicitudes de tarjeta de credito*/
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
       g.cod_garantia,
       g.mto_aplicado,
       s.cod_moneda,
       NULL FEC_VENCIMIENTO,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM GE_SOL_ESTADOS B,
       PR_GAR_TIPOS T,
       TA_SOL_GARANTIAS G,
       TA_SOLICITUDES S
   WHERE/* S.NRO_LINEA IS NULL --NOT NULL
     AND*/ S.COD_ESTADO IN ('PAN','APR')
     AND S.NRO_SOLICITUD = G.NRO_SOLICITUD
     AND S.COD_ESTADO = B.COD_ESTADO
     AND G.COD_GARANTIA = T.COD_GARANTIA
/* fin de tarjetas de credito solicitudes */
UNION ALL
SELECT SOB.NRO_LINEA,
       SOB.NRO_SEC_PADRE,
       CLI.COD_PERSONA,
       CTA.COD_MODALIDAD,
       CTA.COD_MODULO,
       SOB.NRO_CUENTA,
       SOB.COD_MONEDA,
       SOB.MONTO,
       SOB.FEC_INICIO,
       REF.SIGNIFICADO ESTADO,
       TIP.DESCRIPCION TIPO_GAR,
       nvl(CTA.SAL_TOTAL,0)-nvl(CTA.SAL_RETENIDO,0) SALDO,
       gar.cod_garantia,
       pag_gen.FU_CON_MON_A_MONEDA(sob.cod_moneda,lin.cod_moneda,sob.monto,sob.cotizacion)/lin.monto*gar.mto_aplicado mto_aplicado,
       --gar.mto_aplicado,
       LIN.COD_MONEDA COD_MON_APL,
       sob.fec_vencimiento fec_vencimiento,
       sob.cotizacion cotizacion,
       gar.nro_garantia
  FROM BA_COD_REFERENCIAS REF,
       GE_CTA_CLIENTES CLI,
       PR_GAR_TIPOS TIP,
       CC_CTA_CORRIENTES CTA,
       CC_LIN_SOB_GARANTIAS GAR,
       CC_LIN_SOBREGIROS LIN,
       CC_LIN_SOBREGIROS SOB
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
    --and sob.nro_cuenta = (Select min(nro_cuenta)
    --                        from cc_lin_sobregiros x
    --                       where x.nro_sec_padre = lin.nro_secuencia)

UNION ALL
SELECT NRO_LINEA NRO_LINEA,
       0 NRO_SEC_PADRE,
       C.COD_PERSONA,
       P.COD_MODALIDAD,
       P.COD_MODULO,
       P.NRO_CUENTA,
       P.COD_MONEDA,
       NVL(P.LIN_CREDITO,0)+nvl(p.lin_cuotas,0) monto,
       P.FEC_APERTURA FEC_INICIO,
       B.DESCRIPCION ESTADO,
       T.DESCRIPCION TIPO_GAR,
       nvl(P.sal_facturar,0)+nvl(P.sal_facturado,0)+nvl(P.sal_financiado,0) SALDO,
       g.cod_garantia,
       g.mto_aplicado,
       P.COD_MONEDA COD_MON_APL,
       to_date(null) fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       TA_CTA_GARANTIAS G,
       TA_CTA_TARJETAS P
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NOT NULL
   AND P.ESTADO <> 'C'
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
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
       g.cod_garantia,
       G.MTO_APLICADO,
       P.COD_MONEDA COD_MON_APL,
       p.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_CTA_IMPORTACIONES P
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NOT NULL
   AND P.ESTADO not in ('C','G')
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
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
       g.cod_garantia,
       G.MTO_APLICADO,
       P.COD_MONEDA COD_MON_APL,
       p.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_Cta_Exportaciones P
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NOT NULL
   AND P.ESTADO not in ('C','G')
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
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
       g.cod_garantia,
       G.MTO_APLICADO,
       P.COD_MONEDA COD_MON_APL,
       p.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  FROM GE_EST_CUENTAS B,
       PR_GAR_TIPOS T,
       GE_CTA_CLIENTES C,
       CX_CTA_GARANTIAS G,
       CX_FIANZAS P
 WHERE P.nro_cuenta = C.nro_cuenta
   AND C.relacion = 'P'
   AND P.NRO_LINEA IS NOT NULL
   AND P.ESTADO <> 'C'
   AND P.ESTADO = B.ESTADO
   AND P.COD_MODULO = B.COD_MODULO
   AND P.COD_MODALIDAD = B.COD_MODALIDAD
   AND P.NRO_CUENTA = G.NRO_CUENTA
   AND G.COD_GARANTIA = T.COD_GARANTIA
union all
select a.nro_linea,
       0 nro_sec_padre,
       a.cod_persona,
       a.cod_modalidad,
       a.cod_modulo,
       a.nro_cuenta,
       a.cod_moneda,
       a.monto + nvl(a.mto_interes, 0) monto,
       a.fec_inicio,
       Initcap(c.descripcion) ,
       t.descripcion tipo_gar,
       a.monto as saldo,
       g.cod_garantia,
       g.monto,
       a.cod_moneda cod_mon_apl,
       a.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  from ge_est_cuentas    c,
       PR_GAR_TIPOS T,
       ge_cta_clientes   b,
       md_cta_documentos a,
       md_garantias      g
 where b.nro_cuenta = a.nro_cuenta
   and t.cod_garantia(+) = g.cod_garantia
   and b.relacion = 'P'
   and a.estado = c.estado
   and a.cod_modulo = c.cod_modulo
   and a.cod_modalidad = c.cod_modalidad
   and g.nro_cuenta(+) = a.nro_cuenta
   and a.nro_linea is null
   and c.estado <> 'N'
union all
select a.nro_linea,
       0 nro_sec_padre,
       a.cod_persona,
       a.cod_modalidad,
       a.cod_modulo,
       a.nro_cuenta,
       a.cod_moneda,
       a.monto + nvl(a.mto_interes, 0) monto,
       a.fec_inicio,
       Initcap(c.descripcion) ,
       t.descripcion tipo_gar,
       a.monto as saldo,
       g.cod_garantia,
       g.monto,
       a.cod_moneda cod_mon_apl,
       a.fec_vencimiento fec_vencimiento,
       to_number(null) cotizacion,
       g.nro_garantia
  from ge_est_cuentas    c,
       PR_GAR_TIPOS T,
       ge_cta_clientes   b,
       md_cta_documentos a,
       md_garantias      g
 where b.nro_cuenta = a.nro_cuenta
   and t.cod_garantia(+) = g.cod_garantia
   and b.relacion = 'P'
   and a.estado = c.estado
   and a.cod_modulo = c.cod_modulo
   and a.cod_modalidad = c.cod_modalidad
   and g.nro_cuenta(+) = a.nro_cuenta
   and a.nro_linea is not null
   and c.estado <> 'N'
   union
select c.nro_linea,
       0 nro_sec_padre,
       b.cod_persona,
       c.cod_modalidad,
       c.cod_modulo,
       c.nro_cuenta,
       c.cod_moneda,
       c.mto_limite monto,
       c.fec_apertura fec_inicio,
       decode(c.estado,'N','Normal','P','Pendiente','A','Abierta','B','Bloqueada','C','Cancelada') estado,
       'SOLA FIRMA' tipo_gar,
       nvl(c.mto_limite,0) saldo,
       a.cod_garantia cod_garantia,
       c.mto_limite monto,
       c.cod_moneda cod_mon_apl,
       c.fec_vencimiento fec_vencimiento,
       0 cotizacion,
       nvl(c.mto_limite,0) Sal_aplicado
  from lc_cta_cambios    c,
       ge_cta_clientes   b,
       pr_lin_tip_gar_mad a
 where c.nro_cuenta = b.nro_cuenta
   and b.relacion = 'P'
   and c.estado != 'C'
   and c.nro_linea = a.nro_linea
   and c.cod_modulo = a.cod_modulo
   and c.cod_modalidad = a.cod_modalidad
   and a.mto_limite >= c.mto_limite
;

