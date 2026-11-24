BEGIN
  -- Crear el job
  DBMS_SCHEDULER.CREATE_JOB (
    job_name        => 'IT.JOB_INS_BA_ENV_CORREOS_HIS',
    job_type        => 'PLSQL_BLOCK',
    job_action      => q'[DECLARE
                          val_parametro ge_par_dinamicos.val_parametro%type:= fug_obt_pardinamico('FEC_VOL_ENV_CORREOS',null,null,null);
                          v_fecha_actual VARCHAR2(5);

                          BEGIN
                              
                          -- Obtener el día actual en formato 'DD'
                          BEGIN
                              SELECT TO_CHAR(pag_cal.fu_obt_fec_actual(1), 'DD')
                                INTO v_fecha_actual
                              FROM DUAL;
                          EXCEPTION
                              WHEN OTHERS THEN
                                 RAISE_APPLICATION_ERROR(-20001, 'Error al obtener la fecha actual: ' || SQLERRM); 
                          END;
                          -- Validar fecha y correr proceso de volcado
                          IF INSTR(','||val_parametro||',' ,  ','||v_fecha_actual||',') > 0 THEN
                              -- Se ejecuta el proceso de pase a historico
                              prg_ins_ba_env_correos_his;
                          END IF;
                          END;]',
    start_date      => to_date('10-04-2024 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),
    repeat_interval => 'FREQ=DAILY; BYHOUR=06; BYMINUTE=30', -- Se ejecutará a las 06:30 horas
    end_date        => NULL,
    enabled         => TRUE,
    comments            => 'Realiza el proceso de inserción a historico de la tabla ba_env_correos.');
END;
/
