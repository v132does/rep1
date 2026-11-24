CREATE OR REPLACE FUNCTION IT.fug_obt_fre_proceso(p_cod_programa IN ge_procesos_det.cod_programa%TYPE)
   RETURN VARCHAR2 IS
   v_frecuencia ge_procesos_det.frecuencia%TYPE;
BEGIN
   BEGIN
      SELECT a.frecuencia
        INTO v_frecuencia
        FROM ge_procesos_det a
       WHERE a.cod_proceso = 11
         AND upper(a.cod_programa) = upper(p_cod_programa);
   EXCEPTION
      WHEN no_data_found THEN
         v_frecuencia := 'D';
      WHEN too_many_rows THEN
         raise_application_error(-20000,
                                 'Más de una definición en el cierre para el proceso ' ||
                                  upper(p_cod_programa));
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error en FUG_OBT_FRE_PROCESO:' || SQLERRM);
   END;
   ---
   RETURN(v_frecuencia);
END fug_obt_fre_proceso;
/

