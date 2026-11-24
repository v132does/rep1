CREATE OR REPLACE FORCE VIEW IT.IV_SAUPMMDD2_T AS
SELECT to_char(rpad(to_char(trunc(sysdate),'YYYY/MM/DD'),10,' ')) fec_,
       '0007' cd_agencia,
       rpad(A.NRO_CUENTA,30,' ') NU_CTA_SER,
       rpad(A.COD_PERSONA,10,' ') NU_CTA,
       DECODE(pai_dtm.fu_obt_cod_gru_economico(A.COD_PERSONA),
              NULL,rpad(A.COD_PERSONA,10,' '),
              rpad(pai_dtm.fu_obt_cod_gru_economico(A.COD_PERSONA),10,' ')) NU_PARENT_NUM,
       DECODE(pai_dtm.fu_obt_cod_gru_economico(A.COD_PERSONA),
              NULL,rpad(pai_dtm.fu_obt_nom_cliente(A.COD_PERSONA),10,' '),
       rpad(pai_dtm.fu_obt_nom_gru_economico(pai_dtm.fu_obt_cod_gru_economico(A.COD_PERSONA)),10,' ')) SN_PARENT_NUM,
       rpad(to_char(A.COD_MODALIDAD),5,' ') cd_TIPO_CUENTA,
       ---------------------------------------------------
       (fub_con_mon_a_moneda(f.cod_moneda,
                             'USD',
                             F.SAL_CONTABLE,
                             null,
                             to_char(sysdate,'dd/mm/yyyy')))
       /*(F.SAL_CONTABLE)*/ IM_SALDO,
       ---------------------------------------------------
       decode(a.cod_modalidad,
       41,0,
       31,(fub_con_mon_a_moneda(f.cod_moneda,
                                'USD',
                                pai_dtm.FU_OBT_DEV_AV(a.nro_cuenta,pag_cal.fu_obt_fec_actual(a.cod_modulo)),
                                null,
                                to_char(sysdate,'dd/mm/yyyy'))))
       /*decode(a.cod_modalidad,
       41,0,
       31,pai_dtm.FU_OBT_DEV_AV(a.nro_cuenta,pag_cal.fu_obt_fec_actual(a.cod_modulo)))*/ IM_INTERES_DEVENGADO,
       ---------------------------------------------------
       fub_con_mon_a_moneda(f.cod_moneda,
                             'USD',
                             F.SAL_PROMEDIO,
                             null,
                             to_char(sysdate,'dd/mm/yyyy'))
       /*(F.SAL_PROMEDIO)*/ AVG_BAL,
       ---------------------------------------------------
       (F.SAL_CONTABLE)
       /*(fub_con_mon_a_moneda(f.cod_moneda,
                             'USD',
                             F.SAL_CONTABLE,
                             null,
                             to_char(sysdate,'dd/mm/yyyy')))*/ IM_SALDO_BASE,
       ---------------------------------------------------
       decode(a.cod_modalidad,
       41,0,
       31,pai_dtm.FU_OBT_DEV_AV(a.nro_cuenta,pag_cal.fu_obt_fec_actual(a.cod_modulo)))
      /* decode(a.cod_modalidad,
       41,0,
       31,(fub_con_mon_a_moneda(f.cod_moneda,
                                'USD',
                                pai_dtm.FU_OBT_DEV_AV(a.nro_cuenta,pag_cal.fu_obt_fec_actual(a.cod_modulo)),
                                null,
                                to_char(sysdate,'dd/mm/yyyy'))))*/ IM_INTERES_DEV_BASE,

       ---------------------------------------------------
       (F.SAL_PROMEDIO)
       /*fub_con_mon_a_moneda(f.cod_moneda,
                             'USD',
                             F.SAL_PROMEDIO,
                             null,
                             to_char(sysdate,'dd/mm/yyyy'))*/ AVG_BAL_BASE

FROM GE_CTA_CLIENTES A
INNER JOIN BA_PERSONAS D ON(D.COD_PERSONA=A.COD_PERSONA)
INNER JOIN GE_CUENTAS F ON(F.NRO_CUENTA=A.NRO_CUENTA)
INNER JOIN GE_CLIENTES E ON(A.COD_PERSONA=E.COD_PERSONA)--por incosistencia
WHERE A.COD_MODALIDAD IN(31,41)
and a.relacion='P'
--and exists (select 1 from dtm_ctupmmdd dtm where trim(dtm.nu_cta_ser)=a.nro_cuenta)
;

