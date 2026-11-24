create or replace force view it.mi_deu_pendientes as
select sa.nro_cuenta
      ,sa.cod_persona
      ,sum(sa.dpmonto) as mto_deuda
      ,trunc(sa.fec_proceso) as fec_proceso
      ,nvl(sa.est_proceso,0) as est_proceso
      ,sa.respuesta
 from simgia_ardeupend sa
 group by sa.nro_cuenta
        ,sa.cod_persona
        ,trunc(sa.fec_proceso)
        ,sa.est_proceso
        ,sa.respuesta;

