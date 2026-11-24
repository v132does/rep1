CREATE OR REPLACE PROCEDURE IT.PRB_SUM_SAL_CONSOLIDADOS_APE
 IS
v_fec_actual date := pag_cal.fu_obt_fec_actual(2);
v_ano number(4);
v_mes number(2);
v_cod_rubro varchar2(15);
CURSOR UTI is
  SELECT --SUBSTR(COD_RUBRO,1,5)||'XXX'||SUBSTR(COD_RUBRO,9)
         COD_RUBRO, ANO, MES,
         SUM(NVL(SAL_MON_LOC_ANT,0)) SAL_MON_LOC_ANT,
         SUM(NVL(DEB_MON_LOCAL,0)) DEB_MON_LOCAL,
         SUM(NVL(CRE_MON_LOCAL,0)) CRE_MON_LOCAL,
         SUM(NVL(SAL_INI_MES_MON_LOCAL,0)) SAL_INI_MES_MON_LOCAL,
         SUM(NVL(SAL_MON_RUB_ANT,0)) SAL_MON_RUB_ANT,
         SUM(NVL(DEB_MON_RUBRO,0)) DEB_MON_RUBRO,
         SUM(NVL(CRE_MON_RUBRO,0)) CRE_MON_RUBRO,
         SUM(NVL(SAL_INI_MES_MON_RUBRO,0)) SAL_INI_MES_MON_RUBRO,
         SUM(NVL(SAL_EQU_LOC_ANT,0)) SAL_EQU_LOC_ANT,
         SUM(NVL(DEB_EQU_LOCAL,0)) DEB_EQU_LOCAL,
         SUM(NVL(CRE_EQU_LOCAL,0)) CRE_EQU_LOCAL,
         SUM(NVL(SAL_INI_MES_EQU_LOCAL,0)) SAL_INI_MES_EQU_LOCAL
    FROM APE_CB_SAL_OFICINAS
   WHERE ANO = v_ano
     AND MES = v_mes
     AND (sal_mon_loc_ant <> 0
       or deb_mon_local <> 0
       or cre_mon_local <> 0)
     AND SUBSTR(COD_RUBRO,1,8) IN ('31060418','31060422')
   GROUP BY --SUBSTR(COD_RUBRO,1,5)||'XXX'||SUBSTR(COD_RUBRO,9),
         COD_RUBRO,
         ANO, MES;

BEGIN
  /* tomo el año y mes de actual */
  v_ano := to_char(v_fec_actual,'yyyy');
  v_mes := to_char(v_fec_actual,'mm');
  /* borro los registros anteriores */
  DELETE APE_CB_SAL_CONSOLIDADOS
   WHERE ANO = v_ano
     AND MES = v_mes;
  /* copios los saldos por oficina */
  INSERT INTO APE_CB_SAL_CONSOLIDADOS
    (COD_RUBRO, ANO, MES, SAL_MON_LOC_ANT,
     DEB_MON_LOCAL, CRE_MON_LOCAL,
     SAL_INI_MES_MON_LOCAL, SAL_MON_RUB_ANT,
     DEB_MON_RUBRO, CRE_MON_RUBRO, SAL_INI_MES_MON_RUBRO,
     SAL_EQU_LOC_ANT, DEB_EQU_LOCAL, CRE_EQU_LOCAL, SAL_INI_MES_EQU_LOCAL)
  SELECT COD_RUBRO, ANO, MES,
         SUM(NVL(SAL_MON_LOC_ANT,0)),
         SUM(NVL(DEB_MON_LOCAL,0)),
         SUM(NVL(CRE_MON_LOCAL,0)),
         SUM(NVL(SAL_INI_MES_MON_LOCAL,0)),
         SUM(NVL(SAL_MON_RUB_ANT,0)),
         SUM(NVL(DEB_MON_RUBRO,0)),
         SUM(NVL(CRE_MON_RUBRO,0)),
         SUM(NVL(SAL_INI_MES_MON_RUBRO,0)),
         SUM(NVL(SAL_EQU_LOC_ANT,0)),
         SUM(NVL(DEB_EQU_LOCAL,0)),
         SUM(NVL(CRE_EQU_LOCAL,0)),
         SUM(NVL(SAL_INI_MES_EQU_LOCAL,0))
    FROM APE_CB_SAL_OFICINAS
   WHERE ANO = v_ano
     AND MES = v_mes
     AND SUBSTR(COD_RUBRO,1,8) NOT IN ('31060418','31060422')
   GROUP BY COD_RUBRO, ANO, MES;
  /* utilidad */
  FOR I IN UTI LOOP
     /*IF i.sal_mon_loc_ant + i.deb_mon_local - i.cre_mon_local > 0 then
         -- PERDIDA
         V_COD_RUBRO := REPLACE(i.cod_rubro,'XXX','422');
     ELSE
         -- GANANCIA
         V_COD_RUBRO := REPLACE(i.cod_rubro,'XXX','418');
     END IF;*/
     V_COD_RUBRO := i.cod_rubro;
     INSERT INTO APE_CB_SAL_CONSOLIDADOS
      (COD_RUBRO, ANO, MES, SAL_MON_LOC_ANT,
       DEB_MON_LOCAL, CRE_MON_LOCAL,
       SAL_INI_MES_MON_LOCAL, SAL_MON_RUB_ANT,
       DEB_MON_RUBRO, CRE_MON_RUBRO, SAL_INI_MES_MON_RUBRO,
       SAL_EQU_LOC_ANT, DEB_EQU_LOCAL, CRE_EQU_LOCAL, SAL_INI_MES_EQU_LOCAL)
    VALUES
     ( V_COD_RUBRO, V_ANO, V_MES,
       I.SAL_MON_LOC_ANT,
       I.DEB_MON_LOCAL,
       I.CRE_MON_LOCAL,
       I.SAL_INI_MES_MON_LOCAL,
       I.SAL_MON_RUB_ANT,
       I.DEB_MON_RUBRO,
       I.CRE_MON_RUBRO,
       I.SAL_INI_MES_MON_RUBRO,
       I.SAL_EQU_LOC_ANT,
       I.DEB_EQU_LOCAL,
       I.CRE_EQU_LOCAL,
       I.SAL_INI_MES_EQU_LOCAL);
  END LOOP;
END;
/

