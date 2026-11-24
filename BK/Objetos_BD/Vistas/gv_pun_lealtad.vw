CREATE OR REPLACE FORCE VIEW IT.GV_PUN_LEALTAD AS
select e.fec_cierre,
        l.fec_proceso         fec_ult_mov,
        e.nro_cuenta          nro_cuenta,
        e.sal_puntos          pun_cierre,
        case
          when l.fec_proceso >= e.fec_cierre then
            nvl(l.sal_puntos,0)
          else
            nvl(e.sal_puntos,0)
        end sal_puntos,
        nvl(z.pun_generados,0) pun_generados,
        nvl(z.pun_canjeados,0) pun_canjeados,
        nvl(z.pun_vencidos,0)  pun_vencidos,
        nvl(z.pun_baja,0)      pun_baja
   from ta_cab_extracto e, -- Cierre Extracto
        ta_pun_lealtad l,  -- Ultimo Movimiento
       ( select tce.nro_cuenta,
                sum(tpl.pun_generados) pun_generados,
                sum(tpl.pun_canjeados) pun_canjeados,
                sum(tpl.pun_vencidos)  pun_vencidos,
                sum(tpl.pun_baja)      pun_baja
           from ta_cab_extracto tce, ta_pun_lealtad tpl
          where tce.nro_cuenta = tpl.nro_cuenta(+)
            and tce.fec_cierre = ( SELECT MAX(fec_cierre)
                                   FROM ta_cab_extracto ce
                                  WHERE ce.nro_cuenta = tce.nro_cuenta )
            and tpl.fec_proceso >= ( SELECT MAX(fec_cierre)
                                      FROM ta_cab_extracto ce
                                     WHERE ce.nro_cuenta = tce.nro_cuenta )
           group by  tce.nro_cuenta
       ) z -- Movimiento de puntos despues del ultimo cierre
  where e.nro_cuenta = l.nro_cuenta(+)
    and e.nro_cuenta = z.nro_cuenta(+)
    and e.fec_cierre = ( SELECT MAX(fec_cierre)
                           FROM ta_cab_extracto d
                          WHERE d.nro_cuenta = e.nro_cuenta )
    and ( l.fec_proceso = ( SELECT MAX(fec_proceso)
                              FROM ta_pun_lealtad d
                             WHERE d.nro_cuenta = l.nro_cuenta )
           or l.fec_proceso is null )
;

