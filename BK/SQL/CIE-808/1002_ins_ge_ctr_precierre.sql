-- Control 1
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '1', 
    'Verificación de clientes y cuentas', 
    'Asignar cliente principal a la cuenta.Derivar caso a Catastro. Mirta Cristaldo. Verificar cual es el cliente principal que le corresponde a la cuenta e insertar si no existe.', 
    4, 'A', 
    q'[SELECT 'Cta.sin Cliente Principal = ' || m.nro_cuenta || ', cod_modulo= ' || m.cod_modulo || ', cod_modalidad= ' || m.cod_modalidad || ', oficina= ' || m.cod_oficina || ', fecha= ' || TO_CHAR(m.fecha, 'DD/MM/YYYY') || ', hora= ' || m.hora || ', cod_usuario= ' || m.cod_usuario || ', nro_secuencia= ' || m.nro_secuencia AS clave
         FROM ge_movimientos m
        WHERE nro_cuenta in (select nro_cuenta from ge_movimientos a where a.nro_cuenta is NOT NULL and nro_cuenta not in (select b.nro_cuenta from ge_cta_clientes b, ge_cuentas c where b.nro_cuenta = c.nro_cuenta and b.relacion = 'P' and b.nro_cuenta = a.nro_cuenta))]'
);

-- Control 2
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '2', 
    'Movimientos con error en la oficina', 
    'Verifica oficina del movimiento. Debe ser igual a la oficina de la cuenta (ge_cta_clientes.cod_oficina)', 
    4, 'A', 
    q'[SELECT DISTINCT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina || ', fecha= ' || TO_CHAR(a.fecha, 'DD/MM/YYYY') AS clave
         FROM ge_movimientos a
        WHERE a.nro_cuenta is NOT NULL AND exists (select 1 from ge_cta_clientes b where b.nro_cuenta = a.nro_cuenta and b.relacion = 'P' and b.cod_oficina <> a.cod_oficina)]'
);

-- Control 3
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '3', 
    'Movimientos con error en la modalidad', 
    'Verifica modalidad en el movimiento, si corresponde. Verificar ge_cta_clientes, maestro de cuentas.', 
    4, 'A', 
    q'[SELECT DISTINCT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ge_movimientos a
        WHERE a.nro_cuenta is NOT NULL AND exists (select 1 from ge_cta_clientes b where b.nro_cuenta = a.nro_cuenta and b.relacion = 'P' and b.cod_modalidad <> a.cod_modalidad)]'
);

-- Control 4
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '4', 
    'Movimientos con error en código del cliente (ge_cta_clientes)', 
    'Asignar cliente principal a la cuenta. Verificar codigo persona y relacion ge_cta_clientes con ba_personas. Derivar caso a Catastro. Mirta Cristaldo. Verificar cual es el cliente principal que le corresponde a la cuenta e insertar si no existe.', 
    4, 'A', 
    q'[SELECT DISTINCT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ge_movimientos a
        WHERE a.nro_cuenta is NOT NULL AND not exists (select 1 from ge_cta_clientes b, ba_personas c where b.nro_cuenta = a.nro_cuenta and b.relacion = 'P' and b.cod_persona = c.cod_persona)]'
);

-- Control 5
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '5', 
    'Movimientos con error en la modalidad u oficina', 
    'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de la de la cuenta.', 
    4, 'A', 
    q'[SELECT DISTINCT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ge_movimientos a
        WHERE a.nro_cuenta is NOT NULL AND not exists (select 1 from ge_cuentas b where b.nro_cuenta = a.nro_cuenta and b.cod_modalidad = a.cod_modalidad and b.cod_oficina = a.cod_oficina)]'
);

-- Control 6
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '6', 
    'Movimientos con error en la moneda', 
    'Se controlan los movimientos cuyo campo cod_moneda, sea diferente a la moneda de la cuenta.', 
    4, 'A', 
    q'[SELECT DISTINCT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad ||', cod_moneda= ' || a.cod_moneda || ', oficina= ' || a.cod_oficina AS clave
         FROM ge_movimientos a
        WHERE exists (select 1 from ge_cuentas b where b.nro_cuenta = a.nro_cuenta and b.cod_moneda <> a.cod_moneda) and (a.cod_tra_padre not in (374) and a.cod_modulo not in (9) and a.cod_modalidad not in (91)) and a.cod_transaccion not in (401) and a.monto is not null]'
);

-- Control 7
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '7', 
    'Movimientos con error en la modalidad u oficina en ah_cta_vistas', 
    'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de la de la cuenta ahorro vista.', 
    4, 'A', 
    q'[SELECT DISTINCT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ge_movimientos a
        WHERE cod_modulo = 3 and cod_modalidad in (31, 334) AND nro_cuenta IS NOT NULL AND not exists (select 1 from ah_cta_vistas b where b.nro_cuenta = a.nro_cuenta and b.cod_modalidad = a.cod_modalidad and b.cod_oficina = a.cod_oficina)]'
);

-- Control 8
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '8', 
    'Movimientos con error en la modalidad u oficina del CDA o Bono', 
    'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de la del CDA o Bono (modalidad 33 36).', 
    4, 'A', 
    q'[SELECT DISTINCT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ge_movimientos a
        WHERE cod_modulo = 3 and cod_modalidad in (33, 36) AND nro_cuenta IS NOT NULL AND not exists (select 1 from ah_cta_certificados b where b.nro_cuenta = a.nro_cuenta and b.cod_modalidad = a.cod_modalidad and b.cod_oficina = a.cod_oficina)]'
);

-- Control 9
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '9', 
    'Movimientos con error en la modalidad u oficina de las cuentas bancarias', 
    'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de cc_cta_bancarias, (modalidad 41).', 
    4, 'A', 
    q'[SELECT DISTINCT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ge_movimientos a
        WHERE cod_modulo = 4 and cod_modalidad <> 41 AND nro_cuenta IS NOT NULL AND not exists (select 1 from cc_cta_bancarias b where b.nro_cuenta = a.nro_cuenta and b.cod_modalidad = a.cod_modalidad and b.cod_oficina = a.cod_oficina)]'
);

-- Control 10
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '10', 
    'Movimientos con error en la modalidad u oficina del préstamo', 
    'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de pr_cta_prestamos.', 
    4, 'A', 
    q'[SELECT DISTINCT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ge_movimientos a
        WHERE cod_modulo = 6 and nvl(a.monto, 0) <> 0 and nro_cuenta is not null and not exists (select 1 from pr_cta_prestamos b where b.nro_cuenta = a.nro_cuenta and b.cod_modalidad = a.cod_modalidad and b.cod_oficina = a.cod_oficina)]'
);

-- Control 11
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '11', 
    'Movimientos con error en la modalidad u oficina de la tarjeta', 
    'Se controlan los movimientos cuyo campo cod_modalidad y cod_oficina, sea diferente al de ta_cta_tarjetas.', 
    4, 'A', 
    q'[SELECT DISTINCT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ge_movimientos a
        WHERE cod_modulo = 5 and nro_cuenta is not null and not exists (select 1 from ta_cta_tarjetas b where b.nro_cuenta = a.nro_cuenta and b.cod_modalidad = a.cod_modalidad and b.cod_oficina = a.cod_oficina)]'
);

-- Control 12
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '12', 
    'Verificación de cuentas con clientes principales en la base', 
    'Se controlan casos donde las cuentas (ge_cuentas, ge_cta_clientes) no tengan el código persona de ge_clientes.', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ge_cuentas a, ge_cta_clientes b, ge_est_cuentas e
        WHERE a.nro_cuenta = b.nro_cuenta and a.estado = e.estado and a.cod_modulo = e.cod_modulo and a.cod_modalidad = e.cod_modalidad and e.activo = 'S' and b.relacion = 'P' and not exists (select 1 from ge_clientes c where c.cod_persona = b.cod_persona)]'
);

-- Control 13
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '13', 
    'Verificación de cuentas con clientes principales en la base', 
    'Se controlan casos donde las cuentas (ge_cuentas, ge_cta_clientes) no tengan cliente principal asignado ge_cta_clientes con relación = P.', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad AS clave
         FROM ge_cuentas a
        WHERE not exists (select 1 from ge_cta_clientes b where b.nro_cuenta = a.nro_cuenta and b.relacion = 'P') and a.estado != 'X' and not exists (select 1 from ge_est_cuentas c where c.cod_modulo = a.cod_modulo and c.descripcion in ('CANCELADO')) and exists (select 1 from ge_movimientos g where g.nro_cuenta = a.nro_cuenta)]'
);

-- Control 14
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '14', 
    'Verifica si existe inconsistencia de modalidad y oficina entre el maestro de ahorro y ge_cuentas', 
    'Se controlan las cuentas cuyo campo cod_modalidad y cod_oficina, sea diferente al del maestro ahorro vista.', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ah_cta_vistas a
        WHERE exists (select 1 from ge_cuentas b where b.nro_cuenta = a.nro_cuenta and (b.cod_modalidad <> a.cod_modalidad or b.cod_oficina <> a.cod_oficina))]'
);

-- Control 15
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '15', 
    'Verifica si existe inconsistencia de modalidad y oficina entre el maestro de certificados y ge_cuentas', 
    'Se controlan las cuentas cuyo campo cod_modalidad y cod_oficina, sea diferente al de ah_cta_certificados.', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ah_cta_certificados a
        WHERE exists (select 1 from ge_cuentas b where b.nro_cuenta = a.nro_cuenta and (b.cod_modalidad <> a.cod_modalidad or b.cod_oficina <> a.cod_oficina))]'
);

-- Control 16
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '16', 
    'Verifica si existe inconsistencia de modalidad y oficina entre el maestro cc_cta_bancarias y ge_cuentas', 
    'Se controlan las cuentas cuyo campo cod_modalidad y cod_oficina, sea diferente al de cc_cta_bancarias.', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM cc_cta_bancarias a
        WHERE exists (select 1 from ge_cuentas b where b.nro_cuenta = a.nro_cuenta and (b.cod_modalidad <> a.cod_modalidad or b.cod_oficina <> a.cod_oficina))]'
);

-- Control 17
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '17', 
    'Verifica si existe inconsistencia de modalidad y oficina entre el maestro pr_cta_prestamos y ge_cuentas', 
    'Se controlan las cuentas cuyo campo cod_modalidad y cod_oficina, sea diferente al de pr_cta_prestamos.', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM pr_cta_prestamos a
        WHERE a.estado <> 'N' and exists (select 1 from ge_cuentas b where b.nro_cuenta = a.nro_cuenta and (b.cod_modalidad <> a.cod_modalidad or b.cod_oficina <> a.cod_oficina))]'
);

-- Control 18
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '18', 
    'Verifica si existe inconsistencia de modalidad y oficina entre el maestro ta_cta_tarjetas y ge_cuentas', 
    'Se controlan las cuentas cuyo campo cod_modalidad y cod_oficina, sea diferente al de ta_cta_tarjetas.', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina= ' || a.cod_oficina AS clave
         FROM ta_cta_tarjetas a
        WHERE exists (select 1 from ge_cuentas b where b.nro_cuenta = a.nro_cuenta and (b.cod_modalidad <> a.cod_modalidad or b.cod_oficina <> a.cod_oficina))]'
);

-- Control 19
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '19', 
    'Movimientos con transacciones inexistentes', 
    'Se controlan que las transacciones de los movimientos existan con la modalidad y cod_transaccion relacionadas en ge_transacciones.', 
    4, 'A', 
    q'[SELECT 'cod_transaccion= ' || a.cod_transaccion || ', cod_modulo= ' || a.cod_modulo || ', cod_modalidad= ' || a.cod_modalidad || ', oficina. ' || a.cod_oficina || ', fecha= ' || TO_CHAR(a.fecha, 'DD/MM/YYYY') || ', hora= ' || a.hora || ', cod_usuario= ' || a.cod_usuario || ', nro_secuencia= ' || a.nro_secuencia AS clave
         FROM ge_movimientos a
        WHERE cod_transaccion is not null and not exists (select 1 from ge_transacciones b where b.cod_modalidad = a.cod_modalidad and b.cod_transaccion = a.cod_transaccion)]'
);

-- Control 20
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '20', 
    'Validación de dirección principal del cliente', 
    'Se controla si el cliente posee más de una dirección (ba_direcciones) marcada como principal.', 
    4, 'A', 
    q'[SELECT 'cod_persona= ' || a.cod_persona AS clave
         FROM ba_direcciones a
        WHERE a.principal = 'S'
     GROUP BY a.cod_persona
       HAVING count(*) > 1]'
);

-- Control 21
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '21', 
    'Validación de teléfono principal del cliente', 
    'Se controla si el cliente posee más de un teléfono (ba_telefonos) marcado como principal.', 
    4, 'A', 
    q'[SELECT 'cod_persona= ' || a.cod_persona AS clave
         FROM ba_telefonos a
        WHERE a.principal = 'S'
     GROUP BY a.cod_persona
       HAVING count(*) > 1]'
);

-- Control 22
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '22', 
    'Verificar cuentas a ser eliminadas pero que tienen relación por FK - para el proceso 94', 
    'Se eliminan los registros de ge_exoneraciones y ge_cuentas_nov', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || prc.nro_cuenta AS clave
         FROM pr_cta_prestamos prc
        WHERE prc.fec_cancelacion = pag_cal.fu_obt_fec_actual(3) and prc.estado = 'N' and exists (select 1 from ge_movimientos mov where mov.fecha = prc.fec_cancelacion and mov.NRO_CUENTA = prc.nro_cuenta and mov.COD_TRA_PADRE = 358 and mov.REVERSADO = 'S') and prc.nro_cuenta in (select b.nro_cuenta from ge_exoneraciones b union select c.nro_cuenta from ge_cuentas_nov c)]'
);

-- Control 23
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '23', 
    'Verificación solicitudes sin tipo de garantía de línea', 
    'Se controla si la solicitud (pr_solicitudes) posee registro relacionado en la tabla pr_lin_tip_garantias', 
    4, 'A', 
    q'[SELECT 'nro_linea= ' || a.nro_linea || ', nro_solicitud= ' || a.nro_solicitud AS clave
         FROM pr_solicitudes a
        WHERE a.nro_linea is not null and not exists (select 1 from pr_lin_tip_garantias b where b.nro_linea = a.nro_linea)]'
);

-- Control 24
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '24', 
    'Verificación de solicitudes cuyo tipo de garantía de línea no tiene el código de garantía indicada', 
    'Se controla que el tipo de garantía esté relacionado correctamente con el código de garantía en pr_garantias', 
    4, 'A', 
    q'[SELECT 'nro_linea= ' || a.nro_linea AS clave
         FROM pr_solicitudes a
        WHERE a.nro_linea is not null and exists (select 1 from pr_lin_tip_garantias b where b.nro_linea = a.nro_linea and b.cod_garantia not in (1, 2) and not exists (select 2 from pr_garantias g where g.cod_garantia = b.cod_garantia))]'
);

-- Control 25
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '25', 
    'Verifica el libro de ventas temporal, comprobantes I', 
    'Se verifica si existen registros en la tabla de libro de ventas cb_lib_compras_det_tmp con el tipo de comprobante “I”', 
    4, 'A', 
    q'[SELECT 'tip_comprobante= ' || t.tip_comprobante AS clave
         FROM cb_lib_compras_det_tmp t
        WHERE t.tip_comprobante = 'I']'
);

-- Control 26
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '26', 
    'Verificar registros duplicados de saldos en inventario', 
    'Verifica si existen más de un registro por nro_cuenta referencia en la tabla de inventarios det', 
    4, 'A', 
    q'[SELECT 'nro_referencia= ' || a.nro_referencia || ', nro_cuenta= ' || a.nro_cuenta AS clave
         FROM cb_sal_inventarios_det a
     GROUP BY a.nro_referencia, a.nro_cuenta
       HAVING count(*) > 1]'
);

-- Control 27
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '27', 
    'Verificar movimientos según procesa control de pra_con_transaccion', 
    'Se controla que el cod_rubro de los movimientos procesados en pra_con_transaccion tengan la configuración de rubro asignada', 
    4, 'A', 
    q'[SELECT 'cod_mod_padre= ' || a.cod_mod_padre || ', cod_mad_padre= ' || a.cod_mad_padre || ', cod_modalidad= ' || a.cod_modalidad || ', cod_tra_padre= ' || a.cod_tra_padre AS clave
         FROM ge_movimientos a
        WHERE a.cod_mod_padre = 9 and a.cod_mad_padre = 91 and a.cod_modalidad = 91 and a.cod_tra_padre = 229 and a.cod_transaccion = 690 and a.tip_mov_rubro <> 'D' and a.cod_rubro is null]'
);

-- Control 28
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '28', 
    'Verifica clientes con oficina distinto a matriz', 
    'Se controla que ge_clientes.cod_oficina sea el de matriz', 
    4, 'A', 
    q'[SELECT 'cod_persona= ' || g.cod_persona || ', cod_oficina= ' || g.cod_oficina AS clave
         FROM ge_clientes g
        WHERE g.cod_oficina != fug_obt_ofi_matriz and exists (select 1 from ge_cta_clientes c where c.cod_persona = g.cod_persona)]'
);

-- Control 29
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '29', 
    'Verificación de cotizaciones', 
    'Verifica si se encuentra registrada la cotización de la moneda fuerte del día', 
    4, 'A', 
    q'[SELECT 'cod_moneda= ' || pag_gen.fu_obt_mon_fuerte || ', fecha= ' || TO_CHAR(fue_obt_fec_calendar(1), 'DD/MM/YYYY') AS clave
         FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM ge_cotizaciones f WHERE f.cod_moneda = pag_gen.fu_obt_mon_fuerte AND f.fecha = fue_obt_fec_calendar(1))]'
);

-- Control 30
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '30', 
    'Verifica que solo exista una tarjeta principal por persona', 
    'Se verifica que las cuentas principales modulo 5 no posean más de una tarjeta vigente (ta_tarjetas)', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || b.nro_cuenta || ', cod_persona= ' || b.cod_persona AS clave
         FROM (select a.nro_cuenta, a.cod_persona, count(*) cantidad from ta_tarjetas a where a.vigente = 'S' and exists (select 0 from ge_cta_clientes c where c.nro_cuenta = a.nro_cuenta and c.cod_persona = a.cod_persona and c.cod_modulo = 5 and c.relacion = 'P' group by c.nro_cuenta, c.cod_persona having count(*) > 1) group by a.nro_cuenta, a.cod_persona having count(*) > 1) b]'
);

-- Control 31
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '31', 
    'Verifica si existe la rutina del movimiento', 
    'Se verifica que la rutina configurada en la transacción del movimiento. Si exista (el procedure)', 
    4, 'A', 
    q'[SELECT 'cod_transaccion= ' || m.cod_transaccion || ' cod_modulo= ' || m.cod_modulo || ' cod_modalidad= ' || m.cod_modalidad || ', cod_oficina= ' || m.cod_oficina AS clave
         FROM ge_movimientos m, ge_transacciones t
        WHERE not exists (select 1 from all_procedures where owner = 'IT' and object_name = t.rutina1) and t.rutina1 is not null and m.cod_modulo = t.cod_modulo and m.cod_modalidad = t.cod_modalidad and m.cod_transaccion = t.cod_transaccion and m.nro_cuenta is not null]'
);

-- Control 32
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '32', 
    'Verifica si existe cuenta con garantía no registrada (cod_garantia not in (1,2,42))', 
    'Verifica si existe cuenta con garantía no registrada en las tablas pr_cta_garantias cc_lin_sob_garantias ta_cta_garantias y cx_cta_garantias', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || c.nro_cuenta || ', cod_modalidad= ' || c.cod_modalidad || ', nro_garantia= ' || x.nro_garantia || ', mto_aplicado= ' || x.mto_aplicado AS clave
         FROM ge_cuentas c, (select cg.nro_cuenta, cg.nro_garantia, cg.cod_garantia, cg.mto_aplicado from pr_cta_garantias cg where (cg.cod_garantia not in (1, 2, 42) and instr(fug_obt_pardinamico('PRE_TIP_GAR_SOLA_FIRMA') || ',', cg.cod_garantia || ',') = 0) and not exists (select 1 from pr_garantias g where g.nro_garantia = cg.nro_garantia) union all select s.nro_cuenta, cg.nro_garantia, cg.cod_garantia, cg.mto_aplicado from cc_lin_sob_garantias cg, cc_lin_sobregiros s where cg.cod_garantia not in (1, 2, 42) and cg.nro_secuencia = s.nro_sec_padre and not exists (select 1 from pr_garantias g where g.nro_garantia = cg.nro_garantia) union all select cg.nro_cuenta, cg.nro_garantia, cg.cod_garantia, cg.mto_aplicado from ta_cta_garantias cg where cg.cod_garantia not in (1, 2, 42) and not exists (select 1 from pr_garantias g where g.nro_garantia = cg.nro_garantia) union all select cg.nro_cuenta, cg.nro_garantia, cg.cod_garantia, cg.mto_aplicado from cx_cta_garantias cg where cg.cod_garantia not in (1, 2, 42) and not exists (select 1 from pr_garantias g where g.nro_garantia = cg.nro_garantia)) x
        WHERE c.nro_cuenta = x.nro_cuenta]'
);

-- Control 33
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '33', 
    'Control de movimientos con cod rubro contable incorrecto', 
    'Se verifica los movimientos con un valor de rubro inválido', 
    4, 'A', 
    q'[SELECT 'fecha= ' || TO_CHAR(fecha, 'DD/MM/YYYY') || ', hora= ' || hora || ', cod_usuario= ' || cod_usuario || ', nro_secuencia= ' || nro_secuencia || ', cod_rubro= ' || cod_rubro || ', cod_moneda= ' || cod_moneda AS clave
         FROM ge_movimientos
        WHERE cod_rubro is not null and not exists (select 0 from cb_rubros b where b.cod_rubro = cod_rubro and b.cod_moneda = cod_moneda)]'
);

-- Control 34
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '34', 
    'Control de verificación por la carga de la cotización', 
    'El query devuelve si en el día actual no se realizó la carga de la cotización de cambios', 
    4, 'A', 
    q'[SELECT 'fecha= ' || TO_CHAR(PAG_CAL.FU_OBT_FEC_ACTUAL(7), 'DD/MM/YYYY') AS clave
         FROM dual c
        WHERE not exists (SELECT 1 FROM ge_cotizaciones c WHERE c.FECHA = PAG_CAL.FU_OBT_FEC_ACTUAL(7))]'
);

-- Control 35
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '35', 
    'Control de configuracion de tasas para cuentas de Ahorro', 
    'Se verifica que las tasas de las cuentas de ah_cta_vistas esten correctamente configuradas en ge_tas_fechas', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ', cod_moneda= ' || a.cod_moneda AS clave
         FROM ah_cta_vistas a
        WHERE (a.estado in ('C', 'A') and (nvl(a.sal_total, 0) <> 0 or nvl(a.sal_retenido, 0) <> 0 or nvl(a.sal_bloqueado, 0) <> 0)) and not exists (SELECT nvl(val_tasa, 0), fec_vigencia, val_minimo, val_maximo FROM ge_tas_fechas WHERE nvl(cod_modulo, nvl(a.cod_modulo, -1)) = nvl(a.cod_modulo, -1) AND nvl(cod_modalidad, nvl(a.cod_modalidad, -1)) = nvl(a.cod_modalidad, -1) AND nvl(cod_sub_modalidad, nvl(fug_obt_cod_sub_modalidad(a.nro_cuenta), -1)) = nvl(fug_obt_cod_sub_modalidad(a.nro_cuenta), -1) AND nvl(cod_oficina, nvl(a.cod_oficina, -1)) = nvl(a.cod_oficina, -1) AND nvl(cod_ente, nvl(fug_obt_ent_pag_sue(a.nro_cuenta), -1)) = nvl(fug_obt_ent_pag_sue(a.nro_cuenta), -1) AND nvl(cod_moneda, nvl(a.cod_moneda, 'x')) = nvl(a.cod_moneda, 'x') and nvl(tip_iva, nvl(fue_obt_per_tip_iva(fug_obt_cli_principal(a.nro_cuenta)), 'x')) = nvl(fue_obt_per_tip_iva(fug_obt_cli_principal(a.nro_cuenta)), 'x') AND cod_tasa = a.cod_tasa AND nro_cuenta IS NULL and cod_persona IS NULL and fec_vigencia <= pag_cal.fu_obt_fec_actual(1))]'
);

-- Control 36
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '36', 
    'Control de verificación cuentas de prestamos que no existen en pr_solicitudes', 
    'El query verifica si las cuentas de prestamos poseen solicitudes vinculadas en pr_solicitudes', 
    5, 'A', 
    q'[SELECT 'nro_cuenta= ' || p.nro_cuenta || ' ,nro_solicitud= ' || p.nro_solicitud AS clave
         FROM pr_cta_prestamos p, ge_est_cuentas e
        WHERE p.cod_modulo = e.cod_modulo and p.cod_modalidad = e.cod_modalidad and p.estado = e.estado and e.activo = 'S' and p.nro_solicitud is not null and nvl(p.fec_ini_rrr, p.fec_inicio) = pag_cal.FU_OBT_FEC_ACTUAL(1) and not exists (select 1 from pr_solicitudes a where a.nro_solicitud = p.nro_solicitud)]'
);

-- Control 37
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '37', 
    'Control de Modalidad diferente entre cuentas y ge_cta_clientes', 
    'En caso de que las cuentas no tengan movimientos puede que no den error pero si llegan a tener movimientos sí pueden afectar procesos del cierre.', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ' cod_modalidad: ' || a.cod_modalidad AS clave
         FROM ge_cuentas a, ge_est_cuentas e
        WHERE a.cod_modulo = e.cod_modulo and a.cod_modalidad = e.cod_modalidad and a.estado = e.estado and e.activo = 'S' and exists (select b.nro_cuenta from ge_cta_clientes b where b.nro_cuenta = a.nro_cuenta and b.cod_modulo = a.cod_modulo and b.cod_modalidad <> a.cod_modalidad and b.relacion = 'P') and exists (select 1 from ge_movimientos where nro_cuenta = a.nro_cuenta)]'
);

-- Control 38
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '38', 
    'Control de movimientos de cuentas vencidas.', 
    'El query devuelve si encuentra diferencia en la modalidad y oficina del movimiento comparandolo con el maestro de cuentas vencidas.', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ' cod_modalidad: ' || a.cod_modalidad || ', fecha= ' || TO_CHAR(a.fecha, 'DD/MM/YYYY') || ', hora= ' || a.hora || ', cod_usuario= ' || a.cod_usuario || ', nro_secuencia= ' || a.nro_secuencia AS clave
         FROM ge_movimientos a
        WHERE cod_modulo = 15 AND nro_cuenta IS NOT NULL and not exists (select 1 from ov_cta_vencidas b where b.nro_cuenta = a.nro_cuenta and b.cod_modalidad = a.cod_modalidad and b.cod_oficina = a.cod_oficina)]'
);

-- Control 39
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '39', 
    'Control cuentas con mas de un cliente pincipal', 
    'El query devuelve si encuentra mas de un cliente pincipal por cuenta en ge_cta_clientes', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ' cod_persona: ' || a.cod_persona || ' relacion: ' || a.relacion AS clave
         FROM ge_cta_clientes a
        WHERE a.relacion = 'P' AND a.nro_cuenta IN (SELECT nro_cuenta FROM ge_cta_clientes WHERE relacion = 'P' GROUP BY nro_cuenta HAVING COUNT(*) > 1)]'
);

-- Control 40
INSERT INTO GE_CON_PROCESOS (COD_CONTROL, DESCRIPCION, OBSERVACION, PRIORIDAD, ESTADO, SQL_CONTROL) VALUES (
    '40', 
    'Control de cuentas combinadas', 
    'El query verifica si existen cuentas combinadas con la modalidad 334', 
    4, 'A', 
    q'[SELECT 'nro_cuenta= ' || a.nro_cuenta || ' cod_modalidad= ' || a.cod_modalidad || ' cod_modulo= ' || a.cod_modulo AS clave
         FROM ah_cta_vistas a
        WHERE a.cod_modulo = 3 and a.cod_modalidad = 334 and a.cta_combinada = 'S']'
);

COMMIT;
