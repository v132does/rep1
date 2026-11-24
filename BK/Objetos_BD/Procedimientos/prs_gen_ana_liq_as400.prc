CREATE OR REPLACE PROCEDURE IT."PRS_GEN_ANA_LIQ_AS400" is
--- Proceso de Generación de Análisis de Liquidez 6 versiones de As400
--- Realizado por Simgia - Nicolas Andrusky - 14/09/2011
--- Modificado por Simgia - Regina Sosa - 18/01/2013

begin

  --trunca tabla temporal general
  execute immediate 'truncate table sb_ana_liq_tmp_as400';   
  
  --carga tabla temporal general
  insert into sb_ana_liq_tmp_as400 SELECT MONEDA,CUENTAS,decode(cuentas,'140102050200000',monto,decode(tip_saldo,'T',monto,abs(MONTO))) monto,
  CUENTA,DIAS, DIAS_REAL,COD_MODULO,COD_MODALIDAD,COD_PERSONA,'IMPAR'
  --- vista historica de BV_LIQ_CARTERAS
  FROM BV_LIQ_CARTERAS_HIS

    UNION ALL
  --- MESA DE DINERO adicional
  select MONEDA,CUENTAS,decode(cuentas,'140102050200000',monto,decode(tip_saldo,'T',monto,abs(MONTO))) monto,
  CUENTA,DIAS,DIAS DIAS_REAL,COD_MODULO,COD_MODALIDAD,COD_PERSONA,'PAR'
  FROM (
  SELECT decode(c.cod_moneda,'GS',m.cod_mon_bco_central,'6100') moneda,
                      substr(r.cod_rubro,1,2)||'0'||substr(r.cod_rubro,4,7)||'00000' cuentas,
                 (case when c.cod_moneda not in ('GS', 'USD') then
                       FUB_CON_MON_A_MONEDA(c.cod_moneda,'USD',
                       case when c.tip_saldo = 'A' then sal_actual*-1
                       else sal_actual end )
                  else (case when c.tip_saldo = 'A' then sal_actual*-1
                       else sal_actual end)  end) monto,
                 d.nro_cuenta cuenta,
                 a.fec_vencimiento - pag_cal.FU_OBT_FEC_ACTUAL(2) dias,
                 c.cod_modulo,
                 c.cod_modalidad,
                 g.cod_persona,
                 c.tip_saldo
  FROM cb_sal_inventarios_det_his d,
       cb_sal_inventarios_his     c,
       cb_rubros                  r,
       ba_monedas                 m,
       ge_clientes                g,
       ge_cta_clientes            ge,
       md_cta_documentos          a
  WHERE d.nro_referencia = c.nro_referencia
    AND c.cod_rubro = r.cod_rubro
    AND c.cod_moneda = m.cod_moneda
    AND c.cod_modalidad in (101,102,105,106)
    AND c.tip_saldo in ('C', 'A', 'I')  -- Capital, A devengar e Interés
    AND ge.nro_cuenta = d.nro_cuenta
    AND g.cod_persona = ge.cod_persona
    AND nvl(d.sal_actual, 0) != 0
    AND ge.relacion = 'P'
    AND c.cod_rubro IS NOT NULL
    AND d.nro_cuenta = a.nro_cuenta
    AND d.fecha=c.fecha
    AND d.fecha=pag_cal.FU_OBT_FEC_ACTUAL(2)
    ) x;
    
    
    --trunca tablas temporales de informes
    execute immediate 'truncate table sb_ana_liq_inf12';
    execute immediate 'truncate table sb_ana_liq_inf34';
    execute immediate 'truncate table sb_ana_liq_inf56';
    
    -- Genera ANALIQ1
    insert into sb_ana_liq_inf12 SELECT b.moneda,
    b.cuentas, 
    case when abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))) <> 0 then -- Si hay diferencia
          decode(abs(b.monto),b.monto,sum(decode(plazo,'1',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))), -- Si el saldo contable es positivo
                                     (sum(decode(plazo,'1',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))))*-1)
    else -- Si no hay diferencia
       decode(sum(nvl(y.monto,0)),0,nvl(b.monto,0),sum(decode(plazo,'1',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)))
    end plz_vista,
    sum(decode(plazo,'30',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_30_dias,
    sum(decode(plazo,'90',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_90_dias, 
    sum(decode(plazo,'180',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_180_dias,
    sum(decode(plazo,'365',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_1_ano,
    sum(decode(plazo,'1095',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_3_anos,
    sum(decode(plazo,'1096',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) may_3_anos,
    b.monto,
    'ANALIQ1'
    FROM  (
    SELECT v.moneda,
           v.cuentas,
            (CASE
              WHEN dias <= 0 THEN '1'
              WHEN dias BETWEEN 1   AND 30   THEN '30'
              WHEN dias BETWEEN 31  AND 90   THEN '90'
              WHEN dias BETWEEN 91  AND 180  THEN '180'
              WHEN dias BETWEEN 181 AND 365  THEN '365'
              WHEN dias BETWEEN 366 AND 1095 THEN '1095'
              WHEN dias > 1095 THEN '1096'
            END) plazo,
            SUM(nvl(v.monto, 0)) monto
       FROM (
          SELECT MONEDA,CUENTAS,MONTO,
          CUENTA,DIAS,COD_MODULO,COD_MODALIDAD,COD_PERSONA
          FROM sb_ana_liq_tmp_as400 
          WHERE ANALIQ = 'IMPAR'
       )v
       where substr(v.CUENTAS,1,2) not in ('12','17')
       
      GROUP BY v.moneda,
               v.cuentas,
               (CASE
              WHEN dias <= 0 THEN '1'
              WHEN dias BETWEEN 1   AND 30   THEN '30'
              WHEN dias BETWEEN 31  AND 90   THEN '90'
              WHEN dias BETWEEN 91  AND 180  THEN '180'
              WHEN dias BETWEEN 181 AND 365  THEN '365'
              WHEN dias BETWEEN 366 AND 1095 THEN '1095'
              WHEN dias > 1095 THEN '1096'
            END)
            
            ) y, bv_ana_liq_balance b
            WHERE y.cuentas(+)=b.cuentas
            and y.moneda(+)=b.moneda
           -- and b.cuentas='220101560200000'
            and substr(b.cuentas,1,2) not in('12','15','17')-- Excluir Diversos
  group by b.moneda,  b.cuentas, b.monto

  UNION ALL
     --Moneda local
  select 
    h.moneda,
    h.cuentas, 
    sum(decode(plazo,'1',h.monto,0)) plz_vista,
    0 men_30_dias,
    0 men_90_dias, 
    0 men_180_dias,
    0 men_1_ano,
    0 men_3_anos,
    0 may_3_anos,
    h.monto,
    'ANALIQ1'
    from(
       SELECT '6900' moneda,r.cod_rubro cuentas, '1' plazo, 
       ((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
             FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
               where r.cod_rubro=l.cod_rubro and r.nivel=5
               and substr(r.cod_rubro,1,2) IN ('11','12')
       UNION ALL
      ---Moneda Extranjera
      SELECT '6100' moneda,r.cod_rubro cuentas, '1' plazo, 
        (l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro) monto
            FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
               where r.cod_rubro=l.cod_rubro and r.nivel=5
               and substr(r.cod_rubro,1,2) IN ('11','12'))h
  group by h.moneda, h.cuentas,h.monto
  UNION ALL 
  select 
    p.moneda,
    p.cuentas, 
    sum(decode(plazo,'1',p.monto,0)) plz_vista,
    0 men_30_dias,
    0 men_90_dias, 
    0 men_180_dias,
    0 men_1_ano,
    0 men_3_anos,
    0 may_3_anos,
    p.monto,
    'ANALIQ1'
    from( 
   -- Saldos contables directos en Moneda Local
    SELECT '6900' moneda, l.cod_rubro cuentas, '1' plazo,
           abs((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
      FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
     WHERE r.cod_rubro=l.cod_rubro
       AND r.cod_rubro ='170202950000000'
    UNION ALL
    -- Saldos contables directos en Moneda Extranjera
    SELECT '6100' moneda, l.cod_rubro cuentas, '1' plazo,
           l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro monto
      FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
     WHERE r.cod_rubro=l.cod_rubro
       AND r.cod_rubro ='170202950000000') p
     group by p.moneda, p.cuentas,p.monto;
  
    -- Genera ANALIQ2 -----------------------------------------------------------------------------------------------
    
    insert into sb_ana_liq_inf12 SELECT b.moneda,
    b.cuentas, 
    case when abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))) <> 0 then -- Si hay diferencia
          decode(abs(b.monto),b.monto,sum(decode(plazo,'1',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))), -- Si el saldo contable es positivo
                                     (sum(decode(plazo,'1',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))))*-1)
    else -- Si no hay diferencia
       decode(sum(nvl(y.monto,0)),0,nvl(b.monto,0),sum(decode(plazo,'1',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)))
    end plz_vista,
    sum(decode(plazo,'30',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_30_dias,
    sum(decode(plazo,'90',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_90_dias, 
    sum(decode(plazo,'180',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_180_dias,
    sum(decode(plazo,'365',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_1_ano,
    sum(decode(plazo,'1095',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_3_anos,
    sum(decode(plazo,'1096',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) may_3_anos,
    b.monto,
    'ANALIQ2'
    FROM  (
    SELECT v.moneda,
           v.cuentas,
            (CASE
              WHEN dias <= 0 THEN '1'
              WHEN dias BETWEEN 1   AND 30   THEN '30'
              WHEN dias BETWEEN 31  AND 90   THEN '90'
              WHEN dias BETWEEN 91  AND 180  THEN '180'
              WHEN dias BETWEEN 181 AND 365  THEN '365'
              WHEN dias BETWEEN 366 AND 1095 THEN '1095'
              WHEN dias > 1095 THEN '1096'
            END) plazo,
            SUM(nvl(v.monto, 0)) monto
       FROM (
          SELECT MONEDA,CUENTAS,MONTO,
          CUENTA,DIAS_REAL DIAS,COD_MODULO,COD_MODALIDAD,COD_PERSONA          
          FROM sb_ana_liq_tmp_as400
       ) v
       where substr(v.CUENTAS,1,2)<>'17'
       
      GROUP BY v.moneda,
               v.cuentas,
               (CASE
              WHEN dias <= 0 THEN '1'
              WHEN dias BETWEEN 1   AND 30   THEN '30'
              WHEN dias BETWEEN 31  AND 90   THEN '90'
              WHEN dias BETWEEN 91  AND 180  THEN '180'
              WHEN dias BETWEEN 181 AND 365  THEN '365'
              WHEN dias BETWEEN 366 AND 1095 THEN '1095'
              WHEN dias > 1095 THEN '1096'
            END)
            
            ) y, bv_ana_liq_balance b
            WHERE y.cuentas(+)=b.cuentas
            and y.moneda(+)=b.moneda
           -- and b.cuentas='220101560200000'
            and substr(b.cuentas,1,2) not in('15','17')-- Excluir Diversos
  group by b.moneda,  b.cuentas, b.monto

  UNION ALL
     --Moneda local
  select 
    h.moneda,
    h.cuentas, 
    sum(decode(plazo,'1',h.monto,0)) plz_vista,
    0 men_30_dias,
    0 men_90_dias, 
    0 men_180_dias,
    0 men_1_ano,
    0 men_3_anos,
    0 may_3_anos,
    h.monto,
    'ANALIQ2'
    from(
       SELECT '6900' moneda,r.cod_rubro cuentas, '1' plazo, 
       ((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
             FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
               where r.cod_rubro=l.cod_rubro and r.nivel=5
               and substr(r.cod_rubro,1,2) IN ('11')
       UNION ALL
      ---Moneda Extranjera
      SELECT '6100' moneda,r.cod_rubro cuentas, '1' plazo, 
        (l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro) monto
            FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
               where r.cod_rubro=l.cod_rubro and r.nivel=5
               and substr(r.cod_rubro,1,2) IN ('11'))h
  group by h.moneda, h.cuentas,h.monto
  UNION ALL 
  select 
    p.moneda,
    p.cuentas, 
    sum(decode(plazo,'1',p.monto,0)) plz_vista,
    0 men_30_dias,
    0 men_90_dias, 
    0 men_180_dias,
    0 men_1_ano,
    0 men_3_anos,
    0 may_3_anos,
    p.monto,
    'ANALIQ2'
    from( 
   -- Saldos contables directos en Moneda Local
    SELECT '6900' moneda, l.cod_rubro cuentas, '1' plazo,
           abs((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
      FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
     WHERE r.cod_rubro=l.cod_rubro
       AND r.cod_rubro ='170202950000000'
    UNION ALL
    -- Saldos contables directos en Moneda Extranjera
    SELECT '6100' moneda, l.cod_rubro cuentas, '1' plazo,
           l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro monto
      FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
     WHERE r.cod_rubro=l.cod_rubro
       AND r.cod_rubro ='170202950000000') p
     group by p.moneda, p.cuentas,p.monto
     ;
    
    -- Genera ANALIQ3 -----------------------------------------------------------------------------------------------
    
    insert into sb_ana_liq_inf34 SELECT b.moneda,
    b.cuentas, 
    case when abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))) <> 0 then -- Si hay diferencia
          decode(abs(b.monto),b.monto,sum(decode(plazo,'1',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))), -- Si el saldo contable es positivo
                                     (sum(decode(plazo,'1',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))))*-1)
    else -- Si no hay diferencia
       decode(sum(nvl(y.monto,0)),0,nvl(b.monto,0),sum(decode(plazo,'1',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)))
    end plz_vista,
    sum(decode(plazo,'180',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_180_dias,
    sum(decode(plazo,'365',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_365_dias, 
    sum(decode(plazo,'1095',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_3_anos,
    sum(decode(plazo,'1825',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_5_anos,
    sum(decode(plazo,'3650',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_10_anos,
    sum(decode(plazo,'3651',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) may_10_anos,
    b.monto,
    'ANALIQ3'
    FROM  (
    SELECT v.moneda,
           v.cuentas,
           (CASE
              WHEN dias <= 0 THEN '1'
              WHEN dias BETWEEN 1  AND 180  THEN '180'
              WHEN dias BETWEEN 181 AND 365  THEN '365'
              WHEN dias BETWEEN 366 AND 1095 THEN '1095'
              WHEN dias BETWEEN 1096 AND 1825 THEN '1825'
              WHEN dias BETWEEN 1826 AND 3650 THEN '3650'
              WHEN dias > 3650 THEN '3651'
            END) plazo,
            SUM(nvl(v.monto, 0)) monto
       FROM (
          SELECT MONEDA,CUENTAS,MONTO,
          CUENTA,DIAS,COD_MODULO,COD_MODALIDAD,COD_PERSONA
          FROM sb_ana_liq_tmp_as400
          WHERE ANALIQ = 'IMPAR'
       ) v
       where substr(v.CUENTAS,1,2) not in ('12','17')
       
      GROUP BY v.moneda,
               v.cuentas,
               (CASE
              WHEN dias <= 0 THEN '1'
              WHEN dias BETWEEN 1  AND 180  THEN '180'
              WHEN dias BETWEEN 181 AND 365  THEN '365'
              WHEN dias BETWEEN 366 AND 1095 THEN '1095'
              WHEN dias BETWEEN 1096 AND 1825 THEN '1825'
              WHEN dias BETWEEN 1826 AND 3650 THEN '3650'
              WHEN dias > 3650 THEN '3651'
            END)
            
            ) y, bv_ana_liq_balance b
            WHERE y.cuentas(+)=b.cuentas
            and y.moneda(+)=b.moneda
           -- and b.cuentas='220101560200000'
            and substr(b.cuentas,1,2) not in('12','15','17')-- Excluir Diversos
  group by b.moneda,  b.cuentas, b.monto

  UNION ALL
     --Moneda local
  select 
    h.moneda,
    h.cuentas, 
    sum(decode(plazo,'1',h.monto,0)) plz_vista,
    0 ,
    0 , 
    0 ,
    0 ,
    0 ,
    0 ,
    h.monto,
    'ANALIQ3'
    from(
       SELECT '6900' moneda,r.cod_rubro cuentas, '1' plazo, 
       ((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
             FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
               where r.cod_rubro=l.cod_rubro and r.nivel=5
               and substr(r.cod_rubro,1,2) IN ('11','12')
       UNION ALL
      ---Moneda Extranjera
      SELECT '6100' moneda,r.cod_rubro cuentas, '1' plazo, 
        (l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro) monto
            FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
               where r.cod_rubro=l.cod_rubro and r.nivel=5
               and substr(r.cod_rubro,1,2) IN ('11','12'))h
  group by h.moneda, h.cuentas,h.monto
  UNION ALL 
  select 
    p.moneda,
    p.cuentas, 
    sum(decode(plazo,'1',p.monto,0)) plz_vista,
    0 ,
    0 , 
    0 ,
    0 ,
    0 ,
    0 ,
    p.monto,
    'ANALIQ3'
    from( 
   -- Saldos contables directos en Moneda Local
    SELECT '6900' moneda, l.cod_rubro cuentas, '1' plazo,
           abs((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
      FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
     WHERE r.cod_rubro=l.cod_rubro
       AND r.cod_rubro ='170202950000000'
    UNION ALL
    -- Saldos contables directos en Moneda Extranjera
    SELECT '6100' moneda, l.cod_rubro cuentas, '1' plazo,
           l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro monto
      FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
     WHERE r.cod_rubro=l.cod_rubro
       AND r.cod_rubro ='170202950000000'
       ) p
     group by p.moneda, p.cuentas,p.monto
     ;
    
    -- Genera ANALIQ4 -----------------------------------------------------------------------------------------------
    
    insert into sb_ana_liq_inf34 SELECT b.moneda,
    b.cuentas, 
    case when abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))) <> 0 then -- Si hay diferencia
          decode(abs(b.monto),b.monto,sum(decode(plazo,'1',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))), -- Si el saldo contable es positivo
                                     (sum(decode(plazo,'1',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))))*-1)
    else -- Si no hay diferencia
       decode(sum(nvl(y.monto,0)),0,nvl(b.monto,0),sum(decode(plazo,'1',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)))
    end plz_vista,
    sum(decode(plazo,'180',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_180_dias,
    sum(decode(plazo,'365',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_365_dias, 
    sum(decode(plazo,'1095',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_3_anos,
    sum(decode(plazo,'1825',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_5_anos,
    sum(decode(plazo,'3650',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_10_anos,
    sum(decode(plazo,'3651',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) may_10_anos,
    b.monto,
    'ANALIQ4'
    FROM  (
    SELECT v.moneda,
           v.cuentas,
           (CASE
              WHEN dias <= 0 THEN '1'
              WHEN dias BETWEEN 1  AND 180  THEN '180'
              WHEN dias BETWEEN 181 AND 365  THEN '365'
              WHEN dias BETWEEN 366 AND 1095 THEN '1095'
              WHEN dias BETWEEN 1096 AND 1825 THEN '1825'
              WHEN dias BETWEEN 1826 AND 3650 THEN '3650'
              WHEN dias > 3650 THEN '3651'
            END) plazo,
            SUM(nvl(v.monto, 0)) monto
       FROM (
          SELECT MONEDA,CUENTAS,MONTO,
          CUENTA,DIAS_REAL DIAS,COD_MODULO,COD_MODALIDAD,COD_PERSONA          
          FROM sb_ana_liq_tmp_as400
       ) v
       where substr(v.CUENTAS,1,2)<>'17'
       
      GROUP BY v.moneda,
               v.cuentas,
               (CASE
              WHEN dias <= 0 THEN '1'
              WHEN dias BETWEEN 1  AND 180  THEN '180'
              WHEN dias BETWEEN 181 AND 365  THEN '365'
              WHEN dias BETWEEN 366 AND 1095 THEN '1095'
              WHEN dias BETWEEN 1096 AND 1825 THEN '1825'
              WHEN dias BETWEEN 1826 AND 3650 THEN '3650'
              WHEN dias > 3650 THEN '3651'
            END)
            
            ) y, bv_ana_liq_balance b
            WHERE y.cuentas(+)=b.cuentas
            and y.moneda(+)=b.moneda
           -- and b.cuentas='220101560200000'
            and substr(b.cuentas,1,2) not in('15','17')-- Excluir Diversos
  group by b.moneda,  b.cuentas, b.monto

  UNION ALL
     --Moneda local
  select 
    h.moneda,
    h.cuentas, 
    sum(decode(plazo,'1',h.monto,0)) plz_vista,
    0 ,
    0 , 
    0 ,
    0 ,
    0 ,
    0 ,
    h.monto,
    'ANALIQ4'
    from(
       SELECT '6900' moneda,r.cod_rubro cuentas, '1' plazo, 
       ((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
             FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
               where r.cod_rubro=l.cod_rubro and r.nivel=5
               and substr(r.cod_rubro,1,2) IN ('11')
       UNION ALL
      ---Moneda Extranjera
      SELECT '6100' moneda,r.cod_rubro cuentas, '1' plazo, 
        (l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro) monto
            FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
               where r.cod_rubro=l.cod_rubro and r.nivel=5
               and substr(r.cod_rubro,1,2) IN ('11'))h
  group by h.moneda, h.cuentas,h.monto
  UNION ALL 
  select 
    p.moneda,
    p.cuentas, 
    sum(decode(plazo,'1',p.monto,0)) plz_vista,
    0 ,
    0 , 
    0 ,
    0 ,
    0 ,
    0 ,
    p.monto,
    'ANALIQ4'
    from( 
   -- Saldos contables directos en Moneda Local
    SELECT '6900' moneda, l.cod_rubro cuentas, '1' plazo,
           abs((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
      FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
     WHERE r.cod_rubro=l.cod_rubro
       AND r.cod_rubro ='170202950000000'
    UNION ALL
    -- Saldos contables directos en Moneda Extranjera
    SELECT '6100' moneda, l.cod_rubro cuentas, '1' plazo,
           l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro monto
      FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
     WHERE r.cod_rubro=l.cod_rubro
       AND r.cod_rubro ='170202950000000') p
     group by p.moneda, p.cuentas,p.monto
     ;

    -- Genera ANALIQ5 -----------------------------------------------------------------------------------------------
    
    insert into sb_ana_liq_inf56 SELECT b.moneda,
    b.cuentas, 
    case when abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))) <> 0 then -- Si hay diferencia
          decode(abs(b.monto),b.monto,sum(decode(plazo,'7',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))), -- Si el saldo contable es positivo
                                     (sum(decode(plazo,'7',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))))*-1)
    else -- Si no hay diferencia
       decode(sum(nvl(y.monto,0)),0,nvl(b.monto,0),sum(decode(plazo,'7',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)))
    end men_7_dias,
    sum(decode(plazo,'30',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_30_dias,
    sum(decode(plazo,'60',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_60_dias, 
    sum(decode(plazo,'90',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_90_dias,
    sum(decode(plazo,'91',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) may_90_dias,
    b.monto,
    'ANALIQ5'
    FROM  (
    SELECT v.moneda,
           v.cuentas,
           (CASE
              WHEN dias <= 0 or dias BETWEEN 1  AND 7 THEN '7'
              WHEN dias BETWEEN 8 AND 30  THEN '30'
              WHEN dias BETWEEN 31 AND 60 THEN '60'
              WHEN dias BETWEEN 61 AND 90 THEN '90'
              WHEN dias > 90 THEN '91'
            END) plazo,
            SUM(nvl(v.monto, 0)) monto
       FROM (
          SELECT MONEDA,CUENTAS,MONTO,
          CUENTA,DIAS,COD_MODULO,COD_MODALIDAD,COD_PERSONA
          FROM sb_ana_liq_tmp_as400
          WHERE ANALIQ = 'IMPAR'
       ) v
       where substr(v.CUENTAS,1,2) not in ('12','17')
       
      GROUP BY v.moneda,
               v.cuentas,
                (CASE
              WHEN dias <= 0 or dias BETWEEN 1  AND 7 THEN '7'
              WHEN dias BETWEEN 8 AND 30  THEN '30'
              WHEN dias BETWEEN 31 AND 60 THEN '60'
              WHEN dias BETWEEN 61 AND 90 THEN '90'
              WHEN dias > 90 THEN '91'
            END)
            
            ) y, bv_ana_liq_balance b
            WHERE y.cuentas(+)=b.cuentas
            and y.moneda(+)=b.moneda
           -- and b.cuentas='220101560200000'
            and substr(b.cuentas,1,2) not in('12','15','17')-- Excluir Diversos
  group by b.moneda,  b.cuentas, b.monto

  UNION ALL
     --Moneda local
  select 
    h.moneda,
    h.cuentas, 
    sum(decode(plazo,'1',h.monto,0)) ,
    0 ,
    0 , 
    0 ,
    0,
    h.monto,
    'ANALIQ5'
    from(
       SELECT '6900' moneda,r.cod_rubro cuentas, '1' plazo, 
       ((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
             FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
               where r.cod_rubro=l.cod_rubro and r.nivel=5
               and substr(r.cod_rubro,1,2) IN ('11','12')
       UNION ALL
      ---Moneda Extranjera
      SELECT '6100' moneda,r.cod_rubro cuentas, '1' plazo, 
        (l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro) monto
            FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
               where r.cod_rubro=l.cod_rubro and r.nivel=5
               and substr(r.cod_rubro,1,2) IN ('11','12'))h
  group by h.moneda, h.cuentas,h.monto
  UNION ALL 
  select 
    p.moneda,
    p.cuentas, 
    sum(decode(plazo,'1',p.monto,0)) ,
    0 ,
    0 , 
    0 ,
    0,
    p.monto,
    'ANALIQ5'
    from( 
   -- Saldos contables directos en Moneda Local
    SELECT '6900' moneda, l.cod_rubro cuentas, '1' plazo,
           abs((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
      FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
     WHERE r.cod_rubro=l.cod_rubro
       AND r.cod_rubro ='170202950000000'
    UNION ALL
    -- Saldos contables directos en Moneda Extranjera
    SELECT '6100' moneda, l.cod_rubro cuentas, '1' plazo,
           l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro monto
      FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
     WHERE r.cod_rubro=l.cod_rubro
       AND r.cod_rubro ='170202950000000'
       ) p
     group by p.moneda, p.cuentas,p.monto
     ;
     
     -- Genera ANALIQ6 -----------------------------------------------------------------------------------------------
    
     insert into sb_ana_liq_inf56 SELECT b.moneda,
      b.cuentas, 
      case when abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))) <> 0 then -- Si hay diferencia
            decode(abs(b.monto),b.monto,sum(decode(plazo,'7',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))), -- Si el saldo contable es positivo
                                       (sum(decode(plazo,'7',y.monto,0))+abs(nvl(b.monto,0))-abs(sum(nvl(y.monto,0))))*-1)
      else -- Si no hay diferencia
         decode(sum(nvl(y.monto,0)),0,nvl(b.monto,0),sum(decode(plazo,'7',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)))
      end men_7_dias,
      sum(decode(plazo,'30',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_30_dias,
      sum(decode(plazo,'60',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_60_dias, 
      sum(decode(plazo,'90',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) men_90_dias,
      sum(decode(plazo,'91',decode(abs(b.monto),b.monto,nvl(y.monto,0),nvl(y.monto,0)*-1),0)) may_90_dias,
      b.monto,
      'ANALIQ6'
      FROM  (
      SELECT v.moneda,
             v.cuentas,
             (CASE
                WHEN dias <= 0 or dias BETWEEN 1  AND 7 THEN '7'
                WHEN dias BETWEEN 8 AND 30  THEN '30'
                WHEN dias BETWEEN 31 AND 60 THEN '60'
                WHEN dias BETWEEN 61 AND 90 THEN '90'
                WHEN dias > 90 THEN '91'
              END) plazo,
              SUM(nvl(v.monto, 0)) monto
         FROM  (
          SELECT MONEDA,CUENTAS,MONTO,
          CUENTA,DIAS_REAL DIAS,COD_MODULO,COD_MODALIDAD,COD_PERSONA          
          FROM sb_ana_liq_tmp_as400
          ) v
         where substr(v.CUENTAS,1,2)<>'17'
         
        GROUP BY v.moneda,
                 v.cuentas,
                  (CASE
                WHEN dias <= 0 or dias BETWEEN 1  AND 7 THEN '7'
                WHEN dias BETWEEN 8 AND 30  THEN '30'
                WHEN dias BETWEEN 31 AND 60 THEN '60'
                WHEN dias BETWEEN 61 AND 90 THEN '90'
                WHEN dias > 90 THEN '91'
              END)
              
              ) y, bv_ana_liq_balance b
              WHERE y.cuentas(+)=b.cuentas
              and y.moneda(+)=b.moneda
             -- and b.cuentas='220101560200000'
              and substr(b.cuentas,1,2) not in('15','17')-- Excluir Diversos
    group by b.moneda,  b.cuentas, b.monto

    UNION ALL
       --Moneda local
    select 
      h.moneda,
      h.cuentas, 
      sum(decode(plazo,'1',h.monto,0)) ,
      0 ,
      0 , 
      0 ,
      0,
      h.monto,
      'ANALIQ6'
      from(
         SELECT '6900' moneda,r.cod_rubro cuentas, '1' plazo, 
         ((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
               FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
                 where r.cod_rubro=l.cod_rubro and r.nivel=5
                 and substr(r.cod_rubro,1,2) IN ('11')
         UNION ALL
        ---Moneda Extranjera
        SELECT '6100' moneda,r.cod_rubro cuentas, '1' plazo, 
          (l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro) monto
              FROM CB_SAL_CONSOLIDADOS L, cb_rubros r
                 where r.cod_rubro=l.cod_rubro and r.nivel=5
                 and substr(r.cod_rubro,1,2) IN ('11'))h
    group by h.moneda, h.cuentas,h.monto
    UNION ALL 
    select 
      p.moneda,
      p.cuentas, 
      sum(decode(plazo,'1',p.monto,0)) ,
      0 ,
      0 , 
      0 ,
      0,
      p.monto,
      'ANALIQ6'
      from( 
     -- Saldos contables directos en Moneda Local
      SELECT '6900' moneda, l.cod_rubro cuentas, '1' plazo,
             abs((l.sal_mon_loc_ant+l.deb_mon_local-l.cre_mon_local)-(l.sal_equ_loc_ant+l.deb_equ_local-l.cre_equ_local)) monto
        FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
       WHERE r.cod_rubro=l.cod_rubro
         AND r.cod_rubro ='170202950000000'
      UNION ALL
      -- Saldos contables directos en Moneda Extranjera
      SELECT '6100' moneda, l.cod_rubro cuentas, '1' plazo,
             l.sal_mon_rub_ant+l.deb_mon_rubro-l.cre_mon_rubro monto
        FROM CB_SAL_CONSOLIDADOS L, CB_RUBROS R
       WHERE r.cod_rubro=l.cod_rubro
         AND r.cod_rubro ='170202950000000'
         ) p
       group by p.moneda, p.cuentas,p.monto
       ;
       pa_rep_aut.pr_analiq1;
       pa_rep_aut.pr_analiq2;
       pa_rep_aut.pr_analiq3;
       pa_rep_aut.pr_analiq4;
       pa_rep_aut.pr_analiq5;
       pa_rep_aut.pr_analiq6;
       -- para consultar informes
       -- select * from sb_ana_liq_inf12 t where t.informe='ANALIQ1' order by t.cuentas, t.moneda;
       -- select * from sb_ana_liq_inf12 t where t.informe='ANALIQ2' order by t.cuentas, t.moneda;
       -- select * from sb_ana_liq_inf34 t where t.informe='ANALIQ3' order by t.cuentas, t.moneda;
       -- select * from sb_ana_liq_inf34 t where t.informe='ANALIQ4' order by t.cuentas, t.moneda;
       -- select * from sb_ana_liq_inf56 t where t.informe='ANALIQ5' order by t.cuentas, t.moneda;
       -- select * from sb_ana_liq_inf56 t where t.informe='ANALIQ6' order by t.cuentas, t.moneda;
       
end PRS_GEN_ANA_LIQ_AS400;
/

