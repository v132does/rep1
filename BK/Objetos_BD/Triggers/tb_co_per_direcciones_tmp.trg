CREATE OR REPLACE TRIGGER IT.tb_co_per_direcciones_tmp
   BEFORE INSERT ON co_per_direcciones_tmp
   FOR EACH ROW
DECLARE
   -- Variables locales
BEGIN
   IF inserting THEN
      IF :new.cod_per_direccion IS NULL THEN
         --- Generar Código de dirección de la Persona.
         SELECT s_cod_per_direccion.nextval INTO :new.cod_per_direccion FROM dual;
      END IF;
   END IF;
END tb_co_per_direcciones_tmp;
/

