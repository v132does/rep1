CREATE OR REPLACE TRIGGER IT.ta_co_per_correos_tmp
   AFTER UPDATE ON co_per_correos_tmp
   FOR EACH ROW
DECLARE
   -- Variables locales
BEGIN
   IF updating THEN
      IF :new.estado = 'A' THEN
         UPDATE ba_personas SET dir_correo = :new.mail WHERE cod_persona = :new.cod_persona;
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en ta_co_per_correos_tmp ' || SQLERRM);
END ta_co_per_correos_tmp;
/

