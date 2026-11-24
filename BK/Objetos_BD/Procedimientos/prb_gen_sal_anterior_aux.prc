CREATE OR REPLACE PROCEDURE IT.PRB_GEN_SAL_ANTERIOR_aux IS
  /* transfiere los saldos actuales a saldos de ayer */
  v_cod_oficina    NUMBER;
  v_des_oficina    varchar2(100);
  v_fec_actual     date        := pag_cal.fu_obt_fec_actual(2);
  v_ano_actual     number(4)   := to_char(v_fec_actual,'yyyy');
  v_mes_actual     number(2)   := to_char(v_fec_actual,'mm');
  v_cod_mon_fuerte varchar2(5) := pag_gen.FU_OBT_MON_FUERTE;
  v_cot_mon_fuerte NUMBER      := pag_gen.FU_OBT_COTIZACION(v_cod_mon_fuerte,v_fec_actual);
  --------------------------------------------------------------------
  CURSOR OFIC is
    SELECT DISTINCT B.COD_OFICINA, B.DESCRIPCION
      FROM CB_SAL_OFICINAS A, BA_OFICINAS B
     WHERE A.COD_OFICINA = B.COD_OFICINA
       AND A.ANO = v_ano_actual
       AND A.MES = v_mes_actual;
  --------------------------------------------------------------------
  CURSOR CURY is
     SELECT COD_RUBRO,
            NVL(SAL_MON_LOC_ANT,0) + NVL(DEB_MON_LOCAL,0) - NVL(CRE_MON_LOCAL,0),
            NVL(DEB_MON_LOCAL,0),NVL(DEB_MON_RUBRO,0),
            NVL(CRE_MON_LOCAL,0),NVL(CRE_MON_RUBRO,0),
            NVL(SAL_MON_RUB_ANT,0) + NVL(DEB_MON_RUBRO,0) - NVL(CRE_MON_RUBRO,0),
            NVL(SAL_EQU_LOC_ANT,0) + NVL(DEB_EQU_LOCAL,0) - NVL(CRE_EQU_LOCAL,0),
            NVL(DEB_EQU_LOCAL,0),NVL(CRE_EQU_LOCAL,0)
     FROM   CB_SAL_OFICINAS
     WHERE  COD_OFICINA = v_cod_oficina
     AND    ANO = v_ano_actual
     AND    MES = v_mes_actual
     FOR UPDATE OF COD_RUBRO;
  --------------------------------------------------------------------
  v_sal_mon_local      NUMBER;
  v_sal_equ_local      NUMBER;
  v_sal_deu_equ_loc    NUMBER;
  v_sal_acr_equ_loc    NUMBER;
  v_sal_mon_rubro      NUMBER;
  v_sal_deu_mon_loc    NUMBER;
  v_sal_acr_mon_loc    NUMBER;
  v_sal_deu_mon_rub    NUMBER;
  v_sal_acr_mon_rub    NUMBER;
  v_cod_rubro          VARCHAR2(15);
  v_fec_anterior       DATE;
  --v_fec_proxima        DATE;
  v_ano_anterior       NUMBER(4);
  v_mes_anterior       NUMBER(2);
  --RAMG: anulado porque no se usa
  --wani_fcprx NUMBER(4);
  --wmes_fcprx NUMBER(2);
  --w_dias     NUMBER(3,0);
  v_dif_dias          NUMBER;
  v_dif_dias_2        NUMBER;
  v_cod_moneda        VARCHAR2(3);
  --------------------------------------------------------------------
  FUNCTION lf_obt_mon_rubro(p_cod_rubro in varchar2)
    return varchar2 is
  v_retorno varchar2(5);
  BEGIN
     SELECT COD_MONEDA
       INTO v_retorno
       FROM CB_RUBROS
      WHERE COD_RUBRO = p_cod_rubro;
     return v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20000,'Error al leer moneda del Rubro '||sqlerrm);
  END;
BEGIN
 -- Cargar fechas calendario -----------------------------------
 pag_cal.PR_OBT_DAT_CALENDAR(2);
 -- las fechas utiles del calendario ---------------------------
 v_fec_anterior := pag_cal.G_FEC_ANTERIOR;
 --v_fec_proxima  := pag_cal.G_FEC_PROXIMA;
 --------------------------------------------------------------
 v_mes_anterior := TO_CHAR(v_fec_anterior, 'MM');
 v_ano_anterior := TO_CHAR(v_fec_anterior, 'YYYY');
 v_mes_actual := TO_CHAR(v_fec_actual, 'MM');
 v_ano_actual := TO_CHAR(v_fec_actual, 'YYYY');
 --RAMG: marcado porque no se usa
 --wmes_fcprx := TO_CHAR(v_fec_proxima, 'MM');
 --wani_fcprx := TO_CHAR(v_fec_proxima, 'YYYY');
 --w_dias     := v_fec_actual - v_fec_anterior;
 --------------------------------------------------------------
 IF v_mes_anterior <> v_mes_actual THEN
    v_dif_dias := (LAST_DAY(v_fec_anterior) + 1) - v_fec_anterior;
    v_dif_dias_2 := TO_NUMBER(TO_CHAR(v_fec_actual,'DD'))-1;
 ELSE
    v_dif_dias := v_fec_actual - v_fec_anterior;
    v_dif_dias_2 := 0;
 END IF;
 ------------------------------------------------------------------
 IF OFIC%ISOPEN THEN
    CLOSE OFIC;
 END IF;
 OPEN OFIC;
 LOOP
   FETCH OFIC INTO v_cod_oficina, v_des_oficina;
   EXIT WHEN OFIC%notfound;
   ---- proceso de los saldos de las cuentas de la oficina actual ----
   BEGIN
     IF CURY%isopen THEN
        CLOSE CURY;
     END IF;
     OPEN CURY;
     LOOP

        FETCH cury INTO v_cod_rubro, v_sal_mon_local, v_sal_deu_mon_loc, v_sal_deu_mon_rub,
                               v_sal_acr_mon_loc, v_sal_acr_mon_rub, v_sal_mon_rubro,
                               v_sal_equ_local, v_sal_deu_equ_loc, v_sal_acr_equ_loc;
        EXIT WHEN cury%notfound;
        --- MODIFICA SALDOS PROMEDIOS DEL MES DE LA FECHA ANTERIOR ----
        UPDATE CB_SAL_PROMEDIOS
           SET TOT_ACU_MON_LOCAL = NVL(TOT_ACU_MON_LOCAL,0) + v_sal_mon_local * v_dif_dias,
               TOT_ACUMULADO = NVL(TOT_ACUMULADO,0) + v_sal_mon_rubro * v_dif_dias,
               CAN_DIA_ACUMULADO = NVL(CAN_DIA_ACUMULADO,0) + v_dif_dias,
               TOT_ACU_MON_FUERTE = NVL(TOT_ACU_MON_FUERTE,0) +
                            ((v_sal_mon_local * v_dif_dias)/v_cot_mon_fuerte),
               TOT_ACU_DEB_MON_LOCAL = NVL(TOT_ACU_DEB_MON_LOCAL,0) + v_sal_deu_mon_loc,
               TOT_ACU_CRE_MON_LOCAL = NVL(TOT_ACU_CRE_MON_LOCAL,0) + v_sal_acr_mon_loc,
               TOT_ACU_DEBITOS = NVL(TOT_ACU_DEBITOS,0) + v_sal_deu_mon_rub,
               TOT_ACU_CREDITOS = NVL(TOT_ACU_CREDITOS,0) + v_sal_acr_mon_rub,
               TOT_ACU_EQU_LOCAL = NVL(TOT_ACU_EQU_LOCAL,0) + v_sal_equ_local * v_dif_dias,
               TOT_ACU_DEB_EQU_LOC = NVL(TOT_ACU_DEB_EQU_LOC,0) + v_sal_deu_equ_loc,
               TOT_ACU_CRE_EQU_LOC = NVL(TOT_ACU_CRE_EQU_LOC,0) + v_sal_acr_equ_loc
         WHERE COD_OFICINA = v_cod_oficina
           AND COD_RUBRO = v_cod_rubro
           AND ANO = v_ano_anterior
           AND MES = v_mes_anterior;
        ------------------------------------------------------------
        -- si no encontro genera un nuevo registro para la cuenta --
        ------------------------------------------------------------
        IF SQL%NOTFOUND THEN
           v_cod_moneda := lf_obt_mon_rubro(v_cod_rubro);
           INSERT INTO CB_SAL_PROMEDIOS
               (COD_OFICINA, COD_RUBRO, ANO, MES,
                COD_MONEDA, TOT_ACU_MON_LOCAL, TOT_ACUMULADO, CAN_DIA_ACUMULADO,
                TOT_ACU_MON_FUERTE, TOT_ACU_DEB_MON_LOCAL, TOT_ACU_CRE_MON_LOCAL, TOT_ACU_DEBITOS,
                TOT_ACU_CREDITOS,TOT_ACU_EQU_LOCAL,TOT_ACU_DEB_EQU_LOC,TOT_ACU_CRE_EQU_LOC)
           VALUES
               (v_cod_oficina, v_cod_rubro, v_ano_anterior, v_mes_anterior,
                v_cod_moneda, v_sal_mon_local * v_dif_dias, v_sal_mon_rubro * v_dif_dias,
                v_dif_dias, (v_sal_mon_local * v_dif_dias)/v_cot_mon_fuerte,
                v_sal_deu_mon_loc,v_sal_acr_mon_loc,v_sal_deu_mon_rub,v_sal_acr_mon_rub,
                v_sal_equ_local, v_sal_deu_equ_loc, v_sal_acr_equ_loc);
        END IF;
        IF v_dif_dias_2 <> 0 THEN
           ------------------------------------------------
           -- agrega registro del nuevo mes              --
           ------------------------------------------------
           v_cod_moneda := lf_obt_mon_rubro(v_cod_rubro);
           INSERT INTO CB_SAL_PROMEDIOS
               (COD_OFICINA, COD_RUBRO, ANO, MES,
                COD_MONEDA, TOT_ACU_MON_LOCAL, TOT_ACUMULADO, CAN_DIA_ACUMULADO,
                TOT_ACU_MON_FUERTE, TOT_ACU_DEB_MON_LOCAL, TOT_ACU_CRE_MON_LOCAL, TOT_ACU_DEBITOS,
                TOT_ACU_CREDITOS,TOT_ACU_EQU_LOCAL,TOT_ACU_DEB_EQU_LOC,TOT_ACU_CRE_EQU_LOC)
           VALUES
               (v_cod_oficina, v_cod_rubro, v_ano_actual, v_mes_actual,
                v_cod_moneda, v_sal_mon_local *v_dif_dias_2, v_sal_mon_rubro *v_dif_dias_2,
                v_dif_dias_2, (v_sal_mon_local *v_dif_dias_2)/v_cot_mon_fuerte,
                v_sal_deu_mon_loc,v_sal_acr_mon_loc,v_sal_deu_mon_rub,v_sal_acr_mon_rub,
                v_sal_equ_local, v_sal_deu_equ_loc, v_sal_acr_equ_loc);
        END IF;
        ---------- MODIFICA SALDOS POR OFICINA -----------
        UPDATE CB_SAL_OFICINAS
          SET SAL_MON_LOC_ANT = v_sal_mon_local,
              DEB_MON_LOCAL = 0,
              CRE_MON_LOCAL = 0,
              SAL_MON_RUB_ANT = v_sal_mon_rubro,
              DEB_MON_RUBRO = 0,
              CRE_MON_RUBRO = 0,
              SAL_EQU_LOC_ANT = v_sal_equ_local,
              DEB_EQU_LOCAL = 0,
              CRE_EQU_LOCAL = 0
        WHERE CURRENT OF CURY;
     END LOOP;
     IF CURY%ROWCOUNT = 0 THEN
        CLOSE CURY;
        raise_application_error(-20000,' ERROR. No se encontraron registros del mes ' ||
                v_mes_actual|| '/' || v_ano_actual);
     END IF;
     IF CURY%ISOPEN THEN
        CLOSE CURY;
     END IF;
   END;
   ----- FIN del proceso de los saldos de la oficina actual --------
 END LOOP;
 IF OFIC%rowcount = 0 THEN
    CLOSE OFIC;
    raise_application_error(-20000,'No existen saldos para generar. Verificar ');
 END IF;
 IF OFIC%isopen THEN
    CLOSE OFIC;
 END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    CLOSE OFIC;
    raise_application_error(-20000,' ERROR. No existen saldos para actualizar');
  WHEN OTHERS THEN
    CLOSE OFIC;
    raise_application_error(-20000,'Error en prb_gen_sal_anterior '||sqlerrm);
END PRB_GEN_SAL_ANTERIOR_aux;
/

