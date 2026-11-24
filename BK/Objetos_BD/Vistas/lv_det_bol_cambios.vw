CREATE OR REPLACE FORCE VIEW IT.LV_DET_BOL_CAMBIOS AS
SELECT A.COD_USUARIO, A.FECHA, A.HORA, A.NRO_SECUENCIA
           /*COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO, SUM(NVL(MONTO,0))*/
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.cod_mod_padre <> 7
       AND COD_MONEDA <> 'GS'
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = 'GS') or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
/*     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina*/
union all
     --- operaciones de compra y extracciones atm en el extranjero
    SELECT A.COD_USUARIO, A.FECHA, A.HORA, A.NRO_SECUENCIA/* b.cod_moneda, b.cod_modulo, b.cod_oficina,  sum(nvl(b.monto,0)) monto*/
    FROM  GE_MOVIMIENTOS B,GE_MOVIMIENTOS A
    WHERE A.COD_MOD_PADRE = 9
      AND A.COD_TRA_PADRE IN  ( 374,375,388)  -- COMPRA Y EXTRACCIONES EN EL EXTERIOR, Y TRANSF.HB
      AND A.ESTADO = 'N'
      AND A.COD_TRANSACCION = 503
      AND A.MONTO <> 0
      AND B.COD_MOD_PADRE = 9
      AND B.ESTADO = 'N'
      AND B.COD_TRANSACCION = 602
      AND B.FECHA = A.FECHA
      AND B.COD_USUARIO = A.COD_USUARIO
      AND B.HORA = A.HORA
      AND B.COD_MONEDA <> A.COD_MONEDA
      AND B.MONTO <> 0
      and b.cod_moneda <> 'GS'
/*      group by b.cod_moneda, b.cod_modulo, b.cod_oficina*/
union all
    SELECT A.COD_USUARIO, A.FECHA, A.HORA, A.NRO_SECUENCIA /*COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0))*/
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.cod_mod_padre <> 7
       AND COD_MONEDA <> 'GS'
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = 'GS') or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
 /*    GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina*/
union all
     --- operaciones de compra y extracciones atm en el extranjero
    SELECT  A.COD_USUARIO, A.FECHA, A.HORA, A.NRO_SECUENCIA/*b.cod_moneda, b.cod_modulo, b.cod_oficina,  sum(nvl(b.monto,0)) monto*/
    FROM  GE_MOVIMIENTOS B,GE_MOVIMIENTOS A
    WHERE A.COD_MOD_PADRE IN (5,9,16) -- CAJA O TARJETAS
      AND A.COD_TRA_PADRE IN  ( 186,374,375,388,986,987)  -- COMPRA Y EXTRACCIONES EN EL EXTERIOR --FB. agrego la 186-nomina
      AND A.ESTADO = 'N'
      AND A.COD_TRANSACCION IN (602,978,821)
      AND A.MONTO <> 0
      AND B.COD_MOD_PADRE IN (5,9,16)
      AND B.ESTADO = 'N'
      AND B.COD_TRANSACCION = 503
      AND B.FECHA = A.FECHA
      AND B.COD_USUARIO = A.COD_USUARIO
      AND B.HORA = A.HORA
      AND B.COD_MONEDA <> A.COD_MONEDA
      AND B.MONTO <> 0
      and b.cod_moneda <> 'GS'
/*      group by b.cod_moneda, b.cod_modulo, b.cod_oficina; */
union all --Movimientos con rubros - VENTAS
  SELECT A.COD_USUARIO, A.FECHA, A.HORA, A.NRO_SECUENCIA
--        A.COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO, SUM(NVL(MONTO,0))
      FROM CB_RUBROS X, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND A.COD_MONEDA <> 'GS'
       AND ESTADO = 'N'
       AND A.TIP_MOV_RUBRO= 'D'
       AND X.COD_RUBRO(+) = A.COD_RUBRO
       AND ((SUBSTR(A.COD_RUBRO,-2,2) IN ('98','99')) OR
           (X.COD_MONEDA = 'GS') or
            (SUBSTR(A.COD_RUBRO,1,1) IN ('6','7')))
union all
  SELECT A.COD_USUARIO, A.FECHA, A.HORA, A.NRO_SECUENCIA
--        A.COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO, SUM(NVL(MONTO,0))
      FROM CB_RUBROS X, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND A.COD_MONEDA <> 'GS'
       AND ESTADO = 'N'
       AND A.TIP_MOV_RUBRO= 'C'
       AND X.COD_RUBRO(+) = A.COD_RUBRO
       AND ((SUBSTR(A.COD_RUBRO,-2,2) IN ('98','99')) OR
           (X.COD_MONEDA = 'GS') or
            (SUBSTR(A.COD_RUBRO,1,1) IN ('6','7')))
union all -- Apunte masivo
  SELECT A.COD_USUARIO, A.FECHA, A.HORA, A.NRO_SECUENCIA
      FROM CB_RUBROS X, ge_movimientos a
     WHERE a.COD_MOD_PADRE = 2
       AND A.COD_TRA_PADRE=100
       AND A.COD_MONEDA <> 'GS'
       AND ESTADO = 'N'
       AND A.TIP_MOV_RUBRO= 'D'
       AND A.Cod_Rubro is not null
       AND X.COD_RUBRO = A.COD_RUBRO
       AND SUBSTR(a.COD_RUBRO,1,1) IN ('1','2')
       and exists(select c.* from ge_movimientos c
                   where c.hora=a.hora
                   and c.fecha=a.fecha
                   and c.cod_usuario=a.cod_usuario
                   and c.cod_rubro is not null
                   and c.cod_rubro <> a.cod_rubro
                   AND  (
                         (SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(c.COD_RUBRO,1,1) IN ('6','7'))
                      OR (
                          SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(c.COD_RUBRO,1,1) IN ('1','2')
                          )
                        )
                   )
union all -- Apunte masivo
  SELECT A.COD_USUARIO, A.FECHA, A.HORA, A.NRO_SECUENCIA
      FROM CB_RUBROS X, ge_movimientos a
     WHERE a.COD_MOD_PADRE = 2
       AND A.COD_TRA_PADRE=100
       AND A.COD_MONEDA <> 'GS'
       AND ESTADO = 'N'
       AND A.TIP_MOV_RUBRO= 'C'
       AND A.Cod_Rubro is not null
       AND X.COD_RUBRO = A.COD_RUBRO
       AND SUBSTR(a.COD_RUBRO,1,1) IN ('1','2')
       and exists(select c.* from ge_movimientos c
                   where c.hora=a.hora
                   and c.fecha=a.fecha
                   and c.cod_usuario=a.cod_usuario
                   and c.cod_rubro is not null
                   and c.cod_rubro <> a.cod_rubro
                   AND  (
                         (SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(c.COD_RUBRO,1,1) IN ('6','7'))
                      OR (
                          SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(c.COD_RUBRO,1,1) IN ('1','2')
                          )
                        )
                   )
;

