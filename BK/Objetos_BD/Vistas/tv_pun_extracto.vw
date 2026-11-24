CREATE OR REPLACE FORCE VIEW IT.TV_PUN_EXTRACTO AS
select a.val_minimo, a.significado, a.val_maximo, sum(a.puntos) puntos, a.nro_cuenta, sum(a.movimiento) movimiento
from (
  -- Anterior = Saldo al Cierre--
  select e.fec_cierre fecha,
         b.val_minimo val_minimo, b.significado significado, b.val_maximo,
         e.sal_puntos puntos, e.nro_cuenta nro_cuenta,
         decode(b.val_maximo, 'C', e.sal_puntos, 'D', e.sal_puntos* -1, 0) movimiento
  from ta_cab_extracto e,
       ( SELECT b.val_minimo, b.significado, b.val_maximo
           FROM ba_cod_referencias b
          WHERE b.dominio = 'TAR_TIP_PUNTOS'
            AND b.val_minimo = 'A' ) b
  where e.fec_cierre = ( SELECT MAX(fec_cierre)
                           FROM ta_cab_extracto d
                          WHERE e.nro_cuenta = d.nro_cuenta )
  UNION ALL
  -- Generado por sistema despues del Cierre --
  select l.fec_proceso fecha,
         b.val_minimo val_minimo, b.significado significado, b.val_maximo,
         l.pun_generados puntos, e.nro_cuenta nro_cuenta,
         decode(b.val_maximo, 'C', l.pun_generados, 'D', l.pun_generados*-1, 0) movimiento
  from ta_cab_extracto e, ta_pun_lealtad l,
       ( SELECT b.val_minimo, b.significado, b.val_maximo
           FROM ba_cod_referencias b
          WHERE b.dominio = 'TAR_TIP_PUNTOS'
            AND b.val_minimo = 'S' ) b
  where e.nro_cuenta = l.nro_cuenta
  and l.fec_proceso > e.fec_cierre
  and e.fec_cierre = ( SELECT MAX(fec_cierre)
                           FROM ta_cab_extracto d
                          WHERE l.nro_cuenta = d.nro_cuenta )
  UNION ALL
  -- Canjeados despues del Cierre --
  select l.fec_proceso fecha,
         b.val_minimo val_minimo, b.significado significado, b.val_maximo,
         l.pun_canjeados puntos, e.nro_cuenta nro_cuenta,
         decode(b.val_maximo, 'C', l.pun_canjeados, 'D', l.pun_canjeados*-1, 0) movimiento
  from ta_cab_extracto e, ta_pun_lealtad l,
       ( SELECT b.val_minimo, b.significado, b.val_maximo
           FROM ba_cod_referencias b
          WHERE b.dominio = 'TAR_TIP_PUNTOS'
            AND b.val_minimo = 'C' ) b
  where e.nro_cuenta = l.nro_cuenta
  and l.fec_proceso > e.fec_cierre
  and e.fec_cierre = ( SELECT MAX(fec_cierre)
                           FROM ta_cab_extracto d
                          WHERE l.nro_cuenta = d.nro_cuenta )
  UNION ALL
  -- Vencidos despues del Cierre --
  select l.fec_proceso fecha,
         b.val_minimo val_minimo, b.significado significado, b.val_maximo,
         l.pun_vencidos puntos, e.nro_cuenta nro_cuenta,
         decode(b.val_maximo, 'C', l.pun_vencidos, 'D', l.pun_vencidos*-1, 0) movimiento
  from ta_cab_extracto e, ta_pun_lealtad l,
       ( SELECT b.val_minimo, b.significado, b.val_maximo
           FROM ba_cod_referencias b
          WHERE b.dominio = 'TAR_TIP_PUNTOS'
            AND b.val_minimo = 'V' ) b
  where e.nro_cuenta = l.nro_cuenta
  and l.fec_proceso > e.fec_cierre
  and e.fec_cierre = ( SELECT MAX(fec_cierre)
                           FROM ta_cab_extracto d
                          WHERE l.nro_cuenta = d.nro_cuenta )
  UNION ALL
  -- Baja despues del Cierre --
  select l.fec_proceso fecha,
         b.val_minimo val_minimo, b.significado significado, b.val_maximo,
         l.pun_baja puntos, e.nro_cuenta nro_cuenta,
         decode(b.val_maximo, 'C', l.pun_baja, 'D', l.pun_baja*-1, 0) movimiento
  from ta_cab_extracto e, ta_pun_lealtad l,
       ( SELECT b.val_minimo, b.significado, b.val_maximo
           FROM ba_cod_referencias b
          WHERE b.dominio = 'TAR_TIP_PUNTOS'
            AND b.val_minimo = 'B' ) b
  where e.nro_cuenta = l.nro_cuenta
  and l.fec_proceso > e.fec_cierre
  and e.fec_cierre = ( SELECT MAX(fec_cierre)
                           FROM ta_cab_extracto d
                          WHERE l.nro_cuenta = d.nro_cuenta )
  UNION ALL
  -- Saldo Actual --
  select case
           when l.fec_proceso > e.fec_cierre then
             l.fec_proceso
           else
             e.fec_cierre
         end fecha,
         'Z' val_minimo, 'Saldo Actual' significado, 'Z' val_maximo,
         nvl(l.sal_puntos,e.sal_puntos) puntos, e.nro_cuenta nro_cuenta,
         0 movimiento
    from ta_cab_extracto e, ta_pun_lealtad l
   where e.nro_cuenta = l.nro_cuenta(+)
     and e.fec_cierre = ( SELECT MAX(fec_cierre)
                         FROM ta_cab_extracto d
                        WHERE d.nro_cuenta = e.nro_cuenta )
     and ( l.fec_proceso = ( SELECT MAX(fec_proceso)
                              FROM ta_pun_lealtad d
                             WHERE d.nro_cuenta = l.nro_cuenta )
           or l.fec_proceso is null )
  ) a
GROUP BY a.nro_cuenta, a.val_minimo, a.significado, a.val_maximo
;

