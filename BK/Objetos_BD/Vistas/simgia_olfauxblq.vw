create or replace force view it.simgia_olfauxblq as
select  to_number(nvl(substr(a.nro_cuenta,1,2),0)) SUC,
        to_number(nvl(pai_int.FU_SIM_OBT_TIP_CUENTA_3P(substr(a.nro_cuenta,3,2), (select gcue.cod_moneda from ge_cuentas gcue where gcue.nro_cuenta = a.nro_cuenta)),0)) CTA,
        to_number(nvl(substr(a.nro_cuenta,5,6),0)) SUBCTA,
        ''  Filler,
        to_number(pai_int.FU_SIM_OBT_SEC_MNT_BLQ(trim(a.nro_cuenta))) CONTIANL,
        PAI_INT.FU_SIM_NORM_CADENA(nvl((select gcau.descripcion from ge_causales gcau where gcau.cod_causa = a.cod_causa), ''),17) AUTOR1,
        nvl(a.monto,0) MONTO1,
        to_number(nvl(to_char(a.fec_fin,'yymmdd'),0)) VENCI1,
        to_number(nvl(to_char(a.fec_inicio, 'ddmmyy'),0)) FECHA1,
        0 ESTADO1,

        '' AUTOR2,
        0 MONTO2,
        0 VENCI2,
        0 FECHA2,
        0 ESTADO2,

        '' AUTOR3,
        0 MONTO3,
        0 VENCI3,
        0 FECHA3,
        0 ESTADO3,

        '' AUTOR4,
        0 MONTO4,
        0 VENCI4,
        0 FECHA4,
        0 ESTADO4

from
(select  gblo.nro_cuenta, gblo.monto, rownum fila, gblo.cod_causa, gblo.fec_inicio, gblo.fec_fin
from ge_bloqueos gblo
order by to_number(gblo.nro_cuenta)) a
order by to_number(a.nro_cuenta), CONTIANL;

