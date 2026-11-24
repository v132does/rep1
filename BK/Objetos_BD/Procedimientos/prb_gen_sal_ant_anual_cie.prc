CREATE OR REPLACE PROCEDURE IT.PRB_GEN_SAL_ANT_ANUAL_CIE IS
  /* transfiere los saldos actuales a saldos de ayer */
  v_cod_oficina    NUMBER;
  v_des_oficina    varchar2(100);
  v_fec_actual     date        := pag_cal.fu_obt_fec_actual(2);
  v_ano_actual     number(4)   := to_char(v_fec_actual,'yyyy');
  v_mes_actual     number(2)   := to_char(v_fec_actual,'mm');
  --v_cod_mon_fuerte varchar2(5) := pag_gen.FU_OBT_MON_FUERTE;
  --v_cot_mon_fuerte NUMBER      := pag_gen.FU_OBT_COTIZACION(v_cod_mon_fuerte,v_fec_actual);
  --
  -- Requerimiento: CNFGHDBS-5.
  -- Fecha: 27/08/2015.
  --v_fec_historico  ge_calendarios.fec_actual%type;
  --v_can_dias_his   NUMBER := fug_obt_pardinamico('CBT_CAN_DIA_ACU_PROMEDIOS_HIS');
  --v_existe         NUMBER := 0;
  -- Requerimiento: DYDMR-2715.
  -- Fecha: 28/12/2015.
  --v_fec_inventario cb_sal_promedios_dia.fecha%type := to_date(fug_obt_pardinamico('CBN_FEC_ULT_DIA_INV_ANUAL'),'dd/mm/yyyy');
  --------------------------------------------------------------------
  CURSOR OFIC is
    SELECT DISTINCT B.COD_OFICINA, B.DESCRIPCION
      FROM APE_CB_SAL_OFICINAS A, BA_OFICINAS B
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
     FROM   APE_CB_SAL_OFICINAS
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
  --v_fec_anterior       DATE;
  --v_fec_proxima        DATE;
  --v_ano_anterior       NUMBER(4);
  --v_mes_anterior       NUMBER(2);
  --RAMG: anulado porque no se usa
  --wani_fcprx NUMBER(4);
  --wmes_fcprx NUMBER(2);
  --w_dias     NUMBER(3,0);
  --v_dif_dias          NUMBER;
  --v_dif_dias_2        NUMBER;
  --v_cod_moneda        VARCHAR2(3);
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
 --v_fec_anterior := pag_cal.G_FEC_ANTERIOR;
 --v_fec_proxima  := pag_cal.G_FEC_PROXIMA;
 --------------------------------------------------------------
 --v_mes_anterior := TO_CHAR(v_fec_anterior, 'MM');
 --v_ano_anterior := TO_CHAR(v_fec_anterior, 'YYYY');
 v_mes_actual := TO_CHAR(v_fec_actual, 'MM');
 v_ano_actual := TO_CHAR(v_fec_actual, 'YYYY');
 --RAMG: marcado porque no se usa
 --wmes_fcprx := TO_CHAR(v_fec_proxima, 'MM');
 --wani_fcprx := TO_CHAR(v_fec_proxima, 'YYYY');
 --w_dias     := v_fec_actual - v_fec_anterior;
 --------------------------------------------------------------
 /*IF v_mes_anterior <> v_mes_actual THEN
    v_dif_dias := (LAST_DAY(v_fec_anterior) + 1) - v_fec_anterior;
    v_dif_dias_2 := TO_NUMBER(TO_CHAR(v_fec_actual,'DD'))-1;
 ELSE
    v_dif_dias := v_fec_actual - v_fec_anterior;
    v_dif_dias_2 := 0;
 END IF;*/
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
        ---------- MODIFICA SALDOS POR OFICINA -----------
        UPDATE APE_CB_SAL_OFICINAS
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

 -- Requerimiento: DYDMR-2715.
 -- Fecha: 28/12/2015.
 -- Se realiza la validacion de la fecha anterior calendario vs la Fecha registrada en el Parametro Dinamico.
 /*IF ((v_ano_anterior * 100) + v_mes_anterior) <> to_number(to_char(v_fec_inventario,'yyyymm')) THEN
    OPEN OFIC;
    raise_application_error(-20000,' ERROR. El Mes y Año registrado en el parámetro dinámico CBN_FEC_ULT_DIA_INV_ANUAL no corresponden a la Fecha Anterior Hábil.');
 END IF;*/

 -- Requerimiento: CNFGHDBS-5.
 -- Fecha: 27/08/2015.
 -- Elimina/Inserta los registros en la tabla historica.
 -- Verifica que exista registro a ser insertados en el historico.
 /*BEGIN
    SELECT COUNT(1)
      INTO v_existe
      FROM cb_sal_promedios a
     WHERE a.ano = v_ano_anterior
       AND a.mes = v_mes_anterior;
 EXCEPTION
    WHEN OTHERS THEN
       v_existe := 0;
 END;
 */--
 /*IF v_existe > 0 THEN
    -- Obtengo la fecha a ser eliminada del historico.
    v_fec_historico := v_fec_anterior - v_can_dias_his;
    -- Elimina los registros del historico.
    delete cb_sal_promedios_dia a where a.fecha <= v_fec_historico;
    -- Inserta los registro del día actual;
    -- Requerimiento: DYDMR-2715.
    -- Fecha: 28/12/2015.
    insert into cb_sal_promedios_dia select v_fec_inventario, t.* from cb_sal_promedios t where t.ano = v_ano_anterior and t.mes = v_mes_anterior;
 END IF;*/

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    CLOSE OFIC;
    raise_application_error(-20000,' ERROR. No existen saldos para actualizar');
  WHEN OTHERS THEN
    CLOSE OFIC;
    raise_application_error(-20000,'Error en prb_gen_sal_anterior '||sqlerrm);
END;
/

