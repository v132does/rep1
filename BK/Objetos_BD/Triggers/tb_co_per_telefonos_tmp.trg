CREATE OR REPLACE TRIGGER IT.tb_co_per_telefonos_tmp
   BEFORE INSERT ON co_per_telefonos_tmp
   FOR EACH ROW
DECLARE
   -- Variables locales
BEGIN
   IF inserting THEN
      IF :new.cod_per_telefono IS NULL THEN
         --- Generar Código de teléfono de la Persona.
         SELECT s_cod_per_telefono.nextval INTO :new.cod_per_telefono FROM dual;
      END IF;
   END IF;
END tb_co_per_telefonos_tmp;
/

