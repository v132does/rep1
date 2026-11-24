CREATE OR REPLACE PROCEDURE IT.PRS_GEN_ANA_LIQ_MEN is
--- Proceso mensual de Generación de Análisis de Liquidez
--- Realizado por BBVA - Ingrid Larraín - 23/08/2011
---
--- Definición de variables de entorno
   v_fec_actual ge_calendarios.fec_actual%type;
   v_cod_mon_local ba_monedas.cod_moneda%type;
   v_cod_mon_fuerte ba_monedas.cod_moneda%type;

  -- Cursor principal de Cartera
  CURSOR c_liq_mensual IS
  SELECT v_fec_actual fecha, (CASE WHEN moneda = 6900 THEN v_cod_mon_local ELSE v_cod_mon_fuerte END) Moneda,
  cuentas, x.descripcion, sum(decode(plazo,'1',monto,0)) plz_vista,
  sum(decode(plazo,'30',monto,0)) men_30_dias,
  sum(decode(plazo,'90',monto,0)) men_90_dias,
  sum(decode(plazo,'180',monto,0)) men_180_dias,
  sum(decode(plazo,'365',monto,0)) men_1_ano,
  sum(decode(plazo,'1095',monto,0)) men_3_anos,
  sum(decode(plazo,'1096',monto,0)) may_3_anos
  FROM cb_rubros x, (
  -- Vista de Inventarios
   SELECT v.moneda,
          substr(cuentas,1,2)||'0000000000000' cuentas,
          (CASE
            WHEN dias <= 0 THEN '1'
            WHEN dias BETWEEN 1   AND 30   THEN '30'
            WHEN dias BETWEEN 31  AND 90   THEN '90'
            WHEN dias BETWEEN 91  AND 180  THEN '180'
            WHEN dias BETWEEN 181 AND 365  THEN '365'
            WHEN dias BETWEEN 366 AND 1095 THEN '1095'
            WHEN dias > 1095 THEN '1096'
          END) plazo,
          nvl(SUM(v.monto), 0) monto
     FROM bv_liq_carteras v
    GROUP BY v.moneda,
             substr(cuentas,1,2)||'0000000000000',
             (CASE
            WHEN dias <= 0 THEN '1'
            WHEN dias BETWEEN 1   AND 30   THEN '30'
            WHEN dias BETWEEN 31  AND 90   THEN '90'
            WHEN dias BETWEEN 91  AND 180  THEN '180'
            WHEN dias BETWEEN 181 AND 365  THEN '365'
            WHEN dias BETWEEN 366 AND 1095 THEN '1095'
            WHEN dias > 1095 THEN '1096'
          END)
  UNION ALL
  -- Saldos contables directos en Moneda Local
  SELECT 6900 moneda, l.cod_rubro cuentas, '1' plazo,
         abs((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) saldo
    FROM cb_sal_consolidados L, CB_RUBROS R
   WHERE r.cod_rubro=l.cod_rubro
     AND r.cod_rubro in('110000000000000','120000000000000','170202950000000')
  UNION ALL
  -- Saldos contables directos en Moneda Extranjera
  SELECT 6100 moneda, l.cod_rubro cuentas, '1' plazo,
         l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro saldo
    FROM cb_sal_consolidados L, CB_RUBROS R
   WHERE r.cod_rubro=l.cod_rubro
     AND r.cod_rubro in('110000000000000','120000000000000','170202950000000')
  ) y
  WHERE x.cod_rubro=y.cuentas
  and y.cuentas not in ('150000000000000') -- Excluir Diversos
  GROUP BY v_fec_actual, (CASE WHEN moneda = 6900 THEN v_cod_mon_local ELSE v_cod_mon_fuerte END), cuentas, x.descripcion
  order by moneda, cuentas;

  -- Variables auxiliares
  v_diferencia sb_liquidez.plz_vista%type;
  -- Recuperar saldos analisis de liquidez y saldos contables
  cursor c_aju_contable is
  select d.cod_rubro, l.cod_moneda, abs((nvl(d.sal_mon_loc_ant,0)+nvl(d.deb_mon_local,0)-nvl(d.cre_mon_local,0))-
             (nvl(d.sal_equ_loc_ant,0)+nvl(d.deb_equ_local,0)-nvl(d.cre_equ_local,0))) sal_contable,
         nvl(l.PLZ_VISTA,0)+nvl(MEN_30_DIAS,0)+nvl(MEN_90_DIAS,0)+nvl(MEN_180_DIAS,0)+
         nvl(MEN_1_ANO,0)+nvl(MEN_3_ANOS,0)+nvl(MAY_3_ANOS,0) sal_liquidez,
         nvl(l.plz_vista,0) plz_vista
    from cb_sal_consolidados d, sb_liquidez l
   where d.cod_rubro = l.cuenta
     and l.cod_moneda=v_cod_mon_local
     and abs((nvl(d.sal_mon_loc_ant,0)+nvl(d.deb_mon_local,0)-nvl(d.cre_mon_local,0))-
             (nvl(d.sal_equ_loc_ant,0)+nvl(d.deb_equ_local,0)-nvl(d.cre_equ_local,0))) <>
        nvl(l.PLZ_VISTA,0)+nvl(MEN_30_DIAS,0)+nvl(MEN_90_DIAS,0)+nvl(MEN_180_DIAS,0)+
        nvl(MEN_1_ANO,0)+nvl(MEN_3_ANOS,0)+nvl(MAY_3_ANOS,0)
  UNION ALL
  select d.cod_rubro, l.cod_moneda, abs(d.sal_mon_rub_ant+d.deb_mon_rubro-d.cre_mon_rubro) sal_contable,
         nvl(l.PLZ_VISTA,0)+nvl(MEN_30_DIAS,0)+nvl(MEN_90_DIAS,0)+nvl(MEN_180_DIAS,0)+
         nvl(MEN_1_ANO,0)+nvl(MEN_3_ANOS,0)+nvl(MAY_3_ANOS,0) sal_liquidez,
         nvl(l.plz_vista,0) plz_vista
    from cb_sal_consolidados d, sb_liquidez l
   where d.cod_rubro = l.cuenta
     and l.cod_moneda <> v_cod_mon_local
     and abs(d.sal_mon_rub_ant+d.deb_mon_rubro-d.cre_mon_rubro) <>
        nvl(l.PLZ_VISTA,0)+nvl(MEN_30_DIAS,0)+nvl(MEN_90_DIAS,0)+nvl(MEN_180_DIAS,0)+
        nvl(MEN_1_ANO,0)+nvl(MEN_3_ANOS,0)+nvl(MAY_3_ANOS,0);
begin
   v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(2);
   pag_cal.PR_OBT_DAT_CALENDAR(2);
   if v_fec_actual = pag_cal.G_ULT_DIA_MES_HABIL then
      --- Solo ejecutar cuando es el último día del mes
       v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
       v_cod_mon_fuerte := pag_gen.FU_OBT_MON_FUERTE;
       delete sb_liquidez z where z.fecha=v_fec_actual;
       -- Insertar Analisis de Liquidez Mensual según Cartera
       FOR reg in c_liq_mensual loop
          insert into sb_liquidez
          ( FECHA,
            COD_MONEDA,
            CUENTA,
            DESCRIPCION,
            PLZ_VISTA,
            MEN_30_DIAS,
            MEN_90_DIAS,
            MEN_180_DIAS,
            MEN_1_ANO,
            MEN_3_ANOS,
            MAY_3_ANOS)
          values
          ( v_fec_actual,
            reg.MONEDA,
            reg.cuentas,
            reg.descripcion,
            reg.plz_vista,
            reg.men_30_dias,
            reg.men_90_dias,
            reg.men_180_dias,
            reg.men_1_ano,
            reg.men_3_anos,
            reg.may_3_anos);
       END LOOP;
       --- Recuperar saldos contables y ajustar a plazo vista
       FOR reg IN c_aju_contable LOOP
          v_diferencia := nvl(reg.sal_contable,0) - nvl(reg.sal_liquidez,0);
          update sb_liquidez
             set plz_vista = plz_vista + v_diferencia
           where cuenta = reg.cod_rubro
             and cod_moneda = reg.cod_moneda;
       END LOOP;
   end if;
end PRS_GEN_ANA_LIQ_MEN;
/

