CREATE OR REPLACE TRIGGER IT.ta_ge_tas_solicitadas
  AFTER DELETE OR UPDATE
     ON GE_TAS_SOLICITADAS
    FOR EACH ROW
DECLARE
   /*
   || PCCEXECT-33 AT Modulo de exoneración y extorno de comisiones y tasas - Fase 2
   || Si la solicitud es de Tasas de Fechas, insertar en GE_TAS_FECHAS al aprobar el pedido.
   || Si la solicitud es de Tasas de Rangos, insertar en GE_TAS_RANGOS al aprobar el pedido.
   || Si la solicitud es de Transacciones Prohibidas, insertar en GE_TRA_PROHIBIDAS al aprobar el pedido.
   */
   v_cod_circuito wf_circuitos.cod_circuito%TYPE;
   v_cod_tarea    wf_cir_tareas.cod_tarea%TYPE;
BEGIN
   IF updating AND
      :new.estado <> :old.estado THEN
      IF :new.estado = 'A' THEN
         IF :new.tipo = 'F' THEN
            /*
            || PCCEXECT-208
            || CC - Visualizar el importe o porcentaje exonerado
            || USU_INSERCION y USU_MODIFICACION debe ser del que solicita la exoneracion
            || Solicitado por RRAMIREZ el 14/10/2015
            */
            DELETE ge_tas_fechas
             WHERE cod_tasa          = :old.cod_tasa
               AND fec_vigencia      = :old.fec_vigencia
               AND cod_oficina       = :old.cod_oficina
               AND cod_moneda        = :old.cod_moneda
               AND cod_modulo        = :old.cod_modulo
               AND cod_modalidad     = :old.cod_modalidad
               AND nro_cuenta        = :old.nro_cuenta
               AND tip_iva           = :old.tip_iva
               AND cod_persona       = :old.cod_persona
               AND cod_sub_modalidad = :old.cod_sub_modalidad;
            INSERT INTO ge_tas_fechas
               (cod_oficina, cod_tasa, fec_vigencia, cod_moneda, val_minimo, val_maximo, val_tasa,
                val_extension, fec_vencimiento, observaciones, nro_cuenta, cod_modalidad, val_base,
                cod_modulo, aplicar, cod_persona, usu_insercion, usu_modificacion)
            VALUES
               (:old.cod_oficina, :old.cod_tasa, :old.fec_vigencia, :old.cod_moneda,
                :old.val_minimo, :old.val_maximo, :old.val_tasa, :old.val_extension,
                :old.fec_vencimiento, :old.observaciones, :old.nro_cuenta, :old.cod_modalidad,
                :old.val_base, :old.cod_modulo, :old.aplicar, :old.cod_persona,
                :old.usu_insercion, :old.usu_modificacion);
         ELSIF :new.tipo = 'R' THEN
            DELETE ge_tas_rangos
             WHERE cod_tasa          = :old.cod_tasa
               AND fec_vigencia      = :old.fec_vigencia
               AND cod_oficina       = :old.cod_oficina
               AND cod_moneda        = :old.cod_moneda
               AND cod_modulo        = :old.cod_modulo
               AND cod_modalidad     = :old.cod_modalidad
               AND nro_cuenta        = :old.nro_cuenta
               AND val_hasta         = :old.val_hasta
               AND cod_persona       = :old.cod_persona
               AND cod_sub_modalidad = :old.cod_sub_modalidad;
            INSERT INTO ge_tas_rangos
               (cod_oficina, cod_tasa, fec_vigencia, cod_moneda, val_hasta, val_tasa, val_extension,
                fec_vencimiento, observaciones, nro_cuenta, cod_modalidad, cod_modulo, cod_persona,
                usu_insercion, usu_modificacion)
            VALUES
               (:old.cod_oficina, :old.cod_tasa, :old.fec_vigencia, :old.cod_moneda, :old.val_hasta,
                :old.val_tasa, :old.val_extension, :old.fec_vencimiento, :old.observaciones,
                :old.nro_cuenta, :old.cod_modalidad, :old.cod_modulo, :old.cod_persona,
                :old.usu_insercion, :old.usu_modificacion);
         ELSIF :new.tipo = 'P' THEN
            DELETE ge_tra_prohibidas
             WHERE cod_transaccion = :old.cod_transaccion
               AND cod_modulo      = :old.cod_modulo
               AND cod_modalidad   = :old.cod_modalidad
               AND nro_cuenta      = :old.nro_cuenta;
            INSERT INTO ge_tra_prohibidas
               (nro_cuenta, /*cod_persona, cod_oficina, */ cod_modulo, cod_modalidad,
                cod_transaccion, fec_vencimiento, observaciones, usu_insercion, usu_modificacion)
            VALUES
               (:old.nro_cuenta, /*:old.cod_persona, :old.cod_oficina, */ :old.cod_modulo,
                :old.cod_modalidad, :old.cod_transaccion, :old.fec_vencimiento, :old.observaciones,
                :old.usu_insercion, :old.usu_modificacion);
         END IF;
      ELSIF :new.estado IN ('C', 'R') THEN
         BEGIN
            SELECT MAX(cod_circuito)
              INTO v_cod_circuito
              FROM wf_circuitos
             WHERE referencia = :new.nro_sol_tasa
               AND cod_tip_circuito = 49;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error al obtener el numero de Cicuito. ' || SQLERRM);
         END;
         UPDATE wf_circuitos
            SET fec_fin = SYSDATE,
                estado  = :new.estado
          WHERE cod_circuito = v_cod_circuito;
         BEGIN
            SELECT MAX(a.cod_tarea)
              INTO v_cod_tarea
              FROM wf_cir_tareas a
             WHERE cod_circuito = v_cod_circuito
               AND cod_tip_circuito = 49;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error al obtener el codigo de Tarea. ' || SQLERRM);
         END;
         UPDATE wf_cir_tareas a
            SET estado     = :new.estado,
                comentario = 'RECHAZO DE CIRCUITO'
          WHERE a.cod_circuito = v_cod_circuito
            AND a.cod_tip_circuito = 49
            AND a.cod_tarea = v_cod_tarea;
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000,
                              'En TA_GE_TAS_SOLICITADAS. Exoneracion ' ||
                               nvl(:old.nro_sol_tasa, :new.nro_sol_tasa) || '-' || SQLERRM);
END;
/

