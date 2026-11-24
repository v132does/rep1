create or replace force view it.simgia_arley2835 as
select to_number(nvl(to_char(min(ccde.fecha), 'yymmdd'),0)) LEYFECHA,
       to_char(nvl(substr(ccde.nro_cuenta,1,2),0)) LEYSUC,
       to_char(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(ccde.nro_cuenta, 3, 2), ccde.cod_moneda),0)) LEYCTA,
       to_char(nvl(substr(ccde.nro_cuenta, 5, 6),0)) LEYSUB,
       to_char(nvl(ccde.nro_cheque,0)) LEYCHNRO,
       nvl(ccde.monto,0) LEYMONTO,
       nvl((ccde.multa - ccde.sal_multa),0) LEYMULTA

from cc_che_devueltos ccde where ccde.cod_causa = 106
group by ccde.nro_cheque, ccde.nro_cuenta, ccde.monto, ccde.cod_causa, ccde.cod_moneda, ccde.multa, ccde.sal_multa;

