CREATE OR REPLACE PROCEDURE IT.PRC_GEN_DAT_CAM_PRIVADA IS
  V_FECHA DATE := TO_DATE(FUG_OBT_PARDINAMICO('FEC_CAM_PRIVADAS'),
                          'dd/mm/yyyy');
  PROCEDURE PR_GEN_DAT_CAM_PRIVADA(P_FECHA IN DATE) IS
    V_FEC_ACTUAL DATE := FUG_OBT_FEC_HABIL(P_FECHA, 1);
  BEGIN
    --Trucar la tabla--
    EXECUTE IMMEDIATE ('truncate table cc_dat_cam_privadas');
  
    --Insertar los datos de los depositos--
    --1
    INSERT INTO CC_DAT_CAM_PRIVADAS
      (FECHA,
       TIPO,
       OFICINA,
       ORDEN,
       BANCO,
       COD_MONEDA,
       MTO_TRA_400,
       MTO_ENVIADO,
       MTO_DEVUELTO,
       MTO_RECIBIDO,
       MTO_RECHAZADO,
       MTO_NETO,
       ACCION)
    
      SELECT AA.FECHA,
             AA.TIPO,
             AA.OFI_ORI,
             AA.ORDEN,
             AA.BANCO,
             AA.MON,
             SUM(nvl(AA.MTO_400, 0)) MTO_400,
             SUM(nvl(AA.ENVIADO, 0)) ENVIADO,
             SUM(nvl(AA.DEVUELTO, 0)) DEVUELTO,
             SUM(nvl(AA.RECIBIDO, 0)) RECIBIDO,
             SUM(nvl(AA.RECHAZADO, 0)) RECHAZADO,
             SUM(nvl(AA.NETO, 0)) NETO,
             AA.ACCION
        FROM (SELECT A.FECHA,
                     'OFICINAS' TIPO,
                     TO_CHAR(K.COD_OFICINA, '009') || '-' || K.DESCRIPCION OFI_ORI,
                     'COMP_BANCOS' ORDEN,
                     TO_CHAR(Z.COD_BANCO, '009') || '-' || Z.DENOMINACION BANCO,
                     Z.COD_MONEDA MON,
                     MTO_400,
                     MTO_7902 ENVIADO,
                     NVL(T3.MTO_3321, 0) DEVUELTO,
                     MTO_3320 RECIBIDO,
                     MTO_3322 RECHAZADO,
                     NVL(MTO_7902, 0) - NVL(T3.MTO_3321, 0) -
                     NVL(MTO_3320, 0) + NVL(MTO_3322, 0) NETO,
                     DECODE(SIGN(NVL(MTO_7902, 0) - NVL(T3.MTO_3321, 0) -
                                 NVL(MTO_3320, 0) + NVL(MTO_3322, 0)),
                            -1,
                            'PAGAR',
                            'COBRAR') ACCION
                FROM CC_CTA_BANCARIAS Z,
                     BA_OFICINAS K,
                     (SELECT DISTINCT A.FECHA,
                                      B.COD_BANCO,
                                      A.COD_OFI_ORIGEN,
                                      A.COD_MONEDA
                        FROM CC_MOVIMIENTOS_HIS A,
                             CC_CTA_BANCARIAS   B,
                             GE_BANCOS          C,
                             BA_OFICINAS        D
                       WHERE A.FECHA = P_FECHA
                         AND A.REVERSADO = 'N'
                         AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                         AND B.NRO_CUENTA = A.NRO_CUENTA
                         AND C.COD_BANCO = B.COD_BANCO
                         AND D.COD_OFICINA = A.COD_OFI_ORIGEN
                         AND (((A.COD_TRA_PADRE = 7902) AND
                             (A.COD_TRANSACCION = 7902)) OR
                             ((A.COD_TRA_PADRE = 3320) AND
                             (A.COD_TRANSACCION IN (503, 602))) OR
                             ((A.COD_TRA_PADRE = 3322) AND
                             (A.COD_TRANSACCION IN (503, 602))) OR
                             ((A.COD_TRA_PADRE = 400) AND
                             (A.COD_TRANSACCION = 2607)))
                      UNION
                      SELECT DISTINCT A.FECHA,
                                      B.COD_BANCO,
                                      A.COD_OFI_ORIGEN,
                                      A.COD_MONEDA
                        FROM AH_MOVIMIENTOS_HIS A,
                             CC_CTA_BANCARIAS   B,
                             GE_BANCOS          C,
                             BA_OFICINAS        D
                       WHERE A.FECHA = P_FECHA
                         AND A.REVERSADO = 'N'
                         AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                         AND B.NRO_CUENTA = A.NRO_CUENTA
                         AND C.COD_BANCO = B.COD_BANCO
                         AND D.COD_OFICINA = A.COD_OFI_ORIGEN
                         AND ((A.COD_TRA_PADRE = 400) AND
                             (A.COD_TRANSACCION = 2607))) A,
                     (SELECT A.FECHA,
                             C.COD_BANCO,
                             C.DESCRIPCION DES_BANCO,
                             A.COD_OFI_ORIGEN,
                             A.COD_MONEDA,
                             COUNT(*) CAN,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 400) AND
                                            (A.COD_TRANSACCION = 2607)) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_400,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 7902) AND
                                            (A.COD_TRANSACCION = 7902)) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_7902,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 3320) AND
                                            (A.COD_TRANSACCION IN (503, 602))) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_3320,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 3322) AND
                                            (A.COD_TRANSACCION IN (503, 602))) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_3322,
                             SUM(NVL(A.MONTO, 0)) MTO_TOT
                        FROM CC_MOVIMIENTOS_HIS A,
                             CC_CTA_BANCARIAS   B,
                             GE_BANCOS          C
                       WHERE A.FECHA = P_FECHA
                         AND A.REVERSADO = 'N'
                         AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                         AND B.NRO_CUENTA = A.NRO_CUENTA
                         AND C.COD_BANCO = B.COD_BANCO
                         AND (((A.COD_TRA_PADRE = 7902) AND
                             (A.COD_TRANSACCION = 7902)) OR
                             ((A.COD_TRA_PADRE = 3320) AND
                             (A.COD_TRANSACCION IN (503, 602))) OR
                             ((A.COD_TRA_PADRE = 3322) AND
                             (A.COD_TRANSACCION IN (503, 602))) OR
                             ((A.COD_TRA_PADRE = 400) AND
                             (A.COD_TRANSACCION = 2607)))
                       GROUP BY A.FECHA,
                                C.COD_BANCO,
                                C.DESCRIPCION,
                                A.COD_OFI_ORIGEN,
                                A.COD_MONEDA
                      UNION
                      
                      SELECT A.FECHA,
                             C.COD_BANCO,
                             C.DESCRIPCION DES_BANCO,
                             A.COD_OFI_ORIGEN,
                             A.COD_MONEDA,
                             COUNT(*) CAN,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 400) AND
                                            (A.COD_TRANSACCION = 2607)) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_400,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 7902) AND
                                            (A.COD_TRANSACCION = 7902)) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_7902,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 3320) AND
                                            (A.COD_TRANSACCION IN (503, 602))) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_3320,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 3322) AND
                                            (A.COD_TRANSACCION IN (503, 602))) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_3322,
                             SUM(NVL(A.MONTO, 0)) MTO_TOT
                        FROM AH_MOVIMIENTOS_HIS A,
                             CC_CTA_BANCARIAS   B,
                             GE_BANCOS          C
                       WHERE A.FECHA = P_FECHA
                         AND A.REVERSADO = 'N'
                         AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                         AND B.NRO_CUENTA = A.NRO_CUENTA
                         AND C.COD_BANCO = B.COD_BANCO
                         AND ((A.COD_TRA_PADRE = 400) AND
                             (A.COD_TRANSACCION = 2607))
                       GROUP BY A.FECHA,
                                C.COD_BANCO,
                                C.DESCRIPCION,
                                A.COD_OFI_ORIGEN,
                                A.COD_MONEDA) T2,
                     (SELECT A.FECHA,
                             C.COD_BANCO,
                             C.DESCRIPCION DES_BANCO,
                             A.COD_OFI_ORIGEN,
                             A.COD_MONEDA,
                             COUNT(*) CAN,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 3321) AND
                                            (A.COD_TRANSACCION IN (503, 602))) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_3321
                        FROM GV_MOVIMIENTOS   A,
                             CC_CTA_BANCARIAS B,
                             GE_BANCOS        C
                       WHERE A.FECHA = V_FEC_ACTUAL
                         AND A.REVERSADO = 'N'
                         AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                         AND B.NRO_CUENTA = A.NRO_CUENTA
                         AND C.COD_BANCO = B.COD_BANCO
                         AND (((A.COD_TRA_PADRE = 3321) AND
                             (A.COD_TRANSACCION IN (503, 602))))
                       GROUP BY A.FECHA,
                                C.COD_BANCO,
                                C.DESCRIPCION,
                                A.COD_OFI_ORIGEN,
                                A.COD_MONEDA) T3
               WHERE A.FECHA = P_FECHA
                 AND Z.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                 AND A.COD_BANCO = Z.COD_BANCO
                 AND K.COD_OFICINA = A.COD_OFI_ORIGEN
                 AND T2.FECHA(+) = A.FECHA
                 AND T2.COD_BANCO(+) = A.COD_BANCO
                 AND T2.COD_OFI_ORIGEN(+) = A.COD_OFI_ORIGEN
                 AND T2.COD_MONEDA(+) = A.COD_MONEDA
                 AND T3.FECHA(+) = V_FEC_ACTUAL
                 AND T3.COD_BANCO(+) = A.COD_BANCO
                 AND T3.COD_MONEDA(+) = A.COD_MONEDA
                 AND T3.COD_OFI_ORIGEN(+) = A.COD_OFI_ORIGEN) AA
       GROUP BY AA.FECHA,
                AA.TIPO,
                AA.OFI_ORI,
                AA.ORDEN,
                AA.BANCO,
                AA.MON,
                AA.ACCION;
    --2
    INSERT INTO CC_DAT_CAM_PRIVADAS
      (FECHA,
       TIPO,
       OFICINA,
       ORDEN,
       BANCO,
       COD_MONEDA,
       MTO_TRA_400,
       MTO_ENVIADO,
       MTO_DEVUELTO,
       MTO_RECIBIDO,
       MTO_RECHAZADO,
       MTO_NETO,
       ACCION)
    
      SELECT BB.FECHA,
             BB.TIPO,
             BB.OFI_ORI,
             BB.ORDEN,
             BB.BANCO,
             BB.MON,
             SUM(BB.MTO_400) MTO_400,
             0,
             0,
             0,
             0,
             0,
             NULL
        FROM (SELECT A.FECHA,
                     'OFICINAS' TIPO,
                     TO_CHAR(K.COD_OFICINA, '009') || '-' || K.DESCRIPCION OFI_ORI,
                     'COMP_BANCOS' ORDEN,
                     '999-DEPOSITO_400' BANCO,
                     A.COD_MONEDA MON,
                     SUM(NVL(CASE
                               WHEN ((A.COD_TRA_PADRE = 400) AND
                                    (A.COD_TRANSACCION = 2607)) THEN
                                A.MONTO
                               ELSE
                                0
                             END,
                             0)) MTO_400,
                     0,
                     0,
                     0,
                     0,
                     0,
                     NULL
                FROM CC_MOVIMIENTOS_HIS A, BA_OFICINAS K
               WHERE A.FECHA = P_FECHA
                 AND A.REVERSADO = 'N'
                 AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                 AND ((A.COD_TRA_PADRE = 400) AND (A.COD_TRANSACCION = 2607))
                 AND K.COD_OFICINA = A.COD_OFI_ORIGEN
               GROUP BY A.FECHA,
                        TO_CHAR(K.COD_OFICINA, '009') || '-' ||
                        K.DESCRIPCION,
                        A.COD_MONEDA
              UNION
              SELECT A.FECHA,
                     'OFICINAS' TIPO,
                     TO_CHAR(K.COD_OFICINA, '009') || '-' || K.DESCRIPCION OFI_ORI,
                     'COMP_BANCOS' ORDEN,
                     '999-DEPOSITO_400' BANCO,
                     A.COD_MONEDA MON,
                     SUM(NVL(CASE
                               WHEN ((A.COD_TRA_PADRE = 400) AND
                                    (A.COD_TRANSACCION = 2607)) THEN
                                A.MONTO
                               ELSE
                                0
                             END,
                             0)) MTO_400,
                     0,
                     0,
                     0,
                     0,
                     0,
                     NULL
                FROM AH_MOVIMIENTOS_HIS A, BA_OFICINAS K
               WHERE A.FECHA = P_FECHA
                 AND A.REVERSADO = 'N'
                 AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                 AND ((A.COD_TRA_PADRE = 400) AND (A.COD_TRANSACCION = 2607))
                 AND K.COD_OFICINA = A.COD_OFI_ORIGEN
               GROUP BY A.FECHA,
                        TO_CHAR(K.COD_OFICINA, '009') || '-' ||
                        K.DESCRIPCION,
                        A.COD_MONEDA) BB
       GROUP BY BB.FECHA, BB.TIPO, BB.OFI_ORI, BB.ORDEN, BB.BANCO, BB.MON;
  
    --Pagos y Cobro de Bancos--
    --3
    INSERT INTO CC_DAT_CAM_PRIVADAS
      (FECHA,
       TIPO,
       OFICINA,
       ORDEN,
       BANCO,
       COD_MONEDA,
       MTO_TRA_400,
       MTO_ENVIADO,
       MTO_DEVUELTO,
       MTO_RECIBIDO,
       MTO_RECHAZADO,
       MTO_NETO,
       ACCION)
      SELECT CC.FECHA,
             CC.TIPO,
             CC.BANCO,
             CC.ORDEN,
             CC.OFI_ORI,
             CC.MON,
             SUM(nvl(CC.MTO_400, 0)) MTO_400,
             SUM(nvl(CC.ENVIADO, 0)) ENVIADO,
             SUM(nvl(CC.DEVUELTO, 0)) DEVUELTO,
             SUM(nvl(CC.RECIBIDO, 0)) RECIBIDO,
             SUM(nvl(CC.RECHAZADO, 0)) RECHAZADO,
             SUM(nvl(CC.NETO, 0)) NETO,
             CC.ACCION
        FROM (SELECT A.FECHA,
                     'PAGO_COBRO_BCO' TIPO,
                     TO_CHAR(Z.COD_BANCO, '009') || '-' || Z.DENOMINACION BANCO,
                     'SUMA_BANCOS' ORDEN,
                     '999-TOTALES' OFI_ORI,
                     Z.COD_MONEDA MON,
                     MTO_400,
                     MTO_7902 ENVIADO,
                     NVL(T3.MTO_3321, 0) DEVUELTO,
                     MTO_3320 RECIBIDO,
                     MTO_3322 RECHAZADO,
                     NVL(MTO_7902, 0) - NVL(T3.MTO_3321, 0) -
                     NVL(MTO_3320, 0) + NVL(MTO_3322, 0) NETO,
                     DECODE(SIGN(NVL(MTO_7902, 0) - NVL(T3.MTO_3321, 0) -
                                 NVL(MTO_3320, 0) + NVL(MTO_3322, 0)),
                            -1,
                            'PAGAR',
                            'COBRAR') ACCION
                FROM CC_CTA_BANCARIAS Z,
                     (SELECT DISTINCT A.FECHA, B.COD_BANCO, A.COD_MONEDA
                        FROM CC_MOVIMIENTOS_HIS A,
                             CC_CTA_BANCARIAS   B,
                             GE_BANCOS          C,
                             BA_OFICINAS        D
                       WHERE A.FECHA = P_FECHA
                         AND A.REVERSADO = 'N'
                         AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                         AND B.NRO_CUENTA = A.NRO_CUENTA
                         AND C.COD_BANCO = B.COD_BANCO
                         AND D.COD_OFICINA = A.COD_OFI_ORIGEN
                         AND (((A.COD_TRA_PADRE = 7902) AND
                             (A.COD_TRANSACCION = 7902)) OR
                             ((A.COD_TRA_PADRE = 3320) AND
                             (A.COD_TRANSACCION IN (503, 602))) OR
                             ((A.COD_TRA_PADRE = 3322) AND
                             (A.COD_TRANSACCION IN (503, 602))) OR
                             ((A.COD_TRA_PADRE = 400) AND
                             (A.COD_TRANSACCION = 2607)))
                      UNION
                      SELECT DISTINCT A.FECHA, B.COD_BANCO, A.COD_MONEDA
                        FROM AH_MOVIMIENTOS_HIS A,
                             CC_CTA_BANCARIAS   B,
                             GE_BANCOS          C,
                             BA_OFICINAS        D
                       WHERE A.FECHA = P_FECHA
                         AND A.REVERSADO = 'N'
                         AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                         AND B.NRO_CUENTA = A.NRO_CUENTA
                         AND C.COD_BANCO = B.COD_BANCO
                         AND D.COD_OFICINA = A.COD_OFI_ORIGEN
                         AND ((A.COD_TRA_PADRE = 400) AND
                             (A.COD_TRANSACCION = 2607))) A,
                     (SELECT A.FECHA,
                             C.COD_BANCO,
                             C.DESCRIPCION DES_BANCO,
                             A.COD_MONEDA,
                             COUNT(*) CAN,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 400) AND
                                            (A.COD_TRANSACCION = 2607)) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_400,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 7902) AND
                                            (A.COD_TRANSACCION = 7902)) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_7902,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 3320) AND
                                            (A.COD_TRANSACCION IN (503, 602))) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_3320,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 3322) AND
                                            (A.COD_TRANSACCION IN (503, 602))) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_3322,
                             SUM(NVL(A.MONTO, 0)) MTO_TOT
                        FROM CC_MOVIMIENTOS_HIS A,
                             CC_CTA_BANCARIAS   B,
                             GE_BANCOS          C
                       WHERE A.FECHA = P_FECHA
                         AND A.REVERSADO = 'N'
                         AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                         AND B.NRO_CUENTA = A.NRO_CUENTA
                         AND C.COD_BANCO = B.COD_BANCO
                         AND (((A.COD_TRA_PADRE = 7902) AND
                             (A.COD_TRANSACCION = 7902)) OR
                             ((A.COD_TRA_PADRE = 3320) AND
                             (A.COD_TRANSACCION IN (503, 602))) OR
                             ((A.COD_TRA_PADRE = 3322) AND
                             (A.COD_TRANSACCION IN (503, 602))) OR
                             ((A.COD_TRA_PADRE = 400) AND
                             (A.COD_TRANSACCION = 2607)))
                       GROUP BY A.FECHA,
                                C.COD_BANCO,
                                C.DESCRIPCION,
                                A.COD_MONEDA
                      UNION
                      SELECT A.FECHA,
                             C.COD_BANCO,
                             C.DESCRIPCION DES_BANCO,
                             A.COD_MONEDA,
                             COUNT(*) CAN,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 400) AND
                                            (A.COD_TRANSACCION = 2607)) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_400,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 7902) AND
                                            (A.COD_TRANSACCION = 7902)) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_7902,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 3320) AND
                                            (A.COD_TRANSACCION IN (503, 602))) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_3320,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 3322) AND
                                            (A.COD_TRANSACCION IN (503, 602))) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_3322,
                             SUM(NVL(A.MONTO, 0)) MTO_TOT
                        FROM AH_MOVIMIENTOS_HIS A,
                             CC_CTA_BANCARIAS   B,
                             GE_BANCOS          C
                       WHERE A.FECHA = P_FECHA
                         AND A.REVERSADO = 'N'
                         AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                         AND B.NRO_CUENTA = A.NRO_CUENTA
                         AND C.COD_BANCO = B.COD_BANCO
                         AND ((A.COD_TRA_PADRE = 400) AND
                             (A.COD_TRANSACCION = 2607))
                       GROUP BY A.FECHA,
                                C.COD_BANCO,
                                C.DESCRIPCION,
                                A.COD_MONEDA) T2,
                     (SELECT A.FECHA,
                             C.COD_BANCO,
                             C.DESCRIPCION DES_BANCO,
                             A.COD_MONEDA,
                             COUNT(*) CAN,
                             SUM(NVL(CASE
                                       WHEN ((A.COD_TRA_PADRE = 3321) AND
                                            (A.COD_TRANSACCION IN (503, 602))) THEN
                                        A.MONTO
                                       ELSE
                                        0
                                     END,
                                     0)) MTO_3321
                        FROM GV_MOVIMIENTOS   A,
                             CC_CTA_BANCARIAS B,
                             GE_BANCOS        C
                       WHERE A.FECHA = V_FEC_ACTUAL
                         AND A.REVERSADO = 'N'
                         AND A.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                         AND B.NRO_CUENTA = A.NRO_CUENTA
                         AND C.COD_BANCO = B.COD_BANCO
                         AND (((A.COD_TRA_PADRE = 3321) AND
                             (A.COD_TRANSACCION IN (503, 602))))
                       GROUP BY A.FECHA,
                                C.COD_BANCO,
                                C.DESCRIPCION,
                                A.COD_MONEDA) T3
               WHERE A.FECHA = P_FECHA
                 AND Z.COD_MONEDA = PAG_GEN.FU_OBT_MON_LOCAL
                 AND A.COD_BANCO = Z.COD_BANCO
                 AND T2.FECHA(+) = A.FECHA
                 AND T2.COD_BANCO(+) = A.COD_BANCO
                 AND T2.COD_MONEDA(+) = A.COD_MONEDA
                 AND T3.FECHA(+) = V_FEC_ACTUAL
                 AND T3.COD_BANCO(+) = A.COD_BANCO
                 AND T3.COD_MONEDA(+) = A.COD_MONEDA) CC
       GROUP BY CC.FECHA,
                CC.TIPO,
                CC.BANCO,
                CC.ORDEN,
                CC.OFI_ORI,
                CC.MON,
                CC.ACCION;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20005,
                              'Error en pr_gen_dat_cam_privada: ' ||
                              SQLERRM);
  END;
BEGIN
  --Evaluacion de fecha--
  IF V_FECHA IS NULL THEN
    V_FECHA := FUG_OBT_FEC_ANTERIOR(4);
  END IF;

  --Correr el proceso--
  PR_GEN_DAT_CAM_PRIVADA(V_FECHA);

  --Eliminacion del Parametro--
  DELETE FROM GE_PAR_DINAMICOS X WHERE X.PARAMETRO = 'FEC_CAM_PRIVADAS';
EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20005,
                            'Error en prc_gen_dat_cam_privada: ' || SQLERRM);
END;
/

