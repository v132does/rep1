CREATE OR REPLACE PROCEDURE IT.PRB_EJE_PRO_FIN_DIA_CONTABLE
IS 
BEGIN
     DBMS_SCHEDULER.run_job(
        job_name            => 'IT.JOB_EJE_PRO_FIN_DIA_CONTABLE',
        use_current_session => FALSE
    );
EXCEPTION
    WHEN OTHERS THEN
        prg_ins_log_programas(p_cod_programa => 'PRB_EJE_PRO_320_AUTOMATICO', p_det_error => 'Error al ejecutar el JOB: ' || SQLERRM);
END;