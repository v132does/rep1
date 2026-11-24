CREATE OR REPLACE VIEW IT.GV_CAR_PASIVA AS
SELECT TO_CHAR((pag_cal.fu_obt_fec_actual(6)), 'yyyy-mm-dd') AS FECHA_PROCESO,
  ah.cod_oficina AS SUCURSAL_COD,
  FUE_OBT_DES_OFICINA(ah.cod_oficina) AS sucursal,
  cl.cod_usu_oficial AS ASESOR,
  cl.cod_persona AS COD_PERSONA,
  p.nom_completo AS NOMBRE_CLIENTE,
  p.cod_actividad AS COD_ACTIVIDAD,
  DECODE(FUG_OBT_DES_ACTIVIDAD (P.COD_ACTIVIDAD),'Rubro / Actividad no registrados en el Sistema','',FUG_OBT_DES_ACTIVIDAD (P.COD_ACTIVIDAD)) AS DES_ACTIVIDAD,
  cl.cod_tip_deudor AS COD_TIP_DEUDOR,
  de.descripcion  AS TIP_DEUDOR,
  p.nro_documento AS NRO_DOC,
  PF.COD_SEXO AS SEXO,
  to_char(PF.FEC_NACIMIENTO, 'yyyy-mm-dd') AS FEC_NACIMIENTO,
  cl.COD_GRU_ECONOMICO as COD_GRU_ECONOMICO,
  GRU.DESCRIPCION AS DES_GRU_ECONOMICO,
  ah.cod_modulo AS MODULO_COD,
  MC.DESCRIPCION AS MODULO,
  ah.cod_modalidad AS MODALIDAD_COD,
  FUG_OBT_DES_MODAL(AH.COD_MODULO,AH.COD_MODALIDAD) MODALIDAD,
  ah.cod_sub_modalidad AS sub_modalidad_cod,
  sub_m.descripcion AS sub_modalidad,
  ah.cod_tasa AS COD_TASA,
  GT.DESCRIPCION AS DES_TASA,
  Ct.val_tasa,
  ah.denominacion AS DENOMINACION,
  ah.estado as ESTADO_COD,
  FUG_OBT_DES_EST_CTA(ah.COD_MODULO,ah.COD_MODALIDAD,ah.ESTADO) AS ESTADO,
  0 AS PLAZO,
  '' AS DES_PLAZO,
  ah.nro_cuenta AS NRO_CUENTA,
  AH.DIG_VERIFICADOR AS DIG_VERIFICADOR,
  ah.cod_moneda AS COD_MONEDA,
  NVL((fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))),1) as cotizacion,
  (ah.sal_Total-ah.sal_retenido) AS SALDO_OR,
  CASE
    WHEN AH.COD_MONEDA = 'USD' THEN NVL(ROUND(((ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0)
  ELSE (ah.sal_Total-ah.sal_retenido)
  END AS SALDO_GS,
  CASE
    WHEN AH.COD_MONEDA = 'GS' THEN NVL(ROUND(((ah.sal_Total-ah.sal_retenido) /(fug_obt_cotizacion('USD',pag_cal.fu_obt_fec_actual(6))))),0)
  ELSE (ah.sal_Total-ah.sal_retenido)
  END AS SALDO_USD,
  To_char(ah.FEC_APERTURA,'yyyy-mm-dd') AS FECHA_VALOR,
  To_char(ah.fec_ult_movimiento,'yyyy-mm-dd') AS FECHA_ULT_MOVIMIENTO,
  '' AS fecha_vencimiento,
  NVL((SELECT SUM(SAL_PROMEDIO)
      FROM AH_CAPITALIZACIONES
      WHERE FEC_INICIO = (SELECT MAX(CAP.FEC_INICIO)
                FROM AH_CAPITALIZACIONES CAP
                WHERE CAP.NRO_CUENTA = AH.NRO_CUENTA
                AND CAP.COD_MODALIDAD = AH.COD_MODALIDAD
                AND CAP.COD_MODULO = AH.COD_MODULO)
      AND NRO_CUENTA = AH.NRO_CUENTA),0) AS SAL_PROMEDIO_OR,
  CASE
    WHEN AH.COD_MONEDA = 'USD' THEN NVL(ROUND(((SELECT SUM(SAL_PROMEDIO)
                            FROM AH_CAPITALIZACIONES
                            WHERE FEC_INICIO = (SELECT MAX(CAP.FEC_INICIO)
                                      FROM AH_CAPITALIZACIONES CAP
                                      WHERE CAP.NRO_CUENTA = AH.NRO_CUENTA
                                      AND   CAP.COD_MODALIDAD = AH.COD_MODALIDAD
                                      AND   CAP.COD_MODULO = AH.COD_MODULO)
                            AND NRO_CUENTA = AH.NRO_CUENTA)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0)
  ELSE NVL((SELECT SUM(SAL_PROMEDIO)
      FROM AH_CAPITALIZACIONES
      WHERE FEC_INICIO = (SELECT MAX(CAP.FEC_INICIO)
                FROM AH_CAPITALIZACIONES CAP
                WHERE CAP.NRO_CUENTA = AH.NRO_CUENTA
                AND   CAP.COD_MODALIDAD = AH.COD_MODALIDAD
                AND   CAP.COD_MODULO = AH.COD_MODULO)
      AND NRO_CUENTA = AH.NRO_CUENTA),0)
  END AS SAL_PROMEDIO_GS,
  CASE
    WHEN AH.COD_MONEDA = 'GS' THEN NVL(ROUND(((SELECT SUM(SAL_PROMEDIO)
                            FROM AH_CAPITALIZACIONES
                            WHERE FEC_INICIO = (SELECT MAX(CAP.FEC_INICIO)
                                      FROM AH_CAPITALIZACIONES CAP
                                      WHERE CAP.NRO_CUENTA = AH.NRO_CUENTA
                                      AND CAP.COD_MODALIDAD = AH.COD_MODALIDAD
                                      AND CAP.COD_MODULO = AH.COD_MODULO)
                            AND NRO_CUENTA = AH.NRO_CUENTA)/(fug_obt_cotizacion('USD',pag_cal.fu_obt_fec_actual(6))))),0)
  ELSE NVL((SELECT SUM(SAL_PROMEDIO)
      FROM AH_CAPITALIZACIONES
      WHERE FEC_INICIO = (SELECT MAX(CAP.FEC_INICIO)
                FROM AH_CAPITALIZACIONES CAP
                WHERE CAP.NRO_CUENTA = AH.NRO_CUENTA
                AND CAP.COD_MODALIDAD = AH.COD_MODALIDAD
                AND CAP.COD_MODULO = AH.COD_MODULO)
      AND NRO_CUENTA = AH.NRO_CUENTA),0)
  END AS SAL_PROMEDIO_USD,
  0 AS INTERES_OR,
  0 AS INTERES_GS,
  0 AS INTERES_USD,
  P.TIPO AS TIPOPERSONA,
  CASE
    WHEN (ah.sal_Total-ah.sal_retenido) < 50000000 THEN '1-) Menos de 50MM'
    WHEN (ah.sal_Total-ah.sal_retenido) >= 50000000 AND (ah.sal_Total-ah.sal_retenido) <= 100000000 THEN '2-) 50 A 100MM'
    WHEN (ah.sal_Total-ah.sal_retenido) > 100000000 AND (ah.sal_Total-ah.sal_retenido) <= 500000000 THEN '3-)100 A 500MM'
    WHEN (ah.sal_Total-ah.sal_retenido) > 500000000 AND (ah.sal_Total-ah.sal_retenido) <= 1000000000 THEN '4-)500 A 1000MM'
  ELSE '5-) Mas de 1000MM en adelante'
  END AS Rango,
  CASE
    WHEN (ah.sal_Total-ah.sal_retenido) >= 100000000 AND (ah.sal_Total-ah.sal_retenido) <= 200000000 THEN '1-)100 a 200MM'
    WHEN (ah.sal_Total-ah.sal_retenido) >= 200000001 AND (ah.sal_Total-ah.sal_retenido) <= 500000000 THEN '2-) 200 A 500MM'
    WHEN (ah.sal_Total-ah.sal_retenido) >= 500000001 AND (ah.sal_Total-ah.sal_retenido) <= 1000000000 THEN '3-) 500 A 1000MM'
    WHEN (ah.sal_Total-ah.sal_retenido) > 1000000000 THEN '4-) 1000MM en Adelante'
  ELSE '5-) Menor a 100MM'
  END AS Rango2,
  TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25) AS edad,
  CASE
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) < 25 THEN '18 a 24 aÃ±os'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) >= 25 AND (round(((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 30 THEN '25 a 30 aÃ±os'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 30 AND  (round(((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 40 THEN '31 a 40 aÃ±os'
    WHEN  (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 40 AND  (round(((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 50 THEN '41 a 50 aÃ±os'
    WHEN  (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 50 AND  (round(((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 60 THEN '51 a 60 aÃ±os'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 60 THEN 'Mayor a 60 aÃ±os'
  ELSE 'Otro Rango'
  END AS RangoEdad,
  cl.cod_sec_contable,
  se.descripcion des_sec_contable,
  DIR.DIRECCION AS DIRECCON,
  TEL.TELEFONO AS TELEFONO,
  P.DIR_CORREO AS EMAIL,
  CASE
    WHEN ((SELECT SUM(CANTIDAD) AS CANTIDAD
        FROM (SELECT COUNT(*) CANTIDAD,'PR' AS MARCA
            FROM GE_CTA_CLIENTES G
            INNER JOIN PR_CTA_PRESTAMOS PR ON PR.NRO_CUENTA = G.NRO_CUENTA
            AND PR.ESTADO <> 'N'
        WHERE G.COD_PERSONA = P.COD_PERSONA AND G.RELACION = 'P'
        UNION
          SELECT COUNT(*) CANTIDAD,'PR' AS MARCA
          FROM GE_CTA_CLIENTES G
          INNER JOIN TA_CTA_TARJETAS PR ON PR.NRO_CUENTA = G.NRO_CUENTA
          AND PR.ESTADO <> 'C'
          WHERE G.COD_PERSONA = P.COD_PERSONA AND G.RELACION = 'P'
          ) GROUP BY MARCA)) >= 1
    THEN 'S'
  ELSE 'N' END PRODU_ACT,
  CASE WHEN TD.NRO_CUENTA IS NOT NULL THEN 'S' ELSE 'N' END AS TD,
  TD.TAR_ACTIVA AS TAR_ACTIVA,
  TO_CHAR(TD.FEC_VENCIMIENTO,'yyyy-mm-dd') AS FEC_VENCIMIENTO_TD,
  CASE
    WHEN AH.COD_MONEDA = 'USD' THEN
      CASE
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 0 AND  NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 200000 THEN '200000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 200001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 500000 THEN '500000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 500001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 1000000 THEN '1000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 1000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 3000000 THEN '3000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 3000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 5000000 THEN '5000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 5000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 10000000 THEN '10000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 10000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 20000000 THEN '20000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 20000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 50000000 THEN '50000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 50000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 100000000 THEN '100000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 100000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 170000000 THEN '170000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 170000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 300000000 THEN '300000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 300000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 500000000 THEN '500000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 500000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 1000000000 THEN '1000000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 1000000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 3000000000 THEN '3000000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 3000000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 5000000000 THEN '5000000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 5000000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 10000000000 THEN '10000000000'
        WHEN NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 10000000001 AND NVL(ROUND(( (ah.sal_Total-ah.sal_retenido)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 100000000000 THEN '100000000000'
      END
    ELSE
      CASE
        WHEN (ah.sal_Total-ah.sal_retenido) >= 0           AND (ah.sal_Total-ah.sal_retenido) <= 200000     THEN '200000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 200001      AND (ah.sal_Total-ah.sal_retenido) <= 500000     THEN '500000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 500001      AND (ah.sal_Total-ah.sal_retenido) <= 1000000    THEN '1000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 1000001     AND (ah.sal_Total-ah.sal_retenido) <= 3000000    THEN '3000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 3000001     AND (ah.sal_Total-ah.sal_retenido) <= 5000000    THEN '5000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 5000001     AND (ah.sal_Total-ah.sal_retenido) <= 10000000     THEN '10000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 10000001    AND (ah.sal_Total-ah.sal_retenido) <= 20000000     THEN '20000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 20000001    AND (ah.sal_Total-ah.sal_retenido) <= 50000000     THEN '50000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 50000001    AND (ah.sal_Total-ah.sal_retenido) <= 100000000    THEN '100000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 100000001   AND (ah.sal_Total-ah.sal_retenido) <= 170000000    THEN '170000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 170000001   AND (ah.sal_Total-ah.sal_retenido) <= 300000000    THEN '300000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 300000001   AND (ah.sal_Total-ah.sal_retenido) <= 500000000    THEN '500000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 500000001   AND (ah.sal_Total-ah.sal_retenido) <= 1000000000   THEN '1000000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 1000000001  AND (ah.sal_Total-ah.sal_retenido) <= 3000000000   THEN '3000000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 3000000001  AND (ah.sal_Total-ah.sal_retenido) <= 5000000000   THEN '5000000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 5000000001  AND (ah.sal_Total-ah.sal_retenido) <= 10000000000  THEN '10000000000'
        WHEN (ah.sal_Total-ah.sal_retenido) >= 10000000001 AND (ah.sal_Total-ah.sal_retenido) <= 100000000000 THEN '100000000000'
           END
    END AS RANGO_SALDO,
  '' AS RANGO_PLAZO,
  gc.cod_canal AS COD_CANAL,
  gc.descripcion AS DES_CANAL,
  cc.cod_campana AS COD_CAMPANA,
  cc.descripcion AS DES_CAMPANA,
  '' as NRO_CTA_RENOVADA,
  'N/A' AS NRO_CTA_CREDITO,
  AH.TIP_CAPITALIZACION  AS COD_TIP_CAPITALIZACION,
  DECODE(FUE_OBT_DES_REFERENCIA('TIP_CAPITALIZACION',AH.TIP_CAPITALIZACION),'Referencia  no registrada en el Sistema','',FUE_OBT_DES_REFERENCIA('TIP_CAPITALIZACION',AH.TIP_CAPITALIZACION)) DES_TIP_CAPITALIZACION,
  NVL(AH.COD_ENTE,0) AS COD_ENTE ,
  FUE_OBT_NOM_ENTE(AH.COD_ENTE) AS DES_ENTE,
  DECODE(AH.COD_ENTE,NULL,'',FUG_OBT_TIP_ENTE(AH.COD_ENTE)) TIPO_ENTE,
  DP.COD_CIUDAD AS COD_CIUDAD_PAR,
  DECODE(FUE_OBT_DES_CIUDAD(DP.COD_PAIS,DP.COD_CIUDAD),'Ciudad no registrada en el Sistema',NULL,FUE_OBT_DES_CIUDAD(DP.COD_PAIS,DP.COD_CIUDAD)) CIUDAD_PAR,
  DL.COD_CIUDAD AS COD_CIUDAD_LAB,
  DECODE(FUE_OBT_DES_CIUDAD(DL.COD_PAIS,DL.COD_CIUDAD),'Ciudad no registrada en el Sistema',NULL,FUE_OBT_DES_CIUDAD(DL.COD_PAIS,DL.COD_CIUDAD)) CIUDAD_LAB,
  (SELECT to_char(btda.fec_insercion,'yyyy-mm-dd') FROM it.BA_TAB_DAT_ADICIONALES btda WHERE btda.REFERENCIA = p.cod_persona AND btda.parametro like 'CELULAR_ONBOARDING') AS FECHA_ONBOARDING,
  (SELECT DEP.DESCRIPCION FROM BA_DIRECCIONES DIC
    INNER JOIN BA_CIUDADES CIU ON CIU.COD_PAIS = DIC.COD_PAIS AND CIU.COD_CIUDAD = DIC.COD_CIUDAD
    INNER JOIN BA_DEPARTAMENTOS  DEP ON DEP.COD_DEPARTAMENTO = CIU.COD_DEPARTAMENTO
    WHERE DIC.PRINCIPAL = 'S' AND DIC.COD_PERSONA = P.COD_PERSONA) AS DEPARTAMENTO,
  0 as CAPITAL,
  cl.cod_seg_cliente AS COD_SEGMENTO,
  gsc.descripcion AS SEGMENTO,
  CASE WHEN TD.cod_est_solicitud IS NULL THEN '' ELSE TD.cod_est_solicitud  || '-' || fue_obt_des_refcodes('EST_TAR_DEBITO',TD.cod_est_solicitud) end est_solicitud_td,
  td.cod_ent_procesadora || '-' || FUE_OBT_NOM_ENTE(td.cod_ent_procesadora) as procesadora,
  td.tip_tar_debito,
'AHORRO' AS MARCA
FROM ah_cta_vistas ah
INNER JOIN ge_cta_clientes ct
  ON  ct.nro_cuenta = ah.nro_cuenta
  AND ct.relacion = 'P'
INNER JOIN ge_clientes cl
  ON  cl.cod_persona = ct.cod_persona
INNER JOIN  ge_sec_contables se
  ON se.cod_sec_contable = cl.cod_sec_contable
LEFT JOIN ge_tip_deudores de
  ON de.cod_tip_deudor = cl.cod_tip_deudor
  and se.cod_sec_contable = de.cod_sec_contable
INNER JOIN BA_MODULOS MC
  ON MC.COD_MODULO = AH.COD_MODULO
INNER JOIN  ba_personas p
  ON p.cod_persona = cl.cod_persona
LEFT JOIN GE_SUB_MODALIDADES sub_m
  ON ah.cod_modulo = sub_m.cod_modulo
  AND ah.cod_modalidad = sub_m.cod_modalidad
  AND ah.COD_SUB_MODALIDAD  = sub_m.COD_SUB_MODALIDAD
LEFT JOIN BA_PER_FISICAS PF
  ON PF.COD_PERSONA = P.COD_PERSONA
LEFT JOIN (select * from ge_tas_fechas Ct1
              where cT1.FEC_VIGENCIA = (SELECT MAX(FEC_VIGENCIA)
              FROM GE_TAS_FECHAS
              WHERE COD_TASA = CT1.COD_TASA
              AND COD_MONEDA = CT1.COD_MONEDA
              AND COD_MODULO = CT1.COD_MODULO
              AND COD_MODALIDAD = CT1.COD_MODALIDAD)) CT
  ON  AH.COD_TASA = Ct.COD_TASA
  AND AH.COD_MONEDA = Ct.COD_MONEDA
  AND AH.COD_MODULO = Ct.COD_MODULO
  AND AH.COD_MODALIDAD = Ct.COD_MODALIDAD
LEFT JOIN GE_TASAS GT
  ON GT.COD_TASA = AH.COD_TASA
LEFT JOIN BA_DIRECCIONES DIR
  ON P.COD_PERSONA = DIR.COD_PERSONA
  AND DIR.PRINCIPAL = 'S'
LEFT JOIN BA_TELEFONOS TEL
  ON P.COD_PERSONA = TEL.COD_PERSONA
  AND TEL.PRINCIPAL = 'S'
LEFT JOIN GE_CANALES gc
  ON GC.COD_CANAL = ah.COD_CANAL
LEFT JOIN CR_CAMPANAS CC
  ON CC.COD_CAMPANA = ah.COD_CAMPANA
LEFT JOIN ( Select * from AH_TAR_DEBITOS TD1
  Where TD1.NRO_EMISION = (SELECT MAX(NRO_EMISION)
              FROM AH_TAR_DEBITOS
              WHERE NRO_CUENTA = TD1.NRO_CUENTA
              AND COD_PERSONA = TD1.COD_PERSONA
              AND TD1.ADHERENTE = '00')
  AND NVL(TD1.FEC_ACTIVACION,pag_cal.fu_obt_fec_actual(6)) = (SELECT NVL(MAX(FEC_ACTIVACION),pag_cal.fu_obt_fec_actual(6))
              FROM AH_TAR_DEBITOS
              WHERE NRO_CUENTA = TD1.NRO_CUENTA
              AND NRO_EMISION = TD1.NRO_EMISION
              AND COD_PERSONA = TD1.COD_PERSONA
              AND TD1.ADHERENTE = '00' )) TD
  ON TD.NRO_CUENTA = AH.NRO_CUENTA
  AND TD.COD_PERSONA = P.COD_PERSONA
  AND TD.ADHERENTE = '00'
LEFT JOIN (select  * from BA_DIRECCIONES DP1
           where
                   DP1.COD_DIRECCION  = (SELECT MAX(COD_DIRECCION)
                                        FROM BA_DIRECCIONES BDA
                                        WHERE BDA.TIPO = DP1.TIPO AND BDA.COD_PERSONA  = DP1.COD_PERSONA)) DP
  ON DP.COD_PERSONA  = P.COD_PERSONA
  AND DP.TIPO  = 'P'
LEFT JOIN (select * from BA_DIRECCIONES DL1 where DL1.COD_DIRECCION = (SELECT MAX(COD_DIRECCION)
              FROM BA_DIRECCIONES
              WHERE TIPO = DL1.TIPO AND COD_PERSONA = DL1.COD_PERSONA)) DL
  ON DL.COD_PERSONA  = P.COD_PERSONA
  AND DL.TIPO  = 'L'
LEFT JOIN GE_GRU_ECONOMICOS GRU
  ON GRU.COD_GRU_ECONOMICO = CL.COD_GRU_ECONOMICO
LEFT JOIN GE_SEG_CLIENTES gsc
  ON CL.COD_SEG_CLIENTE = GSC.COD_SEG_CLIENTE
WHERE AH.ESTADO NOT IN ('P','C','X')

UNION ALL

----Bloque CDA

----Bloque CDA
SELECT
  TO_CHAR((pag_cal.fu_obt_fec_actual(6)), 'yyyy-mm-dd') AS FECHA_PROCESO,
  AH.cod_oficina AS SUCURSAL_COD,
  FUE_OBT_DES_OFICINA(ah.cod_oficina) SUCURSAL,
  cl.cod_usu_oficial AS ASESOR,
  cl.cod_persona AS COD_PERSONA,
  P.nom_completo as NOMBRE_CLIENTE,
  p.cod_actividad AS COD_ACTIVIDAD,
  DECODE(FUG_OBT_DES_ACTIVIDAD (P.COD_ACTIVIDAD),'Rubro / Actividad no registrados en el Sistema','',FUG_OBT_DES_ACTIVIDAD (P.COD_ACTIVIDAD)) AS DES_ACTIVIDAD,
  cl.cod_tip_deudor AS COD_TIP_DEUDOR,
  de.descripcion  AS TIP_DEUDOR,
  P.nro_documento as NRO_DOC,
  PF.COD_SEXO AS SEXO,
  to_char(PF.FEC_NACIMIENTO, 'yyyy-mm-dd') AS FEC_NACIMIENTO,
  cl.COD_GRU_ECONOMICO as COD_GRU_ECONOMICO,
  GRU.DESCRIPCION AS DES_GRU_ECONOMICO,
  ah.cod_modulo AS MODULO_COD,
  MC.DESCRIPCION AS MODULO,
  ah.cod_modalidad AS MODALIDAD_COD,
  FUG_OBT_DES_MODAL(AH.COD_MODULO,AH.COD_MODALIDAD) MODALIDAD,
  NULL AS sub_modalidad_cod,
  NULL AS sub_modalidad,
  ah.cod_tasa as COD_TASA,
  GT.DESCRIPCION AS DES_TASA,
  ct.val_Tasa,
  ah.denominacion AS DENOMINACION,
  ah.estado AS ESTADO_COD,
  FUG_OBT_DES_EST_CTA(ah.COD_MODULO,ah.COD_MODALIDAD,ah.ESTADO) AS ESTADO,
  AH.fec_vencimiento - AH.fec_apertura as plazo,
  (SELECT pl.descripcion plazo
  FROM ge_plz_contables pl
  WHERE pl.can_dias = (SELECT MIN(can_dias)
            FROM ge_plz_contables
            WHERE can_dias >= (AH.fec_vencimiento - AH.fec_apertura)))
  AS DES_PLAZO,
  AH.NRO_CUENTA AS NRO_CUENTA,
  AH.DIG_VERIFICADOR AS DIG_VERIFICADOR,
  AH.cod_moneda AS COD_MONEDA,
  NVL((fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))),1) as cotizacion,
  AH.sal_Total AS SALDO_OR,
  CASE
    WHEN AH.COD_MONEDA = 'USD' THEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0)
  ELSE ah.sal_Total
  END AS SALDO_GS,
  CASE
    WHEN AH.COD_MONEDA = 'GS' THEN NVL(ROUND(((AH.sal_Total) /(fug_obt_cotizacion('USD',pag_cal.fu_obt_fec_actual(6))))),0)
  ELSE AH.sal_Total
  END AS SALDO_USD,
  To_char(ah.FEC_APERTURA,'yyyy-mm-dd') AS FECHA_VALOR,
  To_char(ah.fec_ult_movimiento,'yyyy-mm-dd') AS FECHA_ULT_MOVIMIENTO,
  To_char(AH.FEC_VENCIMIENTO,'yyyy-mm-dd') AS fecha_vencimiento,
  0 AS SAL_PROMEDIO_OR,
  0 AS SAL_PROMEDIO_GS,
  0 AS SAL_PROMEDIO_USD,
  (select sum(cu.mto_interes) as INTERES
    from ah_cupones cu
    WHERE cu.nro_cuenta= AH.NRO_CUENTA) AS INTERES_OR,
  CASE
    WHEN AH.COD_MONEDA = 'USD' THEN NVL(ROUND(((select sum(cu.mto_interes) as INTERES
                            from ah_cupones cu
                            WHERE cu.nro_cuenta= AH.NRO_CUENTA)*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0)
  ELSE (select  sum(cu.mto_interes) as INTERES
    from ah_cupones cu
    WHERE cu.nro_cuenta= AH.NRO_CUENTA)
  END AS INTERES_GS,
  CASE
    WHEN AH.COD_MONEDA = 'GS' THEN NVL(ROUND(((select  sum(cu.mto_interes) as INTERES
              from ah_cupones cu
            WHERE cu.nro_cuenta= AH.NRO_CUENTA) /(fug_obt_cotizacion('USD',pag_cal.fu_obt_fec_actual(6))))),0)
  ELSE (select  sum(cu.mto_interes) as INTERES
      from ah_cupones cu
      WHERE cu.nro_cuenta= AH.NRO_CUENTA)
  END AS INTERES_USD,
  P.TIPO AS TIPOPERSONA,
  CASE
    WHEN ABS(AH.sal_Total) < 50000000 THEN '1-) Menos de 50MM'
    WHEN ABS(AH.sal_Total) >= 50000000 AND ABS(AH.sal_Total) <= 100000000 THEN '2-) 50 A 100MM'
    WHEN ABS(AH.sal_Total) > 100000000 AND ABS(AH.sal_Total) <= 500000000 THEN '3-)100 A 500MM'
    WHEN ABS(AH.sal_Total) > 500000000 AND ABS(AH.sal_Total) <= 1000000000 THEN '4-)500 A 1000MM'
  ELSE '5-) Mas de 1000MM en adelante'
  END AS Rango,
  CASE
    WHEN ABS(AH.sal_Total) >= 100000000 AND ABS(AH.sal_Total) <= 200000000 THEN '1-)100 a 200MM'
    WHEN ABS(AH.sal_Total) >= 200000001 AND ABS(AH.sal_Total) <= 500000000 THEN '2-) 200 A 500MM'
    WHEN ABS(AH.sal_Total) >= 500000001 AND ABS(AH.sal_Total) <= 1000000000 THEN '3-) 500 A 1000MM'
    WHEN ABS(AH.sal_Total) > 1000000000 THEN '4-) 1000MM en Adelante'
  ELSE '5-) Menor a 100MM'
  END AS Rango2,
  TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25) AS edad,
  CASE
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) < 25 THEN '18 a 24 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) >= 25 AND (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 30 THEN '25 a 30 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 30 AND  (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 40 THEN '31 a 40 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 40 AND  (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 50 THEN '41 a 50 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 50 AND  (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 60 THEN '51 a 60 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 60 THEN 'Mayor a 60 años'
  ELSE 'Otro Rango'
  END AS RangoEdad,
  cl.cod_sec_contable,
  se.descripcion des_sec_contable,
  DIR.DIRECCION AS DIRECCION,
  TEL.TELEFONO AS TELEFONO,
  P.DIR_CORREO AS EMAIL,
  CASE
  WHEN ((SELECT SUM(CANTIDAD) AS CANTIDAD
      FROM (SELECT COUNT(*) CANTIDAD,'PR' AS MARCA
        FROM GE_CTA_CLIENTES G
        INNER JOIN PR_CTA_PRESTAMOS PR
        ON PR.NRO_CUENTA = G.NRO_CUENTA
        AND PR.ESTADO <> 'N'
      WHERE G.COD_PERSONA = P.COD_PERSONA AND G.RELACION = 'P'
      UNION
      SELECT COUNT(*) CANTIDAD,'PR' AS MARCA
        FROM GE_CTA_CLIENTES G
        INNER JOIN TA_CTA_TARJETAS PR
        ON PR.NRO_CUENTA = G.NRO_CUENTA
        AND PR.ESTADO <> 'C'
      WHERE G.COD_PERSONA = P.COD_PERSONA AND G.RELACION = 'P')
    GROUP BY MARCA)) >= 1 THEN 'S'
  ELSE 'N'
  END PRODU_ACT,
  CASE WHEN TD.NRO_CUENTA IS NOT NULL THEN 'S' ELSE 'N' END AS TD,
  TD.TAR_ACTIVA AS TAR_ACTIVA,
  TO_CHAR(TD.FEC_VENCIMIENTO,'yyyy-mm-dd') AS FEC_VENCIMIENTO_TD,
  CASE
    WHEN AH.COD_MONEDA = 'USD' THEN
    CASE
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 0 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 200000 THEN '200000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 200001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 500000 THEN '500000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 500001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 1000000 THEN '1000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 1000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 3000000 THEN '3000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 3000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 5000000 THEN '5000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 5000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 10000000 THEN '10000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 10000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 20000000 THEN '20000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 20000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 50000000 THEN '50000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 50000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 100000000 THEN '100000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 100000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 170000000 THEN '170000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 170000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 300000000 THEN '300000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 300000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 500000000 THEN '500000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 500000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 1000000000 THEN '1000000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 1000000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 3000000000 THEN '3000000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 3000000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 5000000000 THEN '5000000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 5000000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 10000000000 THEN '10000000000'
      WHEN NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) >= 10000000001 AND NVL(ROUND((AH.sal_Total*(fug_obt_cotizacion(ah.cod_moneda,pag_cal.fu_obt_fec_actual(6))))),0) <= 100000000000 THEN '100000000000'
    END
  ELSE
    CASE
      WHEN AH.sal_Total >= 0           AND AH.sal_Total <= 200000     THEN '200000'
      WHEN AH.sal_Total >= 200001      AND AH.sal_Total <= 500000     THEN '500000'
      WHEN AH.sal_Total >= 500001      AND AH.sal_Total <= 1000000    THEN '1000000'
      WHEN AH.sal_Total >= 1000001     AND AH.sal_Total <= 3000000    THEN '3000000'
      WHEN AH.sal_Total >= 3000001     AND AH.sal_Total <= 5000000    THEN '5000000'
      WHEN AH.sal_Total >= 5000001     AND AH.sal_Total <= 10000000     THEN '10000000'
      WHEN AH.sal_Total >= 10000001    AND AH.sal_Total <= 20000000     THEN '20000000'
      WHEN AH.sal_Total >= 20000001    AND AH.sal_Total <= 50000000     THEN '50000000'
      WHEN AH.sal_Total >= 50000001    AND AH.sal_Total <= 100000000    THEN '100000000'
      WHEN AH.sal_Total >= 100000001   AND AH.sal_Total <= 170000000    THEN '170000000'
      WHEN AH.sal_Total >= 170000001   AND AH.sal_Total <= 300000000    THEN '300000000'
      WHEN AH.sal_Total >= 300000001   AND AH.sal_Total <= 500000000    THEN '500000000'
      WHEN AH.sal_Total >= 500000001   AND AH.sal_Total <= 1000000000   THEN '1000000000'
      WHEN AH.sal_Total >= 1000000001  AND AH.sal_Total <= 3000000000   THEN '3000000000'
      WHEN AH.sal_Total >= 3000000001  AND AH.sal_Total <= 5000000000   THEN '5000000000'
      WHEN AH.sal_Total >= 5000000001  AND AH.sal_Total <= 10000000000  THEN '10000000000'
      WHEN AH.sal_Total >= 10000000001 AND AH.sal_Total <= 100000000000 THEN '100000000000'
    END
  END AS RANGO_SALDO,
  CASE
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 0    AND (AH.fec_vencimiento - AH.fec_apertura) <= 180  THEN '< 6 Meses'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 181  AND (AH.fec_vencimiento - AH.fec_apertura) <= 365  THEN '6 Meses'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 366  AND (AH.fec_vencimiento - AH.fec_apertura) <= 375  THEN '1 Año'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 376  AND (AH.fec_vencimiento - AH.fec_apertura) <= 734  THEN '2 Años'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 735  AND (AH.fec_vencimiento - AH.fec_apertura) <= 1099 THEN '3 Años'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 1100 AND (AH.fec_vencimiento - AH.fec_apertura) <= 1465 THEN '4 Años'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 1466 AND (AH.fec_vencimiento - AH.fec_apertura) <= 1829 THEN '5 Años'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 1830 AND (AH.fec_vencimiento - AH.fec_apertura) <= 2193 THEN '6 Años'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 2194 AND (AH.fec_vencimiento - AH.fec_apertura) <= 2557 THEN '7 Años'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 2558 AND (AH.fec_vencimiento - AH.fec_apertura) <= 2925 THEN '8 Años'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 2926 AND (AH.fec_vencimiento - AH.fec_apertura) <= 3287 THEN '9 Años'
    WHEN (AH.fec_vencimiento - AH.fec_apertura) >= 3288 AND (AH.fec_vencimiento - AH.fec_apertura) <= 3700 THEN '10 Años'
  END AS RANGO_PLAZO,
  gc.cod_canal AS COD_CANAL,
  gc.descripcion AS DES_CANAL,
  cc.cod_campana AS COD_CAMPANA,
  cc.descripcion AS DES_CAMPANA,
  ah.NRO_CTA_RENOVADA as NRO_CTA_RENOVADA,
  AH.NRO_CTA_CREDITO AS NRO_CTA_CREDITO,
  AH.TIP_CAPITALIZACION  AS COD_TIP_CAPITALIZACION,
  DECODE(FUE_OBT_DES_REFERENCIA('TIP_CAPITALIZACION',AH.TIP_CAPITALIZACION),'Referencia  no registrada en el Sistema','',FUE_OBT_DES_REFERENCIA('TIP_CAPITALIZACION',AH.TIP_CAPITALIZACION)) DES_TIP_CAPITALIZACION,
  0 AS COD_ENTE,
  '' AS DES_ENTE,
  '' AS TIPO_ENTE,
  DP.COD_CIUDAD AS COD_CIUDAD_PAR,
  DECODE(FUE_OBT_DES_CIUDAD(DP.COD_PAIS,DP.COD_CIUDAD),'Ciudad no registrada en el Sistema',NULL,FUE_OBT_DES_CIUDAD(DP.COD_PAIS,DP.COD_CIUDAD)) CIUDAD_PAR,
  DL.COD_CIUDAD AS COD_CIUDAD_LAB,
  DECODE(FUE_OBT_DES_CIUDAD(DL.COD_PAIS,DL.COD_CIUDAD),'Ciudad no registrada en el Sistema',NULL,FUE_OBT_DES_CIUDAD(DL.COD_PAIS,DL.COD_CIUDAD)) CIUDAD_LAB,
  (SELECT to_char(btda.fec_insercion,'yyyy-mm-dd')
    FROM it.BA_TAB_DAT_ADICIONALES btda
    WHERE btda.REFERENCIA = p.cod_persona
    AND btda.parametro like 'CELULAR_ONBOARDING') AS FECHA_ONBOARDING,
  (SELECT DEP.DESCRIPCION
    FROM BA_DIRECCIONES DIC
    INNER JOIN BA_CIUDADES CIU ON CIU.COD_PAIS = DIC.COD_PAIS AND CIU.COD_CIUDAD = DIC.COD_CIUDAD
    INNER JOIN BA_DEPARTAMENTOS  DEP ON DEP.COD_DEPARTAMENTO = CIU.COD_DEPARTAMENTO
    WHERE DIC.PRINCIPAL = 'S' AND DIC.COD_PERSONA = P.COD_PERSONA) AS DEPARTAMENTO,
  ah.capital as CAPITAL,
  cl.cod_seg_cliente AS COD_SEGMENTO,
  gsc.descripcion AS SEGMENTO,
  CASE WHEN TD.cod_est_solicitud IS NULL THEN '' ELSE TD.cod_est_solicitud  || '-' || fue_obt_des_refcodes('EST_TAR_DEBITO',TD.cod_est_solicitud) end est_solicitud_td,
  td.cod_ent_procesadora || '-' || FUE_OBT_NOM_ENTE(td.cod_ent_procesadora) as procesadora,
  td.tip_tar_debito,
  'CDA' AS MARCA
FROM AH_CTA_CERTIFICADOS AH
INNER JOIN GE_CTA_CLIENTES CT
  ON AH.NRO_CUENTA = CT.NRO_CUENTA
  AND CT.RELACION = 'P'
INNER JOIN GE_CLIENTES CL
  ON CT.COD_PERSONA = CL.COD_PERSONA
LEFT JOIN GE_SEC_CONTABLES SE
  ON CL.COD_SEC_CONTABLE = SE.COD_SEC_CONTABLE
LEFT JOIN GE_TIP_DEUDORES DE
  ON CL.COD_TIP_DEUDOR = DE.COD_TIP_DEUDOR
  AND  DE.COD_SEC_CONTABLE = SE.COD_SEC_CONTABLE
INNER JOIN BA_MODULOS MC
  ON MC.COD_MODULO = AH.COD_MODULO
INNER JOIN  BA_PERSONAS P
  ON CT.COD_PERSONA = P.COD_PERSONA
LEFT JOIN BA_PER_FISICAS PF
  ON P.COD_PERSONA = PF.COD_PERSONA
LEFT JOIN (Select * from ge_tas_fechas Ct1
  Where cT1.FEC_VIGENCIA = (SELECT MAX(FEC_VIGENCIA)
              FROM GE_TAS_FECHAS
              WHERE COD_TASA = CT1.COD_TASA
              AND COD_MONEDA = CT1.COD_MONEDA
              AND COD_MODULO = CT1.COD_MODULO
              AND COD_MODALIDAD = CT1.COD_MODALIDAD)) Ct
  ON  AH.COD_TASA = Ct.COD_TASA
  AND AH.COD_MONEDA = Ct.COD_MONEDA
  AND AH.COD_MODULO = Ct.COD_MODULO
  AND AH.COD_MODALIDAD = Ct.COD_MODALIDAD
LEFT JOIN GE_TASAS GT
  ON GT.COD_TASA = AH.COD_TASA
LEFT JOIN BA_DIRECCIONES DIR
  ON P.COD_PERSONA = DIR.COD_PERSONA
  AND DIR.PRINCIPAL = 'S'
LEFT JOIN BA_TELEFONOS TEL
  ON P.COD_PERSONA = TEL.COD_PERSONA
  AND TEL.PRINCIPAL = 'S'
LEFT JOIN GE_CANALES gc
  ON GC.COD_CANAL = ah.COD_CANAL
LEFT JOIN CR_CAMPANAS CC
  ON CC.COD_CAMPANA = AH.COD_CAMPANA
LEFT JOIN ( Select * from AH_TAR_DEBITOS TD1
  Where TD1.NRO_EMISION = (SELECT MAX(NRO_EMISION)
              FROM AH_TAR_DEBITOS
              WHERE NRO_CUENTA = TD1.NRO_CUENTA
              AND COD_PERSONA = TD1.COD_PERSONA
              AND TD1.ADHERENTE = '00')
  AND NVL(TD1.FEC_ACTIVACION,pag_cal.fu_obt_fec_actual(6)) = (SELECT NVL(MAX(FEC_ACTIVACION),pag_cal.fu_obt_fec_actual(6))
              FROM AH_TAR_DEBITOS
              WHERE NRO_CUENTA = TD1.NRO_CUENTA
              AND NRO_EMISION = TD1.NRO_EMISION
              AND COD_PERSONA = TD1.COD_PERSONA
              AND TD1.ADHERENTE = '00')) TD
  ON TD.NRO_CUENTA = AH.NRO_CUENTA
  AND TD.COD_PERSONA = P.COD_PERSONA
  AND TD.ADHERENTE = '00'
LEFT JOIN GE_GRU_ECONOMICOS GRU
  ON GRU.COD_GRU_ECONOMICO = CL.COD_GRU_ECONOMICO
LEFT JOIN (Select * from BA_DIRECCIONES DP1
  Where DP1.COD_DIRECCION  = (SELECT MAX(COD_DIRECCION)
              FROM BA_DIRECCIONES
              WHERE TIPO = DP1.TIPO
              AND COD_PERSONA = DP1.COD_PERSONA)) DP
  ON DP.COD_PERSONA  = P.COD_PERSONA
  AND DP.TIPO  = 'P'
LEFT JOIN (Select * from BA_DIRECCIONES DL1
  Where DL1.COD_DIRECCION  = (SELECT MAX(COD_DIRECCION)
              FROM BA_DIRECCIONES
              WHERE TIPO = DL1.TIPO
              AND COD_PERSONA = DL1.COD_PERSONA)) DL
  ON DL.COD_PERSONA  = P.COD_PERSONA
  AND DL.TIPO  = 'L'
LEFT JOIN GE_SEG_CLIENTES gsc
  ON CL.COD_SEG_CLIENTE = GSC.COD_SEG_CLIENTE
WHERE AH.ESTADO NOT IN ('T','X','C')

UNION ALL
/*BLOQUE CUENTA CORRIENTE*/

SELECT distinct
  TO_CHAR((pag_cal.fu_obt_fec_actual(6)), 'yyyy-mm-dd') AS FECHA_PROCESO,
  CC.cod_oficina AS SUCURSAL_COD,
  ofi.descripcion AS sucursal,
  cl.cod_usu_oficial AS ASESOR,
  cl.cod_persona AS COD_PERSONA,
  p.nom_completo AS NOMBRE_CLIENTE,
  p.cod_actividad AS COD_ACTIVIDAD,
  ge_act.descripcion as DES_ACTIVIDAD,
  cl.cod_tip_deudor AS COD_TIP_DEUDOR,
  de.descripcion AS TIP_DEUDOR,
  p.nro_documento AS NRO_DOC,
  PF.COD_SEXO AS SEXO,
  to_char(PF.FEC_NACIMIENTO, 'yyyy-mm-dd') AS FEC_NACIMIENTO,
  cl.COD_GRU_ECONOMICO AS COD_GRU_ECONOMICO,
  GRU.DESCRIPCION AS DES_GRU_ECONOMICO,
  CC.cod_modulo AS MODULO_COD,
  MC.DESCRIPCION AS MODULO,
  CC.cod_modalidad AS MODALIDAD_COD,
  mods.descripcion as MODALIDAD,
  CC.cod_sub_modalidad AS SUB_MODALIDAD_COD,
  sub_mod.descripcion AS SUB_MODALIDAD,
  null as COD_TASA, -- CC.cod_tasa AS COD_TASA,
  null AS DES_TASA,--GT.DESCRIPCION AS DES_TASA,
  null as val_tasa,--CT_F.val_tasa,
  CC.denominacion AS DENOMINACION,
  CC.estado AS ESTADO_COD,
  est_c.descripcion as ESTADO,
  0 AS PLAZO,
  null AS DES_PLAZO,
  CC.nro_cuenta AS NRO_CUENTA,
  CC.DIG_VERIFICADOR AS DIG_VERIFICADOR,
  CC.cod_moneda AS COD_MONEDA,
  NVL(cotizacion.val_conversion, 1) AS cotizacion,
  CC.sal_Total - CC.sal_retenido AS SALDO_OR,
  CASE
    WHEN CC.COD_MONEDA = 'USD' THEN NVL(ROUND((CC.sal_Total - CC.sal_retenido) * cotizacion.val_conversion), 0)
    ELSE ( CC.sal_Total - CC.sal_retenido )
  END AS SALDO_GS,
  CASE
    WHEN CC.COD_MONEDA = 'GS' THEN NVL(ROUND((CC.sal_Total - CC.sal_retenido) /  cot_usd.val_conversion), 0)
    ELSE (CC.sal_Total - CC.sal_retenido)
  END AS SALDO_USD,
    To_char(cc.FEC_APERTURA,'yyyy-mm-dd') AS FECHA_VALOR,
  To_char(cc.fec_ult_movimiento,'yyyy-mm-dd') AS FECHA_ULT_MOVIMIENTO,
  null AS fecha_vencimiento,
  null as SAL_PROMEDIO_OR, --NVL(capitalizaciones.sal_promedio, 0) AS SAL_PROMEDIO_OR,
null as SAL_PROMEDIO_GS,
  
null as SAL_PROMEDIO_USD, 
  0 AS INTERES_OR,
  0 AS INTERES_GS,
  0 AS INTERES_USD,
  P.TIPO AS TIPOPERSONA,
	CASE
		WHEN (CC.sal_Total - CC.sal_retenido) < 50000000 THEN '1-) Menos de 50MM'
		WHEN (CC.sal_Total - CC.sal_retenido) >= 50000000 AND (CC.sal_Total-CC.sal_retenido) <= 100000000  THEN '2-) 50 A 100MM'
		WHEN (CC.sal_Total - CC.sal_retenido) > 100000000 AND (CC.sal_Total-CC.sal_retenido) <= 500000000  THEN '3-)100 A 500MM'
		WHEN (CC.sal_Total - CC.sal_retenido) > 500000000 AND (CC.sal_Total-CC.sal_retenido) <= 1000000000 THEN '4-)500 A 1000MM'
	ELSE '5-) Mas de 1000MM en adelante'
	END AS Rango,
	CASE
		WHEN (CC.sal_Total - CC.sal_retenido) >= 100000000 AND (CC.sal_Total - CC.sal_retenido) <= 200000000  THEN '1-)100 a 200MM'
		WHEN (CC.sal_Total - CC.sal_retenido) >= 200000001 AND (CC.sal_Total - CC.sal_retenido) <= 500000000  THEN '2-) 200 A 500MM'
		WHEN (CC.sal_Total - CC.sal_retenido) >= 500000001 AND (CC.sal_Total - CC.sal_retenido) <= 1000000000 THEN '3-) 500 A 1000MM'
		WHEN (CC.sal_Total - CC.sal_retenido) > 1000000000 THEN '4-) 1000MM en Adelante'
	ELSE '5-) Menor a 100MM'
	END AS Rango2,
	TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25) AS edad,
  CASE
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) < 25 THEN '18 a 24 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) >= 25 AND (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 30 THEN '25 a 30 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 30 AND  (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 40 THEN '31 a 40 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 40 AND  (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 50 THEN '41 a 50 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 50 AND  (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 60 THEN '51 a 60 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 60 THEN 'Mayor a 60 años'
  ELSE 'Otro Rango'
  END AS RangoEdad,
  cl.cod_sec_contable,
  se.descripcion des_sec_contable,
  DIR.DIRECCION AS DIRECCON,
  TEL.TELEFONO AS TELEFONO,
  P.DIR_CORREO AS EMAIL,
  CASE
    WHEN CANT_PR.CANTIDAD >= 1 THEN 'S'
    ELSE 'N'
  END AS PRODU_ACT,
  null as TD,
  null as TAR_ACTIVA,--TD.TAR_ACTIVA AS TAR_ACTIVA,
  null as FEC_VENCIMIENTO_TD, --cast(cast(TD.FEC_VENCIMIENTO as timestamp) as date) AS FEC_VENCIMIENTO_TD,
	CASE     
		WHEN CC.COD_MONEDA = 'USD' THEN 
			CASE 
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 0 AND  NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)		 * (cotizacion.val_conversion) )),0) <= 200000 THEN '200000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 200001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 500000 THEN '500000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 500001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 1000000 THEN '1000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 1000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 3000000 THEN '3000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 3000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 5000000 THEN '5000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 5000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 10000000 THEN '10000000' 	  	   
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 10000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 20000000 THEN '20000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 20000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 50000000 THEN '50000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 50000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 100000000 THEN '100000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 100000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 170000000 THEN '170000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 170000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 300000000 THEN '300000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 300000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 500000000 THEN '500000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 500000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)	 * (cotizacion.val_conversion) )),0) <= 1000000000 THEN '1000000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 1000000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido) * (cotizacion.val_conversion) )),0) <= 3000000000 THEN '3000000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 3000000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido) * (cotizacion.val_conversion) )),0) <= 5000000000 THEN '5000000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 5000000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido) * (cotizacion.val_conversion) )),0) <= 10000000000 THEN '10000000000'
				WHEN NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)*(cotizacion.val_conversion) )),0) >= 10000000001 AND NVL(ROUND(( (CC.sal_Total-CC.sal_retenido)* (cotizacion.val_conversion) )),0) <= 100000000000 THEN '100000000000'
			END  
		ELSE
			CASE 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 0           AND (CC.sal_Total-CC.sal_retenido) <= 200000 	  THEN '200000'
				WHEN (CC.sal_Total-CC.sal_retenido) >= 200001      AND (CC.sal_Total-CC.sal_retenido) <= 500000 	  THEN '500000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 500001      AND (CC.sal_Total-CC.sal_retenido) <= 1000000 	  THEN '1000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 1000001     AND (CC.sal_Total-CC.sal_retenido) <= 3000000 	  THEN '3000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 3000001     AND (CC.sal_Total-CC.sal_retenido) <= 5000000 	  THEN '5000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 5000001     AND (CC.sal_Total-CC.sal_retenido) <= 10000000  	  THEN '10000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 10000001    AND (CC.sal_Total-CC.sal_retenido) <= 20000000 	  THEN '20000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 20000001    AND (CC.sal_Total-CC.sal_retenido) <= 50000000     THEN '50000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 50000001    AND (CC.sal_Total-CC.sal_retenido) <= 100000000    THEN '100000000'  
				WHEN (CC.sal_Total-CC.sal_retenido) >= 100000001   AND (CC.sal_Total-CC.sal_retenido) <= 170000000    THEN '170000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 170000001   AND (CC.sal_Total-CC.sal_retenido) <= 300000000    THEN '300000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 300000001   AND (CC.sal_Total-CC.sal_retenido) <= 500000000    THEN '500000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 500000001   AND (CC.sal_Total-CC.sal_retenido) <= 1000000000   THEN '1000000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 1000000001  AND (CC.sal_Total-CC.sal_retenido) <= 3000000000   THEN '3000000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 3000000001  AND (CC.sal_Total-CC.sal_retenido) <= 5000000000   THEN '5000000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 5000000001  AND (CC.sal_Total-CC.sal_retenido) <= 10000000000  THEN '10000000000' 
				WHEN (CC.sal_Total-CC.sal_retenido) >= 10000000001 AND (CC.sal_Total-CC.sal_retenido) <= 100000000000 THEN '100000000000' 
       	   END 
		END AS RANGO_SALDO,
	null AS RANGO_PLAZO,
	gc.cod_canal AS COD_CANAL,
  gc.descripcion AS DES_CANAL,
  CAM.cod_campana AS COD_CAMPANA,
  CAM.descripcion AS DES_CAMPANA,
  null AS NRO_CTA_RENOVADA,
  'N/A' AS NRO_CTA_CREDITO,
  null as COD_TIP_CAPITALIZACION, --CC.TIP_CAPITALIZACION AS COD_TIP_CAPITALIZACION,
 null as DES_TIP_CAPITALIZACION, 
  NVL(CC.COD_ENTE, 0) AS COD_ENTE,
  entes.descripcion AS DES_ENTE, --FUE_OBT_NOM_ENTE(CC.COD_ENTE) AS DES_ENTE,
  CASE
    WHEN cast(CC.COD_ENTE as varchar(20)) IS NULL THEN cast(CC.COD_ENTE as varchar(20))
    ELSE cast(entes.tipo as varchar(20)) --FUG_OBT_TIP_ENTE(CC.COD_ENTE)
  END AS TIPO_ENTE,
  DP.COD_CIUDAD AS COD_CIUDAD_PAR,
  CASE
    WHEN ccp.descripcion IS NOT NULL THEN ccp.descripcion 
    ELSE 'Ciudad no registrada en el Sistema'
  END AS CIUDAD_PAR,
  DL.COD_CIUDAD AS COD_CIUDAD_LAB,
  CASE
    WHEN ccl.descripcion IS NOT NULL THEN ccl.descripcion
    ELSE 'Ciudad no registrada en el Sistema'
  END AS CIUDAD_LAB,
  to_char(ba_tab.fec_insercion,'yyyy-mm-dd') AS FECHA_ONBOARDING,
  dpto.DEPARTAMENTO,
  0 AS CAPITAL,
  cl.cod_seg_cliente AS COD_SEGMENTO,
  gsc.descripcion AS SEGMENTO,
null as est_solicitud_td,
  null as procesadora,--TD.cod_ent_procesadora || '-' || entes_2.descripcion AS procesadora,
  null as tip_tar_debito, --TD.tip_tar_debito,
  cast('CUENTA CORRIENTE' as varchar(20)) AS MARCA 
FROM cc_cta_corrientes cc
    INNER JOIN ge_cta_clientes ct
        ON ct.nro_cuenta = CC.nro_cuenta
        AND ct.relacion = 'P'
    INNER JOIN ge_clientes cl
        ON cl.cod_persona = ct.cod_persona
    INNER JOIN ge_sec_contables se
        ON se.cod_sec_contable = cl.cod_sec_contable
    INNER JOIN BA_MODULOS MC
        ON MC.COD_MODULO = CC.COD_MODULO
    INNER JOIN ba_personas P
        ON P.cod_persona = cl.cod_persona
    LEFT JOIN ge_tip_deudores de
        ON de.cod_tip_deudor = cl.cod_tip_deudor
        AND se.cod_sec_contable = de.cod_sec_contable
    LEFT JOIN BA_PER_FISICAS PF
        ON PF.COD_PERSONA = P.COD_PERSONA
 
   LEFT JOIN GE_CANALES gc
        ON GC.COD_CANAL = CC.COD_CANAL
  
        
    LEFT JOIN CR_CAMPANAS CAM 
        ON CAM.COD_CAMPANA = CC.COD_CAMPANA  
    LEFT JOIN GE_GRU_ECONOMICOS GRU 
        ON GRU.COD_GRU_ECONOMICO = CL.COD_GRU_ECONOMICO
   LEFT JOIN GE_SEG_CLIENTES gsc
        ON CL.COD_SEG_CLIENTE = GSC.COD_SEG_CLIENTE
       
    left join ge_modalidades mods
        on mods.cod_modulo = CC.COD_MODULO
            and mods.cod_modalidad = CC.COD_MODALIDAD
    left join ge_sub_modalidades sub_mod
        on sub_mod.cod_modulo = CC.COD_MODULO
            and sub_mod.cod_modalidad = CC.COD_MODALIDAD
			and sub_mod.cod_modalidad = CC.COD_SUB_MODALIDAD			
    left join ge_est_cuentas est_c
        on est_c.cod_modulo = CC.cod_modulo
        and est_c.cod_modalidad = CC.cod_modalidad
        and est_c.estado = CC.estado
    left join ge_cotizaciones cotizacion
        on cotizacion.cod_moneda = CC.cod_moneda
		and cotizacion.fecha = pag_cal.fu_obt_fec_actual(6)

    left join ge_entes entes
        on entes.cod_ente = CC.COD_ENTE

    left join ba_oficinas ofi
        on ofi.cod_oficina = CC.cod_oficina
  left join ge_cotizaciones cot_usd
        on cot_usd.cod_moneda = 'USD'
        and cot_usd.fecha = pag_cal.fu_obt_fec_actual(6)
    left join ge_actividades ge_act
        on ge_act.cod_actividad = P.COD_ACTIVIDAD
    left join ge_rub_economicos ge_rub_e
        on ge_rub_e.cod_rub_economico = P.COD_ACTIVIDAD

    left join BA_TAB_DAT_ADICIONALES ba_tab
        on ba_tab.REFERENCIA = p.cod_persona
        and ba_tab.parametro like 'CELULAR_ONBOARDING'
--3seg
        
 LEFT JOIN (SELECT dir1.*
                FROM BA_DIRECCIONES dir1
                INNER JOIN (SELECT dir2.cod_persona AS cod_persona, dir2.TIPO, MAX(dir2.cod_direccion) AS cod_direccion
                            FROM BA_DIRECCIONES dir2 
                            GROUP BY dir2.cod_persona, dir2.TIPO) dir3
                    ON dir3.cod_persona = dir1.cod_persona
                    AND dir1.cod_direccion = dir3.cod_direccion) DIR
        ON P.COD_PERSONA = DIR.COD_PERSONA
        AND DIR.PRINCIPAL = 'S'  
 
    LEFT JOIN (SELECT T.*
                FROM BA_TELEFONOS T
                    INNER JOIN (SELECT MAX(T1.COD_TELEFONO) COD_TELEFONO, MAX(T1.PRINCIPAL) PRINCIPAL,
                                        T1.COD_PERSONA
                                FROM BA_TELEFONOS T1
                                GROUP BY T1.COD_PERSONA) T2
                        ON T.COD_PERSONA = T2.COD_PERSONA
                            AND T.COD_TELEFONO = T2.COD_TELEFONO
                ) TEL
        ON P.COD_PERSONA = TEL.COD_PERSONA
        AND TEL.PRINCIPAL = 'S'     
          
    LEFT JOIN (SELECT td1.*
            FROM AH_TAR_DEBITOS td1
            INNER JOIN (SELECT td2.NRO_CUENTA, td2.COD_PERSONA ,MAX(td2.NRO_EMISION) NRO_EMISION, MAX(td2.FEC_ACTIVACION) FEC_ACTIVACION
                            FROM AH_TAR_DEBITOS td2
                            WHERE td2.ADHERENTE = '00'
                            GROUP BY td2.NRO_CUENTA, td2.COD_PERSONA) td3
                ON td1.NRO_CUENTA = td3.NRO_CUENTA
                AND td1.COD_PERSONA = td3.COD_PERSONA
                AND td1.NRO_EMISION = td3.NRO_EMISION
                AND td1.FEC_ACTIVACION = td3.FEC_ACTIVACION) TD
        ON TD.NRO_CUENTA = CC.NRO_CUENTA
        AND TD.COD_PERSONA = P.COD_PERSONA	
        
    left join ba_cod_referencias refs
        on refs.dominio = 'EST_TAR_DEBITO'
            and refs.val_minimo = TD.cod_est_solicitud
    left join ge_entes entes_2
        on entes_2.cod_ente = TD.cod_ent_procesadora        
           
        
  LEFT JOIN (SELECT dir1.*
                FROM BA_DIRECCIONES dir1
                INNER JOIN (SELECT dir2.cod_persona AS cod_persona, MAX(dir2.cod_direccion) AS cod_direccion
                            FROM BA_DIRECCIONES dir2 
                            WHERE dir2.TIPO  = 'P'
                            GROUP BY dir2.cod_persona) dir3
                    ON dir1.cod_persona = dir3.cod_persona
                    AND dir1.cod_direccion = dir3.cod_direccion) DP
        ON DP.COD_PERSONA = P.COD_PERSONA
     
    LEFT JOIN BA_CIUDADES CCP 
        ON CCP.COD_CIUDAD  = DP.COD_CIUDAD 
        AND CCP.COD_PAIS = DP.COD_PAIS
             
        
    LEFT JOIN  (SELECT dir1.*
                FROM BA_DIRECCIONES dir1
                INNER JOIN (SELECT dir2.cod_persona AS cod_persona, MAX(dir2.cod_direccion) AS cod_direccion
                            FROM BA_DIRECCIONES dir2 
                            WHERE dir2.TIPO  = 'L'
                            GROUP BY dir2.cod_persona) dir3
                    ON dir1.cod_persona = dir3.cod_persona
                    AND dir1.cod_direccion = dir3.cod_direccion) DL 
        ON DL.COD_PERSONA  = P.COD_PERSONA
        
     LEFT JOIN BA_CIUDADES CCL 
        ON CCL.COD_PAIS = DL.COD_PAIS 
        AND CCL.COD_CIUDAD  = DL.COD_CIUDAD        
         

 
 left join ( (SELECT SUM(CANTIDAD) AS CANTIDAD, COD_PERSONA
                    FROM (SELECT COUNT(*) CANTIDAD, 'PR' AS MARCA, G.COD_PERSONA as COD_PERSONA
                        FROM GE_CTA_CLIENTES G
                            INNER JOIN pr_cta_prestamos PR
                                ON PR.NRO_CUENTA = G.NRO_CUENTA
                                AND PR.ESTADO <> 'N'
                        WHERE  G.RELACION = 'P'
                        group by G.COD_PERSONA
                        UNION
                        SELECT COUNT(*) CANTIDAD, 'TA' AS MARCA, G.COD_PERSONA as COD_PERSONA
                        FROM GE_CTA_CLIENTES G
                            INNER JOIN TA_CTA_TARJETAS PR
                                ON PR.NRO_CUENTA = G.NRO_CUENTA

                        WHERE  G.RELACION = 'P' 
                        group by G.COD_PERSONA
                    )
                    GROUP BY COD_PERSONA
                    )  ) CANT_PR
                ON CANT_PR.COD_PERSONA = P.COD_PERSONA
                         
      
    left join (SELECT DEP.DESCRIPCION as departamento, DIC.cod_persona
                FROM (SELECT dir1.*
                        FROM BA_DIRECCIONES dir1
                        INNER JOIN (SELECT dir2.cod_persona AS cod_persona, dir2.TIPO, MAX(dir2.cod_direccion) AS cod_direccion
                                    FROM BA_DIRECCIONES dir2 
                                    GROUP BY dir2.cod_persona, dir2.TIPO) dir3
                            ON dir1.cod_persona = dir3.cod_persona
                            AND dir1.cod_direccion = dir3.cod_direccion) DIC
                INNER JOIN BA_CIUDADES CIU ON CIU.COD_PAIS = DIC.COD_PAIS AND CIU.COD_CIUDAD = DIC.COD_CIUDAD
                INNER JOIN BA_DEPARTAMENTOS DEP ON DEP.COD_DEPARTAMENTO = CIU.COD_DEPARTAMENTO
                WHERE DIC.PRINCIPAL = 'S') dpto
        on dpto.COD_PERSONA = P.COD_PERSONA
        


        where CC.sal_Total > 0 

/* BLOQUE AHORRO PROGRAMADO*/

union all
SELECT 
  TO_CHAR((pag_cal.fu_obt_fec_actual(6)), 'yyyy-mm-dd') AS FECHA_PROCESO,
  ap.cod_oficina AS SUCURSAL_COD,
  ofi.descripcion AS sucursal,
  ap.cod_usu_promotor AS ASESOR,
  cl.cod_persona AS COD_PERSONA,
  p.nom_completo AS NOMBRE_CLIENTE,
  p.cod_actividad AS COD_ACTIVIDAD,
  ge_act.descripcion as DES_ACTIVIDAD,
  cl.cod_tip_deudor AS COD_TIP_DEUDOR,
  de.descripcion AS TIP_DEUDOR,
  p.nro_documento AS NRO_DOC,
  PF.COD_SEXO AS SEXO,
  to_char(PF.FEC_NACIMIENTO, 'yyyy-mm-dd') AS FEC_NACIMIENTO,
  cl.COD_GRU_ECONOMICO AS COD_GRU_ECONOMICO,
  GRU.DESCRIPCION AS DES_GRU_ECONOMICO,
  ap.cod_modulo AS MODULO_COD,
  MC.DESCRIPCION AS MODULO,
  ap.cod_modalidad AS MODALIDAD_COD,
  mods.descripcion as MODALIDAD,
  null AS SUB_MODALIDAD_COD,
  null AS SUB_MODALIDAD,
  ap.cod_tasa AS COD_TASA,
  ap.tas_personalizada AS DES_TASA,--GT.DESCRIPCION AS DES_TASA,
  ap.val_tasa,--CT_F.val_tasa,
  ap.denominacion AS DENOMINACION,
  ap.estado AS ESTADO_COD,
  est_c.descripcion as ESTADO,
  0 AS PLAZO,
  null AS DES_PLAZO,
  ap.nro_cuenta AS NRO_CUENTA,
  ap.DIG_VERIFICADOR AS DIG_VERIFICADOR,
  ap.cod_moneda AS COD_MONEDA,
  NVL(cotizacion.val_conversion, 1) AS cotizacion,
  ap.sal_Total - ap.sal_retenido AS SALDO_OR,
  CASE
    WHEN ap.COD_MONEDA = 'USD' THEN NVL(ROUND((ap.sal_Total  - ap.sal_retenido) * cotizacion.val_conversion), 0)
    ELSE ap.sal_Total - ap.sal_retenido 
  END AS SALDO_GS,
  CASE
    WHEN ap.COD_MONEDA = 'GS' THEN NVL(ROUND((ap.sal_Total  - ap.sal_retenido) /  cot_usd.val_conversion), 0)
    ELSE ap.sal_Total  - ap.sal_retenido
  END AS SALDO_USD,
    To_char(ap.FEC_APERTURA,'yyyy-mm-dd') AS FECHA_VALOR,
  To_char(ap.fec_ult_movimiento,'yyyy-mm-dd') AS FECHA_ULT_MOVIMIENTO,
  null AS fecha_vencimiento,
  null as SAL_PROMEDIO_OR, 
 null as SAL_PROMEDIO_GS,
  
  null as SAL_PROMEDIO_USD, 
  0 AS INTERES_OR,
  0 AS INTERES_GS,
  0 AS INTERES_USD,
  P.TIPO AS TIPOPERSONA,
	CASE
		WHEN (AP.sal_Total - AP.sal_retenido) < 50000000 THEN '1-) Menos de 50MM'
		WHEN (AP.sal_Total - AP.sal_retenido) >= 50000000 AND (AP.sal_Total-AP.sal_retenido) <= 100000000  THEN '2-) 50 A 100MM'
		WHEN (AP.sal_Total - AP.sal_retenido) > 100000000 AND (AP.sal_Total-AP.sal_retenido) <= 500000000  THEN '3-)100 A 500MM'
		WHEN (AP.sal_Total - AP.sal_retenido) > 500000000 AND (AP.sal_Total-AP.sal_retenido) <= 1000000000 THEN '4-)500 A 1000MM'
	ELSE '5-) Mas de 1000MM en adelante'
	END AS Rango,
	CASE
		WHEN (AP.sal_Total - AP.sal_retenido) >= 100000000 AND (AP.sal_Total - AP.sal_retenido) <= 200000000  THEN '1-)100 a 200MM'
		WHEN (AP.sal_Total - AP.sal_retenido) >= 200000001 AND (AP.sal_Total - AP.sal_retenido) <= 500000000  THEN '2-) 200 A 500MM'
		WHEN (AP.sal_Total - AP.sal_retenido) >= 500000001 AND (AP.sal_Total - AP.sal_retenido) <= 1000000000 THEN '3-) 500 A 1000MM'
		WHEN (AP.sal_Total - AP.sal_retenido) > 1000000000 THEN '4-) 1000MM en Adelante'
	ELSE '5-) Menor a 100MM'
	END AS Rango2,
	TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25) AS edad,
  CASE
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) < 25 THEN '18 a 24 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) >= 25 AND (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 30 THEN '25 a 30 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 30 AND  (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 40 THEN '31 a 40 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 40 AND  (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 50 THEN '41 a 50 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 50 AND  (round (((pag_cal.fu_obt_fec_actual(6)) - PF.FEC_NACIMIENTO)/ 365)) <= 60 THEN '51 a 60 años'
    WHEN (TRUNC(((pag_cal.fu_obt_fec_actual(6)) - pf.FEC_NACIMIENTO) / 365.25)) > 60 THEN 'Mayor a 60 años'
  ELSE 'Otro Rango'
  END AS RangoEdad,
  cl.cod_sec_contable,
  se.descripcion des_sec_contable,
  DIR.DIRECCION AS DIRECCON,
  TEL.TELEFONO AS TELEFONO,
  P.DIR_CORREO AS EMAIL,
  CASE
    WHEN CANT_PR.CANTIDAD >= 1 THEN 'S'
    ELSE 'N'
  END AS PRODU_ACT,
  null as TD,
  null as TAR_ACTIVA,--TD.TAR_ACTIVA AS TAR_ACTIVA,
  TO_CHAR(ap.FEC_VENCIMIENTO,'yyyy-mm-dd') AS FEC_VENCIMIENTO_TD,
	CASE     
		WHEN ap.COD_MONEDA = 'USD' THEN 
			CASE 
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 0 AND  NVL(ROUND(( ap.sal_Total -ap.sal_retenido)		 * (cotizacion.val_conversion) ),0) <= 200000 THEN '200000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 200001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 500000 THEN '500000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 500001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 1000000 THEN '1000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 1000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 3000000 THEN '3000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 3000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 5000000 THEN '5000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 5000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 10000000 THEN '10000000' 	  	   
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 10000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 20000000 THEN '20000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 20000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 50000000 THEN '50000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 50000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 100000000 THEN '100000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 100000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 170000000 THEN '170000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 170000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 300000000 THEN '300000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 300000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 500000000 THEN '500000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 500000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)	 * (cotizacion.val_conversion) ),0) <= 1000000000 THEN '1000000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 1000000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido) * (cotizacion.val_conversion) ),0) <= 3000000000 THEN '3000000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 3000000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido) * (cotizacion.val_conversion) ),0) <= 5000000000 THEN '5000000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 5000000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido) * (cotizacion.val_conversion) ),0) <= 10000000000 THEN '10000000000'
				WHEN NVL(ROUND(( ap.sal_Total -ap.sal_retenido)*(cotizacion.val_conversion) ),0) >= 10000000001 AND NVL(ROUND(( ap.sal_Total -ap.sal_retenido)* (cotizacion.val_conversion) ),0) <= 100000000000 THEN '100000000000'
			END  
		ELSE
			CASE 
				WHEN ap.sal_Total -ap.sal_retenido >= 0           AND ap.sal_Total -ap.sal_retenido <= 200000 	  THEN '200000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 200001      AND ap.sal_Total -ap.sal_retenido <= 500000 	  THEN '500000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 500001      AND ap.sal_Total -ap.sal_retenido <= 1000000 	  THEN '1000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 1000001     AND ap.sal_Total -ap.sal_retenido <= 3000000 	  THEN '3000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 3000001     AND ap.sal_Total -ap.sal_retenido <= 5000000 	  THEN '5000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 5000001     AND ap.sal_Total -ap.sal_retenido <= 10000000  	  THEN '10000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 10000001    AND ap.sal_Total -ap.sal_retenido <= 20000000 	  THEN '20000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 20000001    AND ap.sal_Total -ap.sal_retenido <= 50000000     THEN '50000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 50000001    AND ap.sal_Total -ap.sal_retenido <= 100000000    THEN '100000000'  
				WHEN ap.sal_Total -ap.sal_retenido >= 100000001   AND ap.sal_Total -ap.sal_retenido <= 170000000    THEN '170000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 170000001   AND ap.sal_Total -ap.sal_retenido <= 300000000    THEN '300000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 300000001   AND ap.sal_Total -ap.sal_retenido <= 500000000    THEN '500000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 500000001   AND ap.sal_Total -ap.sal_retenido <= 1000000000   THEN '1000000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 1000000001  AND ap.sal_Total -ap.sal_retenido <= 3000000000   THEN '3000000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 3000000001  AND ap.sal_Total -ap.sal_retenido <= 5000000000   THEN '5000000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 5000000001  AND ap.sal_Total -ap.sal_retenido <= 10000000000  THEN '10000000000' 
				WHEN ap.sal_Total -ap.sal_retenido >= 10000000001 AND ap.sal_Total -ap.sal_retenido <= 100000000000 THEN '100000000000' 
       	   END 
		END AS RANGO_SALDO,
	null AS RANGO_PLAZO,
	gc.cod_canal AS COD_CANAL,
  gc.descripcion AS DES_CANAL,
  CAM.cod_campana AS COD_CAMPANA,
  CAM.descripcion AS DES_CAMPANA,
  ap.NRO_CTA_RENOVADA,
  ap.nro_cta_capitalizacion AS NRO_CTA_CREDITO,
  ap.TIP_CAPITALIZACION AS COD_TIP_CAPITALIZACION,
  null as DES_TIP_CAPITALIZACION, 
  null AS COD_ENTE,
  null as DES_ENTE,
  null as  TIPO_ENTE,
  DP.COD_CIUDAD AS COD_CIUDAD_PAR,
  CASE
    WHEN ccp.descripcion IS NOT NULL THEN ccp.descripcion 
    ELSE 'Ciudad no registrada en el Sistema'
  END AS CIUDAD_PAR,
  DL.COD_CIUDAD AS COD_CIUDAD_LAB,
  CASE
    WHEN ccl.descripcion IS NOT NULL THEN ccl.descripcion
    ELSE 'Ciudad no registrada en el Sistema'
  END AS CIUDAD_LAB,
  to_char(ba_tab.fec_insercion,'yyyy-mm-dd') AS FECHA_ONBOARDING,
  dpto.DEPARTAMENTO,
  ap.capital AS CAPITAL,
  cl.cod_seg_cliente AS COD_SEGMENTO,
  gsc.descripcion AS SEGMENTO,
  null as est_solicitud_td,
  null as procesadora,--TD.cod_ent_procesadora || '-' || entes_2.descripcion AS procesadora,
  null as tip_tar_debito, --TD.tip_tar_debito,
  'AHORRO PROGRAMADO' AS MARCA


FROM ah_cta_plazos ap
    INNER JOIN ge_cta_clientes ct
        ON ct.nro_cuenta = ap.nro_cuenta
        AND ct.relacion = 'P'
    INNER JOIN ge_clientes cl
        ON cl.cod_persona = ct.cod_persona
    INNER JOIN ge_sec_contables se
        ON se.cod_sec_contable = cl.cod_sec_contable
    INNER JOIN BA_MODULOS MC
        ON MC.COD_MODULO = ap.COD_MODULO
    INNER JOIN ba_personas P
        ON P.cod_persona = cl.cod_persona
    LEFT JOIN ge_tip_deudores de
        ON de.cod_tip_deudor = cl.cod_tip_deudor
        AND se.cod_sec_contable = de.cod_sec_contable
    LEFT JOIN BA_PER_FISICAS PF
        ON PF.COD_PERSONA = P.COD_PERSONA
 
    LEFT JOIN (SELECT dir1.*
                FROM BA_DIRECCIONES dir1
                INNER JOIN (SELECT dir2.cod_persona AS cod_persona, dir2.TIPO, MAX(dir2.cod_direccion) AS cod_direccion
                            FROM BA_DIRECCIONES dir2 
                            GROUP BY dir2.cod_persona, dir2.TIPO) dir3
                    ON dir3.cod_persona = dir1.cod_persona
                    AND dir1.cod_direccion = dir3.cod_direccion) DIR
        ON P.COD_PERSONA = DIR.COD_PERSONA
        AND DIR.PRINCIPAL = 'S'   
    LEFT JOIN (SELECT T.*
                FROM BA_TELEFONOS T
                    INNER JOIN (SELECT MAX(T1.COD_TELEFONO) COD_TELEFONO, MAX(T1.PRINCIPAL) PRINCIPAL,
                                        T1.COD_PERSONA
                                FROM BA_TELEFONOS T1
                                GROUP BY T1.COD_PERSONA) T2
                        ON T.COD_PERSONA = T2.COD_PERSONA
                            AND T.COD_TELEFONO = T2.COD_TELEFONO
                ) TEL
        ON P.COD_PERSONA = TEL.COD_PERSONA
        AND TEL.PRINCIPAL = 'S'
    LEFT JOIN GE_CANALES gc
        ON GC.COD_CANAL = ap.COD_CANAL
    LEFT JOIN CR_CAMPANAS CAM 
        ON CAM.COD_CAMPANA = ap.COD_CAMPANA  
    LEFT JOIN (SELECT td1.*
            FROM AH_TAR_DEBITOS td1
            INNER JOIN (SELECT td2.NRO_CUENTA, td2.COD_PERSONA ,MAX(td2.NRO_EMISION) NRO_EMISION, MAX(td2.FEC_ACTIVACION) FEC_ACTIVACION
                            FROM AH_TAR_DEBITOS td2
                            WHERE td2.ADHERENTE = '00'
                            GROUP BY td2.NRO_CUENTA, td2.COD_PERSONA) td3
                ON td1.NRO_CUENTA = td3.NRO_CUENTA
                AND td1.COD_PERSONA = td3.COD_PERSONA
                AND td1.NRO_EMISION = td3.NRO_EMISION
                AND td1.FEC_ACTIVACION = td3.FEC_ACTIVACION) TD
        ON TD.NRO_CUENTA = ap.NRO_CUENTA
        AND TD.COD_PERSONA = P.COD_PERSONA	
    LEFT JOIN GE_GRU_ECONOMICOS GRU 
        ON GRU.COD_GRU_ECONOMICO = CL.COD_GRU_ECONOMICO
    LEFT JOIN (SELECT dir1.*
                FROM BA_DIRECCIONES dir1
                INNER JOIN (SELECT dir2.cod_persona AS cod_persona, MAX(dir2.cod_direccion) AS cod_direccion
                            FROM BA_DIRECCIONES dir2 
                            WHERE dir2.TIPO  = 'P'
                            GROUP BY dir2.cod_persona) dir3
                    ON dir1.cod_persona = dir3.cod_persona
                    AND dir1.cod_direccion = dir3.cod_direccion) DP
        ON DP.COD_PERSONA = P.COD_PERSONA
    LEFT JOIN BA_CIUDADES CCP 
        ON CCP.COD_CIUDAD  = DP.COD_CIUDAD 
        AND CCP.COD_PAIS = DP.COD_PAIS
    LEFT JOIN  (SELECT dir1.*
                FROM BA_DIRECCIONES dir1
                INNER JOIN (SELECT dir2.cod_persona AS cod_persona, MAX(dir2.cod_direccion) AS cod_direccion
                            FROM BA_DIRECCIONES dir2 
                            WHERE dir2.TIPO  = 'L'
                            GROUP BY dir2.cod_persona) dir3
                    ON dir1.cod_persona = dir3.cod_persona
                    AND dir1.cod_direccion = dir3.cod_direccion) DL 
        ON DL.COD_PERSONA  = P.COD_PERSONA
    LEFT JOIN BA_CIUDADES CCL 
        ON CCL.COD_PAIS = DL.COD_PAIS 
        AND CCL.COD_CIUDAD  = DL.COD_CIUDAD 
    LEFT JOIN GE_SEG_CLIENTES gsc
        ON CL.COD_SEG_CLIENTE = GSC.COD_SEG_CLIENTE

    left join ge_modalidades mods
        on mods.cod_modulo = ap.COD_MODULO
            and mods.cod_modalidad = ap.COD_MODALIDAD
	
    left join ge_est_cuentas est_c
        on est_c.cod_modulo = ap.cod_modulo
        and est_c.cod_modalidad = ap.cod_modalidad
        and est_c.estado = ap.estado

    left join ge_cotizaciones cotizacion
        on cotizacion.cod_moneda = ap.cod_moneda
		and cotizacion.fecha = pag_cal.fu_obt_fec_actual(6)

    left join ba_oficinas ofi
        on ofi.cod_oficina = ap.cod_oficina
    left join ge_entes entes_2
        on entes_2.cod_ente = TD.cod_ent_procesadora
    left join ( (SELECT SUM(CANTIDAD) AS CANTIDAD, COD_PERSONA
                    FROM (SELECT COUNT(*) CANTIDAD, 'PR' AS MARCA, G.COD_PERSONA as COD_PERSONA
                        FROM GE_CTA_CLIENTES G
                            INNER JOIN pr_cta_prestamos PR
                                ON PR.NRO_CUENTA = G.NRO_CUENTA
                                AND PR.ESTADO <> 'N'
                        WHERE /*G.COD_PERSONA = P.COD_PERSONA
                        AND*/ G.RELACION = 'P' --AND G.COD_MODULO IN (5,6)
                        group by G.COD_PERSONA
                        UNION
                        SELECT COUNT(*) CANTIDAD, 'TA' AS MARCA, G.COD_PERSONA as COD_PERSONA
                        FROM GE_CTA_CLIENTES G
                            INNER JOIN TA_CTA_TARJETAS PR
                                ON PR.NRO_CUENTA = G.NRO_CUENTA
                                --AND PR.ESTADO <> 'C'
                        WHERE /*G.COD_PERSONA = P.COD_PERSONA
                        AND*/ G.RELACION = 'P' --AND G.COD_MODULO IN (5,6)
                        group by G.COD_PERSONA
                    )
                    GROUP BY COD_PERSONA
                    )  )  CANT_PR
                ON CANT_PR.COD_PERSONA = P.COD_PERSONA
    left join ge_cotizaciones cot_usd
        on cot_usd.cod_moneda = 'USD'
        and cot_usd.fecha = pag_cal.fu_obt_fec_actual(6)
        
    left join ge_actividades ge_act
        on cast(ge_act.cod_actividad as decimal) = cast(P.COD_ACTIVIDAD as decimal)
    left join ge_rub_economicos ge_rub_e
        on ge_rub_e.cod_rub_economico = P.COD_ACTIVIDAD
    left join (SELECT DEP.DESCRIPCION as departamento, DIC.cod_persona
                FROM (SELECT dir1.*
                        FROM BA_DIRECCIONES dir1
                        INNER JOIN (SELECT dir2.cod_persona AS cod_persona, dir2.TIPO, MAX(dir2.cod_direccion) AS cod_direccion
                                    FROM BA_DIRECCIONES dir2 
                                    GROUP BY dir2.cod_persona, dir2.TIPO) dir3
                            ON dir1.cod_persona = dir3.cod_persona
                            AND dir1.cod_direccion = dir3.cod_direccion) DIC
                INNER JOIN BA_CIUDADES CIU ON CIU.COD_PAIS = DIC.COD_PAIS AND CIU.COD_CIUDAD = DIC.COD_CIUDAD
                INNER JOIN BA_DEPARTAMENTOS DEP ON DEP.COD_DEPARTAMENTO = CIU.COD_DEPARTAMENTO
                WHERE DIC.PRINCIPAL = 'S') dpto
        on dpto.COD_PERSONA = P.COD_PERSONA
    left join BA_TAB_DAT_ADICIONALES ba_tab
        on ba_tab.REFERENCIA = p.cod_persona
        and ba_tab.parametro like 'CELULAR_ONBOARDING'