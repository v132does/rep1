CREATE OR REPLACE PROCEDURE IT.PRE_TAB_DEPURACION (
   P_PROGRAMADO IN VARCHAR2 DEFAULT 'N'
) IS
   v_fecha            date := pag_cal.FU_OBT_FEC_ACTUAL(1);
   v_jobs             NUMBER;
   v_can_job_paralelo NUMBER := 3;
   v_indice           NUMBER;
   v_sentencia        VARCHAR2(4000);
   v_cod_sub_programa ge_pro_paralelos_det.cod_sub_programa%TYPE;
   v_cod_programa     ge_log_procesos.cod_programa%TYPE := 'PRE_EJE_DEPURACION';
   v_can_pro_activos  NUMBER;
   v_can_pro_error    NUMBER;
   v_tiempo           DATE;
   v_nro_grupo        NUMBER;
   
   -- Array indexado con tamaño suficiente
   TYPE t_num_array IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
   t_referencias t_num_array;
   v_ref_count NUMBER := 0;

   FUNCTION lf_ver_reproceso RETURN BOOLEAN IS
      v_tiene_error VARCHAR2(4000);
   BEGIN
      SELECT error
        INTO v_tiene_error
        FROM ge_pro_paralelos_det
       WHERE cod_programa = v_cod_programa
         AND cod_sub_programa = v_cod_sub_programa
         AND fecha = v_fecha
       ORDER BY fec_insercion DESC
       FETCH FIRST 1 ROW ONLY;

      RETURN v_tiene_error IS NOT NULL;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN TRUE;
      WHEN OTHERS THEN
         RAISE_APPLICATION_ERROR(-20001, 'Error en LF_VER_REPROCESO - ' || SQLERRM);
   END;

BEGIN
   v_cod_sub_programa := 'Proceso Principal en Paralelo';
   prg_con_pro_paralelos(v_cod_programa, v_cod_sub_programa, 0, v_fecha, 'I', TO_CHAR(SYSDATE, 'HH24:MI:SS'), NULL);
   v_can_pro_activos := v_can_job_paralelo;   

   -- Ciclo para habilitar los hilos de procesos en paralelo
   FOR v_indice IN 1..v_can_job_paralelo LOOP
      CASE v_indice
         WHEN 1 THEN
            v_cod_sub_programa := 'JOB_1_DEPURACION_GRUPO1';
            v_nro_grupo := 1;
         WHEN 2 THEN
            v_cod_sub_programa := 'JOB_2_DEPURACION_GRUPO2';
            v_nro_grupo := 2;
         WHEN 3 THEN
            v_cod_sub_programa := 'JOB_3_DEPURACION_GRUPO3';
            v_nro_grupo := 3;
      END CASE;

      v_sentencia := 'BEGIN
                       pre_ini_aplicacion;
                       pae_cnf.g_cod_modulo := 1;
                       pae_cnf.g_programa := ''GPPROFIN'';
                       it.pre_eje_depuracion('''||p_programado||''', '||v_nro_grupo||');
                    END;';

      if lf_ver_reproceso then
         dbms_job.submit(v_jobs, v_sentencia);
         v_ref_count := v_ref_count + 1;
         t_referencias(v_ref_count) := v_jobs;
         
         prg_con_pro_paralelos(v_cod_programa, v_cod_sub_programa, v_nro_grupo, v_fecha, 'I', to_char(sysdate, 'HH24:MI:SS'), v_jobs);
         commit;
      end if;
   END LOOP;
 
       -- validar si todos los jobs terminaron
    while v_can_pro_activos > 0 loop
        -- contar jobs activos para el programa paralelo y fecha actual
        select nvl(count(*), 0)
          into v_can_pro_activos
          from user_jobs x
         where upper(what) like '%' || upper('pre_eje_depuracion') || '%'
           and exists (
                select 1
                  from ge_pro_paralelos_det y
                 where y.nro_referencia = x.job
                   and y.fecha = v_fecha
           );

      -- Contar jobs fallidos 
      v_can_pro_error := 0;
      FOR i IN 1..v_ref_count LOOP
         SELECT COUNT(*) INTO v_can_pro_error
         FROM ge_pro_paralelos_det
         WHERE cod_programa = v_cod_programa
           AND fecha = v_fecha
           AND error IS NOT NULL
           AND nro_referencia = t_referencias(i);
      END LOOP;

        -- si hay al menos un error, salir y lanzar error
        if v_can_pro_error > 0 then
            raise_application_error(-20002, 'Al menos un job falló en el proceso paralelo: ' || v_cod_programa);
        end if;

        -- si ya no hay activos, salir del bucle
        if v_can_pro_activos = 0 then
            exit;
        end if;

        -- controla cada 30sg
        v_tiempo := pai_int.smg_sleep('30');
    end loop;
END;
