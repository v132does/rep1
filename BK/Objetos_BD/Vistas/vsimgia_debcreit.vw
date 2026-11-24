create or replace force view it.vsimgia_debcreit as
select sa.fec_proceso
      ,sa.nro_cuenta
      ,sa.itriesgo cod_persona
      ,sa.ittipo
      ,sa.itref
      ,sa.itmonto as mto_deuda
 from simgia_debcreit sa;

