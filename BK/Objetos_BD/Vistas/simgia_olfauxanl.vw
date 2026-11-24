create or replace force view it.simgia_olfauxanl as
select  to_number(nvl(substr(a.nro_cuenta,1,2),0)) SUC,
        nvl(case
         when (select gcue.cod_moneda from ge_cuentas gcue where gcue.nro_cuenta = a.nro_cuenta) like 'GS' then
             700
         else
             709
         end,0) CTA,
         to_number(nvl(substr(a.nro_cuenta,5,6),0)) SUBCTA,
         ' '  Filler, to_number(pai_int.FU_SIM_OBT_SEC_CHE_ANU(trim(a.nro_cuenta))) CONTIANL,
         to_number(nvl(a.nro_cheque,0)) NINIC1,
         0 NFINAL1,
         to_number(nvl(to_char(a.fecha,'ddmmyy'),0)) NFECHANL1,
         0 ESTADOANL1,

         0 NINIC2,
         0 NFINAL2,
         0 NFECHANL2,
         0 ESTADOANL2,

         0 NINIC3,
         0 NFINAL3,
         0 NFECHANL3,
         0 ESTADOANL3,

         0 NINIC4,
         0 NFINAL4,
         0 NFECHANL4,
         0 ESTADOANL4,

         0 NINIC5,
         0 NFINAL5,
         0 NFECHANL5,
         0 ESTADOANL5,

         0 NINIC6,
         0 NFINAL6,
         0 NFECHANL6,
         0 ESTADOANL6


from
(select  cconp.nro_cuenta, cconp.nro_cheque, rownum fila, cconp.fecha
from cc_che_ord_no_pagos cconp
order by to_number(cconp.nro_cuenta)) a
order by to_number(a.nro_cuenta), CONTIANL;

