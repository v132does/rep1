CREATE OR REPLACE TRIGGER IT.ta_co_per_direcciones_tmp
   AFTER UPDATE ON co_per_direcciones_tmp
   FOR EACH ROW
DECLARE
   -- Variables locales
BEGIN
   IF updating THEN
      IF :new.estado = 'A' THEN
         --Direccion
         BEGIN
            UPDATE ba_direcciones
               SET direccion  = :new.calle,
                   tipo       = :new.tip_domicilio,
                   cod_pais   = :new.origen,
                   cod_ciudad = :new.partido,
                   cod_barrio = :new.localidad,
                   numero     = :new.numero,
                   principal  = decode(:new.tip_domicilio, 'P', 'S', 'N')
             WHERE cod_persona = :new.cod_persona
               AND tipo = :new.tip_domicilio
               AND cod_direccion = :new.cod_domicilio;
         EXCEPTION
            WHEN OTHERS THEN
               raise_application_error(-20000,
                                       'Error al procesar la actualizacion de direcciones; ' ||
                                        SQLERRM);
         END;
         IF SQL%ROWCOUNT < 1 THEN
            BEGIN
               INSERT INTO ba_direcciones
                  (cod_persona, cod_direccion, direccion, tipo, cod_pais, cod_ciudad, cod_barrio,
                   numero, principal)
               VALUES
                  (:new.cod_persona, :new.cod_domicilio, :new.calle, :new.tip_domicilio,
                   :new.origen, :new.partido, :new.localidad, :new.numero,
                   decode(:new.cod_domicilio, 1, 'S', 'N'));
            EXCEPTION
               WHEN OTHERS THEN
                  raise_application_error(-20000,
                                          'Error al procesar la inserción de direcciones; ' ||
                                           SQLERRM);
            END;
         END IF;
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al procesar ta_co_per_direcciones_tmp; ' || SQLERRM);
   
END ta_co_per_direcciones_tmp;
/

