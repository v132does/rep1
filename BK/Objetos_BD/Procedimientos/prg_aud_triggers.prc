CREATE OR REPLACE PROCEDURE IT.prg_aud_triggers(p_accion IN VARCHAR2) IS
   -- p_accion = 'D' -> deshabilita los triggers
   -- p_accion = 'H' -> habilita los triggers
   CURSOR c_desactiva_trigger IS
      SELECT 'alter trigger IT.' || a.object_name || ' disable' sentencia
        FROM all_objects a
       WHERE a.owner = 'IT'
         AND a.object_type = 'TRIGGER'
         AND EXISTS (SELECT 1
                       FROM ba_programas b
                      WHERE a.object_name = b.cod_programa
                        AND b.cod_tip_programa = 7
                        AND nvl(b.ina_cierre, 'N') = 'S');

   CURSOR c_activa_trigger IS
      SELECT 'alter trigger IT.' || a.object_name || ' enable' sentencia
        FROM all_objects a
       WHERE a.owner = 'IT'
         AND a.object_type = 'TRIGGER'
         AND EXISTS (SELECT 1
                       FROM ba_programas b
                      WHERE a.object_name = b.cod_programa
                        AND b.cod_tip_programa = 7
                        AND nvl(b.ina_cierre, 'N') = 'S');

BEGIN
   IF p_accion = 'D' THEN
      FOR dt IN c_desactiva_trigger LOOP
         EXECUTE IMMEDIATE dt.sentencia;
      END LOOP;
   ELSIF p_accion = 'H' THEN
      FOR dt IN c_activa_trigger LOOP
         EXECUTE IMMEDIATE dt.sentencia;
      END LOOP;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al ejecutar PRG_AUD_TRIGGERS:' || SQLERRM);
END prg_aud_triggers;
/

