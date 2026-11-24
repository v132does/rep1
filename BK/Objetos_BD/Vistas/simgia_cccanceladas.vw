create or replace force view it.simgia_cccanceladas as
select to_char(nvl(substr(cccor.nro_cuenta, 1, 2),0)) NSUC,
       to_char(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(cccor.nro_cuenta,3,2), cccor.cod_moneda),0)) NCTA,
       to_char(nvl(substr(cccor.nro_cuenta,5,6),0)) NSUB,
       nvl(gccli.cod_persona,0) CLIENTE,
       to_number(nvl(to_char(cccor.fec_ult_movimiento,'yyyymmdd'),0)) FECAN,
       to_number(nvl(decode(cccor.cod_cau_cancelacion, 234, 1, 235, 2, 236, 3),0))  MOTIVO

from cc_cta_corrientes cccor, ge_cta_clientes gccli
where cccor.nro_cuenta = gccli.nro_cuenta
and   gccli.relacion like 'P'
and   cccor.cod_cau_cancelacion  is not null;

