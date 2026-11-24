CREATE OR REPLACE PROCEDURE IT.GESTTRIGGERS_AUDIT
(
   p_opcion VARCHAR2,
   p_owner  VARCHAR2
) IS

   -- p_opcion = 'D' -> deshabilita los triggers
   -- p_opcion = 'H' -> habilita los triggers
   CURSOR disabletriggerit IS
      SELECT 'alter trigger IT.' || a.object_name || ' disable' sentencia
        FROM all_objects a
       WHERE a.owner = 'IT'
         AND a.object_type = 'TRIGGER'
         AND a.object_name LIKE 'AA_%'
         AND a.object_name NOT IN ('AA_GE_CLIENTES', 'AA_CX_EMBARQUES', 'AA_CX_CUOTAS',
              'AA_MD_CTA_DOCUMENTOS', 'AA_MD_DOC_DETALLES', 'AA_CS_CONTRATOS',
              'AA_CS_CON_CUOTAS', 'AA_CS_CAJ_SEGURIDAD', 'AA_GE_PROCESOS_DET');

   CURSOR enabletriggerit IS
      SELECT 'alter trigger IT.' || a.object_name || ' enable' sentencia
        FROM all_objects a
       WHERE a.owner = 'IT'
         AND a.object_type = 'TRIGGER'
         AND a.object_name LIKE 'AA_%'
         AND a.object_name NOT IN ('AA_RH_EMPLEADOS','AB_RH_EMPLEADOS','TA_RH_EMPLEADOS',
                                    'TB_RH_EMPLEADOS');
         
BEGIN
   IF p_opcion = 'D' THEN
      IF p_owner = 'IT' THEN
         FOR dt IN disabletriggerit LOOP
            EXECUTE IMMEDIATE dt.sentencia;
         END LOOP;
      END IF;
   ELSIF p_opcion = 'H' THEN
      IF p_owner = 'IT' THEN
         FOR dt IN enabletriggerit LOOP
            EXECUTE IMMEDIATE dt.sentencia;
         END LOOP;
      END IF;
   END IF;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al ejecutar GESTTRIGGERS_AUDIT:' || SQLERRM);
END gesttriggers_audit;
/

