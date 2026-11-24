create or replace procedure it.prb_gen_sal_mensuales_cie is
/* genera los saldos mensuales */
v_fec_actual     date      := pag_cal.fu_obt_fec_actual(2);
v_ano            number(4) := to_char(v_fec_actual,'yyyy');
v_mes            number(2) := to_char(v_fec_actual,'mm');
v_fec_anterior   date      := pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_ACTUAL(2),1);
v_ano_ant        number(4) := to_char(v_fec_anterior,'yyyy');
v_mes_ant        number(2) := to_char(v_fec_anterior,'mm');
v_cantidad NUMBER := 0;
v_lugar   varchar2(400);
v_cod_mon_fuerte varchar2(5) := pag_gen.FU_OBT_MON_FUERTE;
v_cot_mon_fuerte NUMBER := pag_gen.FU_OBT_COTIZACION(v_cod_mon_fuerte,v_fec_actual);

BEGIN
    v_lugar := 'Borrando datos del CB_SAL_OFICINAS mes actual';
    DELETE APE_CB_SAL_OFICINAS
      WHERE ano = v_ano
        and mes = v_mes;
        
     v_lugar := 'Borrando datos de CB_SAL_CONSOLIDADOS';
     DELETE APE_CB_SAL_CONSOLIDADOS
      WHERE ANO = v_ano
        AND MES = v_mes;
     
     v_lugar := 'Antes de contar reg de ofic, mes, anho ';
     SELECT COUNT(*)
       INTO v_cantidad
       FROM APE_CB_SAL_OFICINAS
      WHERE ANO = v_ano
        AND MES = v_mes
        AND ROWNUM = 1;
     IF v_cantidad > 0 THEN
        RAISE_APPLICATION_ERROR(-20000,'Ya existen registros en Saldos por Oficina ' ||
                  '. Mes : ' || v_mes ||'/' || v_ano);
     ELSE
        ---------- CARGA EN BLOQUE SALDOS POR OFICINA -----------
        v_lugar := 'antes de insertar en CB_SAL_OFICINAS ';
        INSERT INTO APE_CB_SAL_OFICINAS (
          COD_OFICINA, COD_RUBRO, ANO, MES,
          SAL_MON_LOC_ANT, DEB_MON_LOCAL, CRE_MON_LOCAL, SAL_INI_MES_MON_LOCAL,
          SAL_MON_RUB_ANT, DEB_MON_RUBRO, CRE_MON_RUBRO, SAL_INI_MES_MON_RUBRO,
          SAL_EQU_LOC_ANT, DEB_EQU_LOCAL, CRE_EQU_LOCAL,
          SAL_INI_MES_MON_FUERTE, SAL_INI_MES_EQU_LOCAL)
        SELECT
          COD_OFICINA, COD_RUBRO, v_ano, v_mes,
          NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0),0,0,
          NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0),
          NVL(SAL_MON_RUB_ANT,0)+NVL(DEB_MON_RUBRO,0)-NVL(CRE_MON_RUBRO,0),0,0,
          NVL(SAL_MON_RUB_ANT,0)+NVL(DEB_MON_RUBRO,0)-NVL(CRE_MON_RUBRO,0),
          NVL(SAL_EQU_LOC_ANT,0)+NVL(DEB_EQU_LOCAL,0)-NVL(CRE_EQU_LOCAL,0),0,0,
          (NVL(SAL_MON_LOC_ANT,0)+NVL(DEB_MON_LOCAL,0)-NVL(CRE_MON_LOCAL,0))/v_cot_mon_fuerte,
          NVL(SAL_EQU_LOC_ANT,0)+NVL(DEB_EQU_LOCAL,0)-NVL(CRE_EQU_LOCAL,0)
        FROM  CIE_CB_SAL_OFICINAS
        WHERE ANO = v_ano_ant
          AND MES = v_mes_ant;
        ---
   END IF;
EXCEPTION
    WHEN OTHERS THEN
         raise_application_error(-20000,'Error en prb_gen_sal_mensuales '||v_lugar||'-'||sqlerrm);
END;
/

