CREATE OR REPLACE FORCE VIEW IT.BV_BAL_RUB_HIS AS
SELECT substr(r.cod_rubro,1,2)||substr(r.cod_rubro,3,1)||substr(r.cod_rubro,4,2) as Codigo,
       substr(r.cod_rubro,6,3)||substr(r.cod_rubro,3,1)||substr(r.cod_rubro,9,2) as Cuenta,
       to_number(substr(R.cod_rubro, 1, 2)||substr(R.cod_rubro, 4)||substr(R.cod_rubro, 3, 1)) rub_bt,
       NVL(C.SAL_MON_LOC_ANT, 0)*-1 SAL_ANTERIOR,
       NVL(C.DEB_MON_LOCAL, 0) DEBITO,
       NVL(C.CRE_MON_LOCAL, 0) CREDITO,
       NVL(+NVL(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) -
       NVL(C.CRE_MON_LOCAL, 0),0)*-1 as sal_actual,
       C.FECHA
  FROM BA_MONEDAS B, CB_SAL_CONSOLIDADOS_DIA C, CB_RUBROS R
 WHERE R.COD_RUBRO = C.COD_RUBRO
   AND B.COD_MONEDA = R.COD_MONEDA
   AND C.FECHA = pag_cal.fu_obt_fec_anterior(2)
   and (abs(NVL(C.SAL_MON_LOC_ANT, 0)) <> 0 OR NVL(C.DEB_MON_LOCAL, 0) <> 0 OR
       NVL(C.CRE_MON_LOCAL, 0) <> 0)
   and not exists (select 1
          from cb_rubros t
         where substr(t.cod_rubro, 9, 2) = '01'
           and nivel = 5
           and r.cod_rubro = t.cod_rub_padre)
   and r.nivel = '5'
 order by to_number(substr(R.cod_rubro, 1, 2)||substr(R.cod_rubro, 4)||substr(R.cod_rubro, 3, 1));

