CREATE OR REPLACE TRIGGER IT.ta_co_per_telefonos_tmp
   AFTER UPDATE ON co_per_telefonos_tmp
   FOR EACH ROW
DECLARE
   -- Variables locales
BEGIN
   IF updating THEN
      IF :new.estado = 'A' THEN
         --TELEFONO
         BEGIN
            UPDATE ba_telefonos
               SET telefono  = :new.numero,
                   tipo      = :new.tip_telefono,
                   area      = :new.cod_area,
                   interno   = :new.extension,
                   tip_linea = :new.origen,
                   principal = decode(:new.contacto, 'P', 'S', 'N')
             WHERE cod_persona = :new.cod_persona
               AND tipo = :new.tip_telefono
               AND cod_telefono = :new.cod_telefono;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000,
                                       'Error al procesar la actualizacion de Teléfonos; ' ||
                                        SQLERRM);
         END;
         IF SQL%ROWCOUNT < 1 THEN
            BEGIN
               INSERT INTO ba_telefonos
                  (cod_persona, cod_telefono, telefono, tipo, area, interno, tip_linea, principal)
               VALUES
                  (:new.cod_persona, :new.cod_telefono, :new.numero, :new.tip_telefono,
                   :new.cod_area, :new.extension, :new.origen, decode(:new.contacto, 1, 'S', 'N'));
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000,
                                          'Error al procesar la inserción de Teléfonos; ' ||
                                           SQLERRM);
            END;
         END IF;
      END IF;
   END IF;
END ta_co_per_telefonos_tmp;
/

