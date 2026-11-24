CREATE OR REPLACE PROCEDURE IT.PRB_ACT_SALDOS IS
  CURSOR SALD_M IS
         SELECT CB_ASIENTOS.COD_OFICINA, CB_ASIENTOS_DET.COD_RUBRO,
                CB_ASIENTOS_DET.TIP_MOVIMIENTO, BA_OFICINAS.DESCRIPCION,
                SUM(NVL(CB_ASIENTOS_DET.MTO_MON_LOCAL,0)),
                SUM(NVL(CB_ASIENTOS_DET.MTO_MON_RUBRO,0)),
                decode(substr(cb_rubros.cod_rubro,14,2),'98','USD',CB_RUBROS.COD_MONEDA)
                --CB_RUBROS.COD_MONEDA
           FROM CB_RUBROS, CB_ASIENTOS, CB_ASIENTOS_DET, BA_OFICINAS
          WHERE CB_ASIENTOS.COD_OFICINA = CB_ASIENTOS_DET.COD_OFICINA
            AND CB_ASIENTOS.COD_OFICINA = BA_OFICINAS.COD_OFICINA
            AND CB_ASIENTOS.NRO_ASIENTO = CB_ASIENTOS_DET.NRO_ASIENTO
            AND CB_ASIENTOS.CONFIRMADO = 'S'
            AND CB_ASIENTOS.ACTUALIZADO = 'N'
            AND CB_RUBROS.COD_RUBRO = CB_ASIENTOS_DET.COD_RUBRO
          GROUP BY CB_ASIENTOS.COD_OFICINA, CB_ASIENTOS_DET.COD_RUBRO,
                   CB_ASIENTOS_DET.TIP_MOVIMIENTO, BA_OFICINAS.DESCRIPCION,
                  -- CB_RUBROS.COD_MONEDA;
                  decode(substr(cb_rubros.cod_rubro,14,2),'98','USD',CB_RUBROS.COD_MONEDA);
  ---
  CDOFICI NUMBER(03);
  CDCUENT VARCHAR2(15);
  TPMOVIM VARCHAR2(01);
  NMOFICI VARCHAR2(35);
  IMMOVGS NUMBER(18,2);
  IMMONEX NUMBER(18,2);
  WW_IMMOUSD NUMBER(18,2);
  WCDMONED VARCHAR2(4);
  W_MON_FUERTE VARCHAR2(4) := PAG_GEN.FU_OBT_MON_FUERTE;
  W_MON_LOCAL  VARCHAR2(4) := PAG_GEN.FU_OBT_MON_LOCAL;
  --
  v_fec_actual date := pag_cal.fu_obt_fec_actual(2);
  /* tomo el año y mes de actual */
  v_ano number(4) := to_char(v_fec_actual,'yyyy');
  v_mes number(2) := to_char(v_fec_actual,'mm');
  --
  ---
  PROCEDURE lp_sum_sal_consolidados(WCDCUENT IN CHAR,
                                    WTPMOVIM IN CHAR,
                                    WIMMOVGS IN NUMBER,
                                    WIMMONEX IN NUMBER,
                                    WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  WDUMMY  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
      IF SQL%FOUND THEN
         LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO CDCUENT, CDCTPAD
           FROM CB_RUBROS
          WHERE COD_RUBRO = CDCTPAD;
             IF SQL%FOUND THEN
                ---------------------------------------------------------
                -- VERIFICA SI EXISTE EN CB_SAL_CONSOLIDADOS EL PADRE
                ---------------------------------------------------------
                BEGIN
                  SELECT 'X' INTO WDUMMY
                    FROM CB_SAL_CONSOLIDADOS
                   WHERE COD_RUBRO = CDCUENT
                     AND ANO = v_ano
                     AND MES = v_mes
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                       INSERT INTO CB_SAL_CONSOLIDADOS
                                       (COD_RUBRO, ANO, MES, PROTEGIDO)
                                VALUES (CDCUENT, v_ano, v_mes, 'S');
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||CDCUENT||' - '||sqlerrm);
                END;
                IF WTPMOVIM = 'D' THEN
                      ----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE DEBITO --
                      ----------------------------------------
                      UPDATE CB_SAL_CONSOLIDADOS
                        SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                ELSE
                      -----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE CREDITO --
                      -----------------------------------------
                      UPDATE CB_SAL_CONSOLIDADOS
                        SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                END IF;
             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP;
      END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuenta');
  END;
  --
  PROCEDURE lp_ins_rub_oficinas(WCDOFICI IN NUMBER, WCDCUENT IN CHAR) IS
  CDCUENT VARCHAR2(15);
  CDDIGVE NUMBER(01);
  CDCTDFC VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  CDTIPCT NUMBER(01);
  CDNIVCT NUMBER(02);
  NRMAYOR NUMBER(05);
  BEGIN
  SELECT COD_RUBRO, null, null, COD_RUB_PADRE,
         TIPO, NIVEL, ULT_NRO_MAYOR
    INTO CDCUENT, CDDIGVE, CDCTDFC, CDCTPAD,
         CDTIPCT, CDNIVCT, NRMAYOR
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
  IF SQL%FOUND THEN
     INSERT INTO CB_RUB_OFICINAS (COD_OFICINA, COD_RUBRO, ULT_NRO_EXTRACTO)
                  VALUES (WCDOFICI, CDCUENT, NRMAYOR);
     LOOP
     BEGIN
     SELECT COD_RUBRO, COD_RUB_PADRE, TIPO, NIVEL, ULT_NRO_MAYOR
       INTO CDCUENT, CDCTPAD, CDTIPCT, CDNIVCT, NRMAYOR
       FROM CB_RUBROS
      WHERE COD_RUBRO = CDCTPAD;
         IF SQL%FOUND THEN
            INSERT INTO CB_RUB_OFICINAS
            SELECT WCDOFICI, CDCUENT, NRMAYOR, USER, SYSDATE, USER, SYSDATE
              FROM DUAL
             WHERE NOT EXISTS (SELECT 'X' FROM CB_RUB_OFICINAS
                                WHERE COD_OFICINA = WCDOFICI
                                  AND COD_RUBRO = CDCUENT);
         END IF;
     EXCEPTION
     WHEN NO_DATA_FOUND THEN
     EXIT;
     END;
     END LOOP;
  END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cuenta '||WCDCUENT||
          ' inexistente en el Plan de Cuentas Consolidado');
  END;
  ---
  PROCEDURE lp_ins_sal_consolidados(WCDCUENT IN CHAR,
                               WTPMOVIM IN VARCHAR2,
                               WIMMOVGS IN NUMBER,
                               WIMMONEX IN NUMBER,
                               WIMMOUSD IN NUMBER,
                               WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  LGPROTE VARCHAR2(01) := 'N'; ---
  V_MON_EQU_LOCAL NUMBER(18,2) := 0;
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
  IF SQL%FOUND THEN
     IF WCDMONED <> W_MON_LOCAL THEN
        V_MON_EQU_LOCAL := WIMMOVGS;
     END IF;

     IF WTPMOVIM = 'D' THEN
        -----------------------------------------------------------------
        -- INSERTA SALDO DE DEBITO
        -----------------------------------------------------------------
        INSERT INTO CB_SAL_CONSOLIDADOS (COD_RUBRO, ANO, MES,
                             DEB_MON_LOCAL, DEB_MON_RUBRO, PROTEGIDO,
                             DEB_EQU_LOCAL)
                     VALUES (CDCUENT,  v_ano,
                             v_mes, WIMMOVGS, WIMMONEX,
                             LGPROTE,V_MON_EQU_LOCAL);
     ELSE
        -----------------------------------------------------------------
        -- INSERTA SALDO DE CREDITO
        -----------------------------------------------------------------
        INSERT INTO CB_SAL_CONSOLIDADOS (COD_RUBRO, ANO, MES,
                             CRE_MON_LOCAL, CRE_MON_RUBRO, PROTEGIDO,
                             CRE_EQU_LOCAL)
                     VALUES (CDCUENT,  v_ano,
                             v_mes, WIMMOVGS, WIMMONEX,
                             LGPROTE, V_MON_EQU_LOCAL);
      END IF;
      lp_sum_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED);
  END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuentas Consolidado');
  END;
  ---
  PROCEDURE lp_sum_sal_oficinas(WCDOFICI IN NUMBER,
                             WCDCUENT IN CHAR,
                             WTPMOVIM IN CHAR,
                             WIMMOVGS IN NUMBER,
                             WIMMONEX IN NUMBER,
                             WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  WDUMMY  VARCHAR2(01);
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
      IF SQL%FOUND THEN
         <<CICLO>> LOOP
         BEGIN
         SELECT COD_RUBRO, COD_RUB_PADRE
           INTO CDCUENT, CDCTPAD
           FROM CB_RUBROS
          WHERE COD_RUBRO = CDCTPAD;
             IF SQL%FOUND THEN
                BEGIN
                  ---------------------------------------------------------
                  -- VERIFICA SI EXISTE EN CB_SAL_OFICINAS
                  ---------------------------------------------------------
                  SELECT 'X' INTO WDUMMY
                    FROM CB_SAL_OFICINAS
                   WHERE COD_OFICINA = WCDOFICI
                     AND COD_RUBRO = CDCUENT
                     AND ANO = v_ano
                     AND MES = v_mes
                     FOR UPDATE OF COD_RUBRO;
                EXCEPTION
                   WHEN NO_DATA_FOUND THEN
                   INSERT INTO CB_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO, MES, PROTEGIDO)
                                        VALUES (WCDOFICI, CDCUENT, v_ano, v_mes, 'S');
                   WHEN OTHERS THEN
                       RAISE_APPLICATION_ERROR(-20000,'Error al bloquear el rubro '||CDCUENT||' - Ofic '||wcdofici||' - '||sqlerrm);
                END;
                IF SQL%FOUND THEN
                   IF WTPMOVIM = 'D' THEN
                      ----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE DEBITO --
                      ----------------------------------------
                      UPDATE CB_SAL_OFICINAS
                        SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_OFICINA = WCDOFICI
                         AND COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                   ELSE
                      -----------------------------------------
                      -- ACTUALIZA POR MOVIMIENTO DE CREDITO --
                      -----------------------------------------
                      UPDATE CB_SAL_OFICINAS
                        SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                            CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                            CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
                       WHERE COD_OFICINA = WCDOFICI
                         AND COD_RUBRO = CDCUENT
                         AND ANO = v_ano
                         AND MES = v_mes;
                   END IF;
                END IF;

             END IF;
         EXCEPTION
         WHEN NO_DATA_FOUND THEN
         EXIT;
         END;
         END LOOP CICLO;
      END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
   RAISE_APPLICATION_ERROR(-20000,'ERROR. Codigo de la Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuenta');
  END;
  ---
  PROCEDURE lp_ins_sal_oficinas(WCDOFICI IN NUMBER,
                               WCDCUENT IN CHAR,
                               WTPMOVIM IN CHAR,
                               WIMMOVGS IN NUMBER,
                               WIMMONEX IN NUMBER,
                               WIMMOUSD IN NUMBER,
                               WCDMONED IN VARCHAR2) IS
  CDCUENT VARCHAR2(15);
  CDCTPAD VARCHAR2(15);
  LGPROTE VARCHAR2(01) := 'N'; ---
  V_MON_EQU_LOCAL NUMBER(18,2) := 0;
  BEGIN
  SELECT COD_RUBRO, COD_RUB_PADRE
    INTO CDCUENT, CDCTPAD
    FROM CB_RUBROS
   WHERE COD_RUBRO = WCDCUENT;
  IF SQL%FOUND THEN
     IF WCDMONED <> W_MON_LOCAL THEN
        V_MON_EQU_LOCAL := WIMMOVGS;
     END IF;
     IF WTPMOVIM = 'D' THEN
        -----------------------------------------------------------------
        -- INSERTA SALDO DE DEBITO
        -----------------------------------------------------------------
        INSERT INTO CB_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO,
                             MES, DEB_MON_LOCAL, DEB_MON_RUBRO,
                             PROTEGIDO, DEB_EQU_LOCAL)
                     VALUES (WCDOFICI,        CDCUENT,  v_ano,
                             v_mes, WIMMOVGS, WIMMONEX,
                             LGPROTE,V_MON_EQU_LOCAL);
     ELSE
        -----------------------------------------------------------------
        -- INSERTA SALDO DE CREDITO
        -----------------------------------------------------------------
        INSERT INTO CB_SAL_OFICINAS (COD_OFICINA, COD_RUBRO, ANO,
                             MES, CRE_MON_LOCAL, CRE_MON_RUBRO,
                             PROTEGIDO, CRE_EQU_LOCAL)
                     VALUES (WCDOFICI,        CDCUENT,  v_ano,
                             v_mes, WIMMOVGS, WIMMONEX,
                             LGPROTE, V_MON_EQU_LOCAL);
      END IF;
      --lp_sum_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED); -- Comentado ICL 29/07/2011 -- Sumarización de los rubros padres una única vez
  END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20000,'ERROR. Cuenta '||WCDCUENT||
          ' inexistente en Plan de Cuentas Consolidado');
  END;
  ---

----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------

  PROCEDURE lp_act_asientos(WCDOFICI IN NUMBER,
                                      WCDCUENT IN CHAR,
                                      WTPMOVIM IN CHAR) IS
     cursor c_asientos is
     select fecha, cod_oficina, nro_asiento
       from CB_ASIENTOS
      WHERE CB_ASIENTOS.COD_OFICINA = WCDOFICI
        AND CB_ASIENTOS.NRO_ASIENTO IN (SELECT NRO_ASIENTO FROM CB_ASIENTOS_DET
                               WHERE CB_ASIENTOS_DET.COD_OFICINA = CB_ASIENTOS.COD_OFICINA
                                 AND CB_ASIENTOS_DET.NRO_ASIENTO = CB_ASIENTOS_DET.NRO_ASIENTO
                                 AND CB_ASIENTOS_DET.COD_RUBRO = WCDCUENT
                                 AND CB_ASIENTOS_DET.TIP_MOVIMIENTO = WTPMOVIM)
        AND CB_ASIENTOS.ACTUALIZADO = 'N'
        AND CB_ASIENTOS.CONFIRMADO = 'S';

  BEGIN
  /*
  UPDATE CB_ASIENTOS
     SET CB_ASIENTOS.ACTUALIZADO = 'S'
   WHERE CB_ASIENTOS.COD_OFICINA = WCDOFICI
     AND CB_ASIENTOS.NRO_ASIENTO IN (SELECT NRO_ASIENTO FROM CB_ASIENTOS_DET
                            WHERE CB_ASIENTOS_DET.COD_OFICINA = CB_ASIENTOS.COD_OFICINA
                              AND CB_ASIENTOS_DET.NRO_ASIENTO = CB_ASIENTOS_DET.NRO_ASIENTO
                              AND CB_ASIENTOS_DET.COD_RUBRO = WCDCUENT
                              AND CB_ASIENTOS_DET.TIP_MOVIMIENTO = WTPMOVIM)
     AND CB_ASIENTOS.ACTUALIZADO = 'N'
     AND CB_ASIENTOS.CONFIRMADO = 'S';

  UPDATE CB_ASIENTOS_DET
     SET CB_ASIENTOS_DET.ACTUALIZADO = 'S'
   WHERE CB_ASIENTOS_DET.COD_OFICINA = WCDOFICI
     AND CB_ASIENTOS_DET.COD_RUBRO = WCDCUENT
     AND CB_ASIENTOS_DET.TIP_MOVIMIENTO = WTPMOVIM
     AND CB_ASIENTOS_DET.ACTUALIZADO = 'N'
     AND EXISTS (SELECT 0 FROM CB_ASIENTOS
                  WHERE CB_ASIENTOS.COD_OFICINA = CB_ASIENTOS_DET.COD_OFICINA
                    AND CB_ASIENTOS.NRO_ASIENTO = CB_ASIENTOS_DET.NRO_ASIENTO
                    AND CB_ASIENTOS.ACTUALIZADO = 'S'
                    AND CB_ASIENTOS.CONFIRMADO = 'S');*/

     for i in c_asientos loop
        UPDATE CB_ASIENTOS
           SET CB_ASIENTOS.ACTUALIZADO = 'S'
         WHERE CB_ASIENTOS.FECHA = i.fecha
           and CB_ASIENTOS.COD_OFICINA = i.cod_oficina
           and CB_ASIENTOS.Nro_Asiento = i.nro_asiento;

        UPDATE CB_ASIENTOS_DET
           SET CB_ASIENTOS_DET.ACTUALIZADO = 'S'
         WHERE CB_ASIENTOS_DET.FECHA = i.fecha
           and CB_ASIENTOS_DET.COD_OFICINA = i.cod_oficina
           and CB_ASIENTOS_DET.Nro_Asiento = i.nro_asiento
           --and CB_ASIENTOS_DET.COD_RUBRO = WCDCUENT
           --AND CB_ASIENTOS_DET.TIP_MOVIMIENTO = WTPMOVIM
           AND CB_ASIENTOS_DET.ACTUALIZADO = 'N';

     end loop;
  END;
-------------------------------------------------------------
-------------------------------------------------------------
-------------------------------------------------------------


  --
  PROCEDURE lp_act_sal_oficinas(WCDOFICI IN NUMBER,
                              WCDCUENT IN CHAR,
                              WTPMOVIM IN CHAR,
                              WIMMOVGS IN NUMBER,
                              WIMMONEX IN NUMBER,
                              WIMMOUSD IN NUMBER,
                              WCDMONED IN VARCHAR2) IS
  WDUMMY   CHAR(1);
  BEGIN
  SELECT 'X' INTO WDUMMY
    FROM CB_SAL_OFICINAS
   WHERE COD_OFICINA = WCDOFICI
     AND COD_RUBRO = WCDCUENT
     AND ANO = v_ano
     AND MES = v_mes
     FOR UPDATE OF COD_RUBRO;
     IF SQL%FOUND THEN
        IF WTPMOVIM = 'D' THEN
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE DEBITO
           ------------------------------------------------------------
           UPDATE CB_SAL_OFICINAS
              SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_OFICINA = WCDOFICI
              AND COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           --lp_sum_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED); -- Comentado ICL 29/07/2011 -- Sumarización de los rubros padres una única vez
        ELSE
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE CREDITO
           ------------------------------------------------------------
           UPDATE CB_SAL_OFICINAS
              SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_OFICINA = WCDOFICI
              AND COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           --lp_sum_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED); -- Comentado ICL 29/07/2011 -- Sumarización de los rubros padres una única vez
        END IF;
     END IF;
     EXCEPTION
     WHEN NO_DATA_FOUND THEN
     ----------------------------------------------------------------
     -- NO ENCONTRO REGISTRO EN CB_SAL_OFICINAS POR LO TANTO SE DEBE INSERTAR
     -- LA CUENTA PREVIA VERIFICACION EN CB_RUB_OFICINAS
     ----------------------------------------------------------------
     BEGIN
       SELECT 'X'
         INTO WDUMMY
         FROM CB_RUB_OFICINAS
        WHERE COD_OFICINA = WCDOFICI
          AND COD_RUBRO = WCDCUENT;
       IF SQL%FOUND THEN
          lp_ins_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END IF;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
         ------------------------------------------------------------
         -- INSERTA CUENTAS EN EL PLAN DE CUENTAS CONSOLIDADO
         -- CUENTAS ASENTABLES Y CUENTAS PADRES
         ------------------------------------------------------------
         lp_ins_rub_oficinas(WCDOFICI, WCDCUENT);
         lp_ins_sal_oficinas(WCDOFICI,WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END;
  END;
  --
  PROCEDURE lp_act_sal_consolidados(WCDOFICI IN NUMBER,
                              WCDCUENT IN CHAR,
                              WTPMOVIM IN CHAR,
                              WIMMOVGS IN NUMBER,
                              WIMMONEX IN NUMBER,
                              WIMMOUSD IN NUMBER,
                              WCDMONED IN VARCHAR2) IS
  WDUMMY   CHAR(1);
  BEGIN
  SELECT 'X' INTO WDUMMY
    FROM CB_SAL_CONSOLIDADOS
   WHERE COD_RUBRO = WCDCUENT
     AND ANO = v_ano
     AND MES = v_mes
     FOR UPDATE OF COD_RUBRO;
     IF SQL%FOUND THEN
        IF WTPMOVIM = 'D' THEN
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE DEBITO
           ------------------------------------------------------------
           UPDATE CB_SAL_CONSOLIDADOS
              SET DEB_MON_LOCAL = NVL(DEB_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  DEB_MON_RUBRO = NVL(DEB_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  DEB_EQU_LOCAL = NVL(DEB_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           lp_sum_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED);
        ELSE
           ------------------------------------------------------------
           -- ACTUALIZA POR MOVIMIENTO DE CREDITO
           ------------------------------------------------------------
           UPDATE CB_SAL_CONSOLIDADOS
              SET CRE_MON_LOCAL = NVL(CRE_MON_LOCAL,0)+NVL(WIMMOVGS,0),
                  CRE_MON_RUBRO = NVL(CRE_MON_RUBRO,0)+NVL(WIMMONEX,0),
                  CRE_EQU_LOCAL = NVL(CRE_EQU_LOCAL,0)+DECODE(WCDMONED,W_MON_LOCAL,0,NVL(WIMMOVGS,0))
            WHERE COD_RUBRO = WCDCUENT
              AND ANO = v_ano
              AND MES = v_mes;
           lp_sum_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMOUSD,WCDMONED);
        END IF;
     END IF;
     EXCEPTION
     WHEN NO_DATA_FOUND THEN
     ----------------------------------------------------------------
     -- NO ENCONTRO REGISTRO EN CB_SAL_CONSOLIDADOS POR LO TANTO SE DEBE INSERTAR
     -- LA CUENTA PREVIA VERIFICACION EN CB_RUB_OFICINAS
     ----------------------------------------------------------------
     BEGIN
       SELECT 'X'
         INTO WDUMMY
         FROM CB_RUB_OFICINAS
        WHERE COD_OFICINA = WCDOFICI
          AND COD_RUBRO = WCDCUENT;
       IF SQL%FOUND THEN
          lp_ins_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END IF;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
         ------------------------------------------------------------
         -- INSERTA CUENTAS EN EL PLAN DE CUENTAS CONSOLIDADO
         -- CUENTAS ASENTABLES Y CUENTAS PADRES
         ------------------------------------------------------------
         lp_ins_rub_oficinas(WCDOFICI,WCDCUENT);
         lp_ins_sal_consolidados(WCDCUENT,WTPMOVIM,WIMMOVGS,WIMMONEX,WIMMOUSD,WCDMONED);
       END;
  END;

-- Inicio del proceso principal de actualizacion de saldos contables
BEGIN
  PAE_CNF.G_COD_MODULO := 2;
  IF SALD_M%ISOPEN THEN
     CLOSE SALD_M;
  END IF;
  OPEN SALD_M;
  LOOP
  FETCH SALD_M INTO CDOFICI, CDCUENT, TPMOVIM, NMOFICI, IMMOVGS, IMMONEX, WCDMONED;
  WW_IMMOUSD := fub_con_mon_a_moneda(WCDMONED,W_MON_FUERTE,IMMONEX); --Obtener la cotización del modulo 2 (Contabilidad).
  EXIT WHEN SALD_M%notfound;
  IF SALD_M%FOUND THEN
     lp_act_sal_oficinas(CDOFICI, CDCUENT, TPMOVIM, IMMOVGS, IMMONEX,WW_IMMOUSD,WCDMONED);
     --lp_act_sal_consolidados(CDOFICI, CDCUENT, TPMOVIM, IMMOVGS, IMMONEX, WW_IMMOUSD,WCDMONED); -- Comentado ICL 29/07/2011 -- Sumarización de los rubros padres una única vez
  END IF;
  lp_act_asientos(CDOFICI, CDCUENT, TPMOVIM);
  END LOOP;
END;
/

