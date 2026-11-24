CREATE OR REPLACE TRIGGER IT.ta_ge_ret_com_intereses
  AFTER DELETE OR UPDATE
     ON GE_RET_COM_INTERESES
    FOR EACH ROW
DECLARE
   /*
   || PCC-RET_COM_INT - Retrocesiones de Comisiones e Intereses
   || Ejecutar el procedimiento PRG_RET_COM_INTERESES,
   || en caso de que se cambie el estado a A/Aprobado.
   */
   v_cod_circuito wf_circuitos.cod_circuito%TYPE;
   v_cod_tarea    wf_cir_tareas.cod_tarea%TYPE;
   v_cod_oficina  ba_oficinas.cod_oficina%TYPE;
BEGIN
   IF updating THEN
      IF :new.estado = 'A' THEN
       	 begin-- Recupera la oficina en la que se encuentra la cuenta
          select cod_oficina
            into v_cod_oficina 
            from ge_cuentas c
           where c.NRO_CUENTA = :NEW.nro_cta_credito;
         exception
          when others then
            v_cod_oficina :=:NEW.nro_cta_credito;
         end;
         prg_ret_com_intereses(nvl(:old.nro_devolucion, :new.nro_devolucion),
                               nvl(:old.cod_modulo, :new.cod_modulo),
                               nvl(:old.cod_modalidad, :new.cod_modalidad),
                               v_cod_oficina,
                               nvl(:old.nro_cta_credito, :new.nro_cta_credito),
                               nvl(:old.cod_moneda, :new.cod_moneda),
                               nvl(:old.cotizacion, :new.cotizacion));
      END IF;
      ---
      IF :new.estado <> :old.estado and :new.estado in ('C','R') THEN
         BEGIN
            SELECT max(cod_circuito)
              INTO v_cod_circuito
              FROM wf_circuitos
             WHERE referencia = :new.nro_devolucion
               AND cod_tip_circuito = 45;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error al obtener el número de Cicuito. ' || SQLERRM);
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
               AND cod_tip_circuito = 45;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Error al obtener el código de Tarea. ' || SQLERRM);
         END;
         UPDATE wf_cir_tareas a
            SET estado     = :new.estado,
                comentario = 'RECHAZO DE CIRCUITO'
          WHERE a.cod_circuito = v_cod_circuito
            AND a.cod_tip_circuito = 45
            AND a.cod_tarea = v_cod_tarea;
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
         raise_application_error(-20000,
                              'En TA_GE_RET_COM_INTERESES. Retrocesión ' ||
                               nvl(:old.nro_devolucion, :new.nro_devolucion) || '-' || SQLERRM);
END;
/

