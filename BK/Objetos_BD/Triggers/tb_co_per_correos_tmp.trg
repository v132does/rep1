CREATE OR REPLACE TRIGGER IT.tb_co_per_correos_tmp
   BEFORE INSERT ON co_per_correos_tmp
   FOR EACH ROW
DECLARE
   -- Variables locales
BEGIN
   IF inserting THEN
      IF :new.cod_per_correo IS NULL THEN
         --- Generar Código de Correo de la Persona.
         SELECT s_cod_per_correo.nextval INTO :new.cod_per_correo FROM dual;
      END IF;
   END IF;
END tb_co_per_correos_tmp;
/

