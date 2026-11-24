create or replace force view it.wv_not_cli_reactivados as
select a.cod_persona,
       (decode(a.usu_modificacion,
               'HBANK',
               'HOMEBANKING',
               decode(des.cod_destino, 3, 'BBVA MOVIL', 'ITGF'))) ORIGEN_REACTIVACION,
       max(trunc(h.fec_modificacion)) FEC_REACTIVACION
  from bw_not_cli_suscriptos  a,
       bw_not_cli_destino     t,
       bw_not_destinos        des,
       bw_not_cli_destino_his h
 where a.cod_persona = t.cod_persona
   and t.fec_modificacion =
       (select max(de.fec_modificacion)
          from bw_not_cli_destino de
         where de.cod_persona = t.cod_persona)
   and des.cod_destino = t.cod_destino
   and des.activo = 'S'
   and (h.cod_persona_new = a.cod_persona or
       h.cod_persona_old = a.cod_persona)
   and trunc(a.fec_suscripcion) < (h.fec_modificacion)
   and h.cod_destino_new = des.cod_destino
   and h.activo_new = 'S'
   and h.activo_old = 'N'
   and exists (select 1
                 from bw_not_cli_destino_his c
                where c.cod_persona_old = a.cod_persona
                  and c.activo_new = 'N')

 group by a.cod_persona,
          (decode(a.usu_modificacion,
                  'HBANK',
                  'HOMEBANKING',
                  decode(des.cod_destino, 3, 'BBVA MOVIL', 'ITGF')));

