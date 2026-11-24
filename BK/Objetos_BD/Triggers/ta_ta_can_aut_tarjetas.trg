CREATE OR REPLACE TRIGGER IT.ta_ta_can_aut_tarjetas
 after INSERT or UPDATE or DELETE
 ON ta_can_aut_tarjetas
 FOR EACH ROW
DECLARE
   v_vigente ta_tarjetas.vigente%TYPE := 'N';
   v_enviado ta_cta_tarjetas_nov.enviado%TYPE := 'N';
BEGIN
   IF inserting THEN
      IF :new.estado = 'P' THEN
         --- Si no tiene tarjeta activa, procesar desde Bancard
         BEGIN
            SELECT 'S'
              INTO v_vigente
              FROM ta_tarjetas tar
             WHERE tar.nro_cuenta = :new.nro_cuenta
               AND fug_obt_cli_principal(tar.nro_cuenta) = tar.cod_persona
               AND tar.vigente = 'S';
         EXCEPTION
            WHEN no_data_found THEN
               BEGIN
                 --DE-2103-Enviar modificaciones de estado (Baja) de las tarjetas en estado NO VIGENTES - DYD-SDSL-3233
                 SELECT distinct 'S'
                   INTO v_vigente                 
                   FROM ta_tarjetas tar
                  WHERE tar.nro_cuenta = :new.nro_cuenta
                    AND fug_obt_cli_principal(tar.nro_cuenta) = tar.cod_persona
                    AND tar.vigente = 'N';
               EXCEPTION
                 WHEN no_data_found THEN
                      v_vigente := 'N';
                 WHEN OTHERS THEN
                   raise_application_error(-20000,'Al obt.tar.no vigente:' || SQLERRM);
               END;
            WHEN too_many_rows THEN
               v_vigente := 'S';
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Al obt.tar.vigente:' || SQLERRM);
         END;
         IF nvl(v_vigente, 'N') = 'N' THEN
            --DE-2103-Enviar modificaciones de estado (Baja) de las tarjetas en estado NO VIGENTES - DYD-SDSL-3233           
            raise_application_error(-20000, 'Cuenta no posee tarjeta principal.');
         END IF;
      END IF;
   END IF;
   IF inserting OR
      updating THEN
      --- Inserta novedad
      BEGIN
         SELECT enviado
           INTO v_enviado
           FROM ta_cta_tarjetas_nov
          WHERE fecha = :new.fecha
            AND nro_cuenta = :new.nro_cuenta;
      EXCEPTION
         WHEN no_data_found THEN
            v_enviado := 'S'; -- para que inserte
         WHEN OTHERS THEN
            v_enviado := 'N';
      END;
      IF nvl(v_enviado, 'N') = 'S' THEN
         DELETE ta_cta_tarjetas_nov
          WHERE fecha = :new.fecha
            AND nro_cuenta = :new.nro_cuenta;
         BEGIN
            INSERT INTO ta_cta_tarjetas_nov
               (fecha, nro_cuenta, observacion)
            VALUES
               (:new.fecha, :new.nro_cuenta, 'No Paga Corriente/Moratorio Permanente.');
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000, 'Al insertar novedad:' || SQLERRM);
         END;
      ELSE
         UPDATE ta_cta_tarjetas_nov
            SET aprobado    = 'N',
                observacion = substr(nvl(observacion, '') ||
                                     '#No Paga Corriente/Moratorio Permanente.', 1, 4000)
          WHERE fecha = :new.fecha
            AND nro_cuenta = :new.nro_cuenta;
         IF NOT SQL%FOUND THEN
            raise_application_error(-20000,
                                    'Novedad para la cuenta ' || :new.nro_cuenta ||
                                     ' ya enviada el día de hoy a Bancard.');
         END IF;
      END IF;
   END IF;
END;
/

