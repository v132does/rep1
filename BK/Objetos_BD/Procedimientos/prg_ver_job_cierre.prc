CREATE OR REPLACE PROCEDURE IT.PRG_VER_JOB_CIERRE(P_COD_PROCESO IN GE_PROCESOS.COD_PROCESO%TYPE) AS
/* Configuración por registro en ba_cod_referencias:
   Dominio: JOBS_PARALELOS
   Significado: Control Job Cierre - nombre_programa.
   Va_minimo: nombre jobs
   Val_maximo: Frecuencia de ejecución del programa (D/M)
   Abreviatura: Cod_proceso en el que se dispara. (7, 11, 10, 12)
*/
    
-- Cursor que lee la configuración individual de cada Job
CURSOR c_jobs IS
    SELECT val_minimo  AS nombre_job, 
           val_maximo  AS frecuencia,
           abreviatura AS cod_proceso,
           significado AS descripcion
      FROM ba_cod_referencias
     WHERE dominio = 'JOBS_PARALELOS'
       AND activo  = 'S'
       AND abreviatura = to_char(P_COD_PROCESO);

v_err_individual VARCHAR2(1000);
v_err_buffer     VARCHAR2(32000); -- Acumulador de errores
v_cont_errores   NUMBER := 0;
v_monitorear     boolean := FALSE;
--v_frecuencia     VARCHAR2(1);
v_fec_actual      ge_calendarios.fec_actual%type;
v_ult_dia_mes    ge_calendarios.ult_dia_mes_habil%type;
BEGIN
  --Obtenemos la fecha calendario
  pag_cal.pr_obt_dat_calendar(3);
  v_fec_actual  := pag_cal.g_fec_actual;
  v_ult_dia_mes := pag_cal.G_ULT_DIA_MES_HABIL;
  -- Recorremos cada Job activo configurado
  FOR r_job IN c_jobs LOOP
    v_monitorear := false;
    --Controlamos frecuencia, si es diaria debe monitorear
    if r_job.frecuencia = 'D' then
      v_monitorear := true;
    else
      --si es mensual, validar que sea el ultimo dia habil del mes
      if r_job.frecuencia = 'M' then
        if v_fec_actual = v_ult_dia_mes then
          --controlar solo si es el ultima dia
          v_monitorear := true;
        else
          v_monitorear := false;
        end if;
      end if;
    end if;
    
    if v_monitorear then  
      -- Llamada al validador
      IT.prg_ver_job_dinamico(
        p_pref_job     => r_job.nombre_job,
        p_err_out      => v_err_individual
      );

      -- Si el validador retornó un error, lo acumulamos
      IF v_err_individual IS NOT NULL THEN
        v_cont_errores := v_cont_errores + 1;
        v_err_buffer := v_err_buffer || v_cont_errores || ') ' || v_err_individual || CHR(10);
      END IF;
    end if;
  END LOOP;

  -- Al finalizar el loop, si hubo errores, lanzamos la excepción consolidada
  IF v_cont_errores > 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 
        'Se detectaron fallos en el cierre de jobs. Verificar logs de ejecución en ge_pro_programas_log:' || CHR(10) || v_err_buffer);
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20001 THEN
      RAISE; -- Propagamos nuestra lista de errores consolidada
    ELSE
      RAISE_APPLICATION_ERROR(-20999, 'Error crítico en Orquestador: ' || SQLERRM);
    END IF;
END PRG_VER_JOB_CIERRE;
/
