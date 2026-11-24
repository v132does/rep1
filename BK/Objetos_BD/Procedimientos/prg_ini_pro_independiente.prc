CREATE OR REPLACE PROCEDURE IT.prg_ini_pro_independiente IS
   CURSOR procesos IS
      SELECT DISTINCT cod_proceso
        FROM ba_usuarios bau, ba_usu_roles bar, ge_procesos gep
       WHERE bau.cod_usuario = USER
         AND bau.cod_usuario = bar.cod_usuario
         AND gep.tipo IN ('N', 'R', 'T', 'M')
         AND instr(gep.permiso, bar.cod_rol) > 0;
   PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transacción
BEGIN
   FOR p IN procesos LOOP
      UPDATE ge_procesos
         SET hor_inicio = NULL, hor_fin = NULL, cod_usuario = NULL, error = NULL
       WHERE tipo IN ('N', 'R', 'T', 'M') -- independiente o reportes o generación de archivos o Múltiples
         AND cod_proceso = p.cod_proceso;
   
      UPDATE ge_procesos_det d
         SET d.hor_inicio = NULL, d.hor_fin = NULL, d.cod_usuario = NULL, error = NULL
       WHERE EXISTS (SELECT 1
                       FROM ge_procesos p
                      WHERE p.cod_proceso = d.cod_proceso
                        AND p.tipo IN ('N', 'R', 'T', 'M')
                        AND p.cod_proceso = p.cod_proceso);
   END LOOP;
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'En prg_ini_pro_independiente. ' || SQLERRM);
END;
/

