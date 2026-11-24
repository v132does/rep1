CREATE OR REPLACE PROCEDURE IT.PRC_ACT_SAL_MENSUAL
 IS
-- registros para cursores
---------------------------------
rmd_cdmodul ge_movimientos.cod_modulo%type;
rmd_cdmodal ge_movimientos.cod_modalidad%type;
rmd_cdofici ge_movimientos.cod_oficina%type;
rmd_nrcuent ge_movimientos.nro_cuenta%type;
rmd_cdtrans ge_movimientos.cod_transaccion%type;
rmd_fcvalor ge_movimientos.fec_valor%type;
rmd_fctrans ge_movimientos.fecha%type;
rmd_imtrans ge_movimientos.monto%type;
---------------------------------
rmc_cdmodul cc_cta_corrientes.cod_modulo%type;
rmc_cdmodal cc_cta_corrientes.cod_modalidad%type;
rmc_cdofici cc_cta_corrientes.cod_oficina%type;
rmc_nrcuent cc_cta_corrientes.nro_cuenta%type;
rmc_cdmoned cc_cta_corrientes.cod_moneda%type;
rmc_sltotol cc_cta_corrientes.sal_total%type;
rmc_slretol cc_cta_corrientes.sal_retenido%type;
rmc_slblool cc_cta_corrientes.sal_bloqueado%type;
rmc_ctacomb cc_cta_corrientes.cta_combinada%type;
rmc_cdsubmod cc_cta_corrientes.cod_sub_modalidad%type;
---------------------------------
rsm_dummy varchar2(1);
v_mesinici  cc_sal_mensuales.mes%type;
v_aniinici  cc_sal_mensuales.ano%type;
v_aniact    cc_sal_mensuales.ano%type;
v_mesact    cc_sal_mensuales.mes%type;
v_detalle   varchar2(5) ;
v_mest      cc_sal_mensuales.mes%type;
v_anit      cc_sal_mensuales.ano%type;
v_mesv      cc_sal_mensuales.mes%type;
v_aniv      cc_sal_mensuales.ano%type;
v_difermes  cc_sal_mensuales.sal_ini_mes%type;
v_diferdia  cc_sal_mensuales.sal_ini_mes%type;
v_fechaini  DATE;
v_imtrans   cc_sal_mensuales.sal_ini_mes%type;
v_ok        varchar2(1) ;
v_auxfec    DATE;
v_aniprx    cc_sal_mensuales.ano%type;
v_mesprx    cc_sal_mensuales.mes%type;
v_diferde1  cc_sal_mensuales.sal_ini_mes%type;
v_fcdehoy   DATE  ;
v_fcproxi   DATE    ;
v_salfina   NUMBER;
v_monto     cc_sal_mensuales.sal_ini_mes%type;
v_ctdiast   NUMBER  ;
v_fechai    DATE;
v_fechaux   DATE;
v_fechac    DATE;
v_fechaf    DATE;
v_cbslminpa number;
rv_gcale    GE_CALENDARIOS%ROWTYPE;
v_monloc    BA_MONEDAS.cod_moneda%type;
v_tip_implementacion number := fug_obt_tip_implementacion;   
V_SAL_ACU_DIARIO CC_SAL_MENSUALES.SAL_ACU_DIARIO%TYPE;
V_CAN_DIA_ACUMULADO CC_SAL_MENSUALES.CAN_DIA_ACUMULADO%TYPE;
v_usu_mig_excluir varchar2(30);

CURSOR diari  IS
     select cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
            cod_transaccion, fec_valor, fecha, monto
       from ge_movimientos
      where cod_modulo  = 4
        and fec_valor  < v_fcdehoy
        AND v_tip_implementacion not in (1,7)  -- NO VALIDO PARA REGIONAL
        and cod_rubro is null
        and cod_transaccion not in (515,565,507,604);
CURSOR salme IS
     SELECT 'X'
       FROM cc_sal_mensuales
      WHERE nro_cuenta    = rmd_nrcuent
        AND ano           = v_aniinici
        AND mes           = v_mesinici
 FOR UPDATE OF cod_modulo;
CURSOR ctcte  IS
     select cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
            cod_moneda, sal_total, sal_retenido, sal_bloqueado,cta_combinada, cod_sub_modalidad
       from cc_cta_corrientes
      where estado not in ('C','A','X')
        and (v_usu_mig_excluir is null or usu_insercion <> v_usu_mig_excluir);
CURSOR salme2 IS
     SELECT 'X'
     FROM   cc_sal_mensuales
     WHERE  nro_cuenta    = rmc_nrcuent
     AND    ano           = v_aniinici
     AND    mes           = v_mesinici
     FOR    UPDATE OF cod_modulo;
PROCEDURE LP_FEC_VALOR (p_cdmodul IN  NUMBER,
                       p_cdmodal IN  NUMBER,
                       p_cdofici IN  NUMBER,
                       p_nrcuent IN  varchar2,
                       p_imtrans IN  NUMBER,
                       p_fechai  IN  DATE,
                       p_fechaf  IN  DATE,
                       p_fechac  OUT DATE,
                       p_detalle IN  varchar2);
PROCEDURE LP_BUS_SOBREGIROS(p_cdmodul IN NUMBER,
                            p_cdmodal IN NUMBER,
                            p_cdofici IN NUMBER,
                            p_nrcuent IN varchar2,
                            p_fechac  IN DATE,
                            p_hay     OUT varchar2,
                            p_sldeudo OUT NUMBER);
PROCEDURE LP_DIF_HOY_SGTE_HABIL (p_fecha   IN DATE,
                                 p_cdofici IN NUMBER,
                                 p_dias    OUT NUMBER);
PROCEDURE LP_CTA_COMBINADA (p_cdmodul IN  NUMBER,
                            p_cdmodal IN  NUMBER,
                            p_cdofici IN  NUMBER,
                            p_nrcuent IN  varchar2,
                            p_imtrans IN  NUMBER,
                            p_fechai  IN  DATE,
                            p_fechaf  IN  DATE,
                            p_fechac  OUT DATE,
                            p_detalle IN  varchar2);
PROCEDURE LP_BUS_SOBREGIROS(p_cdmodul IN NUMBER,
                            p_cdmodal IN NUMBER,
                            p_cdofici IN NUMBER,
                            p_nrcuent IN varchar2,
                            p_fechac  IN DATE,
                            p_hay     OUT varchar2,
                            p_sldeudo OUT NUMBER) IS
BEGIN
  p_hay := 'N';
  SELECT saldo
    INTO p_sldeudo
    FROM cc_sobregiros
   WHERE nro_cuenta = p_nrcuent
     AND fecha      = p_fechac;
  p_hay := 'S';
EXCEPTION
 WHEN NO_DATA_FOUND THEN
   p_hay := 'N';
 WHEN TOO_MANY_ROWS THEN
   p_hay := 'S';
END;
--
PROCEDURE LP_FEC_VALOR (p_cdmodul IN  NUMBER,
                        p_cdmodal IN  NUMBER,
                        p_cdofici IN  NUMBER,
                        p_nrcuent IN  varchar2,
                        p_imtrans IN  NUMBER,
                        p_fechai  IN  DATE,
                        p_fechaf  IN  DATE,
                        p_fechac  OUT DATE,
                        p_detalle IN  varchar2) IS
v_diferencia cc_sal_mensuales.sal_acu_acreedor%type;
v_lgdeudo    varchar2(1);
v_sldeudo    cc_sal_mensuales.sal_acu_acreedor%type;
vk_acsalac   cc_sal_mensuales.sal_acu_acreedor%type;
vk_acsalde   cc_sal_mensuales.sal_acu_deudor%type;
BEGIN
  p_fechac := p_fechai;
  vk_acsalde := 0;
  vk_acsalac := 0;
  BEGIN
    SELECT NVL(sal_acu_acreedor,0), NVL(sal_acu_deudor,0)
      INTO vk_acsalac, vk_acsalde
      FROM cc_sal_mensuales
     WHERE nro_cuenta    = p_nrcuent
       AND ano           = TO_NUMBER(TO_CHAR(p_fechac,'YYYY'))
       AND mes           = TO_NUMBER(TO_CHAR(p_fechac,'MM'));
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
     -- INSERTAR REGISTRO --
     INSERT INTO cc_sal_mensuales
           (cod_modulo, cod_modalidad, cod_oficina,
            nro_cuenta, ano, mes,
            can_debitos, can_creditos, tot_debitos,
            tot_creditos, can_che_devueltos, sal_ini_mes,
            can_dia_acumulado, sal_acu_diario,
            sal_acu_acreedor, can_dia_acreedor,
            sal_acu_deudor, can_dia_deudor)
     VALUES
           (p_cdmodul, p_cdmodal, p_cdofici,
            p_nrcuent, TO_NUMBER(TO_CHAR(p_fechac,'YYYY')),
            TO_NUMBER(TO_CHAR(p_fechac,'MM')),
            0, 0, 0,
            0, 0, 0,
            p_fechaf-p_fechac, 0,
            0, 0,
            0, 0);
         ------
         vk_acsalac := 0;
         vk_acsalde := 0;
  END;
---------------------------------------------------------------------
-- ciclo general
---------------------------------------------------------------------
  WHILE (p_fechac <= p_fechaf)  LOOP
     -------------------
     --    DEBITO     --
     -------------------
     IF p_detalle = 'D' THEN
        v_lgdeudo := 'N';
        LP_BUS_SOBREGIROS(p_cdmodul,p_cdmodal,p_cdofici,
                          p_nrcuent,p_fechac, v_lgdeudo, v_sldeudo);
        IF v_lgdeudo = 'S' THEN
           vk_acsalde := NVL(vk_acsalde,0) + NVL(p_imtrans,0);
        ELSE
           vk_acsalac := NVL(vk_acsalac,0) - NVL(p_imtrans,0);
           IF vk_acsalac < 0 THEN
              vk_acsalde := NVL(vk_acsalde,0) - NVL(vk_acsalac,0);
              vk_acsalac := 0;
           END IF;
         END IF;
     END IF;
     -------------------
     --  FIN  DEBITO  --
     -------------------
     ------------------------------------------------------------------
     -------------------
     --    CREDITO    --
     -------------------
     IF p_detalle = 'C' THEN
        v_lgdeudo := 'N';
        LP_BUS_SOBREGIROS(p_cdmodul,p_cdmodal,p_cdofici,
                          p_nrcuent,p_fechac, v_lgdeudo, v_sldeudo);
        IF v_lgdeudo = 'S' THEN
           v_diferencia := NVL(v_sldeudo,0) - NVL(p_imtrans,0);
           IF v_diferencia <= 0 THEN
              vk_acsalac := vk_acsalac - v_diferencia;
              vk_acsalde := NVL(vk_acsalde,0) -
                            (NVL(p_imtrans,0) + v_diferencia);
           ELSE
              vk_acsalde := NVL(vk_acsalde,0) - NVL(p_imtrans,0);
           END IF;
        ELSE
           vk_acsalac := NVL(vk_acsalac,0) + NVL(p_imtrans,0);
        END IF;
     END IF;
     -------------------
     --  FIN CREDITO  --
     -------------------
     p_fechac := p_fechac + 1;
  END LOOP;
  UPDATE cc_sal_mensuales
     SET sal_acu_acreedor = vk_acsalac,
         sal_acu_deudor   = vk_acsalde
   WHERE nro_cuenta    = p_nrcuent
     AND ano           = TO_NUMBER(TO_CHAR(p_fechac,'YYYY'))
     AND mes           = TO_NUMBER(TO_CHAR(p_fechac,'MM'));
END;
--
PROCEDURE LP_CTA_COMBINADA (p_cdmodul IN  NUMBER,
                            p_cdmodal IN  NUMBER,
                            p_cdofici IN  NUMBER,
                            p_nrcuent IN  VARCHAR2,
                            p_imtrans IN  NUMBER,
                            p_fechai  IN  DATE,
                            p_fechaf  IN  DATE,
                            p_fechac  OUT DATE,
                            p_detalle IN  VARCHAR2) IS
v_diferencia cc_sal_mensuales.sal_acu_acreedor%type;
v_lgdeudo    varchar2(1);
v_sldeudo    NUMBER;
vk_acsalac   NUMBER;
vk_acsalde   NUMBER;
v_cdmodav    ge_cuentas.cod_modulo%type;
v_cdmadav    ge_cuentas.cod_modalidad%type;
v_cdofiav    ge_cuentas.cod_oficina%type;
v_nrctaav    ge_cuentas.nro_cuenta%type;
v_DUMMY      varchar2(1);
v_importe    cc_sal_mensuales.sal_acu_acreedor%type;
v_dias       NUMBER;
v_fechaux    DATE;
vht_imtrans  cc_sal_mensuales.sal_acu_acreedor%type;
vk_monaho    cc_sal_mensuales.sal_acu_acreedor%type;
vk_moncc     cc_sal_mensuales.sal_acu_acreedor%type;
BEGIN
    p_fechac := p_fechai;
    vk_acsalde := 0;
    vk_acsalac := 0;
    BEGIN
      SELECT av.cod_modalidad, av.cod_modalidad, av.cod_oficina, cc.nro_cta_ahorro
        INTO v_cdmodav , v_cdmadav , v_cdofiav , v_nrctaav
        FROM cc_cta_combinadas cc,
             ge_cuentas ac,
             ge_cuentas av
       WHERE ac.cod_modulo     = p_cdmodul
         AND ac.cod_modalidad  = p_cdmodal
         AND ac.cod_oficina    = p_cdofici
         AND ac.nro_cuenta     = cc.nro_cta_cte
         AND cc.nro_cta_cte    = p_nrcuent
         AND cc.nro_cta_ahorro = av.nro_cuenta;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
          raise_application_error(-20000,'Modul/Modal/Ofi/Cta.comb: ' ||
                    TO_CHAR(p_cdmodul) || '-' ||
                    TO_CHAR(p_cdmodal) || '-' ||
                    TO_CHAR(p_cdofici) || '-' ||
                    p_nrcuent || ' no existe en CC_CTA_COMBINADAS');
      WHEN TOO_MANY_ROWS THEN
          raise_application_error(-20000,'Modul/Modal/Ofi/Cta.comb: ' ||
                    TO_CHAR(p_cdmodul) || '-' ||
                    TO_CHAR(p_cdmodal) || '-' ||
                    TO_CHAR(p_cdofici) || '-' ||
                    p_nrcuent || ' Muchas filas en CC_CTA_COMBINADAS');
    END;
     -- procesar fechas atrasadas desde la fecha valor hasta ayer --
     ---------------------------------------------------------------
    WHILE (p_fechac <= p_fechaf) LOOP
      BEGIN
        SELECT NVL(sal_acu_acreedor,0), NVL(sal_acu_deudor,0)
          INTO vk_acsalac, vk_acsalde
          FROM cc_sal_mensuales
         WHERE nro_cuenta      = p_nrcuent
           AND ano             = TO_NUMBER(TO_CHAR(p_fechac,'YYYY'))
           AND mes             = TO_NUMBER(TO_CHAR(p_fechac,'MM'));
      EXCEPTION
       WHEN NO_DATA_FOUND THEN
         -- INSERTAR REGISTRO --
         INSERT INTO cc_sal_mensuales
               (cod_modulo, cod_modalidad, cod_oficina,
                nro_cuenta, ano, mes,
                can_debitos, can_creditos, tot_debitos,
                tot_creditos, can_che_devueltos, sal_ini_mes,
                can_dia_acumulado,sal_acu_diario,
                sal_acu_acreedor, can_dia_acreedor,
                sal_acu_deudor, can_dia_deudor)
         VALUES
               (p_cdmodul, p_cdmodal, p_cdofici,
                p_nrcuent, TO_NUMBER(TO_CHAR(p_fechac,'YYYY')),
                TO_NUMBER(TO_CHAR(p_fechac,'MM')),
                0, 0, 0,
                0, 0, 0,
                p_fechaf-p_fechac, 0,
                0, 0,
                0, 0);
             ------
             vk_acsalac := 0;
             vk_acsalde := 0;
      END;
      BEGIN
         SELECT monto
           INTO vht_imtrans
           FROM cc_movimientos_his
          WHERE cod_modulo      = p_cdmodul
            AND cod_modalidad   = p_cdmodal
            AND cod_oficina     = p_cdofici
            AND nro_cuenta      = p_nrcuent
            AND fecha           = p_fechac
            AND cod_tra_padre   = 310
            AND cod_transaccion = 503;
         -- SI ENCONTRO --
         -----------------
         --
         LP_DIF_HOY_SGTE_HABIL (p_fechac,p_cdofici, v_dias);
         --
         IF p_detalle = 'D' THEN
            IF vht_imtrans >= p_imtrans THEN
               -- la transferencia es mayor a la transaccion atrasada --
               ---------------------------------------------------------
               vk_monaho := p_imtrans * v_dias * -1;
               vk_moncc  := 0;
            ELSE
               vk_monaho := vht_imtrans * v_dias * -1;
               vk_moncc  := (p_imtrans - vht_imtrans) * v_dias;
            END IF;
         ELSE
            vk_monaho := p_imtrans * v_dias;
            vk_moncc  := 0;
         END IF;
         --
         UPDATE ah_sal_mensuales SET
                sal_acu_diario = NVL(sal_acu_diario, 0) + vk_monaho
          WHERE nro_cuenta    = v_nrctaav
            AND ano           = TO_CHAR(p_fechac, 'YYYY')
            AND mes           = TO_CHAR(p_fechac, 'MM');
         IF SQL%NOTFOUND THEN
            INSERT INTO ah_sal_mensuales
               (cod_modulo, cod_modalidad, cod_oficina,
                nro_cuenta, ano, mes,
                can_debitos, can_creditos, tot_debitos,
                tot_creditos, can_che_devueltos, sal_ini_mes,
                can_dia_acumulado, sal_acu_diario)
              VALUES
               (v_cdmodav, v_cdmadav, v_cdofiav,
                v_nrctaav, TO_NUMBER(TO_CHAR(p_fechac,'YYYY')),
                TO_NUMBER(TO_CHAR(p_fechac,'MM')),
                0, 0, 0,
                0, 0, 0,
                p_fechaf-p_fechac, vk_monaho);
         END IF;
         IF vk_moncc <> 0 THEN
            UPDATE cc_sal_mensuales SET
                   sal_acu_diario = NVL(sal_acu_diario, 0) - vk_moncc
             WHERE nro_cuenta    = p_nrcuent
               AND ano           = TO_CHAR(p_fechac, 'YYYY')
               AND mes           = TO_CHAR(p_fechac, 'MM');
             -- actualizar los campos de saldos deudores y acreedores --
             v_lgdeudo := 'N';
             LP_BUS_SOBREGIROS(p_cdmodul,p_cdmodal,p_cdofici, p_nrcuent,
                               p_fechac, v_lgdeudo,v_sldeudo);
             IF v_lgdeudo = 'S' THEN
                vk_acsalde := NVL(vk_acsalde,0) + vk_moncc;
             ELSE
                vk_acsalac := NVL(vk_acsalac,0) - vk_moncc;
                IF vk_acsalac < 0 THEN
                      vk_acsalde := NVL(vk_acsalde,0) - NVL(vk_acsalac,0);
                      vk_acsalac := 0;
                END IF;
             END IF;
             UPDATE cc_sal_mensuales
                SET sal_acu_acreedor = vk_acsalac,
                    sal_acu_deudor   = vk_acsalde
              WHERE nro_cuenta    = p_nrcuent
                AND ano           = TO_NUMBER(TO_CHAR(p_fechac,'YYYY'))
                AND mes           = TO_NUMBER(TO_CHAR(p_fechac,'MM'));
             --- Actualiza saldos deudores
             -----------------------------
             v_fechaux := p_fechac;
             WHILE v_fechaux < p_fechac + v_dias LOOP
                UPDATE cc_sobregiros
                   SET saldo = NVL(saldo, 0) + vk_moncc
                 WHERE nro_cuenta = p_nrcuent
                   AND fecha      = v_fechaux
                   AND liquidado  = 'N';
                v_fechaux := v_fechaux + 1;
             END LOOP;
         END IF;
      EXCEPTION
        WHEN TOO_MANY_ROWS THEN
           raise_application_error(-20000,'Modul/Modal/Ofi/Cta: ' ||
                                   TO_CHAR(p_cdmodul) || '-' ||
                                   TO_CHAR(p_cdmodal) || '-' ||
                                   TO_CHAR(p_cdofici) || '-' ||
                                   p_nrcuent || ' muchas filas en CC_MOVIMIENTOS_HIS');
        WHEN NO_DATA_FOUND THEN
           -- SI NO ENCONTRO EN EL HISTORICO --
           IF p_detalle = 'D' THEN
             v_importe := p_imtrans * -1;
           ELSE
             v_importe := p_imtrans;
           END IF;
             --
           LP_DIF_HOY_SGTE_HABIL (p_fechac,p_cdofici, v_dias);
             --
           UPDATE cc_sal_mensuales SET
                  sal_acu_diario = NVL(sal_acu_diario, 0) + (v_importe * v_dias)
            WHERE nro_cuenta    = p_nrcuent
              AND ano           = TO_CHAR(p_fechac, 'YYYY')
              AND mes           = TO_CHAR(p_fechac, 'MM');
           IF SQL%NOTFOUND THEN
              INSERT INTO cc_sal_mensuales
                 (cod_modulo, cod_modalidad, cod_oficina,
                  nro_cuenta, ano, mes,
                  can_debitos, can_creditos, tot_debitos,
                  tot_creditos, can_che_devueltos, sal_ini_mes,
                  can_dia_acumulado, sal_acu_diario,
                  sal_acu_acreedor, can_dia_acreedor,
                  sal_acu_deudor, can_dia_deudor)
              VALUES
                 (v_cdmodav, v_cdmadav, v_cdofiav,
                  v_nrctaav, TO_NUMBER(TO_CHAR(p_fechac,'YYYY')),
                  TO_NUMBER(TO_CHAR(p_fechac,'MM')),
                  0, 0, 0,
                  0, 0, 0,
                  p_fechaf-p_fechac, v_importe * v_dias,
                  0, 0, 0, 0);
           END IF;
           -------------------
           --    DEBITO     --
           -------------------
           IF p_detalle = 'D' THEN
             v_lgdeudo := 'N';
             LP_BUS_SOBREGIROS(p_cdmodul,p_cdmodal,p_cdofici,
                               p_nrcuent,p_fechac, v_lgdeudo,v_sldeudo);
             IF v_lgdeudo = 'S' THEN
               vk_acsalde := NVL(vk_acsalde,0) +
                                 (NVL(p_imtrans,0) * v_dias);
             ELSE
               vk_acsalac := NVL(vk_acsalac,0) -
                            (NVL(p_imtrans,0) * v_dias);
               IF vk_acsalac < 0 THEN
                 vk_acsalde := NVL(vk_acsalde,0) - NVL(vk_acsalac,0);
                 vk_acsalac := 0;
               END IF;
             END IF;
           END IF;
           -------------------
           --  FIN  DEBITO  --
           -------------------
           -------------------
           --    CREDITO    --
           -------------------
           IF p_detalle = 'C' THEN
             v_lgdeudo := 'N';
             LP_BUS_SOBREGIROS(p_cdmodul,p_cdmodal,p_cdofici,
                               p_nrcuent,p_fechac, v_lgdeudo, v_sldeudo);
             IF v_lgdeudo = 'S' THEN
               v_diferencia := (NVL(v_sldeudo,0) * v_dias) -
                               (NVL(p_imtrans,0) * v_dias);
               IF v_diferencia <= 0 THEN
                 vk_acsalac := vk_acsalac - v_diferencia;
                 vk_acsalde := NVL(vk_acsalde,0) -
                              ((NVL(p_imtrans,0) * v_dias) + v_diferencia);
               ELSE
                 vk_acsalde := NVL(vk_acsalde,0) -
                              (NVL(p_imtrans,0) * v_dias);
               END IF;
             ELSE
               vk_acsalac := NVL(vk_acsalac,0) +
                            (NVL(p_imtrans,0) * v_dias);
             END IF;
           END IF;
           -------------------
           --  FIN CREDITO  --
           -------------------
           UPDATE cc_sal_mensuales
              SET sal_acu_acreedor = vk_acsalac,
                  sal_acu_deudor   = vk_acsalde
            WHERE nro_cuenta    = p_nrcuent
              AND ano           = TO_NUMBER(TO_CHAR(p_fechac,'YYYY'))
              AND mes           = TO_NUMBER(TO_CHAR(p_fechac,'MM'));
           v_fechaux := v_fechac;
           WHILE v_fechaux < p_fechac + v_dias LOOP
             UPDATE cc_sobregiros
                SET saldo = NVL(saldo, 0) - v_importe
              WHERE nro_cuenta = p_nrcuent
                AND fecha      = v_fechaux
                AND liquidado  = 'N';
                v_fechaux := v_fechaux + 1;
           END LOOP;
      END;
      p_fechac := p_fechac + v_dias;
    END LOOP;
    DELETE cc_sobregiros WHERE  saldo < 0;
END;
PROCEDURE LP_DIF_HOY_SGTE_HABIL (p_fecha IN DATE,
                                 p_cdofici IN NUMBER,
                                 p_dias  OUT NUMBER) IS
--
-----------------------------------------------------------------------
-- recibe una fecha y devuelve la cantidad de dias que hay entre esa --
-- fecha y la siguiente habil. Ve si es dia habil, y si es, ve en la --
-- tabla de feriados (fgferia).                                      --
-----------------------------------------------------------------------
--
v_fechax DATE;
BEGIN
  p_dias   := 0;
  v_fechax := PAG_CAL.FU_OBT_FEC_HABIL(p_fecha+1,1,p_cdofici);
  p_dias   := v_fechax - p_fecha  ;
END;
--
BEGIN
     v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
     rv_gcale  := pag_cal.fu_obt_reg_cal(4);
     v_fcproxi := rv_gcale.fec_proxima;
     v_monloc := pag_gen.fu_obt_mon_local;
     v_usu_mig_excluir := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');
     IF diari%ISOPEN THEN
        CLOSE diari;
     END IF;
     OPEN diari;
     --
     -------------------------------------------------------
     LOOP
       FETCH diari INTO
           rmd_cdmodul, rmd_cdmodal, rmd_cdofici, rmd_nrcuent,
           rmd_cdtrans, rmd_fcvalor, rmd_fctrans, rmd_imtrans;
       EXIT WHEN diari%NOTFOUND;
       v_ok := 'S';
       BEGIN
           SELECT tipo
             INTO v_detalle
             FROM ge_transacciones
            WHERE cod_modulo      = rmd_cdmodul
              AND cod_modalidad   = rmd_cdmodal
              AND cod_transaccion = rmd_cdtrans;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
           raise_application_error(-20000,'Modul/Modal/Trans : ' ||
                   to_char(rmd_cdmodul) || ' ' ||
                   to_char(rmd_cdmodal) || ' ' ||
                   to_char(rmd_cdtrans) ||
                   'no existe en GE_TRANSACCIONES');
       END;
       v_ok := 'S';
       IF v_detalle NOT IN ('D','C') THEN
          v_ok := 'N';
       END IF;
       IF v_ok = 'S' THEN
          v_mesv     := TO_NUMBER(TO_CHAR(rmd_fcvalor, 'MM'));
          v_aniv     := TO_NUMBER(TO_CHAR(rmd_fcvalor, 'YYYY'));
          v_mest     := TO_NUMBER(TO_CHAR(rmd_fctrans, 'MM'));
          v_anit     := TO_NUMBER(TO_CHAR(rmd_fctrans, 'YYYY'));
          v_difermes := v_mest - v_mesv + 12 * (v_anit-v_aniv);
          IF v_difermes = 0 THEN
             v_diferdia := rmd_fctrans - rmd_fcvalor;
             v_fechai   := rmd_fcvalor;
             v_fechaf   := v_fcdehoy - 1; -- ayer --
          ELSE
             v_diferdia := to_number(to_char(rmd_fctrans,'DD'))-1;
             v_fechaini := rmd_fcvalor;
             v_fechaux := to_date('01' || to_char(v_fcdehoy,'MMYYYY'),'ddmmyyyy');
             v_fechai   := v_fechaux;
             /*v_fechaux := '01' || to_char(v_fcdehoy,'MMYYYY');
             v_fechai   := TO_DATE(v_fechaux, 'DDMMYYYY');*/
             v_fechaf   := v_fcdehoy - 1; -- ayer --
          END IF;
          BEGIN
            select nvl(cta_combinada, 'N')
              into rmc_ctacomb
              from cc_cta_corrientes
             where nro_cuenta    = rmd_nrcuent;
          EXCEPTION
              WHEN NO_DATA_FOUND THEN
                raise_application_error(-20000,'Cuenta no existe en CC_CTA_CORRIENTES ' ||
                   to_char(rmd_cdmodul) || '-' ||
                   to_char(rmd_cdmodal) || '-' ||
                   to_char(rmd_cdofici) || '-' ||
                           rmd_nrcuent);
          END ;
          ------------------------------------------------------
          IF NVL(rmc_ctacomb,'N') = 'N' THEN
            LP_FEC_VALOR(rmd_cdmodul, rmd_cdmodal,
                         rmd_cdofici, rmd_nrcuent,
                         rmd_imtrans, v_fechai, v_fechaf,
                         v_fechac, v_detalle);
           ------------------------------------------------------
            v_mesinici := TO_CHAR(v_fechaini,'MM');
            v_aniinici := TO_CHAR(v_fechaini,'YYYY');
            IF v_detalle = 'D' THEN
               v_imtrans := rmd_imtrans * -1;
            ELSE
               v_imtrans := rmd_imtrans;
            END IF;
            -- actualizar saldos deudores para la fecha si hubieran --
            ----------------------------------------------------------
            BEGIN
              UPDATE cc_sobregiros
                 SET saldo =  saldo - TO_NUMBER(v_imtrans)
               WHERE nro_cuenta =  rmd_nrcuent AND
                     fecha      >= rmd_fcvalor AND
                     liquidado  = 'N';
            EXCEPTION
              WHEN OTHERS THEN
                 raise_application_error(-20000,sqlerrm);
            END;
            DELETE cc_sobregiros WHERE saldo <= 0;
            ----- lee saldos mensuales del mes en curso -----
            -------------------------------------------------
            IF salme%isopen THEN
              CLOSE salme;
            END IF;
            v_mesinici := v_mest;
            v_aniinici := v_anit;
            OPEN salme;
            FETCH salme INTO rsm_dummy;
            IF salme%NOTFOUND THEN
              -- NO ENCONTRO EL REGISTRO EN SALDOS MENSUALES --
              -------------------------------------------------
              -- INSERTAR REGISTRO --
              BEGIN
                INSERT INTO cc_sal_mensuales
                (cod_modulo, cod_modalidad, cod_oficina,
                 nro_cuenta, ano, mes,
                 can_debitos, can_creditos, tot_debitos,
                 tot_creditos, can_che_devueltos, sal_ini_mes,
                 can_dia_acumulado, sal_acu_diario,
                 sal_acu_acreedor, can_dia_acreedor,
                 sal_acu_deudor, can_dia_deudor)
                 VALUES
                 (rmd_cdmodul, rmd_cdmodal, rmd_cdofici,
                  rmd_nrcuent, v_aniinici, v_mesinici,
                  0, 0, 0,
                  0, 0, 0,
                  0, 0,
                  0, 0,
                  0, 0);
              EXCEPTION
                WHEN OTHERS THEN
                  raise_application_error(-20000,sqlerrm);
              END;
            END IF;
            BEGIN
              BEGIN
                SELECT can_dia_acumulado
                  INTO v_ctdiast
                  FROM cc_sal_mensuales
                 WHERE nro_cuenta    = rmd_nrcuent
                   AND ano           = v_aniinici
                   AND mes           = v_mesinici;
                EXCEPTION
                     WHEN NO_DATA_FOUND THEN
                          v_ctdiast := 0;
                     WHEN TOO_MANY_ROWS THEN
                          v_ctdiast := 0;
              END;
              IF  v_diferdia > v_ctdiast THEN
                UPDATE cc_sal_mensuales SET
                       sal_acu_diario = nvl(sal_acu_diario,0) +
                                       (v_imtrans*v_diferdia),
                       can_dia_acumulado = v_diferdia
                 WHERE nro_cuenta    = rmd_nrcuent
                   AND ano           = v_aniinici
                   AND mes           = v_mesinici;
              ELSE
                UPDATE cc_sal_mensuales SET
                     sal_acu_diario = nvl(sal_acu_diario,0) +
                                     (v_imtrans*v_diferdia)
                 WHERE nro_cuenta    = rmd_nrcuent
                   AND ano           = v_aniinici
                   AND mes           = v_mesinici;
              END IF;
            EXCEPTION
              WHEN OTHERS THEN
                 raise_application_error(-20000,sqlerrm);
            END;
          ELSE
            LP_CTA_COMBINADA(rmd_cdmodul, rmd_cdmodal,
                             rmd_cdofici, rmd_nrcuent,
                             rmd_imtrans, v_fechai, v_fechaf,
                             v_fechac, v_detalle);
          END IF;   -- de si es ctacomb
       END IF;   -- de si es ok
     END LOOP;
     ---------------------------------------------
     -- fin procesamiento fecha atrasada        --
     ---------------------------------------------
     -- inicio procesamiento saldo de la cuenta --
     ---------------------------------------------
     ---------
    v_fechaini := v_fcdehoy;
    v_mesinici := TO_CHAR(v_fechaini,'MM');
    v_aniinici := TO_CHAR(v_fechaini,'YYYY');
    v_mesprx := TO_CHAR(v_fcproxi,'MM') ;
    v_aniprx := TO_CHAR(v_fcproxi,'YYYY');

     IF ctcte%ISOPEN THEN
       CLOSE ctcte;
     END IF;
     OPEN ctcte;
     LOOP -------------------------------------------------------
       FETCH CTCTE INTO
          rmc_cdmodul, rmc_cdmodal, rmc_cdofici, rmc_nrcuent,
          rmc_cdmoned, rmc_sltotol, rmc_slretol, rmc_slblool,
          rmc_ctacomb, rmc_cdsubmod;
       EXIT WHEN ctcte%NOTFOUND;
       IF salme2%isopen THEN
          CLOSE salme2;
       END IF;
       OPEN salme2;
       FETCH salme2 INTO rsm_dummy;
       IF salme2%NOTFOUND THEN
          -- NO ENCONTRO EL REGISTRO EN SALDOS MENSUALES --
          -------------------------------------------------
          -- INSERTAR REGISTRO --
          BEGIN
          INSERT INTO cc_sal_mensuales
            (cod_modulo, cod_modalidad, cod_oficina,
             nro_cuenta, ano, mes,
             can_debitos, can_creditos, tot_debitos,
             tot_creditos, can_che_devueltos, sal_ini_mes,
             can_dia_acumulado, sal_acu_diario,
             sal_acu_acreedor, can_dia_acreedor,
             sal_acu_deudor, can_dia_deudor)
          VALUES
            (rmc_cdmodul, rmc_cdmodal, rmc_cdofici,
             rmc_nrcuent, v_aniinici, v_mesinici,
             0, 0, 0,
             0, 0, 0,
             0, 0,
             0, 0,
             0, 0);
          EXCEPTION
             WHEN OTHERS THEN
               raise_application_error(-20000,sqlerrm);
             END;
            ------
       END IF;
       ---------
       v_monto := nvl(rmc_sltotol,0) - nvl(rmc_slretol,0);
       --asume q la transferencia se ejecuta después
       IF rmc_ctacomb = 'S' THEN
          BEGIN
            SELECT nvl(sal_minimo,FUG_OBT_SAL_MIN_TRASPASO(nro_cta_cte))
              INTO V_CBSLMINPA
              FROM cc_cta_combinadas
             WHERE nro_cta_cte = rmc_nrcuent
               --DYDMR-3175: Ajustes del Saldo promedio.-
               and nvl(fug_obt_pardinamico('COD_SUB_MAD_TRA_CTACOMB',
                                            rmc_cdmodul             ,
                                            rmc_cdmodal             ,
                                            rmc_cdmoned             ,
                                            rmc_cdofici             ,
                                            rmc_cdsubmod            ), 
                                            'S') = 'S';
          EXCEPTION
              WHEN NO_DATA_FOUND THEN
                v_cbslminpa := v_monto;
          END;
          IF v_monto > to_number(v_cbslminpa) THEN
             v_monto := TO_NUMBER(v_cbslminpa);
          END IF;
       END IF;
       IF TO_CHAR(v_fechaini,'MM') <> v_mesprx THEN
          v_diferdia := LAST_DAY(v_fechaini) - v_fechaini + 1;
          v_diferde1 := TO_NUMBER(TO_CHAR(v_fcproxi,'DD'))-1;
       ELSE
          v_diferdia := v_fcproxi - v_fechaini;
          v_diferde1 := 0;
       END IF;
       BEGIN
         UPDATE cc_sal_mensuales SET
                sal_acu_diario= nvl(sal_acu_diario,0) + v_monto * v_diferdia,
                can_dia_acumulado = nvl(can_dia_acumulado,0) + v_diferdia,
                sal_fin_mes = decode(to_CHAR(v_fechaini,'MM'),v_mesprx,null, v_monto)
          WHERE nro_cuenta    = rmc_nrcuent
            AND ano           = v_aniinici
            AND mes           = v_mesinici;
       EXCEPTION
         WHEN OTHERS THEN
         raise_application_error(-20000,sqlerrm);
       END;
       --actualizar saldo promedio en ge_cuentas
       Begin
          SELECT nvl(can_dia_acumulado,0), sal_acu_diario
            INTO v_can_dia_acumulado, v_sal_acu_diario
            FROM CC_SAL_MENSUALES
           WHERE nro_cuenta  = rmc_nrcuent
             AND ano = v_aniinici
             AND mes = v_mesinici;
          Update ge_cuentas
             set sal_promedio = round(decode(v_can_dia_acumulado, 0, 0, v_sal_acu_diario / v_can_dia_acumulado), 2)
           Where nro_cuenta = rmc_nrcuent;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_can_dia_acumulado := 0;
         WHEN TOO_MANY_ROWS THEN
            v_can_dia_acumulado := 0;
       End;

       IF rmc_ctacomb = 'N' THEN
         IF (NVL(rmc_sltotol,0) - NVL(rmc_slretol,0)) < 0 THEN
           begin
             UPDATE cc_sal_mensuales SET
                    sal_acu_deudor = NVL(sal_acu_deudor,0) -
                                    (NVL(rmc_sltotol,0) - NVL(rmc_slretol,0)) * v_diferdia,
                    can_dia_deudor = nvl(can_dia_deudor,0) + v_diferdia
              WHERE nro_cuenta    = rmc_nrcuent
                AND ano           = v_aniinici
                AND mes           = v_mesinici;
           EXCEPTION
             WHEN OTHERS THEN
               raise_application_error(-20000,sqlerrm);
           end;
         ELSE
           begin
             UPDATE cc_sal_mensuales SET
                    sal_acu_acreedor = NVL(sal_acu_acreedor,0) +
                                      (NVL(rmc_sltotol,0) - NVL(rmc_slretol,0)) * v_diferdia,
                    can_dia_acreedor = nvl(can_dia_acreedor,0) + v_diferdia
              WHERE nro_cuenta    = rmc_nrcuent
                AND ano           = v_aniinici
                AND mes           = v_mesinici;
           EXCEPTION
             WHEN OTHERS THEN
                 raise_application_error(-20000,sqlerrm);
           end;
         END IF;
       ELSE
         -- si tiene cuenta combinada --
         IF  NVL(v_monto,0)< 0 THEN
           begin
             UPDATE cc_sal_mensuales SET
                    sal_acu_deudor = NVL(sal_acu_deudor,0) -
                                     nvl(v_monto,0) * v_diferdia,
                    can_dia_deudor = nvl(can_dia_deudor,0) + v_diferdia
              WHERE nro_cuenta    = rmc_nrcuent
                AND ano           = v_aniinici
                AND mes           = v_mesinici;
           EXCEPTION
             WHEN OTHERS THEN
               raise_application_error(-20000,sqlerrm);
           end;
         ELSE
           begin
             UPDATE cc_sal_mensuales SET
               sal_acu_acreedor = NVL(sal_acu_acreedor,0) +
                                  nvl(v_monto,0) * v_diferdia,
               can_dia_acreedor = nvl(can_dia_acreedor,0) + v_diferdia
              WHERE nro_cuenta    = rmc_nrcuent
                AND ano           = v_aniinici
                AND mes           = v_mesinici;
           EXCEPTION
             WHEN OTHERS THEN
               raise_application_error(-20000,sqlerrm);
           end;
         END IF;
       END IF;
       ------- agregar registro mes siguiente --------
       -----------------------------------------------
       IF TO_CHAR(v_fechaini,'MM') <> v_mesprx THEN
          begin
          INSERT INTO cc_sal_mensuales
            (cod_modulo, cod_modalidad , cod_oficina,
             nro_cuenta, ano, mes,
             can_debitos, can_creditos, tot_debitos,
             tot_creditos, can_che_devueltos, sal_ini_mes,
             can_dia_acumulado, sal_acu_diario,
             sal_acu_acreedor, can_dia_acreedor,
             sal_acu_deudor, can_dia_deudor)
          VALUES
            (rmc_cdmodul, rmc_cdmodal, rmc_cdofici,
             rmc_nrcuent, v_aniprx, v_mesprx,
             0, 0, 0,
             0, 0, v_monto,
             v_diferde1,
             v_monto*v_diferde1,
             0, 0,
             0, 0);
          EXCEPTION
             WHEN OTHERS THEN
                raise_application_error(-20000,sqlerrm);
          end;
       END IF;
       IF rmc_ctacomb = 'N' THEN
         IF (NVL(rmc_sltotol,0) - NVL(rmc_slretol,0)) < 0 THEN
           begin
             UPDATE cc_sal_mensuales SET
                    sal_acu_deudor = NVL(sal_acu_deudor,0) -
                                    (NVL(rmc_sltotol,0) - NVL(rmc_slretol,0)) * v_diferde1,
                    can_dia_deudor = nvl(can_dia_deudor,0) + v_diferde1
              WHERE nro_cuenta    = rmc_nrcuent
                AND ano           = v_aniprx
                AND mes           = v_mesprx;
           EXCEPTION
             WHEN OTHERS THEN
               raise_application_error(-20000,sqlerrm);
           end;
         ELSE
           begin
             UPDATE cc_sal_mensuales SET
                    sal_acu_acreedor = NVL(sal_acu_acreedor,0) +
                                      (NVL(rmc_sltotol,0) - NVL(rmc_slretol,0)) * v_diferde1,
                    can_dia_acreedor = nvl(can_dia_acreedor,0) + v_diferde1
              WHERE nro_cuenta    = rmc_nrcuent
                AND ano           = v_aniprx
                AND mes           = v_mesprx;
           EXCEPTION
             WHEN OTHERS THEN
               raise_application_error(-20000,sqlerrm);
           end;
         END IF;
       ELSE
         -- si tiene cuenta combinada --
         IF NVL(v_monto,0) < 0 THEN
           begin
             UPDATE cc_sal_mensuales SET
                    sal_acu_deudor = NVL(sal_acu_deudor,0) -
                                     nvl(v_monto,0) * v_diferde1,
                    can_dia_deudor = nvl(can_dia_deudor,0) + v_diferde1
              WHERE nro_cuenta    = rmc_nrcuent
                AND ano           = v_aniprx
                AND mes           = v_mesprx;
           EXCEPTION
             WHEN OTHERS THEN
                raise_application_error(-20000,sqlerrm);
           end;
         ELSE
           begin
             UPDATE cc_sal_mensuales SET
                    sal_acu_acreedor = NVL(sal_acu_acreedor,0) +
                                       nvl(v_monto,0) * v_diferde1,
                    can_dia_acreedor = nvl(can_dia_acreedor,0) + v_diferde1
              WHERE nro_cuenta    = rmc_nrcuent
                AND ano           = v_aniprx
                AND mes           = v_mesprx;
           EXCEPTION
             WHEN OTHERS THEN
                raise_application_error(-20000,sqlerrm);
           end;
         END IF;
       END IF;
       ---
       -- fin agrega registro para siguiente mes  --
       ---------------------------------------------
    END LOOP;
END;

 
/
