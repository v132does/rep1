CREATE OR REPLACE VIEW IT.GV_CON_PRE_CIERRE AS
select '1' codigo,
       'Verificación de clientes y cuentas' descripcion,
       'Asignar cliente principal a la cuenta.Derivar caso a Catastro. Mirta Cristaldo.
       Verificar cual es el cliente principal que le corresponde a la cuenta e insertar si no existe.' observacion,
       'Cta.sin Cliente Principal = ' || m.nro_cuenta || ', cod_modulo= ' ||
       m.cod_modulo || ', cod_modalidad= ' || m.cod_modalidad ||
       ', oficina= ' || m.cod_oficina || ', fecha= ' || m.fecha ||
       ', hora= ' || m.hora || ', cod_usuario= ' || m.cod_usuario ||
       ', nro_secuencia= ' || m.nro_secuencia clave,
       '4' prioridad
  from ge_movimientos m
 where nro_cuenta in
       (select nro_cuenta
          from ge_movimientos a
         where a.nro_cuenta is NOT NULL
           and nro_cuenta not in
               (select b.nro_cuenta
                  from ge_cta_clientes b, ge_cuentas c
                 where b.nro_cuenta = c.nro_cuenta
                   and b.relacion = 'P'
                   and b.nro_cuenta = a.nro_cuenta))

UNION ALL
select distinct '2' codigo,
       'Movimientos con error en la oficina' descripcion,
       'Verifica oficina del movimiento. Debe ser igual a la oficina de la cuenta (ge_cta_clientes.cod_oficina)' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina= ' || a.cod_oficina || ', fecha= ' || a.fecha clave,
       '4' prioridad
  from ge_movimientos a
 where a.nro_cuenta is NOT NULL
   AND exists (select 1
                 from ge_cta_clientes b
                where b.nro_cuenta = a.nro_cuenta
                  and b.relacion = 'P'
                  and b.cod_oficina <> a.cod_oficina)

UNION ALL
select Distinct '3' codigo,
       'Movimientos con error en la modalidad' descripcion,
       'Verifica modalidad en el movimiento, si corresponde. Verificar ge_cta_clientes, maestro de cuentas.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina= ' || a.cod_oficina clave,
       '4' prioridad
  from ge_movimientos a
 where a.nro_cuenta is NOT NULL
   AND exists (select 1
                 from ge_cta_clientes b
                where b.nro_cuenta = a.nro_cuenta
                  and b.relacion = 'P'
                  and b.cod_modalidad <> a.cod_modalidad)
UNION ALL
select Distinct '4' codigo,
       'Movimientos con error en código del cliente (ge_cta_clientes)' descripcion,
       'Asignar cliente principal a la cuenta. Verificar codigo persona y relacion ge_cta_clientes con ba_personas. Derivar caso a Catastro. Mirta Cristaldo.
       Verificar cual es el cliente principal que le corresponde a la cuenta e insertar si no existe.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina= ' || a.cod_oficina clave,
       '4' prioridad
  from ge_movimientos a
 where a.nro_cuenta is NOT NULL
   AND not exists (select 1
                     from ge_cta_clientes b, ba_personas c
                    where b.nro_cuenta = a.nro_cuenta
                      and b.relacion = 'P'
                      and b.cod_persona = c.cod_persona)

UNION ALL
select Distinct '5' codigo,
       'Movimientos con error en la modalidad u oficina' descripcion,
       'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de la de la cuenta.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina= ' || a.cod_oficina clave,
       '4' prioridad
  from ge_movimientos a
 where a.nro_cuenta is NOT NULL
   AND not exists (select 1
                     from ge_cuentas b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.cod_modalidad = a.cod_modalidad
                      and b.cod_oficina = a.cod_oficina)

UNION ALL
select Distinct '6' codigo,
       'Movimientos con error en la moneda' descripcion,
       'Se controlan los movimientos cuyo campo cod_moneda, sea diferente a la moneda de la cuenta.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina= ' || a.cod_oficina clave,
       '4' prioridad
  from ge_movimientos a
 where exists (select 1
                 from ge_cuentas b
                where b.nro_cuenta = a.nro_cuenta
                  and b.cod_moneda <> a.cod_moneda)
   and (a.cod_tra_padre not in (374) and a.cod_modulo not in (9) and
        a.cod_modalidad not in (91))

UNION ALL
select Distinct '7' codigo,
       'Movimientos con error en la modalidad u oficina en ah_cta_vistas' descripcion,
       'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de la de la cuenta ahorro vista.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina= ' || a.cod_oficina clave,
       '4' prioridad
  from ge_movimientos a
 where cod_modulo = 3
   and cod_modalidad in (31, 334)
   AND nro_cuenta IS NOT NULL
   AND not exists (select 1
                     from ah_cta_vistas b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.cod_modalidad = a.cod_modalidad
                      and b.cod_oficina = a.cod_oficina)

UNION ALL
select Distinct '8' codigo,
       'Movimientos con error en la modalidad u oficina del CDA o Bono' descripcion,
       'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de la del CDA o Bono (modalidad 33 36).' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina= ' || a.cod_oficina clave,
       '4' prioridad
  from ge_movimientos a
 where cod_modulo = 3
   and cod_modalidad in (33, 36)
   AND nro_cuenta IS NOT NULL
   AND not exists (select 1
                     from ah_cta_certificados b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.cod_modalidad = a.cod_modalidad
                      and b.cod_oficina = a.cod_oficina)

UNION ALL
select Distinct '9' codigo,
       'Movimientos con error en la modalidad u oficina de las cuentas bancarias' descripcion,
       'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de cc_cta_bancarias, (modalidad 41).' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina= ' || a.cod_oficina clave,
       '4' prioridad
  from ge_movimientos a
 where cod_modulo = 4
   and cod_modalidad <> 41
   AND nro_cuenta IS NOT NULL
   AND not exists (select 1
                     from cc_cta_bancarias b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.cod_modalidad = a.cod_modalidad
                      and b.cod_oficina = a.cod_oficina)

UNION ALL
-- Movimientos con error en la modalidad u oficina del préstamo
select Distinct '10' codigo,
       'Movimientos con error en la modalidad u oficina del préstamo' descripcion,
       'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de pr_cta_prestamos.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina= ' || a.cod_oficina clave,
       '4' prioridad
  from ge_movimientos a
 where cod_modulo = 6
   and nvl(a.monto, 0) <> 0
   and nro_cuenta is not null
   and not exists (select 1
                     from pr_cta_prestamos b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.cod_modalidad = a.cod_modalidad
                      and b.cod_oficina = a.cod_oficina)

UNION ALL
-- Movimientos con error en la modalidad u oficina de la tarjeta
select Distinct '11' codigo,
       'Movimientos con error en la modalidad u oficina de la tarjeta' descripcion,
       'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de ta_cta_tarjetas.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina= ' || a.cod_oficina clave,
       '4' prioridad
  from ge_movimientos a
 where cod_modulo = 5
   and nro_cuenta is not null
   and not exists (select 1
                     from ta_cta_tarjetas b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.cod_modalidad = a.cod_modalidad
                      and b.cod_oficina = a.cod_oficina)

UNION ALL
-- Verificación de cuentas con clientes principales en la base (2do caso)
   select '12' codigo,
          'Verificación de cuentas con clientes principales en la base' descripcion,
          'Se controlan casos donde las cuentas (ge_cuentas, ge_cta_clientes) no tengan el código persona de ge_clientes.' observacion,
          'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo ||
          ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' ||
          a.cod_oficina clave,
          '4' prioridad
  from ge_cuentas a, ge_cta_clientes b, ge_est_cuentas e
 where a.nro_cuenta = b.nro_cuenta
   and a.estado = e.estado
   and a.cod_modulo = e.cod_modulo
   and a.cod_modalidad = e.cod_modalidad
   and e.activo = 'S'
   and b.relacion = 'P'
   and not exists (select 1 
                     from ge_clientes c 
                    where c.cod_persona = b.cod_persona)

UNION ALL
-- Verificación de cuentas con clientes principales en la base (3er caso)
select '13' codigo,
       'Verificación de cuentas con clientes principales en la base' descripcion,
       'Se controlan casos donde las cuentas (ge_cuentas, ge_cta_clientes) no tengan cliente principal asignado ge_cta_clientes con relación = P.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo ||
       ', cod_modalidad= ' || a.cod_modalidad clave,
       '4' prioridad
  from ge_cuentas a
 where not exists (select 1
                     from ge_cta_clientes b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.relacion = 'P')
   and a.estado != 'X'

UNION ALL
-- Verificación de inconsistencia en modalidad y oficina entre el maestro de ahorro y ge_cuentas
select '14' codigo,
       'Verifica si existe inconsistencia de modalidad y oficina entre el maestro de ahorro y ge_cuentas' descripcion,
       'Se controlan las cuentas cuyo campo cod_modalidad y cod_oficina, sea diferente al del maestro ahorro vista.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo ||
       ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' ||
       a.cod_oficina clave,
       '4' prioridad
  from ah_cta_vistas a
 where exists (select 1
                 from ge_cuentas b
                where b.nro_cuenta = a.nro_cuenta
                  and (b.cod_modalidad <> a.cod_modalidad or
                       b.cod_oficina <> a.cod_oficina))

UNION ALL
-- Verificación de inconsistencia en modalidad y oficina entre el maestro de certificados y ge_cuentas
select '15' codigo,
       'Verifica si existe inconsistencia de modalidad y oficina entre el maestro de certificados y ge_cuentas' descripcion,
       'Se controlan las cuentas cuyo campo cod_modalidad y cod_oficina, sea diferente al de ah_cta_certificados.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo ||
       ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' ||
       a.cod_oficina clave,
       '4' prioridad
  from ah_cta_certificados a
 where exists (select 1
                 from ge_cuentas b
                where b.nro_cuenta = a.nro_cuenta
                  and (b.cod_modalidad <> a.cod_modalidad or
                       b.cod_oficina <> a.cod_oficina))

UNION ALL
-- Verificación de inconsistencia en modalidad y oficina entre el maestro cc_cta_bancarias y ge_cuentas
select '16' codigo,
       'Verifica si existe inconsistencia de modalidad y oficina entre el maestro cc_cta_bancarias y ge_cuentas' descripcion,
       'Se controlan las cuentas cuyo campo cod_modalidad y cod_oficina, sea diferente al de cc_cta_bancarias.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo ||
       ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' ||
       a.cod_oficina clave,
       '4' prioridad
  from cc_cta_bancarias a
 where exists (select 1
                 from ge_cuentas b
                where b.nro_cuenta = a.nro_cuenta
                  and (b.cod_modalidad <> a.cod_modalidad or
                       b.cod_oficina <> a.cod_oficina))

UNION ALL
-- Verificación de inconsistencia en modalidad y oficina entre el maestro pr_cta_prestamos y ge_cuentas
select '17' codigo,
       'Verifica si existe inconsistencia de modalidad y oficina entre el maestro pr_cta_prestamos y ge_cuentas' descripcion,
       'Se controlan las cuentas cuyo campo cod_modalidad y cod_oficina, sea diferente al de pr_cta_prestamos.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo ||
       ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' ||
       a.cod_oficina clave,
       '4' prioridad
  from pr_cta_prestamos a
 where a.estado <> 'N'
   and exists (select 1
                 from ge_cuentas b
                where b.nro_cuenta = a.nro_cuenta
                  and (b.cod_modalidad <> a.cod_modalidad or
                       b.cod_oficina <> a.cod_oficina))

UNION ALL
-- Verificación de inconsistencia en modalidad y oficina entre el maestro ta_cta_tarjetas y ge_cuentas
select '18' codigo,
       'Verifica si existe inconsistencia de modalidad y oficina entre el maestro ta_cta_tarjetas y ge_cuentas' descripcion,
       'Se controlan las cuentas cuyo campo cod_modalidad y cod_oficina, sea diferente al de ta_cta_tarjetas.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo ||
       ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' ||
       a.cod_oficina clave,
       '4' prioridad
  from ta_cta_tarjetas a
 where exists (select 1
                 from ge_cuentas b
                where b.nro_cuenta = a.nro_cuenta
                  and (b.cod_modalidad <> a.cod_modalidad or
                       b.cod_oficina <> a.cod_oficina))

UNION ALL
-- Movimientos con transacciones inexistentes
select '19' codigo,
       'Movimientos con transacciones inexistentes' descripcion,
       'Se controlan que las transacciones de los movimientos existan con la modalidad y cod_transaccion relacionadas en ge_transacciones.' observacion,
       'cod_transaccion= ' || a.cod_transaccion || ', cod_modulo= ' ||
       a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||
       ', oficina. ' || a.cod_oficina || ', fecha= ' || a.fecha ||
       ', hora= ' || a.hora || ', cod_usuario= ' || a.cod_usuario ||
       ', nro_secuencia= ' || a.nro_secuencia clave,
       '4' prioridad
  from ge_movimientos a
 where cod_transaccion is not null
   and not exists (select 1
                     from ge_transacciones b
                    where b.cod_modalidad = a.cod_modalidad
                      and b.cod_transaccion = a.cod_transaccion)

UNION ALL
-- Validación de dirección principal del cliente
select '20' codigo,
       'Validación de dirección principal del cliente' descripcion,
       'Se controla si el cliente posee más de una dirección (ba_direcciones) marcada como principal.' observacion,
       'cod_persona= ' || a.cod_persona clave,
       '4' prioridad
  from ba_direcciones a
 where a.principal = 'S'
 group by a.cod_persona
having count(*) > 1

UNION ALL
-- Validación de teléfono principal del cliente
select '21' codigo,
       'Validación de teléfono principal del cliente' descripcion,
       'Se controla si el cliente posee más de un teléfono (ba_telefonos) marcado como principal.' observacion,
       'cod_persona= ' || a.cod_persona clave,
       '4' prioridad
  from ba_telefonos a
 where a.principal = 'S'
 group by a.cod_persona
having count(*) > 1

UNION ALL
-- Verifica ofertas expiradas
select '22' codigo,
       'Verifica ofertas expiradas' descripcion,
       'Se controlan registros de ofertas expiradas que deben ser eliminados del histórico.' observacion,
       'cod_persona= ' || b.cod_persona || ', cod_registro= ' ||
       b.cod_registro || ', fec_consulta= ' || b.fec_consulta clave,
       '4' prioridad
  from ba_per_gen_ofertas b
 where b.cod_persona in
       (select distinct (t.cod_persona)
          from it.pr_pre_aprobados t
         where t.fec_fin_oferta <= pag_cal.fu_obt_fec_actual(3)
           and t.estado in ('C', 'G'))
   and exists (select 1
                 from ba_per_gen_ofertas_his bh
                where bh.cod_registro = b.cod_registro
                  and bh.fec_consulta = b.fec_consulta
                  and bh.cod_persona = b.cod_persona)

UNION ALL
-- Verificar cuentas a ser eliminadas pero que tienen relación por FK - para el proceso 94
select '23' codigo,
       'Verificar cuentas a ser eliminadas pero que tienen relación por FK - para el proceso 94' descripcion,
       'Se eliminan los registros de ge_exoneraciones y ge_cuentas_nov' observacion,
       'nro_cuenta= ' || prc.nro_cuenta clave,
       '4' prioridad
  from pr_cta_prestamos prc
 where prc.fec_cancelacion = pag_cal.fu_obt_fec_actual(3)
   and prc.estado = 'N'
   and exists (select 1
                 from ge_movimientos mov
                where mov.fecha = prc.fec_cancelacion
                  and mov.NRO_CUENTA = prc.nro_cuenta
                  and mov.COD_TRA_PADRE = 358
                  and mov.REVERSADO = 'S')
   and prc.nro_cuenta in (select b.nro_cuenta
                            from ge_exoneraciones b
                          union
                          select c.nro_cuenta
                            from ge_cuentas_nov c)

UNION ALL
-- Verificación solicitudes sin tipo de garantía de línea
select '24' codigo,
       'Verificación solicitudes sin tipo de garantía de línea' descripcion,
       'Se controla si la solicitud (pr_solicitudes) posee registro relacionado en la tabla pr_lin_tip_garantias' observacion,
       'nro_linea= ' || a.nro_linea clave,
       '4' prioridad
  from pr_solicitudes a
 where a.nro_linea is not null
   and not exists (select 1 
                     from pr_lin_tip_garantias b 
                    where b.nro_linea = a.nro_linea)

UNION ALL
-- Verificación de solicitudes cuyo tipo de garantía de línea no tiene el código de garantía indicada
select '25' codigo,
       'Verificación de solicitudes cuyo tipo de garantía de línea no tiene el código de garantía indicada' descripcion,
       'Se controla que el tipo de garantía esté relacionado correctamente con el código de garantía en pr_garantias' observacion,
       'nro_linea= ' || a.nro_linea clave,
       '4' prioridad
  from pr_solicitudes a
 where a.nro_linea is not null
   and exists (select 1
                 from pr_lin_tip_garantias b
                where b.nro_linea = a.nro_linea
                  and b.cod_garantia not in (1, 2)
                  and not exists (select 2
                                   from pr_garantias g
                                  where g.cod_garantia = b.cod_garantia))

UNION ALL
-- Verifica el libro de ventas temporal, comprobantes I
select '26' codigo,
       'Verifica el libro de ventas temporal, comprobantes I' descripcion,
       'Se verifica si existen registros en la tabla de libro de ventas cb_lib_compras_det_tmp con el tipo de comprobante “I”' observacion,
       'tip_comprobante= ' || t.tip_comprobante clave,
       '4' prioridad
  from cb_lib_compras_det_tmp t
 where t.tip_comprobante = 'I'

UNION ALL
-- Verificar registros duplicados de saldos en inventario (2)
select '27' codigo,
       'Verificar registros duplicados de saldos en inventario' descripcion,
       'Verifica si existen más de un registro por nro_cuenta referencia en la tabla de inventarios det' observacion,
       'nro_referencia= ' || a.nro_referencia || ', nro_cuenta= ' ||
       a.nro_cuenta clave,
       '4' prioridad
  from cb_sal_inventarios_det a
 group by a.nro_referencia, a.nro_cuenta
having count(*) > 1

UNION ALL
-- Verificar movimientos según procesa control de pra_con_transaccion
select '28' codigo,
       'Verificar movimientos según procesa control de pra_con_transaccion' descripcion,
       'Se controla que el cod_rubro de los movimientos procesados en pra_con_transaccion tengan la configuración de rubro asignada' observacion,
       'cod_mod_padre= ' || a.cod_mod_padre || ', cod_mad_padre= ' ||
       a.cod_mad_padre || ', cod_modalidad= ' || a.cod_modalidad ||
       ', cod_tra_padre= ' || a.cod_tra_padre clave,
       '4' prioridad
  from ge_movimientos a
 where a.cod_mod_padre = 9
   and a.cod_mad_padre = 91
   and a.cod_modalidad = 91
   and a.cod_tra_padre = 229
   and a.cod_transaccion = 690
   and a.tip_mov_rubro <> 'D'
   and a.cod_rubro is null

UNION ALL
-- Verifica clientes con oficina distinto a matriz
select '29' codigo,
       'Verifica clientes con oficina distinto a matriz' descripcion,
       'Se controla que ge_clientes.cod_oficina sea el de matriz' observacion,
       'cod_persona= ' || g.cod_persona || ', cod_oficina= ' ||
       g.cod_oficina clave,
       '4' prioridad
  from ge_clientes g
 where g.cod_oficina != fug_obt_ofi_matriz
   and exists (select 1 
                 from ge_cta_clientes c 
                where c.cod_persona = g.cod_persona)

-- PRG_CTL_ANT_CIERRE

UNION ALL
-- Verificación de cotizaciones
SELECT '30' AS codigo,
       'Verificación de cotizaciones' AS descripcion,
       'Verifica si se encuentra registrada la cotización de la moneda fuerte del día' AS observacion,
       'cod_moneda= ' || pag_gen.fu_obt_mon_fuerte || ', fecha= ' ||
       fue_obt_fec_calendar(1) AS clave,
       '4' AS prioridad
  FROM DUAL
 WHERE NOT EXISTS (SELECT 1
                     FROM ge_cotizaciones f
                    WHERE f.cod_moneda = pag_gen.fu_obt_mon_fuerte
                      AND f.fecha = fue_obt_fec_calendar(1))

UNION ALL
-- Verifica que solo exista una tarjeta principal por persona
select '31' codigo,
       'Verifica que solo exista una tarjeta principal por persona' descripcion,
       'Se verifica que las cuentas principales modulo 5 no posean más de una tarjeta vigente (ta_tarjetas)' observacion,
       'nro_cuenta= ' || b.nro_cuenta || ', cod_persona= ' || b.cod_persona clave,
       '4' prioridad
  from (select a.nro_cuenta, a.cod_persona, count(*) cantidad
          from ta_tarjetas a
         where a.vigente = 'S'
           and exists (select 0
                         from ge_cta_clientes c
                        where c.nro_cuenta = a.nro_cuenta
                          and c.cod_persona = a.cod_persona
                          and c.cod_modulo = 5
                          and c.relacion = 'P'
                        group by c.nro_cuenta, c.cod_persona
                       having count(*) > 1)
         group by a.nro_cuenta, a.cod_persona
        having count(*) > 1) b

UNION ALL
-- Verifica si existe la rutina del movimiento
select '32' codigo,
       'Verifica si existe la rutina del movimiento' descripcion,
       'Se verifica que la rutina configurada en la transacción del movimiento. Si exista (el procedure)' observacion,
       'cod_transaccion= ' || m.cod_transaccion || ' cod_modulo= ' ||
       m.cod_modulo || ' cod_modalidad= ' || m.cod_modalidad ||
       ', cod_oficina= ' || m.cod_oficina clave,
       '4' prioridad
  from ge_movimientos m, ge_transacciones t
 where not exists (select 1
                     from all_procedures
                    where owner = 'IT'
                      and object_name = t.rutina1)
   and t.rutina1 is not null
   and m.cod_modulo = t.cod_modulo
   and m.cod_modalidad = t.cod_modalidad
   and m.cod_transaccion = t.cod_transaccion
   and m.nro_cuenta is not null

UNION ALL
-- Verifica si existe cuenta con garantía no registrada
select '33' codigo,
       'Verifica si existe cuenta con garantía no registrada (cod_garantia not in (1,2,42))' descripcion,
       'Verifica si existe cuenta con garantía no registrada en las tablas pr_cta_garantias cc_lin_sob_garantias ta_cta_garantias y cx_cta_garantias' observacion,
       'nro_cuenta= ' || c.nro_cuenta || ', cod_modalidad= ' ||
       c.cod_modalidad || ', nro_garantia= ' || x.nro_garantia ||
       ', mto_aplicado= ' || x.mto_aplicado clave,
       '4' prioridad
  from ge_cuentas c,
       (select cg.nro_cuenta,
               cg.nro_garantia,
               cg.cod_garantia,
               cg.mto_aplicado
          from pr_cta_garantias cg
         where (cg.cod_garantia not in (1, 2, 42) and
               instr(fug_obt_pardinamico('PRE_TIP_GAR_SOLA_FIRMA') || ',',
                      cg.cod_garantia || ',') = 0)
           and not exists (select 1
                             from pr_garantias g
                            where g.nro_garantia = cg.nro_garantia)
        union all
        select s.nro_cuenta,
               cg.nro_garantia,
               cg.cod_garantia,
               cg.mto_aplicado
          from cc_lin_sob_garantias cg, cc_lin_sobregiros s
         where cg.cod_garantia not in (1, 2, 42)
           and cg.nro_secuencia = s.nro_sec_padre
           and not exists (select 1
                             from pr_garantias g
                            where g.nro_garantia = cg.nro_garantia)
        union all
        select cg.nro_cuenta,
               cg.nro_garantia,
               cg.cod_garantia,
               cg.mto_aplicado
          from ta_cta_garantias cg
         where cg.cod_garantia not in (1, 2, 42)
           and not exists (select 1
                             from pr_garantias g
                            where g.nro_garantia = cg.nro_garantia)
        union all
        select cg.nro_cuenta,
               cg.nro_garantia,
               cg.cod_garantia,
               cg.mto_aplicado
          from cx_cta_garantias cg
         where cg.cod_garantia not in (1, 2, 42)
           and not exists (select 1
                             from pr_garantias g
                            where g.nro_garantia = cg.nro_garantia)) x
 where c.nro_cuenta = x.nro_cuenta

UNION ALL
-- Control de movimientos con cod rubro contable incorrecto
select '34' codigo,
       'Control de movimientos con cod rubro contable incorrecto' descripcion,
       'Se verifica los movimientos con un valor de rubro inválido' observacion,
       'fecha= ' || fecha || ', hora= ' || hora || ', cod_usuario= ' ||
       cod_usuario || ', nro_secuencia= ' || nro_secuencia ||
       ', cod_rubro= ' || cod_rubro || ', cod_moneda= ' || cod_moneda clave,
       '4' prioridad
  from ge_movimientos
 where cod_rubro is not null
   and not exists (select 0
                     from cb_rubros b
                    where b.cod_rubro = cod_rubro
                      and b.cod_moneda = cod_moneda)

UNION ALL
-- Control de verificación por la carga de la cotización
select '35' codigo,
       'Control de verificación por la carga de la cotización' descripcion,
       'El query devuelve si en el día actual no se realizó la carga de la cotización de cambios' observacion,
       'fecha= ' || PAG_CAL.FU_OBT_FEC_ACTUAL(7) clave,
       '4' prioridad
  from dual c
 where not exists (SELECT 1
                     FROM ge_cotizaciones c
                    WHERE c.FECHA = PAG_CAL.FU_OBT_FEC_ACTUAL(7))

UNION ALL
select '36' codigo,
       'Control de configuracion de tasas para cuentas de Ahorro' descripcion,
       'Se verifica que las tasas de las cuentas de ah_cta_vistas esten correctamente configuradas en ge_tas_fechas' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ', cod_moneda= ' || a.cod_moneda clave,
       '4' prioridad
  from ah_cta_vistas a
 where (a.estado in ('C', 'A') -- cancelados o nuevos con saldos
       and (nvl(a.sal_total, 0) <> 0 or nvl(a.sal_retenido, 0) <> 0 or
       nvl(a.sal_bloqueado, 0) <> 0))
   and not exists (SELECT nvl(val_tasa, 0), fec_vigencia, val_minimo, val_maximo
                     FROM ge_tas_fechas
                    WHERE nvl(cod_modulo, nvl(a.cod_modulo, -1)) =
                          nvl(a.cod_modulo, -1)
                      AND nvl(cod_modalidad, nvl(a.cod_modalidad, -1)) =
                          nvl(a.cod_modalidad, -1)
                      AND nvl(cod_sub_modalidad, nvl(fug_obt_cod_sub_modalidad(a.nro_cuenta), -1)) =
                          nvl(fug_obt_cod_sub_modalidad(a.nro_cuenta), -1)
                      AND nvl(cod_oficina, nvl(a.cod_oficina, -1)) =
                          nvl(a.cod_oficina, -1)
                      AND nvl(cod_ente, nvl(fug_obt_ent_pag_sue(a.nro_cuenta), -1)) =
                          nvl(fug_obt_ent_pag_sue(a.nro_cuenta), -1)
                      AND nvl(cod_moneda, nvl(a.cod_moneda, 'x')) =
                          nvl(a.cod_moneda, 'x')
                      and nvl(tip_iva,
                             nvl(fue_obt_per_tip_iva(fug_obt_cli_principal(a.nro_cuenta)),
                                 'x')) = nvl(fue_obt_per_tip_iva(fug_obt_cli_principal(a.nro_cuenta)),
                                             'x')
                      AND cod_tasa = a.cod_tasa
                      AND nro_cuenta IS NULL
                      and cod_persona IS NULL
                      and fec_vigencia <= pag_cal.fu_obt_fec_actual(1))

UNION ALL
--Verificar cuentas de prestamos que no existen en pr_solicitudes
select '37' codigo,
       'Control de verificación cuentas de prestamos que no existen en pr_solicitudes' descripcion,
       'El query verifica si las cuentas de prestamos poseen solicitudes vinculadas en pr_solicitudes' observacion,
       'nro_cuenta= ' || p.nro_cuenta || ' ,nro_solicitud= ' ||
       p.nro_solicitud clave,
       '5' prioridad
  from pr_cta_prestamos p, ge_est_cuentas e
 where p.cod_modulo = e.cod_modulo
   and p.cod_modalidad = e.cod_modalidad
   and p.estado = e.estado
   and e.activo = 'S'
   and p.nro_solicitud is not null
   and nvl(p.fec_ini_rrr, p.fec_inicio) = pag_cal.FU_OBT_FEC_ACTUAL(1)
   and not exists (select 1
                     from pr_solicitudes a
                    where a.nro_solicitud = p.nro_solicitud)

UNION ALL
--Control de Modalidad diferente entre cuentas y ge_cta_clientes
select '38' codigo,
       'Control de Modalidad diferente entre cuentas y ge_cta_clientes' descripcion,
       'En caso de que las cuentas no tengan movimientos puede que no den error pero si llegan a tener movimientos sí pueden afectar procesos del cierre.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ' cod_modalidad: ' ||
       a.cod_modalidad clave,
       '4' prioridad
  from ge_cuentas a, ge_est_cuentas e
 where a.cod_modulo = e.cod_modulo
   and a.cod_modalidad = e.cod_modalidad
   and a.estado = e.estado
   and e.activo = 'S'
   and exists (select b.nro_cuenta
                 from ge_cta_clientes b
                where b.nro_cuenta = a.nro_cuenta
                  and b.cod_modulo = a.cod_modulo
                  and b.cod_modalidad <> a.cod_modalidad
                  and b.relacion = 'P')

UNION ALL
--movimientos vs maestro cuentas vencidas.
select '39' codigo,
       'Control de movimientos de cuentas vencidas.' descripcion,
       'El query devuelve si encuentra diferencia en la modalidad y oficina del movimiento comparandolo con el maestro de cuentas vencidas.' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ' cod_modalidad: ' ||
       a.cod_modalidad || 'fecha= ' || a.fecha || ', hora= ' || a.hora ||
       ', cod_usuario= ' || a.cod_usuario || ', nro_secuencia= ' ||
       a.nro_secuencia clave,
       '4' prioridad
  from ge_movimientos a
 where cod_modulo = 15
   AND nro_cuenta IS NOT NULL
   and not exists (select 1
                     from ov_cta_vencidas b
                    where b.nro_cuenta = a.nro_cuenta
                      and b.cod_modalidad = a.cod_modalidad
                      and b.cod_oficina = a.cod_oficina)
UNION ALL
select '40' codigo,
       'Control cuentas con mas de un cliente pincipal' descripcion,
       'El query devuelve si encuentra mas de un cliente pincipal por cuenta en ge_cta_clientes' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ' cod_persona: ' || a.cod_persona ||
       ' relacion: ' || a.relacion clave,
       '4' prioridad
  FROM ge_cta_clientes a
 WHERE a.relacion = 'P'
   AND a.nro_cuenta IN (SELECT nro_cuenta
                          FROM ge_cta_clientes
                         WHERE relacion = 'P'
                         GROUP BY nro_cuenta
                        HAVING COUNT(*) > 1)
UNION ALL
SELECT '41' codigo,
       'Control de PK a GE_AUT_PEDIDOS' descripcion,
       'El query verifica si existen más de un registro con el mismo cod_usuario, fecha y hora, que hayan tenido respuesta positiva (P) y estado de (S) el mismo día' observacion,
       'cod_usuario= ' || cod_usuario || ' fecha= ' || fecha || ' hora= ' || hora clave,
       '4' prioridad
  FROM GE_AUT_PEDIDOS
 WHERE (cod_usuario, fecha, hora) IN
       (SELECT cod_usuario, fecha, hora
          FROM ge_aut_pedidos
         WHERE respuesta = 'P'
           AND estado = 'S'
           AND TRUNC(fec_insercion) = TRUNC(SYSDATE))
 GROUP BY cod_usuario, fecha, hora
HAVING COUNT(*) > 1
UNION ALL
SELECT '42' codigo,
       'Control de cuentas combinadas' descripcion,
       'El query verifica si existen cuentas combinadas con la modalidad 334' observacion,
       'nro_cuenta= ' || a.nro_cuenta || ' cod_modalidad= ' || a.cod_modalidad || ' cod_modulo= ' || a.cod_modulo  clave,
       '4' prioridad
  from ah_cta_vistas a
 where a.cod_modulo = 3
   and a.cod_modalidad = 334
   and a.cta_combinada = 'S'
 ORDER BY codigo DESC;
