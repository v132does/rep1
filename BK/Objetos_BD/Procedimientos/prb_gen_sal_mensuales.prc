create or replace procedure it.prb_gen_sal_mensuales is
/* genera los saldos mensuales */
v_fec_actual     date      := pag_cal.fu_obt_fec_actual(2);
v_ano            number(4) := to_char(v_fec_actual,'yyyy');
v_mes            number(2) := to_char(v_fec_actual,'mm');
v_ano_ant        number(4) := to_char(pag_cal.G_FEC_ANTERIOR,'yyyy');
v_mes_ant        number(2) := to_char(pag_cal.G_FEC_ANTERIOR,'mm');
v_cantidad NUMBER := 0;
v_lugar   varchar2(400);
v_cod_mon_fuerte varchar2(5) := pag_gen.FU_OBT_MON_FUERTE;
v_cot_mon_fuerte NUMBER := pag_gen.FU_OBT_COTIZACION(v_cod_mon_fuerte,v_fec_actual);

BEGIN
     v_lugar := 'Antes de contar reg de ofic, mes, anho ';
     SELECT COUNT(*)
       INTO v_cantidad
       FROM CB_SAL_OFICINAS
      WHERE ANO = v_ano
        AND MES = v_mes
        AND ROWNUM = 1;
     IF v_cantidad > 0 THEN
        /*RAISE_APPLICATION_ERROR(-20000,'Ya existen registros en Saldos por Oficina ' ||
                  '. Mes : ' || v_mes ||'/' || v_ano);*/
        null;
     ELSE
        ---------- CARGA EN BLOQUE SALDOS POR OFICINA -----------
        v_lugar := 'antes de insertar en CB_SAL_OFICINAS ';
        INSERT INTO CB_SAL_OFICINAS (
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
        FROM  CB_SAL_OFICINAS
        WHERE ANO = v_ano_ant
          AND MES = v_mes_ant;
        v_lugar := 'Borrando datos del CB_SAL_OFICINAS mes actual';
        DELETE CB_SAL_OFICINAS
         WHERE ano = v_ano_ant
           and mes = v_mes_ant;
        v_lugar := 'Borrando datos de CB_SAL_CONSOLIDADOS';
        DELETE CB_SAL_CONSOLIDADOS;
        ---
   END IF;
EXCEPTION
    WHEN OTHERS THEN
         raise_application_error(-20000,'Error en prb_gen_sal_mensuales '||v_lugar||'-'||sqlerrm);
END;
/

