CREATE OR REPLACE PROCEDURE IT.prg_con_mov_automatico
(
   p_nro_cuenta ge_cuentas.nro_cuenta%TYPE,
   p_fec_desde  IN DATE,
   p_fec_hasta  IN DATE
) IS
   v_nro_cuenta       ge_cuentas.nro_cuenta%TYPE;
   v_ref_swift        ge_movimientos.concepto%TYPE;
   v_ref_mov          ge_movimientos.concepto%TYPE;
   v_nro_conciliacion ge_movimientos.nro_conciliacion%TYPE;
   v_cod_banco        cc_cta_bancarias.cod_banco%TYPE;
   v_existe_swift     VARCHAR2(1);
   v_variable         VARCHAR2(18);

   CURSOR c_swift IS
      SELECT 'S' libro,
             c.nro_cuenta,
             c.cod_moneda,
             d.nro_documento,
             d.tip_movimiento tipo,
             d.monto,
             d.ref_movimiento,
             d.monto cta_monto,
             0 mov_monto,
             d.nro_orden nro_secuencia,
             c.fec_mensaje fecha_s,
             NULL hora_s,
             NULL cod_usuario_s,
             NULL mov_tipo,
             NULL cod_modulo,
             NULL cod_modalidad,
             d.nro_ref_externa,
             d.nro_conciliacion
        FROM ge_ext_swift c, ge_ext_swift_det d
       WHERE c.nro_ref_externa = d.nro_ref_externa
         AND c.nro_cuenta = p_nro_cuenta
         AND c.fec_mensaje BETWEEN nvl(p_fec_desde, to_date('01011900', 'ddmmyyyy')) AND
             nvl(p_fec_hasta, to_date('01012999', 'ddmmyy'))
         AND d.nro_conciliacion IS NULL
         AND (d.ref_movimiento LIKE '%' || v_ref_mov || '%' OR
             d.nro_documento LIKE '%' || v_ref_mov || '%');
   CURSOR c_contabilidad IS
      SELECT 'N',
             m.nro_cuenta,
             m.cod_moneda,
             to_char(m.nro_documento),
             t.tipo,
             m.monto,
             m.concepto,
             0 cta_monto,
             m.monto mov_monto,
             m.nro_secuencia,
             m.fecha,
             m.hora,
             m.cod_usuario,
             m.tipo mov_tipo,
             m.cod_modulo,
             m.cod_modalidad,
             NULL,
             m.nro_conciliacion
        FROM gv_movimientos m, ge_transacciones t
       WHERE m.cod_modulo = t.cod_modulo
         AND m.cod_modalidad = t.cod_modalidad
         AND m.cod_transaccion = t.cod_transaccion
         AND m.cod_modulo = 4
         AND m.cod_modalidad = 45
         AND m.reversado = 'N'
         AND nvl(m.monto, 0) <> 0
         AND m.nro_cuenta = p_nro_cuenta
         AND m.fecha BETWEEN nvl(p_fec_desde, to_date('01011900', 'ddmmyyyy')) AND
             nvl(p_fec_hasta, to_date('01012999', 'ddmmyy'))
         AND m.nro_conciliacion IS NULL;
   v_existe VARCHAR2(1) := 'N';
BEGIN
   v_nro_conciliacion := fue_obt_sig_secuencia('S_NRO_CONCILIACION');

   FOR j IN c_contabilidad LOOP
      BEGIN
         SELECT cod_banco INTO v_cod_banco FROM cc_cta_bancarias WHERE nro_cuenta = p_nro_cuenta;
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error al obtener código del Banco correspondiente a la cuenta.' ||
                                     SQLERRM);
      END;
   
      IF v_cod_banco = 285 THEN
         v_ref_mov := substr(substr(j.concepto, instr(j.concepto, '//') + 2,
                                    instr(substr(j.concepto, instr(j.concepto, '//') + 2), '//') - 1),
                             3);
      
      ELSE
         v_ref_mov := substr(j.concepto, instr(j.concepto, '//') + 2,
                             instr(substr(j.concepto, instr(j.concepto, '//') + 2), '//') - 1); --substr(j.concepto, instr(j.concepto, '//') + 2, instr(j.concepto, '//') - 2);
      
      END IF;
      IF v_ref_mov IS NULL THEN
         v_ref_mov := 'ºº';
      END IF;
   
      FOR i IN c_swift LOOP
         IF i.monto = j.monto THEN
            -- Movimientos del Día
            IF j.mov_tipo = 'D' THEN
               UPDATE ge_movimientos
                  SET nro_conciliacion = v_nro_conciliacion --j.nro_conciliacion
                WHERE fecha = j.fecha
                  AND hora = j.hora
                  AND nro_secuencia = j.nro_secuencia
                  AND cod_usuario = j.cod_usuario;
            
               -- Movimientos del Histórico
            ELSIF j.mov_tipo = 'H' THEN
               UPDATE cc_movimientos_his
                  SET nro_conciliacion = v_nro_conciliacion --j.nro_conciliacion
                WHERE fecha = j.fecha
                  AND hora = j.hora
                  AND nro_secuencia = j.nro_secuencia
                  AND cod_usuario = j.cod_usuario;
               v_existe := 'S';
            END IF;
            IF v_existe = 'S' THEN
               UPDATE ge_ext_swift_det d
                  SET nro_conciliacion = v_nro_conciliacion --i.nro_conciliacion
                WHERE nro_ref_externa = i.nro_ref_externa
                  AND nro_orden = i.nro_secuencia;
            
            END IF;
         END IF;
      END LOOP;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error pp_con_mov_automatico.' || SQLERRM);
END;
/

