CREATE OR REPLACE PROCEDURE IT.PRB_GEN_CTA_ESPECIALES IS
  v_nro_asiento    number;
  v_cod_ofi_matriz number(3) := 1;
  v_fec_actual     date;
  v_ano            number(4);
  v_mes            number(2);
  v_hay_asiento    varchar2(1) := 'N';
  ---
  PROCEDURE PROC_1 IS
  ----------------------------------------------
  --- DEFINICION DE REGISTROS PARA CURSORES ----
  ----------------------------------------------
    R_CURE CB_RUB_ESPECIALES%rowtype;
    W_OFIC     NUMBER;
  ----------------------------------------------
    v_cod_rubro VARCHAR2(15);
    v_sal_mon_local NUMBER(14,2);
    v_sal_mon_rubro NUMBER(14,2);
  ----
    v_acu_deb_mon_local NUMBER(14,2);
    v_acu_cre_mon_local NUMBER(14,2);
    v_acu_deb_mon_rubro NUMBER(14,2);
    v_acu_cre_mon_rubro NUMBER(14,2);
    v_tip_mov_origen     VARCHAR2(1);
    v_tip_mov_destino     VARCHAR2(1);
    v_imp_mon_local   NUMBER;
    v_imp_mon_rubro   NUMBER;
  ----
  ----
    CURSOR CURE is SELECT *
                   FROM   CB_RUB_ESPECIALES;
  ----
    CURSOR CURX is SELECT COD_RUBRO,
                          NVL(SAL_MON_LOC_ANT,0) +
                          NVL(DEB_MON_LOCAL,0) -
                          NVL(CRE_MON_LOCAL,0),
                          NVL(SAL_MON_RUB_ANT,0) +
                          NVL(DEB_MON_RUBRO,0) -
                          NVL(CRE_MON_RUBRO,0)
                   FROM   CB_SAL_CONSOLIDADOS
                   WHERE  COD_RUBRO IN (SELECT COD_RUBRO
                                           FROM CB_RUBROS
                                          WHERE COD_RUB_PADRE =
                                                R_CURE.COD_RUB_ORIGEN)
                   AND    ANO = v_ano
                   AND    MES = v_mes;
    WSALPTEANT NUMBER;
    WSALPTEANE NUMBER;
    CURSOR CURY is SELECT NVL(SAL_MON_LOC_ANT,0),NVL(SAL_MON_RUB_ANT,0)
                   FROM   CB_SAL_CONSOLIDADOS
                   WHERE  COD_RUBRO = R_CURE.COD_RUB_TRA_ORIGEN
                   AND    ANO = v_ano
                   AND    MES = v_mes;
   W_AUXI NUMBER;
  BEGIN
    ---
    --------------------------
    IF CURE%isopen THEN
       CLOSE CURE;
    END IF;
    OPEN CURE;
    LOOP
        FETCH CURE INTO R_CURE;
          EXIT  WHEN CURE%notfound;
          IF CURX%isopen THEN
             CLOSE CURX;
          END IF;
          OPEN CURX;
          v_acu_deb_mon_local := 0;
          v_acu_cre_mon_local := 0;
          v_acu_deb_mon_rubro := 0;
          v_acu_cre_mon_rubro := 0;
          W_AUXI     := 0;
          LOOP
            FETCH CURX INTO  v_cod_rubro,
                             v_sal_mon_local,
                             v_sal_mon_rubro;
            EXIT WHEN CURX%notfound;
            IF v_sal_mon_local > 0 THEN
               -- saldo deudor
               v_acu_deb_mon_local := NVL(v_acu_deb_mon_local,0) +
                             NVL(v_sal_mon_local,0);
               v_acu_deb_mon_rubro := NVL(v_acu_deb_mon_rubro,0) +
                             NVL(v_sal_mon_rubro,0);
            END IF;
            IF v_sal_mon_local < 0 THEN
               -- saldo acreedor
               v_acu_cre_mon_local := NVL(v_acu_cre_mon_local,0) +
                             NVL(v_sal_mon_local,0);
               v_acu_cre_mon_rubro := NVL(v_acu_cre_mon_rubro,0) +
                             NVL(v_sal_mon_rubro,0);
            END IF;
          END LOOP;
          IF CURX%rowcount > 0 THEN
             ---- ve el tipo de transferencia
             IF R_CURE.TIP_SALDO ='1' THEN
                -- transfiere saldos deudores
                v_tip_mov_origen   := 'D';
                v_tip_mov_destino  := 'C';
                v_imp_mon_local := v_acu_deb_mon_local;
                v_imp_mon_rubro := v_acu_deb_mon_rubro;
             END IF;
             IF R_CURE.TIP_SALDO ='2' THEN
                -- transfiere saldos acreedores
                v_imp_mon_local := v_acu_cre_mon_local;
                v_imp_mon_rubro := v_acu_cre_mon_rubro;
                v_tip_mov_origen   := 'C';
                v_tip_mov_destino   := 'D';
             END IF;
             IF R_CURE.TIP_SALDO ='3' THEN
                -- transfiere saldos netos
                v_imp_mon_local  := v_acu_deb_mon_local + v_acu_cre_mon_local;
                v_imp_mon_rubro  := v_acu_deb_mon_rubro + v_acu_cre_mon_rubro;
                IF v_imp_mon_local > 0 THEN
                   v_tip_mov_origen  := 'C';
                   v_tip_mov_destino := 'D';
                ELSE
                   v_tip_mov_origen  := 'D';
                   v_tip_mov_destino := 'C';
                END IF;
             END IF;
             IF CURY%ISOPEN THEN
                CLOSE CURY;
             END IF;
             OPEN CURY;
             WSALPTEANT := 0;
             WSALPTEANE := 0;
             FETCH CURY INTO WSALPTEANT,WSALPTEANE;
             IF CURY%NOTFOUND THEN
                raise_application_error(-20000,' ERROR. No se encontro cta. pte. origen '||
                                        R_CURE.COD_RUB_TRA_ORIGEN || ' Ofic: ' ||
                                         to_char(W_OFIC) || 'AAAA/MM ' || v_ano ||'/'||v_mes);
             END IF;
             IF ABS(v_imp_mon_local) >= ABS(WSALPTEANT) THEN
                v_tip_mov_origen  := 'D';
                v_tip_mov_destino := 'C';
             ELSE
                v_tip_mov_origen  := 'C';
                v_tip_mov_destino := 'D';
             END IF;
             v_imp_mon_local := v_imp_mon_local + WSALPTEANT;
             v_imp_mon_rubro := v_imp_mon_rubro + WSALPTEANE;
             IF v_imp_mon_local < 0 THEN
                v_imp_mon_local := v_imp_mon_local * -1;
                v_imp_mon_rubro := v_imp_mon_rubro * -1;
             END IF;
               --------
               -- graba asiento
               IF v_imp_mon_local > 0 THEN
                 v_hay_asiento := 'S';
                 INSERT INTO CB_ASIENTOS
                (COD_OFICINA, NRO_ASIENTO, COD_USUARIO, FECHA,
                 FEC_INSERCION, COD_MODULO, COD_MODALIDAD,
                 TOT_CONTROL, ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
                 OFI_INTEGRADA, CONFIRMADO)
               VALUES
                 (v_cod_ofi_matriz, v_nro_asiento,  USER, v_fec_actual,
                  SYSDATE, 2,
                  21, v_imp_mon_local, 'N','N' , NULL, 'N', 'S');
               ------------------------------------------
               -- carga detalles (1a. Linea)           --
               -- La cuenta que se modifica el saldo   --
               ------------------------------------------
               INSERT INTO CB_ASIENTOS_DET
                 (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
                  MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
                  DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
                  DISTRIBUIDO,FECHA)
               VALUES
                 (v_cod_ofi_matriz, v_nro_asiento, 1, R_CURE.COD_RUB_TRA_ORIGEN,
                  v_imp_mon_local, v_imp_mon_rubro, v_tip_mov_origen, 'CTA ESP',
                  'CTAS ESP', 'N', 'N', 0 ,'N',v_fec_actual);
               ------------------------------------------
               -- carga detalles (2a. linea)           --
               -- La contra cuenta                     --
               ------------------------------------------
               INSERT INTO CB_ASIENTOS_DET
                 (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
                  MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
                  DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
                  DISTRIBUIDO,FECHA)
               VALUES
                 (v_cod_ofi_matriz, v_nro_asiento,2, R_CURE.COD_RUB_TRA_DESTINO,
                  v_imp_mon_local, v_imp_mon_rubro,v_tip_mov_destino, 'CTAS ESP',
                  'CUENTAS ESPECIALES', 'N','N', NULL,'N',v_fec_actual);
               ------ fin asiento ---------
               -- incrementa numero de asiento
               v_nro_asiento := v_nro_asiento + 1;
              END IF;
          END IF;
      END LOOP;
      CLOSE CURE;
  ---------------------------------
  EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20000,'ERROR. Proceso con error. '||sqlerrm);
  END;
  ---
  PROCEDURE PROC_2 IS
  ----------------------------------------------
  --- DEFINICION DE REGISTROS PARA CURSORES ----
  ----------------------------------------------
    v_cod_rubro         VARCHAR2(15);
    v_sal_mon_local     NUMBER(14,2);
    v_sal_mon_rubro     NUMBER(14,2);
  ----
    v_acu_deb_mon_local NUMBER(14,2);
    v_acu_cre_mon_local NUMBER(14,2);
    v_acu_deb_mon_rubro NUMBER(14,2);
    v_acu_cre_mon_rubro NUMBER(14,2);
    v_tip_mov_origen    VARCHAR2(1);
    v_tip_mov_destino   VARCHAR2(1);
    v_imp_mon_local     NUMBER;
    v_imp_mon_rubro     NUMBER;

    CURSOR CURE is SELECT COD_RUB_ORIGEN,COD_RUB_DESTINO,TIP_SALDO,COD_RUB_TRA_ORIGEN,
                          COD_RUB_TRA_DESTINO
                   FROM   CB_RUB_ESPECIALES,CB_RUBROS
                   WHERE  COD_RUBRO = COD_RUB_ORIGEN
                     AND  IMPUTABLE = 'S';
  R_CURE CURE%rowtype;

  ----
    W_AUXI NUMBER;
  BEGIN
    IF CURE%isopen THEN
       CLOSE CURE;
    END IF;
    OPEN CURE;
    LOOP
        FETCH CURE INTO R_CURE;
          EXIT  WHEN CURE%notfound;
          v_acu_deb_mon_local := 0;
          v_acu_cre_mon_local := 0;
          v_acu_deb_mon_rubro := 0;
          v_acu_cre_mon_rubro := 0;
          W_AUXI     := 0;
          BEGIN
            SELECT COD_RUBRO,
                   NVL(SAL_MON_LOC_ANT,0) +
                   NVL(DEB_MON_LOCAL,0) -
                   NVL(CRE_MON_LOCAL,0),
                   NVL(SAL_MON_RUB_ANT,0) +
                   NVL(DEB_MON_RUBRO,0) -
                   NVL(CRE_MON_RUBRO,0)
            INTO   v_cod_rubro,v_sal_mon_local,v_sal_mon_rubro
            FROM   CB_SAL_CONSOLIDADOS
            WHERE  COD_RUBRO = R_CURE.COD_RUB_ORIGEN
            AND    ANO = v_ano
            AND    MES = v_mes;
            W_AUXI := 1;
            IF v_sal_mon_local > 0 THEN
               -- saldo deudor
               W_AUXI := 0;
               v_acu_deb_mon_local := 0;
               v_acu_deb_mon_rubro := 0;
            END IF;
            IF v_sal_mon_local < 0 THEN
               -- saldo acreedor
               v_acu_cre_mon_local := NVL(v_acu_cre_mon_local,0) +
                             NVL(v_sal_mon_local,0);
               v_acu_cre_mon_rubro := NVL(v_acu_cre_mon_rubro,0) +
                             NVL(v_sal_mon_rubro,0);
            END IF;
            EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                      v_acu_cre_mon_local := 0;
                      v_acu_cre_mon_rubro := 0;
                      v_acu_deb_mon_local := 0;
                      v_acu_deb_mon_rubro := 0;
                 WHEN TOO_MANY_ROWS THEN
                      v_acu_cre_mon_local := 0;
                      v_acu_cre_mon_rubro := 0;
                      v_acu_deb_mon_local := 0;
                      v_acu_deb_mon_rubro := 0;
          END;
          IF W_AUXI = 1 THEN
             ---- ve el tipo de transferencia
             IF R_CURE.TIP_SALDO ='1' THEN
                -- transfiere saldos deudores
                v_tip_mov_origen   := 'C';
                v_tip_mov_destino   := 'D';
                v_imp_mon_local := v_acu_deb_mon_local;
                v_imp_mon_rubro := v_acu_deb_mon_rubro;
             END IF;
             IF R_CURE.TIP_SALDO ='2' THEN
                -- transfiere saldos acreedores
                v_imp_mon_local := v_acu_cre_mon_local;
                v_imp_mon_rubro := v_acu_cre_mon_rubro;
                v_tip_mov_origen   := 'D';
                v_tip_mov_destino   := 'C';
             END IF;
             IF R_CURE.TIP_SALDO ='3' THEN
                -- transfiere saldos netos
                v_imp_mon_local  := v_acu_deb_mon_local + v_acu_cre_mon_local;
                v_imp_mon_rubro  := v_acu_deb_mon_rubro + v_acu_cre_mon_rubro;
                IF v_imp_mon_local > 0 THEN
                   v_tip_mov_origen  := 'D';
                   v_tip_mov_destino  := 'C';
                ELSE
                   v_tip_mov_origen  := 'C';
                   v_tip_mov_destino  := 'D';
                END IF;
             END IF;
             IF v_imp_mon_local < 0 THEN
                v_imp_mon_local := v_imp_mon_local * -1;
                v_imp_mon_rubro := v_imp_mon_rubro * -1;
             END IF;
               --------
               -- graba asiento
               IF v_imp_mon_local > 0 THEN
                 v_hay_asiento := 'S';
                 INSERT INTO CB_ASIENTOS
                (COD_OFICINA, NRO_ASIENTO, COD_USUARIO, FECHA,
                 FEC_INSERCION, COD_MODULO, COD_MODALIDAD,
                 TOT_CONTROL, ACTUALIZADO, REVERSADO, COD_OFI_ORIGEN,
                 OFI_INTEGRADA, CONFIRMADO)
               VALUES
                 (v_cod_ofi_matriz, v_nro_asiento, USER, v_fec_actual,
                  SYSDATE, 2, 21,
                  v_imp_mon_local, 'N','N', NULL,'N', 'S');
               ------------------------------------------
               -- carga detalles (1a. Linea)           --
               -- La cuenta que se modifica el saldo   --
               ------------------------------------------
               INSERT INTO CB_ASIENTOS_DET
                 (COD_OFICINA, NRO_ASIENTO,NRO_LINEA, COD_RUBRO,
                  MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
                  DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
                  DISTRIBUIDO,FECHA)
               VALUES
                 (v_cod_ofi_matriz,v_nro_asiento,1, R_CURE.COD_RUB_TRA_ORIGEN,
                  v_imp_mon_local, v_imp_mon_rubro,v_tip_mov_origen, 'CTA ESP',
                  'CTAS ESP','N', 'N', 0 ,'N',v_fec_actual);
               ------------------------------------------
               -- carga detalles (2a. linea)           --
               -- La contra cuenta                     --
               ------------------------------------------
               INSERT INTO CB_ASIENTOS_DET
                 (COD_OFICINA, NRO_ASIENTO, NRO_LINEA, COD_RUBRO,
                  MTO_MON_LOCAL, MTO_MON_RUBRO, TIP_MOVIMIENTO, REFERENCIA,
                  DESCRIPCION, PROTEGIDO, ACTUALIZADO, VAL_COTIZACION,
                  DISTRIBUIDO,FECHA)
               VALUES
                 (v_cod_ofi_matriz, v_nro_asiento,2, R_CURE.COD_RUB_TRA_DESTINO,
                  v_imp_mon_local, v_imp_mon_rubro, v_tip_mov_destino, 'CTAS ESP',
                  'CUENTAS ESPECIALES', 'N','N', NULL, 'N',v_fec_actual);
               ------ fin asiento ---------
               -- incrementa numero de asiento
               v_nro_asiento := v_nro_asiento + 1;
              END IF;
          END IF;
      END LOOP;
  ---------------------------------
  EXCEPTION
     WHEN OTHERS THEN
       raise_application_error(-20000,'ERROR. Proceso con error. '||sqlerrm);
  END;
BEGIN
   select cod_ofi_matriz into v_cod_ofi_matriz from ge_par_generales;
   -----------------------------------
   v_fec_actual := pag_cal.fu_obt_fec_actual(2);
   /* tomo el a¿o y mes de actual */
   v_ano := to_char(v_fec_actual,'yyyy');
   v_mes := to_char(v_fec_actual,'mm');
   ------- ve nro asiento -----------
   v_nro_asiento := fug_obt_pardinamico('SIG_NRO_ASIENTO');
   ---
   PROC_1;
   ---
   PROC_2;
   ------- ACTUALIZA NRO DE ASIENTO---
   if v_hay_asiento = 'S' then
      prg_act_par_dinamico('SIG_NRO_ASIENTO',null, null, null, null, v_nro_asiento);
   end if;
   -----------------------------------

END;
/

