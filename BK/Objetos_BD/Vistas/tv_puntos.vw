CREATE OR REPLACE FORCE VIEW IT.TV_PUNTOS AS
SELECT a.val_minimo, a.significado, t.puntos, t.nro_cuenta,
       decode(a.val_maximo, 'C', t.puntos, 'D', t.puntos * -1, 0) movimiento
  FROM (SELECT b.val_minimo, b.significado, b.val_maximo
           FROM ba_cod_referencias b
          WHERE b.dominio = 'TAR_TIP_PUNTOS') a,
       (SELECT SUM(t.puntos) puntos, t.tip_movimiento, t.nro_cuenta
           FROM ta_puntos_dia t, ta_extracto_det d
          WHERE t.nro_cuenta = d.nro_cuenta
            AND t.fec_movimiento > d.fec_cierre
            AND d.fec_cierre = (SELECT MAX(fec_cierre)
                                  FROM ta_extracto_det e
                                 WHERE e.nro_cuenta = d.nro_cuenta)
          GROUP BY t.tip_movimiento, t.nro_cuenta
         UNION
         SELECT t.tot_puntos, 'A', t.nro_cuenta
           FROM ta_extracto_det t
          WHERE t.fec_cierre = (SELECT MAX(fec_cierre)
                                  FROM ta_extracto_det d
                                 WHERE t.nro_cuenta = d.nro_cuenta)) t
 WHERE a.val_minimo = t.tip_movimiento;

