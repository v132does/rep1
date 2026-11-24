CREATE OR REPLACE TRIGGER IT.tb_ba_rol_programas
   before delete or insert or update
   on ba_rol_programas
   for each row
BEGIN
   IF inserting OR updating THEN
      IF :new.inserta = 'N' AND :new.actualiza = 'N' AND :new.elimina = 'N' 
			   AND :new.consulta = 'N' AND :new.imprime = 'N' THEN
            raise_application_error(-20000, 'Debe asignar al menos un Permiso al Rol o eliminar el registro.');
      END IF;
   END IF;
END;
/

