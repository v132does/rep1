CREATE OR REPLACE FORCE VIEW IT.SV_CIR_236 AS
SELECT 1 as codigo,
         0 as monto_mn
       from dual
UNION ALL
SELECT 2 as codigo,
       0 as monto_mn
     from dual
UNION ALL
SELECT 3 as codigo,
    to_number(nvl(fug_obt_pardinamico('RES_AUDITADO'),0)) as monto_mn
    from dual

UNION ALL
    SELECT 4 as codigo,
         0 as monto_mn
       from dual
UNION ALL
  SELECT 5 as codigo,
         0 as monto_mn
       from dual
union all
 select  6 as codigo,
    nvl(round(-1 * (sum((NVL(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL,0)))  )),0) as monto_mn

    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
    and cod_rubro = '310500000000000'
UNION ALL
SELECT 7 as codigo,
             COUNT(distinct c.cod_persona) monto_mn
     FROM ge_cla_operaciones c, ba_per_dat_adicionales s, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND substr(p.cod_rub_primario, 1, 3)  = '011'--Agricultura
UNION ALL
SELECT   8 as codigo,
         COUNT(distinct c.cod_persona) monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND substr(p.cod_rub_primario, 1, 3)  = '012'--Ganaderia
UNION ALL
SELECT      9 as codigo,
            COUNT(distinct c.cod_persona) monto_mn
 FROM ge_cla_operaciones c,  ba_per_dat_adicionales s, pr_rub_economicos rb, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and s.cod_persona = c.cod_persona
           and c.cod_persona = p.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND p.cod_rub_primario = rb.cod_rub_economico
           AND rb.cod_rub_eco_padre = 'D'--Industrias
UNION ALL
SELECT   10 as codigo,
          COUNT(distinct c.cod_persona) monto_Mn
 FROM ge_cla_operaciones c, ba_per_dat_adicionales s, pr_rub_economicos rb, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and s.cod_persona = c.cod_persona
           and c.cod_persona = p.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND p.cod_rub_primario = rb.cod_rub_economico
           AND rb.cod_rub_eco_padre = 'F'--Construccion
UNION ALL
SELECT     11 as codigo,
           COUNT(distinct c.cod_persona) monto_mn
 FROM ge_cla_operaciones c,  ba_per_dat_adicionales s, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND substr(p.cod_rub_primario, 1, 2)  = '51'--Comercio al por mayor
UNION ALL
SELECT     12 as codigo,
          COUNT(distinct c.cod_persona) monto_mn
 FROM ge_cla_operaciones c, ba_per_dat_adicionales s, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and s.cod_persona = c.cod_persona
           and c.cod_persona = p.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND substr(p.cod_rub_primario, 1, 2)  = '52'--Comercio al por menor
UNION ALL
SELECT     13 as codigo,
          COUNT(distinct c.cod_persona) monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s, pr_rub_economicos rb, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND p.cod_rub_primario = rb.cod_rub_economico
           AND (rb.cod_rub_eco_padre IN ('H','I') or (instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_13'), p.cod_rub_primario) > 0)) --Servicios
UNION ALL
SELECT     14 as codigo,
           COUNT(distinct c.cod_persona) monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND substr(p.cod_rub_primario, 1, 4)  = '9701'--consumo

UNION ALL
SELECT     15 as codigo,
           COUNT(distinct c.cod_persona) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND substr(p.cod_rub_primario, 1, 4)  = '9700'--vivienda
UNION ALL
SELECT     16 as codigo,
           COUNT(distinct ge.cod_persona)  monto_mn
 FROM ge_cla_operaciones c,  ge_cta_clientes ge, ba_per_dat_adicionales s, pr_rub_economicos rb, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and ge.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND p.cod_rub_primario = rb.cod_rub_economico
           AND rb.cod_rub_eco_padre = 'J' --Intermediacion Financiera

UNION ALL
SELECT     17 as codigo,
            COUNT(distinct ge.cod_persona) monto_mn
 FROM ge_cla_operaciones c,  ge_cta_clientes ge, ba_per_dat_adicionales s, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and ge.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND substr(p.cod_rub_primario, 1,3)  in ('013','014') --Agribusiness

UNION ALL
SELECT     18 as codigo,
           COUNT(distinct ge.cod_persona) monto_mn
 FROM ge_cla_operaciones c, ge_cta_clientes ge, ba_per_dat_adicionales s, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and ge.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_18'), p.cod_rub_primario) > 0--vehiculos

UNION ALL
SELECT     19 as codigo,
           COUNT(distinct ge.cod_persona)  monto_mn
 FROM ge_cla_operaciones c, ge_cta_clientes ge, ba_per_dat_adicionales s, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and ge.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND substr(p.cod_rub_primario, 1,2) in ('72','73','74')--servicios personales

UNION ALL
SELECT     20 as codigo,
           COUNT(distinct c.cod_persona) monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s, pr_rub_economicos rb, ba_personas p
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_persona = p.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND p.cod_rub_primario = rb.cod_rub_economico
           AND not  (substr(p.cod_rub_primario, 1,2) in ('72','73','74')--servicios personales
         or    instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_18'), p.cod_rub_primario) > 0--vehiculos
         or    substr(p.cod_rub_primario, 1,3)  in ('013','014') --Agribusiness
         or    rb.cod_rub_eco_padre = 'J' --Intermediacion Financiera
         or substr(p.cod_rub_primario, 1, 4)  = '9701' --consumo
         or    substr(p.cod_rub_primario, 1, 4)  = '9700'--vivienda
         or    rb.cod_rub_eco_padre IN ('H','I') --Servicios
         or  instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_13'), p.cod_rub_primario) > 0
         or    substr(p.cod_rub_primario, 1, 2)  = '52'--Comercio al por menor
         or  substr(p.cod_rub_primario, 1, 2)  = '51'--Comercio al por mayor
         or  rb.cod_rub_eco_padre = 'F'--Construccion
         or  rb.cod_rub_eco_padre = 'D'--Industrias
         or  substr(p.cod_rub_primario, 1, 3)  = '012'--Ganaderia
         or  substr(p.cod_rub_primario, 1, 3)  = '011') --Agricultura)

UNION ALL
SELECT   21 as codigo,
         COUNT(distinct c.cod_persona) monto_mn
   FROM ge_cla_operaciones c, ge_cta_clientes ge, ba_per_fisicas fi,  ba_per_dat_adicionales s
   WHERE s.val_parametro = 'S'
   AND s.parametro = 'EMP_NO_GENERADORA'
   AND ge.cod_persona = s.cod_persona
   AND ge.nro_cuenta = c.nro_cuenta
   AND ge.relacion = 'P'
   AND c.cod_moneda <> pag_gen.fu_obt_mon_local
   AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
   AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
   AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
   AND c.cod_modulo in (5,6)
   AND ge.cod_persona = fi.cod_persona

UNION ALL
SELECT   22 as codigo,
         COUNT(distinct c.cod_persona) monto_mn
   FROM ge_cla_operaciones c, ge_cta_clientes ge, ba_per_juridicas ju,  ba_per_dat_adicionales s
   WHERE s.val_parametro = 'S'
   AND s.parametro = 'EMP_NO_GENERADORA'
   AND ge.cod_persona = s.cod_persona
   AND ge.nro_cuenta = c.nro_cuenta
   AND ge.relacion = 'P'
   AND c.cod_moneda <> pag_gen.fu_obt_mon_local
   AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
   AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
   AND nvl(fup_obt_tip_bono(c.cod_modalidad),'N') = 'N'
   AND c.cod_modulo in (5,6)
   AND ge.cod_persona = ju.cod_persona
UNION ALL
SELECT codigo, SUM(monto_mn)
  FROM (SELECT 23 AS codigo, COUNT(DISTINCT c.cod_persona) monto_mn
          FROM ge_cla_operaciones c, ge_clientes s
         WHERE /*s.tipo IN ('N', 'R') --vinculados
           and c.cod_sec_credito not in (702, 703)*/
           c.cod_persona = s.cod_persona
           AND c.cod_modulo IN (5, 6)
           AND s.cod_gru_economico =  fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD')
           AND nvl(fup_obt_tip_letra(c.cod_modalidad), 'N') = 'N'
           AND nvl(fup_obt_tip_afd_vivienda(c.cod_modalidad), 'N') = 'N'
           AND nvl(fup_obt_tip_bono(c.cod_modalidad), 'N') = 'N'
        UNION ALL
        SELECT DISTINCT 23 AS codigo, 1 AS monto_mn --siempre es la entidad
          FROM cc_che_enviados c, lc_che_comprados g
         WHERE c.nro_cheque = g.nro_cheque(+)
           AND c.cod_banco = g.cod_banco(+)
           AND (c.fecha >= to_date(fug_obt_pardinamico('FEC_IMP_RUB_CHE_COM'), 'dd/mm/yyyy') AND
               pag_gen.fu_obt_cod_entidad = 2036)
           AND c.nro_cuenta IS NULL
           AND c.estado = 'I')
 GROUP BY codigo
UNION ALL
SELECT 24 AS codigo, COUNT(DISTINCT c.cod_persona) monto_mn
  FROM ge_cla_operaciones c, ge_clientes s --grandes deudores
 WHERE c.cod_persona = s.cod_persona
   AND (c.cod_modulo IN (5, 6) OR (c.cod_modulo = 10 AND c.cod_modalidad = 114))
   AND nvl(fup_obt_tip_letra(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_afd_vivienda(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_bono(c.cod_modalidad), 'N') = 'N'
   AND s.tipo IN ('G','M','R')

UNION ALL

SELECT 25 AS codigo, COUNT(DISTINCT ge.cod_persona) monto_mn
  FROM ge_cla_operaciones c, ge_cta_clientes ge, ge_clientes s
 WHERE ge.cod_persona = s.cod_persona
   AND ge.cod_persona = s.cod_persona
   AND ge.nro_cuenta = c.nro_cuenta
   AND ge.relacion = 'P'
   AND c.cod_modulo IN (5, 6)
   AND nvl(fup_obt_tip_letra(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_afd_vivienda(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_bono(c.cod_modalidad), 'N') = 'N'
   and s.tipo = 'T'--> microcreditos
   --AND (c.tip_destino <> 4 or c.tip_destino is null) se comenta

UNION ALL
SELECT    26 as codigo,
          COUNT(distinct ge.cod_persona) monto_mn
 FROM GE_cla_operaciones c,   ge_cta_clientes ge, ge_clientes s
           where ge.cod_persona = s.cod_persona
           and ge.cod_persona = s.cod_persona
           and ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5, 6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           and s.tipo IN('N','C')  -->pymes no vinculados
           and c.cod_sec_credito not in (702, 703)

 union all
SELECT 27 as codigo,
            nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c,  ge_cta_clientes ge ,  ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and ge.cod_persona = s.cod_persona
           and ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5, 6)
            AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND substr(c.cod_rub_economico, 1, 3)  = '011'--Agricultura
 UNION ALL
SELECT    28 as codigo,
             nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c,    ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
            and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5, 6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND substr(c.cod_rub_economico, 1, 3)  = '012'--Ganaderia
UNION ALL
SELECT    29 as codigo,
             nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c,    pr_rub_economicos rb, ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND c.cod_rub_economico = rb.cod_rub_economico
           AND rb.cod_rub_eco_padre = 'D'--Industrias
           AND substr(c.cod_rub_economico, 1, 1)  = substr(rb.cod_rub_economico,1,1)

UNION ALL
SELECT     30 as codigo,
               nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   pr_rub_economicos rb, ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND c.cod_rub_economico = rb.cod_rub_economico
           AND rb.cod_rub_eco_padre = 'F'--Construccion
             AND substr(c.cod_rub_economico, 1, 1)  = substr(rb.cod_rub_economico,1,1)

UNION ALL
SELECT     31 as codigo,
         nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c,  ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND substr(c.cod_rub_economico, 1, 2)  = '51'--Comercio al por mayor
UNION ALL
SELECT     32 as codigo,
          nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c, ge_cta_clientes ge ,  ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and ge.cod_persona = s.cod_persona
           and ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND substr(c.cod_rub_economico, 1, 2)  = '52'--Comercio al por menor

UNION ALL
SELECT     33 as codigo,
       nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s,  pr_rub_economicos rb
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND c.cod_rub_economico = rb.cod_rub_economico
           AND (rb.cod_rub_eco_padre IN ('H','I') or (instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_13'), c.cod_rub_economico) > 0)) --Servicios

UNION ALL
SELECT     34 as codigo,
         nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c,    ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND substr(c.cod_rub_economico, 1, 4)  = '9701'--consumo

UNION ALL
SELECT     35 as codigo,
      nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND substr(c.cod_rub_economico, 1, 4)  = '9700'--vivienda

UNION ALL
SELECT     36 as codigo,
       nvl(round(SUM((nvl(c.tot_deu_real, 0) ) )  ),0) as monto_mn
 FROM ge_cla_operaciones c,    ba_per_dat_adicionales s,  pr_rub_economicos rb
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and s.cod_persona = c.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND c.cod_rub_economico = rb.cod_rub_economico
           AND rb.cod_rub_eco_padre = 'J' --Intermediacion Financiera

UNION ALL
SELECT     37 as codigo,
      nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c,    ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND substr(c.cod_rub_economico, 1,3)  in ('013','014') --Agribusiness
UNION ALL
SELECT    38 as codigo,
       nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,  ge_cta_clientes ge ,  ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and ge.cod_persona = s.cod_persona
           and ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_18'), c.cod_rub_economico) > 0--vehiculos
UNION ALL
SELECT     39 as codigo,
    nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,    ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND substr(c.cod_rub_economico, 1,2) in ('72','73','74')--servicios personales
UNION ALL
SELECT    40 as codigo,
         nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s, pr_rub_economicos rb
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_rub_economico  = rb.cod_rub_economico
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
        AND c.cod_rub_economico = rb.cod_rub_economico
        AND not  (substr(c.cod_rub_economico, 1,2) in ('72','73','74')--servicios personales
         or    instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_18'), c.cod_rub_economico) > 0--vehiculos
         or    substr(c.cod_rub_economico, 1,3)  in ('013','014') --Agribusiness
         or    rb.cod_rub_eco_padre = 'J' --Intermediacion Financiera
         or   substr(c.cod_rub_economico, 1, 4)  = '9701' --consumo
         or    substr(c.cod_rub_economico, 1, 4)  = '9700'--vivienda
         or    rb.cod_rub_eco_padre IN ('H','I') --Servicios
         or  instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_13'), c.cod_rub_economico) > 0
         or    substr(c.cod_rub_economico, 1, 2)  = '52'--Comercio al por menor
         or  substr(c.cod_rub_economico, 1, 2)  = '51'--Comercio al por mayor
         or  rb.cod_rub_eco_padre = 'F'--Construccion
         or  rb.cod_rub_eco_padre = 'D'--Industrias
         or  substr(c.cod_rub_economico, 1, 3)  = '012'--Ganaderia
         or  substr(c.cod_rub_economico, 1, 3)  = '011'--Agricultura
         )
UNION ALL
SELECT   41 as codigo,
        nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,    ba_per_dat_adicionales s,  ba_personas ba
           where s.parametro = 'EMP_NO_GENERADORA'
           AND s.val_parametro = 'S'
           and c.cod_persona = s.cod_persona
           and s.cod_persona = ba.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND ba.tipo ='F'
UNION ALL
SELECT     42 as codigo,
     nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,    ba_per_dat_adicionales s,  ba_personas ba
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and s.cod_persona = ba.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           AND ba.tipo ='J'
UNION ALL
SELECT codigo, SUM(monto_mn)
  FROM (SELECT 43 AS codigo, nvl(round(SUM((nvl(c.tot_deu_real, 0)))), 0) AS monto_mn
          FROM ge_cla_operaciones c, ge_clientes s
         WHERE c.cod_modulo IN (5, 6)
           AND c.cod_persona = s.cod_persona
           --AND s.tipo IN ('N', 'R') --vinculados
           --and c.cod_sec_credito not in (702, 703)
           AND s.cod_gru_economico =  fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD')
           AND nvl(fup_obt_tip_letra(c.cod_modalidad), 'N') = 'N'
           AND nvl(fup_obt_tip_afd_vivienda(c.cod_modalidad), 'N') = 'N'
           AND nvl(fup_obt_tip_bono(c.cod_modalidad), 'N') = 'N'
           AND c.cod_moneda <> pag_gen.fu_obt_mon_local
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
        UNION ALL
        SELECT 43 AS codigo,
               SUM(nvl(pag_gen.fu_con_mon_a_moneda(c.cod_moneda, pag_gen.fu_obt_mon_local, c.monto,
                                                   NULL), 0)) AS monto_mn
          FROM cc_che_enviados c, lc_che_comprados g
         WHERE c.nro_cheque = g.nro_cheque(+)
           AND c.cod_banco = g.cod_banco(+)
           AND (c.fecha >= to_date(fug_obt_pardinamico('FEC_IMP_RUB_CHE_COM'), 'dd/mm/yyyy') AND
               pag_gen.fu_obt_cod_entidad = 2036)
           AND c.nro_cuenta IS NULL
           AND c.cod_moneda <> pag_gen.fu_obt_mon_local
           AND c.estado = 'I')
 GROUP BY codigo
UNION ALL
SELECT 44 as codigo,
         nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   GE_CLIENTES s
           where ( c.cod_modulo in (5,6)  or    (c.cod_modulo=10 and c.cod_modalidad=114))
           and c.cod_persona = s.cod_persona
           and s.tipo IN ('G','M','R')    --grandes
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
UNION ALL
SELECT 45 as codigo,
        nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   GE_CLIENTES s
           where  c.cod_modulo in (5,6)
           and c.cod_persona = s.cod_persona
           and  s.tipo = 'T'   --Microcreditos
           --AND (c.tip_destino <> 4 or c.tip_destino is null)
            AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
UNION ALL
SELECT    46 as codigo,
          nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   GE_CLIENTES s
           where c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           and  s.tipo IN ('N','C')   --pymes
           and c.cod_sec_credito not in (702, 703)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
UNION ALL
SELECT     47  as codigo,
 nvl(round(SUM(nvl(c.TOT_DEU_REAL, 0)   )   ),0) as monto_mn
 FROM ge_cla_operaciones c,   GE_CLIENTES s
           where  c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           --and s.tipo IN ('N', 'R')   --vinculados
           ---and c.cod_sec_credito not in (702, 703)
           AND s.cod_gru_economico =  fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD')
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda = pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
UNION ALL


SELECT 48 AS codigo, nvl(round(SUM(nvl(c.tot_deu_real, 0))), 0) AS monto_mn
  FROM ge_cla_operaciones c, ge_clientes s
 WHERE (c.cod_modulo IN (5, 6) OR (c.cod_modulo = 10 AND c.cod_modalidad = 114))
   AND c.cod_persona = s.cod_persona
   AND s.tipo IN ('G','M','R') --grandes deudores
   AND nvl(fup_obt_tip_letra(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_afd_vivienda(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_bono(c.cod_modalidad), 'N') = 'N'
   AND c.cod_moneda = pag_gen.fu_obt_mon_local
   AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60

UNION ALL

SELECT 49 as codigo,
     nvl(round(SUM(nvl(c.TOT_DEU_REAL, 0)   )   ),0) as monto_mn
 FROM ge_cla_operaciones c,  GE_CLIENTES s
           where  c.cod_modulo in (5,6)
           and c.cod_persona = s.cod_persona
           and s.tipo = 'T'   --microcreditos
           --AND (c.tip_destino <> 4 or c.tip_destino is null)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda = pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
UNION ALL

SELECT     50 as codigo,
   nvl(round(SUM(nvl(c.TOT_DEU_REAL, 0)   )   ),0) as monto_mn
 FROM ge_cla_operaciones c,  GE_CLIENTES s
           where c.cod_modulo in (5,6)
           and c.cod_persona = s.cod_persona
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda = pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60
           and s.tipo in('N','C')   --pymes
           and c.cod_sec_credito not in (702, 703)

UNION ALL

SELECT    51 as codigo,
       nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 999999
           AND substr(c.cod_rub_economico, 1, 3)  = '011'--Agricultura

UNION ALL
SELECT     52 as codigo,
        nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 999999
           AND substr(c.cod_rub_economico, 1, 3)  = '012'--Ganaderia
UNION ALL
SELECT    53 as codigo,
        nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s,  pr_rub_economicos rb
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 99999
            AND substr(c.cod_rub_economico, 1, 1)  = substr(rb.cod_rub_economico, 1, 1)
           AND c.cod_rub_economico = rb.cod_rub_economico
           AND rb.cod_rub_eco_padre = 'D'--Industrias

UNION ALL
SELECT     54 as codigo,
        nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s, pr_rub_economicos rb
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 99999
           AND substr(c.cod_rub_economico, 1, 1)  = substr(rb.cod_rub_economico, 1, 1)
           AND c.cod_rub_economico = rb.cod_rub_economico
           AND rb.cod_rub_eco_padre = 'F'--Construccion

UNION ALL
SELECT 55 as  codigo,
       nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 99999
           AND substr(c.cod_rub_economico, 1, 2)  = '51'--Comercio al por mayor
UNION ALL
SELECT     56 as codigo,
        nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
            AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 99999
           AND substr(c.cod_rub_economico, 1, 2)  = '52'--Comercio al por menor

 UNION ALL
SELECT     57 as codigo,
       nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,  ba_per_dat_adicionales s,  pr_rub_economicos rb
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 99999
           AND c.cod_rub_economico = rb.cod_rub_economico
           AND rb.cod_rub_eco_padre IN ('H','I') --Servicios
          and substr(c.cod_rub_economico,1,1) = substr(rb.cod_rub_economico,1,1)

UNION ALL
SELECT    58 as codigo,
        nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,    ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and s.cod_persona = c.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999
           AND substr(c.cod_rub_economico, 1, 4)  = '9701'--consumo

UNION ALL
SELECT    59 as codigo,
         nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999
           AND substr(c.cod_rub_economico, 1, 4)  = '9700'--vivienda

UNION ALL
SELECT    60 as codigo,
         nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s,  pr_rub_economicos rb
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and s.cod_persona = c.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 99999
           AND c.cod_rub_economico = rb.cod_rub_economico
           AND rb.cod_rub_eco_padre = 'J' --Intermediacion Financiera

 UNION ALL
SELECT     61 as codigo,
         nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
FROM ge_cla_operaciones c,    ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and s.cod_persona = c.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999
           AND substr(c.cod_rub_economico, 1,3)  in ('013','014') --Agribusiness

UNION ALL
SELECT 62 as codigo,
         nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999
           AND instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_18'), c.cod_rub_economico) > 0--vehiculos

UNION ALL
SELECT    63 as codigo,
            nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and s.cod_persona = c.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999
           AND substr(c.cod_rub_economico, 1,2) in ('72','73','74')--servicios personales

UNION ALL
SELECT    64 as codigo,
          nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,    ba_per_dat_adicionales s,  pr_rub_economicos rb
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999
        AND c.cod_rub_economico = rb.cod_rub_economico
        --and substr(c.cod_rub_economico,1,1) = substr(rb.cod_rub_economico,1,1)
        AND c.cod_rub_economico = rb.cod_rub_economico
        AND not  (substr(c.cod_rub_economico, 1,2) in ('72','73','74')--servicios personales
         or    instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_18'), c.cod_rub_economico) > 0--vehiculos
         or    substr(c.cod_rub_economico, 1,3)  in ('013','014') --Agribusiness
         or    rb.cod_rub_eco_padre = 'J' --Intermediacion Financiera
         or    substr(c.cod_rub_economico, 1, 4)  = '9701' --consumo
         or    substr(c.cod_rub_economico, 1, 4)  = '9700'--vivienda
         or    rb.cod_rub_eco_padre IN ('H','I') --Servicios
         or  instr(fug_obt_pardinamico('SIB_CIR_236_RUBROS_13'), c.cod_rub_economico) > 0
         or    substr(c.cod_rub_economico, 1, 2)  = '52'--Comercio al por menor
         or  substr(c.cod_rub_economico, 1, 2)  = '51'--Comercio al por mayor
         or  rb.cod_rub_eco_padre = 'F'--Construccion
         or  rb.cod_rub_eco_padre = 'D'--Industrias
         or  substr(c.cod_rub_economico, 1, 3)  = '012'--Ganaderia
         or  substr(c.cod_rub_economico, 1, 3)  = '011') --Agricultura
 UNION ALL
SELECT    65 as codigo,
         nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   ba_per_dat_adicionales s,  ba_personas ba
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and c.cod_persona = s.cod_persona
           and s.cod_persona = ba.cod_persona
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999
           AND ba.tipo ='F'

 union all
 SELECT    66 as codigo,
          nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,  ge_cta_clientes ge ,  ba_per_dat_adicionales s,  ba_personas ba
           where s.val_parametro = 'S'
           and s.parametro = 'EMP_NO_GENERADORA'
           and ge.cod_persona = s.cod_persona
           and ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999
           AND ba.tipo ='J'
           AND ba.cod_persona = ge.cod_persona

 UNION ALL
 SELECT    67 as codigo,
        nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,  ge_cta_clientes ge, GE_CLIENTES s
           where ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           and ge.cod_persona = s.cod_persona
           --and s.tipo IN ('N', 'R')   --vinculados
           --and c.cod_sec_credito not in (702, 703)
           AND s.cod_gru_economico =  fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD')
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999

UNION ALL
SELECT    68 as codigo,
           nvl(round(SUM((nvl(c.tot_deu_real, 0) )) ),0) as monto_mn
 FROM ge_cla_operaciones c,  ge_cta_clientes ge, GE_CLIENTES s
           where ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           and ge.cod_persona = s.cod_persona
           and s.tipo IN ('G','M','R')  --grandes deudores
            AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999

UNION ALL
SELECT    69 as codigo,
         nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   GE_CLIENTES s
           where  c.cod_modulo in (5,6)
           and c.cod_persona = s.cod_persona
           and  s.tipo = 'T'  --microcreditos
           --AND (c.tip_destino <> 4 or c.tip_destino is null)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999

  UNION ALL
SELECT    70 as codigo,
          nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,   GE_CLIENTES s
           where  c.cod_modulo in (5,6)
           and c.cod_persona = s.cod_persona
           and  s.tipo = 'C'   --pymes
           and c.cod_sec_credito not in (702, 703)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999

UNION ALL

SELECT    71 as codigo,
      nvl(round(SUM(nvl(c.TOT_DEU_REAL, 0)   )   ),0) as monto_mn
 FROM ge_cla_operaciones c,  GE_CLIENTES s
           where  c.cod_modulo in (5,6)
           and c.cod_persona = s.cod_persona
           --and s.tipo IN ('N', 'R')  --vinculados
           --and c.cod_sec_credito not in (702, 703)
           AND s.cod_gru_economico =  fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD')
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda = pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999

UNION ALL

SELECT    72 as codigo,
      nvl(round(SUM(nvl(c.TOT_DEU_REAL, 0)   )   ),0) as monto_mn
 FROM ge_cla_operaciones c,   GE_CLIENTES s
           where  c.cod_modulo in (5,6)
          AND c.cod_persona = s.cod_persona
          and s.tipo IN ('G','M','R')  --grandes deudores
          AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
          AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
          AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
          AND c.cod_moneda = pag_gen.FU_OBT_MON_LOCAL
          AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999

 UNION ALL

SELECT    73 as codigo,
        nvl(round(SUM(nvl(c.TOT_DEU_REAL, 0)   )   ),0) as monto_mn
 FROM ge_cla_operaciones c,  ge_cta_clientes ge, GE_CLIENTES s
           where ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           and ge.cod_persona = s.cod_persona
           and s.tipo = 'T'  --microcreditos
           --AND (c.tip_destino <> 4 or c.tip_destino is null)
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda = pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999
 UNION ALL

SELECT    74 as codigo,
      nvl(round(SUM(nvl(c.TOT_DEU_REAL, 0)   )   ),0) as monto_mn
 FROM ge_cla_operaciones c,  ge_cta_clientes ge, GE_CLIENTES s
           where ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           and ge.cod_persona = s.cod_persona
            AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda = pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999
           and s.tipo = 'C'  --pymes
           and c.cod_sec_credito not in (702, 703)
UNION ALL --- Cantidad de deudores ? Cr?ditos a Vinculados con otros grupos
SELECT 75 AS codigo, COUNT(DISTINCT c.cod_persona) monto_mn
  FROM ge_cla_operaciones c, ge_clientes s
 WHERE c.cod_persona = s.cod_persona
   AND c.cod_modulo IN (5, 6)
   AND (s.cod_gru_economico <>  fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD')
   and s.cod_gru_economico is not null)
   --AND s.tipo = 'G'
   AND nvl(fup_obt_tip_letra(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_afd_vivienda(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_bono(c.cod_modalidad), 'N') = 'N'
UNION ALL

SELECT 76 AS codigo, -- Cr?ditos Vigentes en ME equivalente ? Cr?ditos a Vinculados con otros grupos
       nvl(round(SUM((nvl(c.tot_deu_real, 0)))), 0) AS monto_mn
  FROM ge_cla_operaciones c, ge_clientes s
 WHERE c.cod_modulo IN (5, 6)
   AND c.cod_persona = s.cod_persona
   AND (s.cod_gru_economico <> fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD')
   and s.cod_gru_economico is not null)
   --AND s.tipo = 'G'
   AND nvl(fup_obt_tip_letra(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_afd_vivienda(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_bono(c.cod_modalidad), 'N') = 'N'
   AND c.cod_moneda <> pag_gen.fu_obt_mon_local
   AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60

UNION ALL
SELECT 77 AS codigo, --Cr?ditos Vigentes en MN ? Cr?ditos a Vinculados con otros grupos
       nvl(round(SUM(nvl(c.tot_deu_real, 0))), 0) AS monto_mn
  FROM ge_cla_operaciones c, ge_clientes s
 WHERE c.cod_persona = s.cod_persona
   AND c.cod_modulo IN (5, 6)
    AND (s.cod_gru_economico <> fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD')
   and s.cod_gru_economico is not null)
   --AND s.tipo = 'G'
   AND nvl(fup_obt_tip_letra(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_afd_vivienda(c.cod_modalidad), 'N') = 'N'
   AND nvl(fup_obt_tip_bono(c.cod_modalidad), 'N') = 'N'
   AND c.cod_moneda = pag_gen.fu_obt_mon_local
   AND nvl(c.dia_atraso, 0) BETWEEN 0 AND 60

UNION ALL
 SELECT    78 as codigo, --- Cr?ditos Vencidos en ME equivalente ? Cr?ditos a Vinculados con otros grupos
        nvl(round(SUM((nvl(c.tot_deu_real, 0)  )) ),0) as monto_mn
 FROM ge_cla_operaciones c,  ge_cta_clientes ge, GE_CLIENTES s
           where ge.nro_cuenta = c.nro_cuenta
           and ge.relacion = 'P'
           and c.cod_modulo in (5,6)
           AND (s.cod_gru_economico <> fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD')
           and s.cod_gru_economico is not null)
           --AND s.tipo = 'G'
           AND ge.cod_persona = s.cod_persona
           AND nvl(fup_obt_tip_letra(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_afd_vivienda(c.cod_modalidad),'N') = 'N'
           AND NVL(fup_obt_tip_bono(c.cod_modalidad),'N')= 'N'
           AND c.cod_moneda <> pag_gen.FU_OBT_MON_LOCAL
           AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999

UNION ALL
 SELECT 79 AS codigo, ---Cr?ditos Vencidos en MN? Cr?ditos a Vinculados con otros grupos
        nvl(round(SUM(nvl(c.tot_deu_real, 0))), 0) AS monto_mn
   FROM ge_cla_operaciones c, ge_clientes s
  WHERE c.cod_modulo IN (5, 6)
    AND c.cod_persona = s.cod_persona
    AND (s.cod_gru_economico <> fug_obt_pardinamico('COD_GRU_ECO_ENTIDAD')
    and s.cod_gru_economico is not null)
    --AND s.tipo = 'G'
    AND nvl(fup_obt_tip_letra(c.cod_modalidad), 'N') = 'N'
    AND nvl(fup_obt_tip_afd_vivienda(c.cod_modalidad), 'N') = 'N'
    AND nvl(fup_obt_tip_bono(c.cod_modalidad), 'N') = 'N'
    AND c.cod_moneda = pag_gen.fu_obt_mon_local
    AND nvl(c.dia_atraso, 0) BETWEEN 61 AND 9999

UNION ALL
  select 100 as codigo,
         sum(mto_sin_riesgo)  * (0/100) monto_mn
from
(
SELECT least(SUM(mto_riesgo), SUM(mto_valor)) mto_sin_riesgo, val.tip_gar, val.cod_persona
  FROM (SELECT fue_obt_des_oficina(c.cod_oficina) oficina,
               c.cod_persona,
               SUM(nvl(c.tot_deu_real, 0))  mto_riesgo,
               e.descripcion tip_gar
          FROM ge_cla_operaciones c,
               (SELECT DISTINCT (a.nro_cuenta), a.cod_garantia
                  FROM pr_cta_garantias a, pr_garantias g, pr_gar_cash ca
                 WHERE a.nro_garantia = g.nro_garantia
                   AND a.cod_garantia = g.cod_garantia
                   and g.nro_garantia = ca.nro_garantia
                   AND g.estado IN ('C', 'I')
                   AND nvl(g.valor, 0) > 0) gar,
               pr_gar_tipos e
         WHERE gar.nro_cuenta = c.nro_cuenta
           AND gar.cod_garantia = e.cod_garantia
         GROUP BY c.cod_oficina, c.cod_persona, e.descripcion) rie,
       (SELECT MAX(b.fec_confirmacion) fecha,
               b.cod_persona,
               fue_obt_nom_persona(b.cod_persona) nom_persona,
               e.descripcion tip_gar,
               SUM(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, pag_gen.fu_obt_mon_local,
                                               (nvl(b.valor, 0)),
                                               nvl(fug_obt_cotizacion(b.cod_moneda,
                                                                       pag_cal.fu_obt_fec_actual(1)), 1))) mto_valor
          FROM (SELECT DISTINCT (a.nro_garantia), a.cod_garantia
                  FROM pr_cta_garantias a, ge_cla_operaciones c
                 WHERE a.nro_cuenta = c.nro_cuenta  ) pre,
               pr_garantias b,
               pr_gar_tipos e,
               pr_gar_cash ca
         WHERE b.nro_garantia = pre.nro_garantia
           AND b.cod_garantia = pre.cod_garantia
           AND b.cod_garantia = e.cod_garantia
           and b.nro_garantia = ca.nro_garantia
           AND nvl(e.por_bco_central, 0) > 0
           AND nvl(b.valor, 0) > 0
           AND b.estado IN ('C', 'I')
         GROUP BY b.cod_persona, e.descripcion) val
 WHERE rie.tip_gar = val.tip_gar
   AND rie.cod_persona = val.cod_persona
 GROUP BY val.tip_gar, val.cod_persona
 UNION ALL
   select
    nvl(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0)  as mto_sin_riesgo,
    '1','1'
    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
    and cod_rubro in (
    '110100000000000',
    '110201050000000',
    '130101290100000',
    '120101230000000',
    '510106510413701',
    '510106510413799',
    '510106510403001')
  )
  UNION ALL

SELECT  120 as codigo,
    round( nvl(round(sum(NVL(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0))  ),0) * (20/100)) as monto_mn
    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
    and cod_rubro in (
      '120101250100000',
    '110201070000000',
    '130101330700000',
    '110201090500000',
    '130101310300000',
    '130101310500000',
    '130101310900000',
    '130101330900000',
    '130101330300000',
    '130101330500000',
    '130101330700000',
    '130101410300000',
    '130101410500000',
    '130101410700000',
    '130101410900000',
    '130101411100000',
    '130101411300000',
    '130101411500000',
    '130101430300000',
    '130101430500000',
    '130101430700000',
    '130101430900000',
    '130101431100000',
    '130101431300000',
    '130101431500000')

  UNION ALL

  SELECT  150 as codigo,
  round(sum(monto_mn) * (50/100)) as monto_mn
  from
  (select
   round(sum(NVL(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0))  )   as monto_mn

    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
    and cod_rubro in (
     '110201090200000',
     '110201090400000',
     '110201090800000',
     '110201091000000',
     '110201130000000',
     '130101310200000',
     '130101310400000',
     '130101310600000',
     '130101330200000',
     '130101330400000',
     '130101330600000',
     '130101410200000',
     '130101410400000',
     '130101410600000',
     '130101430200000',
     '130101430400000',
     '130101430600000',
     '130103910000000',
     '130200000000000',
     '130300000000000',
     '170202950400000',
     '510106510402099',
     '510106510402001',
     '510106510404001',
     '510106510404099',
     '140300000000000')

     union all

     select    sum(mto_sin_riesgo)  monto_mn
from
(
SELECT least(SUM(mto_riesgo), SUM(mto_valor)) mto_sin_riesgo, val.tip_gar, val.cod_persona
  FROM (SELECT fue_obt_des_oficina(c.cod_oficina) oficina,
               c.cod_persona,
               SUM(nvl(c.tot_deu_real, 0))  mto_riesgo,
               e.descripcion tip_gar
          FROM ge_cla_operaciones c,

               (SELECT DISTINCT (a.nro_cuenta), a.cod_garantia
                  FROM pr_cta_garantias a, pr_garantias g, pr_gar_hipotecarias ca
                 WHERE a.nro_garantia = g.nro_garantia
                   AND a.cod_garantia = g.cod_garantia
                   and g.nro_garantia = ca.nro_garantia
                   AND g.estado IN ('C', 'I')
                   AND nvl(g.valor, 0) > 0) gar,
               pr_gar_tipos e
         WHERE gar.nro_cuenta = c.nro_cuenta
           AND gar.cod_garantia = e.cod_garantia
         GROUP BY c.cod_oficina, c.cod_persona, e.descripcion) rie,
       (SELECT   a.fecha,
                 a.cod_persona,
                 fue_obt_nom_persona(a.cod_persona) nom_persona,
                 a.tip_gar,
                 sum(a.mto_valor) mto_valor
            FROM pv_pla_garantias a
           WHERE a.tip_gar = 'HIPOTECAS' group by cod_persona, tip_gar,a.fecha, fue_obt_nom_persona(a.cod_persona) ) val
 WHERE rie.tip_gar = val.tip_gar
   AND rie.cod_persona = val.cod_persona
 GROUP BY val.tip_gar, val.cod_persona
  )
  union all
       select    sum(mto_sin_riesgo)  monto_mn
from
(
SELECT least(SUM(mto_riesgo), SUM(mto_valor)) mto_sin_riesgo, val.tip_gar, val.cod_persona
  FROM (SELECT fue_obt_des_oficina(c.cod_oficina) oficina,
               c.cod_persona,
               SUM(nvl(c.tot_deu_real, 0))  mto_riesgo,
               e.descripcion tip_gar
          FROM ge_cla_operaciones c,

               (SELECT DISTINCT (a.nro_cuenta), a.cod_garantia
                  FROM pr_cta_garantias a, pr_garantias g, pr_gar_vehiculos ca
                 WHERE a.nro_garantia = g.nro_garantia
                   AND a.cod_garantia = g.cod_garantia
                   and g.nro_garantia = ca.nro_garantia
                   AND g.estado IN ('C', 'I')
                   AND nvl(g.valor, 0) > 0) gar,
               pr_gar_tipos e
         WHERE gar.nro_cuenta = c.nro_cuenta
           AND gar.cod_garantia = e.cod_garantia
         GROUP BY c.cod_oficina, c.cod_persona, e.descripcion) rie,
       (SELECT MAX(b.fec_confirmacion) fecha,
               b.cod_persona,
               fue_obt_nom_persona(b.cod_persona) nom_persona,
               e.descripcion tip_gar,
               SUM(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, pag_gen.fu_obt_mon_local,
                                               (nvl(b.valor, 0)),
                                               nvl(fug_obt_cotizacion(b.cod_moneda,
                                                                       pag_cal.fu_obt_fec_actual(1)), 1))) mto_valor
          FROM (SELECT DISTINCT (a.nro_garantia), a.cod_garantia
                  FROM pr_cta_garantias a, ge_cla_operaciones c
                 WHERE a.nro_cuenta = c.nro_cuenta  ) pre,
               pr_garantias b,
               pr_gar_tipos e,
               pr_gar_vehiculos ca
         WHERE b.nro_garantia = pre.nro_garantia
           AND b.cod_garantia = pre.cod_garantia
           AND b.cod_garantia = e.cod_garantia
           and b.nro_garantia = ca.nro_garantia
           AND nvl(e.por_bco_central, 0) > 0
           AND nvl(b.valor, 0) > 0
           AND b.estado IN ('C', 'I')
         GROUP BY b.cod_persona, e.descripcion) val
 WHERE rie.tip_gar = val.tip_gar
   AND rie.cod_persona = val.cod_persona
 GROUP BY val.tip_gar, val.cod_persona
  ))
  UNION ALL
  SELECT  200 AS codigo,
     sum(monto_mn - res_monto) monto_mn
from (
SELECT  nvl(round(sum(NVL(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0))  ),0) as monto_mn,
   0 as res_monto
    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
     and cod_rubro =  '100000000000000'
         UNION  ALL

select sum(monto_mn) as monto_mn,
      sum(res_monto) as res_monto
from
(
SELECT 0 as monto_mn,
     NVL(round(sum(NVL(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0))  ),0) as res_monto
    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
    and cod_rubro  in (
    '120101250100000',
    '110201070000000',
    '130101330700000',
    '110201090500000',
    '130101310300000',
    '130101310500000',
    '130101310900000',
    '130101330900000',
    '130101330300000',
    '130101330500000',
    '130101330700000',
    '130101410300000',
    '130101410500000',
    '130101410700000',
    '130101410900000',
    '130101411100000',
    '130101411300000',
    '130101411500000',
    '130101430300000',
    '130101430500000',
    '130101430700000',
    '130101430900000',
    '130101431100000',
    '130101431300000',
    '130101431500000'

  )

union all

--rubro 100
 select 0 as monto_mn,
         sum(mto_sin_riesgo)  monto_riesgo
from
(

--SELECT fug_obt_rie_gar_cash mto_sin_riesgo, '1','1'
--  FROM dual
  --cuentas activas
  select sum(o.tot_gar_computables) mto_sin_riesgo, '1','1'
  from ge_cla_operaciones o
  where o.nro_cuenta in (select distinct(b.nro_cuenta)
                         from pr_gar_cash a,pr_cta_garantias b
                         where a.nro_garantia=b.nro_garantia)

 UNION ALL
   select
    nvl(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0)  as mto_sin_riesgo,
    '1','1'
    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
    and cod_rubro in (
    '110100000000000',
    '110201050000000',
    '130101290100000',
    '120101230000000',
    '510106510413701',
    '510106510413799')
  )
union all

--rubro 150
 SELECT  0 as monto_mn,
  sum(monto_mn) res_monto
  from
  (


   select
   round(sum(NVL(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0))  ) as monto_mn

    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
    and cod_rubro in (
     '110201090200000',
     '110201090400000',
     '110201090800000',
     '110201091000000',
     '110201130000000',
     '130101310200000',
     '130101310400000',
     '130101310600000',
     '130101330200000',
     '130101330400000',
     '130101330600000',
     '130101410200000',
     '130101410400000',
     '130101410600000',
     '130101430200000',
     '130101430400000',
     '130101430600000',
     '130103910000000',
     '130200000000000',
     '130300000000000',
     '170202950400000',
     '510106510402099',
     '510106510402001',
     '510106510404001',
     '510106510404099',
     '140300000000000')

     union all
     select    sum(mto_sin_riesgo)  monto_mn
from
(
SELECT least(SUM(mto_riesgo), SUM(mto_valor)) mto_sin_riesgo, val.tip_gar, val.cod_persona
  FROM (SELECT fue_obt_des_oficina(c.cod_oficina) oficina,
               c.cod_persona,
               SUM(nvl(c.tot_deu_real, 0))  mto_riesgo,
               e.descripcion tip_gar
          FROM ge_cla_operaciones c,

               (SELECT DISTINCT (a.nro_cuenta), a.cod_garantia
                  FROM pr_cta_garantias a, pr_garantias g, pr_gar_hipotecarias ca
                 WHERE a.nro_garantia = g.nro_garantia
                   AND a.cod_garantia = g.cod_garantia
                   and g.nro_garantia = ca.nro_garantia
                   AND g.estado IN ('C', 'I')
                   AND nvl(g.valor, 0) > 0) gar,
               pr_gar_tipos e
         WHERE gar.nro_cuenta = c.nro_cuenta


           AND gar.cod_garantia = e.cod_garantia
         GROUP BY c.cod_oficina, c.cod_persona, e.descripcion) rie,
       ( SELECT   a.fecha,
                 a.cod_persona,
                 fue_obt_nom_persona(a.cod_persona) nom_persona,
                 a.tip_gar,
                 sum(a.mto_valor) mto_valor
            FROM pv_pla_garantias a
           WHERE a.tip_gar = 'HIPOTECAS' group by cod_persona, tip_gar,a.fecha, fue_obt_nom_persona(a.cod_persona) ) val

 WHERE rie.tip_gar = val.tip_gar
   AND rie.cod_persona = val.cod_persona
 GROUP BY val.tip_gar, val.cod_persona

  )
  union all
       select    sum(mto_sin_riesgo)  monto_mn
from
(
SELECT least(SUM(mto_riesgo), SUM(mto_valor)) mto_sin_riesgo, val.tip_gar, val.cod_persona
  FROM (SELECT fue_obt_des_oficina(c.cod_oficina) oficina,
               c.cod_persona,
               SUM(nvl(c.tot_deu_real, 0))  mto_riesgo,
               e.descripcion tip_gar
          FROM ge_cla_operaciones c,

               (SELECT DISTINCT (a.nro_cuenta), a.cod_garantia
                  FROM pr_cta_garantias a, pr_garantias g, pr_gar_vehiculos ca
                 WHERE a.nro_garantia = g.nro_garantia
                   AND a.cod_garantia = g.cod_garantia
                   and g.nro_garantia = ca.nro_garantia
                   AND g.estado IN ('C', 'I')
                   AND nvl(g.valor, 0) > 0) gar,
               pr_gar_tipos e
         WHERE gar.nro_cuenta = c.nro_cuenta


           AND gar.cod_garantia = e.cod_garantia
         GROUP BY c.cod_oficina, c.cod_persona, e.descripcion) rie,
       (SELECT MAX(b.fec_confirmacion) fecha,
               b.cod_persona,
               fue_obt_nom_persona(b.cod_persona) nom_persona,
               e.descripcion tip_gar,
               SUM(pag_gen.fu_con_mon_a_moneda(b.cod_moneda, pag_gen.fu_obt_mon_local,
                                               (nvl(b.valor, 0)),
                                               nvl(fug_obt_cotizacion(b.cod_moneda,
                                                                       pag_cal.fu_obt_fec_actual(1)), 1))) mto_valor
          FROM (SELECT DISTINCT (a.nro_garantia), a.cod_garantia
                  FROM pr_cta_garantias a, ge_cla_operaciones c
                 WHERE a.nro_cuenta = c.nro_cuenta  ) pre,
               pr_garantias b,
               pr_gar_tipos e,
               pr_gar_vehiculos ca
         WHERE b.nro_garantia = pre.nro_garantia
           AND b.cod_garantia = pre.cod_garantia
           AND b.cod_garantia = e.cod_garantia
           and b.nro_garantia = ca.nro_garantia
           AND nvl(e.por_bco_central, 0) > 0
           AND nvl(b.valor, 0) > 0
           AND b.estado IN ('C', 'I')
         GROUP BY b.cod_persona, e.descripcion) val
 WHERE rie.tip_gar = val.tip_gar
   AND rie.cod_persona = val.cod_persona
 GROUP BY val.tip_gar, val.cod_persona

  ))
    )
)
 UNION ALL

  SELECT 300 AS CODIGO,
     round(sum(NVL(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0))  ) * (0/100) as monto_mn

    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
    and cod_rubro in (
     '410106090000000',
    '410106130000000',
    '410106170000000',
    '410106190000000')

 UNION ALL

  SELECT 320 AS CODIGO,
    0 * (20/100) as monto_mn
   FROM dual

 UNION ALL
   select 350 AS CODIGO,
    0 * (50/100) as monto_mn from dual

 UNION ALL

 select 400 as codigo,
   sum(monto_mn - monto_res)
   from
   (select
    nvl(round(sum((NVL(C.SAL_MON_LOC_ANT, 0) +NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0)))  ),0) as monto_mn,
    0 as monto_res

    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
    and cod_rubro = '410000000000000'
    union all
   SELECT 0 as monto_mn,
     nvl(round(sum(NVL(C.SAL_MON_LOC_ANT, 0) + NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0))  ),0) as monto_res

    from cb_sal_consolidados_his c
    where ano = to_char(fue_obt_fec_calendar(1),'YYYY')
    and mes = to_char(fue_obt_fec_calendar(1),'MM')
    and cod_rubro in (
     '410106090000000',
    '410106130000000',
    '410106170000000',
    '410106190000000'  ))
;

