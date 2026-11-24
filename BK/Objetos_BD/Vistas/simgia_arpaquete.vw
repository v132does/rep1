create or replace force view it.simgia_arpaquete as
select nvl(gpc.cod_persona,0) PQCLIENTE,
       nvl(gpc.cod_paquete,0) PQCLASE,
       pai_int.FU_SIM_OBT_SEC_ARPAQUETE(to_number(gpcli.cod_persona)) PQSEQ,
       nvl(to_char(gpcli.fec_inicio,'yymmdd'),0) PQFEINI,
       nvl(to_char(gpcli.fec_final,'yymmdd'),0) PQVTO,
       case
       when gpc.cod_modulo != 5 then nvl(to_number(substr(gpc.nro_cuenta,1,2)),0) else 0 end PQSUC,
       case
       when gpc.cod_modulo != 5 then nvl(pai_int.FU_SIM_OBT_TIP_CUENTA(substr(gpc.nro_cuenta,3,2),(select a.cod_moneda from ge_cuentas a where a.nro_cuenta = gpc.nro_cuenta)),0) else 0 end PQCTA,
       case
       when gpc.cod_modulo != 5 then nvl(to_number(substr(gpc.nro_cuenta,5,6)),0) else 0 end PQSUB,
       0 PQFPRICH

from (select * from ge_paq_cuentas order by to_number(cod_persona)) gpc, ge_paq_clientes gpcli
where gpc.cod_paquete = gpcli.cod_paquete
and gpc.cod_persona = gpcli.cod_persona;

