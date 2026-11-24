CREATE OR REPLACE PROCEDURE IT.PRS_GEN_DAT_DIV_PROVISORIO (
    P_ANO IN NUMBER DEFAULT NULL,
    P_MES IN NUMBER DEFAULT NULL
) IS
  v_fecha                  DATE;
  v_ano                    NUMBER;
  v_mes                    NUMBER;
  vg_lugar                 VARCHAR2(100);
  v_mto_145_mon_local      NUMBER(18,2);
  v_mto_145_mon_extranjera NUMBER(18,2);
  v_mto_146_mon_local      NUMBER(18,2);
  v_mto_146_mon_extranjera NUMBER(18,2);

  PROCEDURE lp_car_limites IS
  BEGIN
    SELECT SUM(CASE
                 WHEN SUBSTR(cod_rubro, 1, 2) = '15' AND cod_rubro LIKE '15000%' THEN
                  (ABS(NVL(sal_mon_loc_ant, 0) + NVL(deb_mon_local, 0) -
                       NVL(cre_mon_local, 0)) -
                  ABS(NVL(sal_equ_loc_ant, 0) + NVL(deb_equ_local, 0) -
                       NVL(cre_equ_local, 0)))
               END) * 0.05,
           SUM(CASE
                 WHEN SUBSTR(cod_rubro, 1, 2) = '15' AND cod_rubro LIKE '15000%' THEN
                  ABS(NVL(sal_mon_rub_ant, 0) + NVL(deb_mon_rubro, 0) -
                      NVL(cre_mon_rubro, 0))
               END) * 0.05,
           SUM(CASE
                 WHEN SUBSTR(cod_rubro, 1, 2) = '24' AND cod_rubro LIKE '24000%' THEN
                  (ABS(NVL(sal_mon_loc_ant, 0) + NVL(deb_mon_local, 0) -
                       NVL(cre_mon_local, 0)) -
                  ABS(NVL(sal_equ_loc_ant, 0) + NVL(deb_equ_local, 0) -
                       NVL(cre_equ_local, 0)))
               END) * 0.05,
           SUM(CASE
                 WHEN SUBSTR(cod_rubro, 1, 2) = '24' AND cod_rubro LIKE '24000%' THEN
                  (NVL(sal_mon_rub_ant, 0) + NVL(deb_mon_rubro, 0) -
                  NVL(cre_mon_rubro, 0))
               END) * 0.05
      INTO v_mto_145_mon_local,
           v_mto_145_mon_extranjera,
           v_mto_146_mon_local,
           v_mto_146_mon_extranjera
      FROM cb_sal_consolidados
     WHERE ano = v_ano AND mes = v_mes
       AND (cod_rubro LIKE '15000%' OR cod_rubro LIKE '24000%');
  END;

BEGIN
  -- LÓGICA DE DEFINICIÓN DE AÑO Y MES
  IF P_ANO IS NOT NULL AND P_MES IS NOT NULL THEN
    v_ano := P_ANO;
    v_mes := P_MES;
  ELSE
    -- Si no vienen parámetros cargamos como en la version historica
    SELECT MAX(fecha)
      INTO v_fecha
      FROM (SELECT (TRUNC(pag_cal.FU_OBT_FEC_ACTUAL(3), 'MM') - LEVEL) AS fecha
              FROM DUAL
            CONNECT BY LEVEL <= 7)
     WHERE TO_CHAR(fecha, 'DY', 'NLS_DATE_LANGUAGE = AMERICAN') NOT IN ('SAT', 'SUN')
       AND fecha NOT IN (SELECT fecha FROM ba_feriados);

    -- Extraemos el año y mes de esa fecha encontrada
    v_ano := TO_NUMBER(TO_CHAR(v_fecha, 'YYYY'));
    v_mes := TO_NUMBER(TO_CHAR(v_fecha, 'MM'));
  END IF;

  vg_lugar := 'Calculo de límites';
  lp_car_limites;

  vg_lugar := 'Limpieza sb_diversos';
  DELETE FROM it.sb_diversos WHERE fecha = v_fecha AND provisorio = 'S';

  vg_lugar := 'Insercion a sb_diversos';
  INSERT INTO it.sb_diversos
    (fecha, cod_rubro, descripcion, mto_mon_local, mto_equ_local, provisorio)
    WITH Saldos_Actuales AS
     (SELECT a.cod_rubro,
             SUM(NVL(a.sal_mon_loc_ant, 0) + NVL(a.deb_mon_local, 0) -
                 NVL(a.cre_mon_local, 0)) as mto_local,
             SUM(NVL(a.sal_mon_rub_ant, 0) + NVL(a.deb_mon_rubro, 0) -
                 NVL(a.cre_mon_rubro, 0)) as mto_ext
        FROM cb_sal_consolidados a
       WHERE a.ano = v_ano AND a.mes = v_mes
         AND SUBSTR(a.cod_rubro, 1, 2) IN ('15', '24')
         AND a.cod_rubro NOT IN ('150000000000000', '240000000000000')
       GROUP BY a.cod_rubro)
    SELECT v_fecha,
           r.cod_rubro,
           r.descripcion,
           CASE WHEN r.cod_moneda = 'GS' THEN ABS(sa.mto_local) ELSE 0 END,
           CASE WHEN r.cod_moneda <> 'GS' THEN ABS(sa.mto_local) ELSE 0 END,
           'S'
      FROM cb_rubros r
      JOIN Saldos_Actuales sa ON r.cod_rubro = sa.cod_rubro
     WHERE (sa.mto_local <> 0 OR sa.mto_ext <> 0)
       AND r.imputable = 'S'
       AND EXISTS
     (SELECT 1
              FROM cb_rubros r_padre
              JOIN Saldos_Actuales sa_padre ON r_padre.cod_rubro = sa_padre.cod_rubro
             WHERE r.cod_rub_padre = r_padre.cod_rubro
               AND r_padre.imputable = 'N'
               AND ((SUBSTR(r_padre.cod_rubro, 1, 2) = '15' AND
                   ((r.cod_moneda = 'GS' AND ABS(sa_padre.mto_local) > ABS(v_mto_145_mon_local)) OR
                   (r.cod_moneda <> 'GS' AND ABS(sa_padre.mto_ext) > ABS(v_mto_145_mon_extranjera)))) OR
                   (SUBSTR(r_padre.cod_rubro, 1, 2) = '24' AND
                   ((r.cod_moneda = 'GS' AND ABS(sa_padre.mto_local) > ABS(v_mto_146_mon_local)) OR
                   (r.cod_moneda <> 'GS' AND ABS(sa_padre.mto_ext) > ABS(v_mto_146_mon_extranjera))))));

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20001, 'Error en PRS_GEN_DAT_DIV_PROVISORIO en ' || vg_lugar || ': ' || SQLERRM);
END;
/
