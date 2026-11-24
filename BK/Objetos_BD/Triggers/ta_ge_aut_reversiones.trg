CREATE OR REPLACE TRIGGER IT.TA_GE_AUT_REVERSIONES AFTER UPDATE ON "GE_AUT_REVERSIONES"
FOR EACH ROW
DECLARE

   v_cod_circuito wf_circuitos.cod_circuito%TYPE;
   v_cod_tarea    wf_cir_tareas.cod_tarea%TYPE;
   v_fec_actual   DATE := pag_cal.fu_obt_fec_actual(9);
   v_nro_caja     cj_cajas.nro_caja%TYPE;
   --obtiene el numero de caja del movimiento principal
   FUNCTION lf_obt_nro_caja
   (
      p_fecha       IN DATE,
      p_hora        IN VARCHAR2,
      p_cod_usuario IN VARCHAR2
      
   ) RETURN NUMBER IS
      v_nro_caja NUMBER;
   BEGIN
      SELECT nro_caja
        INTO v_nro_caja
        FROM cj_movimientos c
       WHERE estado = 'N'
         AND fecha = p_fecha
         AND hora = p_hora
         AND cod_usuario = p_cod_usuario
         --AND tipo <> 'N' --No afecta saldo
         AND nro_secuencia = 1;

      IF v_nro_caja IS NULL THEN
         raise_application_error(-20000,
                                 'ERROR: Existe Nro. Caja en movimiento con Fecha: ' || p_fecha ||
                                  ', hora:' || p_hora || ', usuario:' || p_cod_usuario);
      ELSE
         RETURN v_nro_caja;
      END IF;
   EXCEPTION
      WHEN no_data_found THEN

         /* 06/02/2014 PN DI: Se agrega esta busqueda debido a que existen movimientos  
                              cuyo nro de secuencia primero es mayor que 1 (Caja de Operaciones de cambios por Mov. Pendientes) 
                              y no deja aprobar reversar. */                               

       BEGIN
         SELECT nro_caja
          INTO v_nro_caja
          FROM cj_movimientos c
         WHERE estado = 'N'
           AND fecha = p_fecha
           AND hora = p_hora
           AND cod_usuario = p_cod_usuario
           AND nro_secuencia = (select min (nro_secuencia)
                                  from cj_movimientos cj
                                 where cj.estado = 'N'
                                   and cj.fecha = c.fecha
                                   and cj.hora = c.hora
                                   and cj.cod_usuario = c.cod_usuario);
      IF v_nro_caja IS NULL THEN
         raise_application_error(-20000,
                                 'ERROR: Existe Nro. Caja en movimiento con Fecha: ' || p_fecha ||
                                  ', hora:' || p_hora || ', usuario:' || p_cod_usuario);
      ELSE
         RETURN v_nro_caja;
      END IF;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
         raise_application_error(-20000,
                                 'ERROR: No existe movimiento. Fecha: ' || p_fecha || ', hora:' ||
                                  p_hora || ', usuario:' || p_cod_usuario || ', Caja:' || v_nro_caja);
        WHEN OTHERS THEN
           raise_application_error(-20000,
                                   'ERROR: Existen varios movimientos con Fecha: ' || p_fecha ||
                                    ', hora:' || p_hora || ', usuario:' || p_cod_usuario || ', Caja:' ||
                                    v_nro_caja);
      END;
      
          
      WHEN OTHERS THEN
         raise_application_error(-20000,
                                 'ERROR: Existen varios movimientos con Fecha: ' || p_fecha ||
                                  ', hora:' || p_hora || ', usuario:' || p_cod_usuario || ', Caja:' ||
                                  v_nro_caja);
   END lf_obt_nro_caja;

   -- Procedimiento interno para reversar el movimiento si es de caja
   PROCEDURE lp_ver_operacion
   (
      p_fecha       IN DATE,
      p_hora        IN VARCHAR2,
      p_cod_usuario IN VARCHAR2
   ) IS
      v_cod_tra_padre ge_movimientos.cod_transaccion%TYPE;
      v_cod_oficina   cj_movimientos.cod_oficina%TYPE; -- oficina de la caja
      v_estado        NUMBER(1); -- estado de la caja
      v_fec_caja      cj_controles.fecha%TYPE; -- fecha de la caja
      v_sal_actual    NUMBER(18, 2); -- saldo actual de la caja en efectivo
      v_sal_cheques   NUMBER(18, 2); -- saldo actual de la caja en cheques
      v_msj_salida    VARCHAR2(8000); -- mensaje final retornado
      CURSOR cj_movs IS
         SELECT cod_moneda, monto, tipo, tip_monto, tot_detallado, nro_doc_referencia, ROWID,
                nro_documento, cod_mod_padre, cod_mad_padre, cod_tra_padre, fecha, hora, cod_usuario,
                nro_caja -- Agregado para transferencias entre cajas. RABF 19/11/2013
           FROM cj_movimientos
          WHERE cod_usuario = p_cod_usuario --nro_caja = v_nro_caja
            AND hora = p_hora
            AND cod_tra_padre = v_cod_tra_padre
            AND estado = 'N'; -- normal                              
   BEGIN
      v_nro_caja := lf_obt_nro_caja(p_fecha, p_hora, p_cod_usuario);
      BEGIN
         SELECT DISTINCT cod_tra_padre
           INTO v_cod_tra_padre
           FROM cj_movimientos a
          WHERE fecha = p_fecha
            AND hora = p_hora
            AND cod_usuario = p_cod_usuario
            AND nro_caja = v_nro_caja;
      EXCEPTION
         WHEN no_data_found THEN
            raise_application_error(-20000, 'No se encontró transacción padre de Caja. Verifique!!');
         WHEN dup_val_on_index THEN
            raise_application_error(-20000, 'Mas de una transacción padre de Caja. Verifique!!');
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al buscar transacción padre de Caja:' || SQLERRM);
      END;
   
      FOR cj IN cj_movs LOOP
      
         -- Obtengo los datos de la caja x moneda local------------------
         prj_obt_datos_caja(cj.nro_caja, cj.cod_moneda, v_cod_oficina, v_fec_caja, v_estado,
                            v_sal_actual, v_sal_cheques, 'N');
      
         IF v_estado = -1 THEN
            raise_application_error(-20000, 'Caja ' || cj.nro_caja || ' inexistente!!');
         ELSIF v_estado IN (0, 2) THEN
            raise_application_error(-20000,
                                    'Caja ' || cj.nro_caja || ' no esta habilitada para esta Operacion en ' ||
                                     cj.cod_moneda);
         ELSIF v_fec_caja <> v_fec_actual THEN
            raise_application_error(-20000, 'Caja ' || cj.nro_caja || ' no fue habilitada el dia de hoy');
         END IF;
      
         v_msj_salida := fuj_pro_transaccion_200(:new.nro_pedido,
                                                 -- Nro de referencia de la operacion
                                                 cj.nro_caja,
                                                 -- Nro de Caja
                                                 v_cod_tra_padre,
                                                 -- Codigo de transaccion
                                                 cj.nro_documento,
                                                 -- Nro. de Boleta
                                                 cj.hora,
                                                 -- hora de la transaccion a reversar
                                                 :new.concepto, 'S');
         IF instr(v_msj_salida, '~999~') > 0 THEN
            raise_application_error(-20000, 'Pedido:' || v_msj_salida);
         END IF;
      END LOOP;
   END lp_ver_operacion;

   /* Proceso Principal */
BEGIN
   IF updating THEN
      IF :new.estado = 'A' THEN
         IF :new.cod_mod_padre = 9 THEN
            lp_ver_operacion(:new.fecha, :new.hora, :new.cod_usuario);
         ELSE
            prg_rev_operacion(:new.fecha, :new.hora, :new.cod_usuario, :new.cod_mod_padre,
                              :new.cod_mad_padre, :new.cod_tra_padre, :new.usu_insercion,
                              to_char(SYSDATE, 'hh24:mi:ss'), 'N',
                              --Es nocturno.
                              :new.concepto);
         END IF;
      ELSIF :new.estado in ('R','C') THEN
         BEGIN
            SELECT cod_circuito
              INTO v_cod_circuito
              FROM wf_circuitos
             WHERE referencia = :new.nro_pedido
               AND cod_tip_circuito = 105;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error al obtener el número de Cicuito. ' || SQLERRM);
         END;
         BEGIN
            SELECT MAX(a.cod_tarea)
              INTO v_cod_tarea
              FROM wf_cir_tareas a
             WHERE cod_circuito = v_cod_circuito
               AND cod_tip_circuito = 105;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error al obtener el código de Tarea. ' || SQLERRM);
         END;
      
         IF :new.cod_mod_padre = 9 THEN
            v_nro_caja := lf_obt_nro_caja(:new.fecha, :new.hora, :new.cod_usuario);
            UPDATE cj_movimientos
               SET estado = 'N' --Cancela lo reversado
             WHERE fecha = :new.fecha
               AND hora = :new.hora
               AND cod_usuario = :new.cod_usuario
               AND nro_caja = v_nro_caja;
         END IF;
         -- Finaliza el Circuito.
         UPDATE wf_circuitos
            SET fec_fin = SYSDATE,
                estado  = 'C'
          WHERE cod_circuito = v_cod_circuito;
      
         UPDATE wf_cir_tareas a
            SET estado     = 'C',
                comentario = 'RECHAZO DE CIRCUITO'
          WHERE a.cod_circuito = v_cod_circuito
            AND a.cod_tip_circuito = 105
            AND a.cod_tarea = v_cod_tarea;
      END IF;
   END IF;
END;
/

