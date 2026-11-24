create or replace force view it.simgia_saldo_oficina as
select a.msuc cod_oficina,
       c.cod_rubro cod_rubro,
       nvl((a.mcta || lpad(a.msubcta,6,0)),0) cta_contable,
       to_char(pae_cnf.fu_obt_fec_actual(2),'yyyy') ano,
       to_char(pae_cnf.fu_obt_fec_actual(2),'mm') mes,
       (a.saldoact * -1) SAL_MON_LOC_ANT,
       /*abs(a.acudeb)*/ 0 DEB_MON_LOCAL,
       /*abs(a.credihoy)*/ 0 CRE_MON_LOCAL,
       0 SAL_INI_MES_MON_LOCAL,
       (a.saldoactme * -1) SAL_MON_RUB_ANT,
       0 DEB_MON_RUBRO,
       0 CRE_MON_RUBRO,
       0 SAL_INI_MES_MON_RUBRO,
       0 SAL_INI_MES_MON_FUERTE,
       'N' PROTEGIDO,
       '' USU_INSERCION,
       '' FEC_INSERCION,
       '' USU_MODIFICACION,
       '' FEC_MODIFICACION,
       nvl((a.saldoact * -1),0) SAL_EQU_LOC_ANT,
       /*nvl(abs(a.acudeb),0)*/ 0 DEB_EQU_LOCAL,
       /*nvl(abs(a.credihoy),0)*/ 0 CRE_EQU_LOCAL,
       0 SAL_INI_MES_EQU_LOCAL
from simgia_armamay a,  ba_oficinas b, cb_rubros c
where c.cod_rub_externo = (a.mcta || lpad(a.msubcta,6,0))
and b.cod_oficina = a.msuc
--Desarrollado por Simgia, programador Juan Bauer.
--20100319 se agregan campos faltantes y valores por defecto - Nicolas Andrusky
--20100413 se envia 0 en DEB_MON_LOCAL y CRE_MON_LOCAL. - NA
--20100415 se envia 0 en DEB_EQU_LOCAL y CRE_EQU_LOCAL. - NA
;

