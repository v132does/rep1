CREATE OR REPLACE FORCE VIEW IT.PV_LIN_OPERACIONES_HIS AS
SELECT DISTINCT  LIN.NRO_LINEA       ,
                 0 NRO_SEC_PADRE     ,
                 S.COD_PERSONA       ,
                 S.COD_MODALIDAD     ,
                 S.COD_MODULO        ,
                 'Prop.Nro. '||TO_CHAR(S.NRO_SOLICITUD) NRO_CUENTA,
                 S.COD_MONEDA        ,
                 S.TOT_PRESTAMO MONTO,
                 S.FEC_INICIO        ,
                 INITCAP(B.SIGNIFICADO) ESTADO,
                 T.DESCRIPCION TIPO_GAR       ,
                 0 SALDO             ,
                 0 SAL_INTERES       ,
                 S.FEC_VENCIMIENTO   ,
                 0 COTIZACION        ,
                 0 SAL_APLICADO      ,
                 X.COD_GRU_ECONOMICO
  FROM BA_COD_REFERENCIAS B,
       PR_GAR_TIPOS       T,
       PR_SOL_GARANTIAS   G,
       PR_SOLICITUDES     S,
       GE_CLIENTES        X,
       (SELECT distinct(LA.COD_PERSONA), LA.NRO_LINEA
                 FROM PR_LINEAS_HIS LA
                 WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                           FROM PR_LINEAS_HIS LB
                                          WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
   WHERE S.NRO_LINEA      IS NULL
     AND S.ESTADO         NOT IN  ('A','N','R')
     AND S.NRO_SOLICITUD  = G.NRO_SOLICITUD
     AND S.ESTADO         = B.VAL_MINIMO
     AND B.DOMINIO        = 'EST_SOLICITUD'
     AND G.COD_GARANTIA   = T.COD_GARANTIA
     AND X.COD_PERSONA(+) = S.COD_PERSONA
     and exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = s.nro_solicitud)
     AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                               FROM PR_GAR_TIPOS TIP,PR_SOL_GARANTIAS GAR
                              WHERE GAR.NRO_SOLICITUD = S.NRO_SOLICITUD
                                AND TIP.COD_GARANTIA  = GAR.COD_GARANTIA)
    AND X.COD_PERSONA = LIN.COD_PERSONA(+)
UNION ALL
-- Bloque de Préstamos que estuvieron bajo límites de créditos
SELECT LIN.NRO_LINEA     ,
       0 NRO_SEC_PADRE   ,
       C.COD_PERSONA     ,
       P.COD_MODALIDAD   ,
       P.COD_MODULO      ,
       P.NRO_CUENTA      ,
       P.COD_MONEDA      ,
       P.MTO_CAPITAL+NVL(CU_INT_ADELANTADO,0)        MONTO,
       P.FEC_INICIO      ,
       INITCAP(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION          TIPO_GAR,
       NVL(SAL_CAPITAL,0)+ NVL(SAL_INT_ADELANTADO,0) SALDO,
       NVL(SAL_INTERES,0)     SAL_INTERES,
       P.FEC_VENCIMIENTO ,
       0 COTIZACION      ,
       NVL(P.SAL_CAPITAL,0)   SAL_APLICADO,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS   B,
       (SELECT NRO_CUENTA CU_CUENTA,
               SUM(MTO_INT_DOCUMENTADO) CU_INT_ADELANTADO
          FROM PR_CUOTAS
         WHERE NRO_CUOTA > 0
         GROUP BY NRO_CUENTA),
       PR_GAR_TIPOS     T,
       GE_CTA_CLIENTES  C,
       PR_CTA_GARANTIAS G,
       PR_CTA_PRESTAMOS P,
       GE_CLIENTES      X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
                 FROM PR_LINEAS_HIS LA
                 WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                           FROM PR_LINEAS_HIS LB
                                          WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE CU_CUENTA          = P.NRO_CUENTA
   AND P.NRO_CUENTA       = C.NRO_CUENTA
   AND C.RELACION         = 'P'
   AND P.NRO_LINEA        IS NULL
   AND P.ESTADO           <> 'N'
   AND P.NRO_SOL_RENOVADA IS NULL
   AND P.ESTADO           = B.ESTADO
   AND P.COD_MODULO       = B.COD_MODULO
   AND P.COD_MODALIDAD    = B.COD_MODALIDAD
   AND P.NRO_CUENTA       = G.NRO_CUENTA
   AND G.COD_GARANTIA     = T.COD_GARANTIA
   AND X.COD_PERSONA(+)   = C.COD_PERSONA
   AND X.COD_PERSONA      = LIN.COD_PERSONA(+)
   and exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = p.nro_cuenta)
   AND (G.NRO_GARANTIA    = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                               FROM PR_GAR_TIPOS Y, PR_CTA_GARANTIAS X
                              WHERE X.NRO_CUENTA     = P.NRO_CUENTA
                                AND Y.COD_GARANTIA   = X.COD_GARANTIA
                                AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                          FROM PR_GAR_TIPOS TIP, PR_CTA_GARANTIAS GAR
                                                         WHERE TIP.COD_GARANTIA = GAR.COD_GARANTIA
                                                           AND GAR.NRO_CUENTA   = X.NRO_CUENTA)) OR
         (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                           FROM PR_GAR_TIPOS TIP, PR_CTA_GARANTIAS GAR
                                                          WHERE GAR.NRO_CUENTA   = P.NRO_CUENTA
                                                            AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
-- Bloque de Préstamos que NO estuvieron bajo límites de créditos
SELECT 0 NRO_LINEA     ,
       0 NRO_SEC_PADRE   ,
       C.COD_PERSONA     ,
       P.COD_MODALIDAD   ,
       P.COD_MODULO      ,
       P.NRO_CUENTA      ,
       P.COD_MONEDA      ,
       P.MTO_CAPITAL+NVL(CU_INT_ADELANTADO,0)        MONTO,
       P.FEC_INICIO      ,
       INITCAP(B.DESCRIPCION) ESTADO,
       T.DESCRIPCION          TIPO_GAR,
       NVL(SAL_CAPITAL,0)+ NVL(SAL_INT_ADELANTADO,0) SALDO,
       NVL(SAL_INTERES,0)     SAL_INTERES,
       P.FEC_VENCIMIENTO ,
       0 COTIZACION      ,
       NVL(P.SAL_CAPITAL,0)   SAL_APLICADO,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS   B,
       (SELECT NRO_CUENTA CU_CUENTA,
               SUM(MTO_INT_DOCUMENTADO) CU_INT_ADELANTADO
          FROM PR_CUOTAS
         WHERE NRO_CUOTA > 0
         GROUP BY NRO_CUENTA),
       PR_GAR_TIPOS     T,
       GE_CTA_CLIENTES  C,
       PR_CTA_GARANTIAS G,
       PR_CTA_PRESTAMOS P,
       GE_CLIENTES      X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
                 FROM PR_LINEAS_HIS LA
                 WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                           FROM PR_LINEAS_HIS LB
                                          WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE CU_CUENTA          = P.NRO_CUENTA
   AND P.NRO_CUENTA       = C.NRO_CUENTA
   AND C.RELACION         = 'P'
   AND P.NRO_LINEA        IS NULL
   AND P.ESTADO           <> 'N'
   AND P.NRO_SOL_RENOVADA IS NULL
   AND P.ESTADO           = B.ESTADO
   AND P.COD_MODULO       = B.COD_MODULO
   AND P.COD_MODALIDAD    = B.COD_MODALIDAD
   AND P.NRO_CUENTA       = G.NRO_CUENTA
   AND G.COD_GARANTIA     = T.COD_GARANTIA
   AND X.COD_PERSONA(+)   = C.COD_PERSONA
   AND X.COD_PERSONA      = LIN.COD_PERSONA(+)
   and not exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = p.nro_cuenta)
   AND (G.NRO_GARANTIA    = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                               FROM PR_GAR_TIPOS Y, PR_CTA_GARANTIAS X
                              WHERE X.NRO_CUENTA     = P.NRO_CUENTA
                                AND Y.COD_GARANTIA   = X.COD_GARANTIA
                                AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                          FROM PR_GAR_TIPOS TIP, PR_CTA_GARANTIAS GAR
                                                         WHERE TIP.COD_GARANTIA = GAR.COD_GARANTIA
                                                           AND GAR.NRO_CUENTA   = X.NRO_CUENTA)) OR
         (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                           FROM PR_GAR_TIPOS TIP, PR_CTA_GARANTIAS GAR
                                                          WHERE GAR.NRO_CUENTA   = P.NRO_CUENTA
                                                            AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
-- Bloque de Solcitudes de Tarjetas de Créditos que estuvieron bajo límites de créditos
SELECT LIN.NRO_LINEA       ,
       0 NRO_SEC_PADRE     ,
       S.COD_PERSONA       ,
       S.COD_MODALIDAD     ,
       S.COD_MODULO        ,
       'Sol.Nro. '||TO_CHAR(S.NRO_SOLICITUD) NRO_CUENTA,
       S.COD_MONEDA        ,
       S.MONTO MONTO       ,
       S.FEC_SOLICITUD     ,
       INITCAP(B.DESCRIPCION) ESTADO  ,
       T.DESCRIPCION          TIPO_GAR,
       0 SALDO             ,
       0                   ,
       NULL FEC_VENCIMIENTO,
       0 COTIZACION        ,
       0 SAL_APLICADO      ,
       X.COD_GRU_ECONOMICO
  FROM GE_SOL_ESTADOS   B,
       PR_GAR_TIPOS     T,
       TA_SOL_GARANTIAS G,
       TA_SOLICITUDES   S,
       GE_CLIENTES      X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
                 FROM PR_LINEAS_HIS LA
                 WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                           FROM PR_LINEAS_HIS LB
                                          WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
   WHERE S.NRO_LINEA       IS NULL
     AND S.COD_ESTADO      IN ('PAN','APR')
     AND S.NRO_SOLICITUD   = G.NRO_SOLICITUD
     AND S.COD_ESTADO      = B.COD_ESTADO
     AND G.COD_GARANTIA    = T.COD_GARANTIA
     AND X.COD_PERSONA(+)  = S.COD_PERSONA
     AND X.COD_PERSONA     = LIN.COD_PERSONA(+)
     and exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = s.nro_cuenta)
     AND T.PRI_APLICACION  = (SELECT MAX(PRI_APLICACION)
                                FROM PR_GAR_TIPOS TIP, TA_SOL_GARANTIAS GAR
                               WHERE GAR.NRO_SOLICITUD = S.NRO_SOLICITUD
                                 AND TIP.COD_GARANTIA  = GAR.COD_GARANTIA)
UNION ALL
-- Bloque de Solcitudes de Tarjetas de Créditos que NO estuvieron bajo límites de créditos
SELECT 0 NRO_LINEA       ,
       0 NRO_SEC_PADRE     ,
       S.COD_PERSONA       ,
       S.COD_MODALIDAD     ,
       S.COD_MODULO        ,
       'Sol.Nro. '||TO_CHAR(S.NRO_SOLICITUD) NRO_CUENTA,
       S.COD_MONEDA        ,
       S.MONTO MONTO       ,
       S.FEC_SOLICITUD     ,
       INITCAP(B.DESCRIPCION) ESTADO  ,
       T.DESCRIPCION          TIPO_GAR,
       0 SALDO             ,
       0                   ,
       NULL FEC_VENCIMIENTO,
       0 COTIZACION        ,
       0 SAL_APLICADO      ,
       X.COD_GRU_ECONOMICO
  FROM GE_SOL_ESTADOS   B,
       PR_GAR_TIPOS     T,
       TA_SOL_GARANTIAS G,
       TA_SOLICITUDES   S,
       GE_CLIENTES      X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
                 FROM PR_LINEAS_HIS LA
                 WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                           FROM PR_LINEAS_HIS LB
                                          WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
   WHERE S.NRO_LINEA       IS NULL
     AND S.COD_ESTADO      IN ('PAN','APR')
     AND S.NRO_SOLICITUD   = G.NRO_SOLICITUD
     AND S.COD_ESTADO      = B.COD_ESTADO
     AND G.COD_GARANTIA    = T.COD_GARANTIA
     AND X.COD_PERSONA(+)  = S.COD_PERSONA
     AND X.COD_PERSONA     = LIN.COD_PERSONA(+)
     and NOT exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = s.nro_cuenta)
     AND T.PRI_APLICACION  = (SELECT MAX(PRI_APLICACION)
                                FROM PR_GAR_TIPOS TIP, TA_SOL_GARANTIAS GAR
                               WHERE GAR.NRO_SOLICITUD = S.NRO_SOLICITUD
                                 AND TIP.COD_GARANTIA  = GAR.COD_GARANTIA)
UNION ALL
-- Bloque de Líneas de Sobregiros
SELECT DISTINCT LNA.NRO_LINEA       ,
                SOB.NRO_SEC_PADRE   ,
                CLI.COD_PERSONA     ,
                CTA.COD_MODALIDAD   ,
                CTA.COD_MODULO      ,
                SOB.NRO_CUENTA      ,
                SOB.COD_MONEDA      ,
                DECODE(GREATEST(FUC_OBT_MTO_LIN_SOB(CTA.NRO_CUENTA),(NVL(CTA.SAL_TOTAL,0)-NVL(CTA.SAL_RETENIDO,0))*-1),
                FUC_OBT_MTO_LIN_SOB(CTA.NRO_CUENTA), SOB.MONTO, (NVL(CTA.SAL_TOTAL,0)-NVL(CTA.SAL_RETENIDO,0))*-1) MONTO,
                SOB.FEC_INICIO      ,
                INITCAP(REF.SIGNIFICADO) ESTADO    ,
                TIP.DESCRIPCION          TIPO_GAR  ,
                NVL(CTA.SAL_TOTAL,0)-NVL(CTA.SAL_RETENIDO,0) SALDO,
                0                   ,
                LIN.FEC_VENCIMIENTO ,
                SOB.COTIZACION           COTIZACION,
                0 SAL_APLICADO      ,
                X.COD_GRU_ECONOMICO
  FROM BA_COD_REFERENCIAS   REF,
       PR_GAR_TIPOS         TIP,
       GE_CTA_CLIENTES      CLI,
       CC_CTA_CORRIENTES    CTA,
       CC_LIN_SOBREGIROS    LIN,
       CC_LIN_SOBREGIROS    SOB,
       CC_LIN_SOB_GARANTIAS GAR,
       GE_CLIENTES            X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
                 FROM PR_LINEAS_HIS LA
                 WHERE LA.ESTADO      IN ('V','C')
                   AND LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                           FROM PR_LINEAS_HIS LB
                                          WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LNA
  WHERE LIN.NRO_SECUENCIA    = SOB.NRO_SEC_PADRE
    AND SOB.TIPO             = 'P'
    AND SOB.ESTADO           = 'A'
    AND SOB.NRO_SEC_PADRE    = GAR.NRO_SECUENCIA
    AND SOB.ESTADO           = REF.VAL_MINIMO
    AND SOB.NRO_CUENTA       = CTA.NRO_CUENTA
    AND SOB.NRO_CUENTA       = CLI.NRO_CUENTA
    AND CLI.RELACION         = 'P'
    AND REF.DOMINIO          = 'EST_LIN_SOBREGIRO'
    AND SOB.NRO_LINEA        IS NULL
    AND GAR.COD_GARANTIA     = TIP.COD_GARANTIA
    AND X.COD_PERSONA(+)     = CLI.COD_PERSONA
    AND X.COD_PERSONA        = LNA.COD_PERSONA(+)
    and exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = cta.nro_cuenta)
    AND TIP.PRI_APLICACION   = (SELECT MAX(PRI_APLICACION)
                                  FROM PR_GAR_TIPOS T, CC_LIN_SOB_GARANTIAS G
                                 WHERE G.NRO_SECUENCIA = GAR.NRO_SECUENCIA
                                   AND T.COD_GARANTIA  = G.COD_GARANTIA)
UNION ALL
-- Bloque de Tarjetas de Créditos que estuvieron bajo límites de créditos
SELECT LIN.NRO_LINEA         ,
       0 NRO_SEC_PADRE       ,
       C.COD_PERSONA         ,
       P.COD_MODALIDAD       ,
       P.COD_MODULO          ,
       P.NRO_CUENTA          ,
       P.COD_MONEDA          ,
       NVL(P.LIN_CREDITO,0)+NVL(P.LIN_CUOTAS,0) MONTO,
       P.FEC_APERTURA         FEC_INICIO,
       INITCAP(B.DESCRIPCION) ESTADO    ,
       T.DESCRIPCION          TIPO_GAR  ,
       NVL(P.SAL_FACTURAR,0)+NVL(P.SAL_FACTURADO,0)+NVL(P.SAL_FINANCIADO,0) SALDO,
       0                     ,
       TO_DATE(NULL) FEC_VENCIMIENTO,
       0             COTIZACION     ,
       0             SAL_APLICADO   ,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS   B,
       PR_GAR_TIPOS     T,
       GE_CTA_CLIENTES  C,
       TA_CTA_GARANTIAS G,
       TA_CTA_TARJETAS  P,
       GE_CLIENTES      X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
                 FROM PR_LINEAS_HIS LA
                 WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                           FROM PR_LINEAS_HIS LB
                                          WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE P.NRO_CUENTA       = C.NRO_CUENTA
   AND C.RELACION         = 'P'
   AND P.NRO_LINEA        IS NULL
   AND P.ESTADO           <> 'C'
   AND P.ESTADO           = B.ESTADO
   AND P.COD_MODULO       = B.COD_MODULO
   AND P.COD_MODALIDAD    = B.COD_MODALIDAD
   AND P.NRO_CUENTA       = G.NRO_CUENTA
   AND G.COD_GARANTIA     = T.COD_GARANTIA
   AND X.COD_PERSONA(+)   = C.COD_PERSONA
   AND X.COD_PERSONA      = LIN.COD_PERSONA(+)
   and exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = p.nro_cuenta)
   AND (G.NRO_GARANTIA    = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                               FROM PR_GAR_TIPOS Y, TA_CTA_GARANTIAS X
                              WHERE X.NRO_CUENTA     = P.NRO_CUENTA
                                AND Y.COD_GARANTIA   = X.COD_GARANTIA
                                AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                          FROM PR_GAR_TIPOS TIP, TA_CTA_GARANTIAS GAR
                                                         WHERE GAR.NRO_CUENTA   = X.NRO_CUENTA
                                                           AND TIP.COD_GARANTIA = Y.COD_GARANTIA)) OR
                            (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                                              FROM PR_GAR_TIPOS TIP, TA_CTA_GARANTIAS GAR
                                                                             WHERE GAR.NRO_CUENTA   = P.NRO_CUENTA
                                                                               AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
-- Bloque de Tarjetas de Créditos que NO estuvieron bajo límites de créditos
SELECT 0 NRO_LINEA         ,
       0 NRO_SEC_PADRE       ,
       C.COD_PERSONA         ,
       P.COD_MODALIDAD       ,
       P.COD_MODULO          ,
       P.NRO_CUENTA          ,
       P.COD_MONEDA          ,
       NVL(P.LIN_CREDITO,0)+NVL(P.LIN_CUOTAS,0) MONTO,
       P.FEC_APERTURA         FEC_INICIO,
       INITCAP(B.DESCRIPCION) ESTADO    ,
       T.DESCRIPCION          TIPO_GAR  ,
       NVL(P.SAL_FACTURAR,0)+NVL(P.SAL_FACTURADO,0)+NVL(P.SAL_FINANCIADO,0) SALDO,
       0                     ,
       TO_DATE(NULL) FEC_VENCIMIENTO,
       0             COTIZACION     ,
       0             SAL_APLICADO   ,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS   B,
       PR_GAR_TIPOS     T,
       GE_CTA_CLIENTES  C,
       TA_CTA_GARANTIAS G,
       TA_CTA_TARJETAS  P,
       GE_CLIENTES      X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
                 FROM PR_LINEAS_HIS LA
                 WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                           FROM PR_LINEAS_HIS LB
                                          WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE P.NRO_CUENTA       = C.NRO_CUENTA
   AND C.RELACION         = 'P'
   AND P.NRO_LINEA        IS NULL
   AND P.ESTADO           <> 'C'
   AND P.ESTADO           = B.ESTADO
   AND P.COD_MODULO       = B.COD_MODULO
   AND P.COD_MODALIDAD    = B.COD_MODALIDAD
   AND P.NRO_CUENTA       = G.NRO_CUENTA
   AND G.COD_GARANTIA     = T.COD_GARANTIA
   AND X.COD_PERSONA(+)   = C.COD_PERSONA
   AND X.COD_PERSONA      = LIN.COD_PERSONA(+)
   and NOT exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = p.nro_cuenta)
   AND (G.NRO_GARANTIA    = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                               FROM PR_GAR_TIPOS Y, TA_CTA_GARANTIAS X
                              WHERE X.NRO_CUENTA     = P.NRO_CUENTA
                                AND Y.COD_GARANTIA   = X.COD_GARANTIA
                                AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                          FROM PR_GAR_TIPOS TIP, TA_CTA_GARANTIAS GAR
                                                         WHERE GAR.NRO_CUENTA   = X.NRO_CUENTA
                                                           AND TIP.COD_GARANTIA = Y.COD_GARANTIA)) OR
                            (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                                              FROM PR_GAR_TIPOS TIP, TA_CTA_GARANTIAS GAR
                                                                             WHERE GAR.NRO_CUENTA   = P.NRO_CUENTA
                                                                               AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
-- Bloque de Comercio Exterior que estuvieron bajo límites de créditos: Importaciones
SELECT LIN.NRO_LINEA        ,
       0 NRO_SEC_PADRE      ,
       C.COD_PERSONA        ,
       P.COD_MODALIDAD      ,
       P.COD_MODULO         ,
       P.NRO_CUENTA         ,
       P.COD_MONEDA         ,
       P.MONTO MONTO        ,
       P.FEC_SOLICITUD      ,
       INITCAP(B.DESCRIPCION) ESTADO  ,
       T.DESCRIPCION          TIPO_GAR,
       P.SALDO              ,
       0                    ,
       P.FEC_VENCIMIENTO    ,
       0 COTIZACION         ,
       0 SAL_APLICADO       ,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS       B,
       PR_GAR_TIPOS         T,
       GE_CTA_CLIENTES      C,
       CX_CTA_GARANTIAS     G,
       CX_CTA_IMPORTACIONES P,
       GE_CLIENTES          X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
         FROM PR_LINEAS_HIS LA
         WHERE LA.ESTADO      IN ('V','C')
           AND LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                   FROM PR_LINEAS_HIS LB
                                  WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE P.NRO_CUENTA      = C.NRO_CUENTA
   AND C.RELACION        = 'P'
   AND P.NRO_LINEA       IS NULL
   AND P.ESTADO          NOT IN ('C','G')
   AND P.ESTADO          = B.ESTADO
   AND P.COD_MODULO      = B.COD_MODULO
   AND P.COD_MODALIDAD   = B.COD_MODALIDAD
   AND P.NRO_CUENTA      = G.NRO_CUENTA
   AND G.COD_GARANTIA    = T.COD_GARANTIA
   AND X.COD_PERSONA(+)  = C.COD_PERSONA
   AND X.COD_PERSONA     = LIN.COD_PERSONA(+)
   and exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = p.nro_cuenta)
   AND (G.NRO_GARANTIA   = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                              FROM PR_GAR_TIPOS Y, CX_CTA_GARANTIAS X
                             WHERE X.NRO_CUENTA     = P.NRO_CUENTA
                               AND Y.COD_GARANTIA   = X.COD_GARANTIA
                               AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                         FROM PR_GAR_TIPOS TIP,CX_CTA_GARANTIAS GAR
                                                        WHERE TIP.COD_GARANTIA = GAR.COD_GARANTIA
                                                          AND GAR.NRO_CUENTA = X.NRO_CUENTA))  OR
                           (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                                             FROM PR_GAR_TIPOS TIP, CX_CTA_GARANTIAS GAR
                                                                            WHERE GAR.NRO_CUENTA   = P.NRO_CUENTA
                                                                              AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
-- Bloque de Comercio Exterior que NO estuvieron bajo límites de créditos: Importaciones
SELECT 0 NRO_LINEA        ,
       0 NRO_SEC_PADRE      ,
       C.COD_PERSONA        ,
       P.COD_MODALIDAD      ,
       P.COD_MODULO         ,
       P.NRO_CUENTA         ,
       P.COD_MONEDA         ,
       P.MONTO MONTO        ,
       P.FEC_SOLICITUD      ,
       INITCAP(B.DESCRIPCION) ESTADO  ,
       T.DESCRIPCION          TIPO_GAR,
       P.SALDO              ,
       0                    ,
       P.FEC_VENCIMIENTO    ,
       0 COTIZACION         ,
       0 SAL_APLICADO       ,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS       B,
       PR_GAR_TIPOS         T,
       GE_CTA_CLIENTES      C,
       CX_CTA_GARANTIAS     G,
       CX_CTA_IMPORTACIONES P,
       GE_CLIENTES          X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
         FROM PR_LINEAS_HIS LA
         WHERE LA.ESTADO      IN ('V','C')
           AND LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                   FROM PR_LINEAS_HIS LB
                                  WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE P.NRO_CUENTA      = C.NRO_CUENTA
   AND C.RELACION        = 'P'
   AND P.NRO_LINEA       IS NULL
   AND P.ESTADO          NOT IN ('C','G')
   AND P.ESTADO          = B.ESTADO
   AND P.COD_MODULO      = B.COD_MODULO
   AND P.COD_MODALIDAD   = B.COD_MODALIDAD
   AND P.NRO_CUENTA      = G.NRO_CUENTA
   AND G.COD_GARANTIA    = T.COD_GARANTIA
   AND X.COD_PERSONA(+)  = C.COD_PERSONA
   AND X.COD_PERSONA     = LIN.COD_PERSONA(+)
   and NOT exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = p.nro_cuenta)
   AND (G.NRO_GARANTIA   = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                              FROM PR_GAR_TIPOS Y, CX_CTA_GARANTIAS X
                             WHERE X.NRO_CUENTA     = P.NRO_CUENTA
                               AND Y.COD_GARANTIA   = X.COD_GARANTIA
                               AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                         FROM PR_GAR_TIPOS TIP,CX_CTA_GARANTIAS GAR
                                                        WHERE TIP.COD_GARANTIA = GAR.COD_GARANTIA
                                                          AND GAR.NRO_CUENTA = X.NRO_CUENTA))  OR
                           (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                                             FROM PR_GAR_TIPOS TIP, CX_CTA_GARANTIAS GAR
                                                                            WHERE GAR.NRO_CUENTA   = P.NRO_CUENTA
                                                                              AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
-- Bloque de Comercio Exterior que estuvieron bajo límites de Créditos: Exportaciones
SELECT LIN.NRO_LINEA      ,
       0 NRO_SEC_PADRE    ,
       C.COD_PERSONA      ,
       P.COD_MODALIDAD    ,
       P.COD_MODULO       ,
       P.NRO_CUENTA       ,
       P.COD_MONEDA       ,
       P.MONTO MONTO      ,
       P.FEC_SOLICITUD    ,
       INITCAP(B.DESCRIPCION) ESTADO  ,
       T.DESCRIPCION          TIPO_GAR,
       P.SALDO            ,
       0                  ,
       P.FEC_VENCIMIENTO  ,
       0 COTIZACION       ,
       0 SAL_APLICADO     ,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS       B,
       PR_GAR_TIPOS         T,
       GE_CTA_CLIENTES      C,
       CX_CTA_GARANTIAS     G,
       CX_CTA_EXPORTACIONES P,
       GE_CLIENTES          X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
         FROM PR_LINEAS_HIS LA
         WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                   FROM PR_LINEAS_HIS LB
                                  WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE P.NRO_CUENTA      = C.NRO_CUENTA
   AND C.RELACION        = 'P'
   AND P.NRO_LINEA       IS NULL
   AND P.ESTADO          NOT IN ('C','G')
   AND P.ESTADO          = B.ESTADO
   AND P.COD_MODULO      = B.COD_MODULO
   AND P.COD_MODALIDAD   = B.COD_MODALIDAD
   AND P.NRO_CUENTA      = G.NRO_CUENTA
   AND G.COD_GARANTIA    = T.COD_GARANTIA
   AND X.COD_PERSONA(+)  = C.COD_PERSONA
   AND X.COD_PERSONA     = LIN.COD_PERSONA(+)
   and exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = p.nro_cuenta)
   AND (G.NRO_GARANTIA   = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                              FROM PR_GAR_TIPOS Y, CX_CTA_GARANTIAS X
                             WHERE X.NRO_CUENTA     = P.NRO_CUENTA
                               AND Y.COD_GARANTIA   = X.COD_GARANTIA
                               AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                         FROM PR_GAR_TIPOS TIP, CX_CTA_GARANTIAS GAR
                                                       WHERE TIP.COD_GARANTIA = GAR.COD_GARANTIA
                                                         AND GAR.NRO_CUENTA   = X.NRO_CUENTA))  OR
                           (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                                             FROM PR_GAR_TIPOS TIP, CX_CTA_GARANTIAS GAR
                                                                            WHERE GAR.NRO_CUENTA   = P.NRO_CUENTA
                                                                              AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
-- Bloque de Comercio Exterior que NO estuvieron bajo límites de Créditos: Exportaciones
SELECT 0 NRO_LINEA      ,
       0 NRO_SEC_PADRE    ,
       C.COD_PERSONA      ,
       P.COD_MODALIDAD    ,
       P.COD_MODULO       ,
       P.NRO_CUENTA       ,
       P.COD_MONEDA       ,
       P.MONTO MONTO      ,
       P.FEC_SOLICITUD    ,
       INITCAP(B.DESCRIPCION) ESTADO  ,
       T.DESCRIPCION          TIPO_GAR,
       P.SALDO            ,
       0                  ,
       P.FEC_VENCIMIENTO  ,
       0 COTIZACION       ,
       0 SAL_APLICADO     ,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS       B,
       PR_GAR_TIPOS         T,
       GE_CTA_CLIENTES      C,
       CX_CTA_GARANTIAS     G,
       CX_CTA_EXPORTACIONES P,
       GE_CLIENTES          X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
         FROM PR_LINEAS_HIS LA
         WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                   FROM PR_LINEAS_HIS LB
                                  WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE P.NRO_CUENTA      = C.NRO_CUENTA
   AND C.RELACION        = 'P'
   AND P.NRO_LINEA       IS NULL
   AND P.ESTADO          NOT IN ('C','G')
   AND P.ESTADO          = B.ESTADO
   AND P.COD_MODULO      = B.COD_MODULO
   AND P.COD_MODALIDAD   = B.COD_MODALIDAD
   AND P.NRO_CUENTA      = G.NRO_CUENTA
   AND G.COD_GARANTIA    = T.COD_GARANTIA
   AND X.COD_PERSONA(+)  = C.COD_PERSONA
   AND X.COD_PERSONA     = LIN.COD_PERSONA(+)
   and not exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = p.nro_cuenta)
   AND (G.NRO_GARANTIA   = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                              FROM PR_GAR_TIPOS Y, CX_CTA_GARANTIAS X
                             WHERE X.NRO_CUENTA     = P.NRO_CUENTA
                               AND Y.COD_GARANTIA   = X.COD_GARANTIA
                               AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                         FROM PR_GAR_TIPOS TIP, CX_CTA_GARANTIAS GAR
                                                       WHERE TIP.COD_GARANTIA = GAR.COD_GARANTIA
                                                         AND GAR.NRO_CUENTA   = X.NRO_CUENTA))  OR
                           (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                                             FROM PR_GAR_TIPOS TIP, CX_CTA_GARANTIAS GAR
                                                                            WHERE GAR.NRO_CUENTA   = P.NRO_CUENTA
                                                                              AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
-- Bloque de Comercio Exterior que estuvieron bajo límites de créditos: Fianzas
SELECT LIN.NRO_LINEA        ,
       0 NRO_SEC_PADRE      ,
       C.COD_PERSONA        ,
       P.COD_MODALIDAD      ,
       P.COD_MODULO         ,
       P.NRO_CUENTA         ,
       P.COD_MONEDA         ,
       P.MONTO MONTO        ,
       P.FEC_CONCESION      ,
       INITCAP(B.DESCRIPCION) ESTADO  ,
       T.DESCRIPCION          TIPO_GAR,
       P.MONTO                SALDO   ,
       0                    ,
       P.FEC_VENCIMIENTO    ,
       0 COTIZACION         ,
       0 SAL_APLICADO       ,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS   B,
       PR_GAR_TIPOS     T,
       GE_CTA_CLIENTES  C,
       CX_CTA_GARANTIAS G,
       CX_FIANZAS       P,
       GE_CLIENTES      X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
         FROM PR_LINEAS_HIS LA
         WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                   FROM PR_LINEAS_HIS LB
                                  WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE P.NRO_CUENTA      = C.NRO_CUENTA
   AND C.RELACION        = 'P'
   AND P.NRO_LINEA       IS NULL
   AND P.ESTADO          <> 'C'
   AND P.ESTADO          = B.ESTADO
   AND P.COD_MODULO      = B.COD_MODULO
   AND P.COD_MODALIDAD   = B.COD_MODALIDAD
   AND P.NRO_CUENTA      = G.NRO_CUENTA
   AND G.COD_GARANTIA    = T.COD_GARANTIA
   AND X.COD_PERSONA(+)  = C.COD_PERSONA
   AND X.COD_PERSONA     = LIN.COD_PERSONA(+)
   and exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = p.nro_cuenta)
   AND (G.NRO_GARANTIA   = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                              FROM PR_GAR_TIPOS Y, CX_CTA_GARANTIAS X
                             WHERE X.NRO_CUENTA = P.NRO_CUENTA
                               AND Y.COD_GARANTIA = X.COD_GARANTIA
                               AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                         FROM PR_GAR_TIPOS TIP, CX_CTA_GARANTIAS GAR
                                                        WHERE TIP.COD_GARANTIA = GAR.COD_GARANTIA
                                                          AND GAR.NRO_CUENTA   = X.NRO_CUENTA))  OR
                           (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                                             FROM PR_GAR_TIPOS TIP, CX_CTA_GARANTIAS GAR
                                                                            WHERE GAR.NRO_CUENTA   = P.NRO_CUENTA
                                                                              AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION ALL
-- Bloque de Comercio Exterior que NO estuvieron bajo límites de créditos: Fianzas
SELECT 0 NRO_LINEA        ,
       0 NRO_SEC_PADRE      ,
       C.COD_PERSONA        ,
       P.COD_MODALIDAD      ,
       P.COD_MODULO         ,
       P.NRO_CUENTA         ,
       P.COD_MONEDA         ,
       P.MONTO MONTO        ,
       P.FEC_CONCESION      ,
       INITCAP(B.DESCRIPCION) ESTADO  ,
       T.DESCRIPCION          TIPO_GAR,
       P.MONTO                SALDO   ,
       0                    ,
       P.FEC_VENCIMIENTO    ,
       0 COTIZACION         ,
       0 SAL_APLICADO       ,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS   B,
       PR_GAR_TIPOS     T,
       GE_CTA_CLIENTES  C,
       CX_CTA_GARANTIAS G,
       CX_FIANZAS       P,
       GE_CLIENTES      X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
         FROM PR_LINEAS_HIS LA
         WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                   FROM PR_LINEAS_HIS LB
                                  WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE P.NRO_CUENTA      = C.NRO_CUENTA
   AND C.RELACION        = 'P'
   AND P.NRO_LINEA       IS NULL
   AND P.ESTADO          <> 'C'
   AND P.ESTADO          = B.ESTADO
   AND P.COD_MODULO      = B.COD_MODULO
   AND P.COD_MODALIDAD   = B.COD_MODALIDAD
   AND P.NRO_CUENTA      = G.NRO_CUENTA
   AND G.COD_GARANTIA    = T.COD_GARANTIA
   AND X.COD_PERSONA(+)  = C.COD_PERSONA
   AND X.COD_PERSONA     = LIN.COD_PERSONA(+)
   and not exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = p.nro_cuenta)
   AND (G.NRO_GARANTIA   = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                              FROM PR_GAR_TIPOS Y, CX_CTA_GARANTIAS X
                             WHERE X.NRO_CUENTA = P.NRO_CUENTA
                               AND Y.COD_GARANTIA = X.COD_GARANTIA
                               AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                         FROM PR_GAR_TIPOS TIP, CX_CTA_GARANTIAS GAR
                                                        WHERE TIP.COD_GARANTIA = GAR.COD_GARANTIA
                                                          AND GAR.NRO_CUENTA   = X.NRO_CUENTA))  OR
                           (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                                             FROM PR_GAR_TIPOS TIP, CX_CTA_GARANTIAS GAR
                                                                            WHERE GAR.NRO_CUENTA   = P.NRO_CUENTA
                                                                              AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION
-- Bloque de Comercio Exterior que estuvieron bajo límites de créditos: Documentos
SELECT LIN.NRO_LINEA          ,
       0 NRO_SEC_PADRE        ,
       A.COD_PERSONA          ,
       A.COD_MODALIDAD        ,
       A.COD_MODULO           ,
       A.NRO_CUENTA           ,
       A.COD_MONEDA           ,
       A.MONTO                ,
       A.FEC_INICIO           ,
       INITCAP(C.DESCRIPCION) ,
       T.DESCRIPCION TIPO_GAR ,
       A.MONTO AS SALDO       ,
       G.MONTO                ,
       A.FEC_VENCIMIENTO FEC_VENCIMIENTO,
       TO_NUMBER(NULL)   COTIZACION     ,
       A.MONTO*NVL(PAG_GEN.FU_OBT_COTIZACION( A.COD_MONEDA, PAG_CAL.FU_OBT_FEC_ACTUAL(1)),1) AS SAL_APLICADO,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS    C,
       PR_GAR_TIPOS      T,
       GE_CTA_CLIENTES   B,
       MD_CTA_DOCUMENTOS A,
       MD_GARANTIAS      G,
       GE_CLIENTES       X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
         FROM PR_LINEAS_HIS LA
         WHERE LA.ESTADO      IN ('V','C')
           AND LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                   FROM PR_LINEAS_HIS LB
                                  WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE B.NRO_CUENTA       = A.NRO_CUENTA
   AND T.COD_GARANTIA(+)  = G.COD_GARANTIA
   AND B.RELACION         = 'P'
   AND A.ESTADO           = C.ESTADO
   AND C.ACTIVO           = 'S'
   AND A.COD_MODULO       = C.COD_MODULO
   AND A.COD_MODALIDAD    = C.COD_MODALIDAD
   AND G.NRO_CUENTA(+)    = A.NRO_CUENTA
   AND A.NRO_LINEA        IS NULL
   AND X.COD_PERSONA(+)   = B.COD_PERSONA
   AND X.COD_PERSONA      = LIN.COD_PERSONA(+)
   and exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = a.nro_cuenta)
   AND (G.NRO_GARANTIA    = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                               FROM PR_GAR_TIPOS Y, MD_GARANTIAS X
                              WHERE X.NRO_CUENTA     = A.NRO_CUENTA
                                AND Y.COD_GARANTIA   = X.COD_GARANTIA
                                AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                          FROM PR_GAR_TIPOS TIP, MD_GARANTIAS GAR
                                                         WHERE GAR.NRO_CUENTA   = X.NRO_CUENTA
                                                           AND TIP.COD_GARANTIA = Y.COD_GARANTIA)) OR
                            (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                                              FROM PR_GAR_TIPOS TIP, MD_GARANTIAS GAR
                                                                             WHERE GAR.NRO_CUENTA   = A.NRO_CUENTA
                                                                               AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION
-- Bloque de Comercio Exterior que NO estuvieron bajo límites de créditos: Documentos
SELECT 0 NRO_LINEA          ,
       0 NRO_SEC_PADRE        ,
       A.COD_PERSONA          ,
       A.COD_MODALIDAD        ,
       A.COD_MODULO           ,
       A.NRO_CUENTA           ,
       A.COD_MONEDA           ,
       A.MONTO                ,
       A.FEC_INICIO           ,
       INITCAP(C.DESCRIPCION) ,
       T.DESCRIPCION TIPO_GAR ,
       A.MONTO AS SALDO       ,
       G.MONTO                ,
       A.FEC_VENCIMIENTO FEC_VENCIMIENTO,
       TO_NUMBER(NULL)   COTIZACION     ,
       A.MONTO*NVL(PAG_GEN.FU_OBT_COTIZACION( A.COD_MONEDA, PAG_CAL.FU_OBT_FEC_ACTUAL(1)),1) AS SAL_APLICADO,
       X.COD_GRU_ECONOMICO
  FROM GE_EST_CUENTAS    C,
       PR_GAR_TIPOS      T,
       GE_CTA_CLIENTES   B,
       MD_CTA_DOCUMENTOS A,
       MD_GARANTIAS      G,
       GE_CLIENTES       X,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
         FROM PR_LINEAS_HIS LA
         WHERE LA.ESTADO      IN ('V','C')
           AND LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                   FROM PR_LINEAS_HIS LB
                                  WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE B.NRO_CUENTA       = A.NRO_CUENTA
   AND T.COD_GARANTIA(+)  = G.COD_GARANTIA
   AND B.RELACION         = 'P'
   AND A.ESTADO           = C.ESTADO
   AND C.ACTIVO           = 'S'
   AND A.COD_MODULO       = C.COD_MODULO
   AND A.COD_MODALIDAD    = C.COD_MODALIDAD
   AND G.NRO_CUENTA(+)    = A.NRO_CUENTA
   AND A.NRO_LINEA        IS NULL
   AND X.COD_PERSONA(+)   = B.COD_PERSONA
   AND X.COD_PERSONA      = LIN.COD_PERSONA(+)
   and not exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = a.nro_cuenta)
   AND (G.NRO_GARANTIA    = (SELECT MIN(NVL(X.NRO_GARANTIA,0))
                               FROM PR_GAR_TIPOS Y, MD_GARANTIAS X
                              WHERE X.NRO_CUENTA     = A.NRO_CUENTA
                                AND Y.COD_GARANTIA   = X.COD_GARANTIA
                                AND Y.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                          FROM PR_GAR_TIPOS TIP, MD_GARANTIAS GAR
                                                         WHERE GAR.NRO_CUENTA   = X.NRO_CUENTA
                                                           AND TIP.COD_GARANTIA = Y.COD_GARANTIA)) OR
                            (G.NRO_GARANTIA IS NULL AND T.PRI_APLICACION = (SELECT MAX(PRI_APLICACION)
                                                                              FROM PR_GAR_TIPOS TIP, MD_GARANTIAS GAR
                                                                             WHERE GAR.NRO_CUENTA   = A.NRO_CUENTA
                                                                               AND TIP.COD_GARANTIA = GAR.COD_GARANTIA)))
UNION
-- Bloque de Cambios que estuvieron bajo límites de créditos
SELECT LIN.NRO_LINEA             ,
       0 NRO_SEC_PADRE           ,
       B.COD_PERSONA             ,
       LC.COD_MODALIDAD          ,
       LC.COD_MODULO             ,
       LC.NRO_CUENTA             ,
       LC.COD_MONEDA             ,
       LC.MTO_LIMITE   MONTO     ,
       LC.FEC_APERTURA FEC_INICIO,
       INITCAP(C.DESCRIPCION)    ,
       'SOLA FIRMA' TIPO_GAR     ,
       NVL(LC.MTO_LIMITE,0) SALDO,
       NVL(LC.MTO_LIMITE,0) MONTO,
       LC.FEC_VENCIMIENTO FEC_VENCIMIENTO,
       0 COTIZACION              ,
       NVL(LC.MTO_LIMITE,0) SAL_APLICADO ,
       X.COD_GRU_ECONOMICO

  FROM LC_CTA_CAMBIOS    LC,
       GE_CTA_CLIENTES    B,
       GE_CLIENTES        X,
       GE_EST_CUENTAS     C,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
         FROM PR_LINEAS_HIS LA
         WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                   FROM PR_LINEAS_HIS LB
                                  WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE LC.NRO_CUENTA   = B.NRO_CUENTA
   AND B.COD_MODULO    = C.COD_MODULO
   AND B.COD_MODALIDAD = C.COD_MODALIDAD
   AND LC.ESTADO       = C.ESTADO
   AND B.RELACION      = 'P'
   AND B.COD_PERSONA   = X.COD_PERSONA
   AND X.COD_PERSONA   = LIN.COD_PERSONA(+)
   and exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = lc.nro_cuenta)
UNION
-- Bloque de Cambios que NO estuvieron bajo límites de créditos
SELECT 0 NRO_LINEA             ,
       0 NRO_SEC_PADRE           ,
       B.COD_PERSONA             ,
       LC.COD_MODALIDAD          ,
       LC.COD_MODULO             ,
       LC.NRO_CUENTA             ,
       LC.COD_MONEDA             ,
       LC.MTO_LIMITE   MONTO     ,
       LC.FEC_APERTURA FEC_INICIO,
       INITCAP(C.DESCRIPCION)    ,
       'SOLA FIRMA' TIPO_GAR     ,
       NVL(LC.MTO_LIMITE,0) SALDO,
       NVL(LC.MTO_LIMITE,0) MONTO,
       LC.FEC_VENCIMIENTO FEC_VENCIMIENTO,
       0 COTIZACION              ,
       NVL(LC.MTO_LIMITE,0) SAL_APLICADO ,
       X.COD_GRU_ECONOMICO

  FROM LC_CTA_CAMBIOS    LC,
       GE_CTA_CLIENTES    B,
       GE_CLIENTES        X,
       GE_EST_CUENTAS     C,
       (SELECT DISTINCT(LA.COD_PERSONA), LA.NRO_LINEA
         FROM PR_LINEAS_HIS LA
         WHERE LA.NRO_LINEA   = (SELECT MAX(LB.NRO_LINEA)
                                   FROM PR_LINEAS_HIS LB
                                  WHERE LB.COD_PERSONA = LA.COD_PERSONA)
                   AND NOT EXISTS(SELECT 1
                                   FROM PR_LINEAS AX
                                   WHERE AX.COD_PERSONA = LA.COD_PERSONA
                                     AND AX.ESTADO IN ('A','P'))) LIN
 WHERE LC.NRO_CUENTA   = B.NRO_CUENTA
   AND B.COD_MODULO    = C.COD_MODULO
   AND B.COD_MODALIDAD = C.COD_MODALIDAD
   AND LC.ESTADO       = C.ESTADO
   AND B.RELACION      = 'P'
   AND B.COD_PERSONA   = X.COD_PERSONA
   AND X.COD_PERSONA   = LIN.COD_PERSONA(+)
   and not exists(Select 1
                from pr_lin_vin_productos_his hi
               where hi.nro_linea   = lin.nro_linea
                 and hi.nro_cuenta  = lc.nro_cuenta)
;

