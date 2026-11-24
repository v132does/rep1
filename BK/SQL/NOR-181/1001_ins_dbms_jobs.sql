BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name            => '"IT"."JOB_PRO_CRC_MENSUAL"',
    job_type            => 'PLSQL_BLOCK',
    job_action          => 
    q'[
      DECLARE
          v_fec_actual             DATE;
          v_ult_dia_mes_habil      DATE;
          v_fecha                  DATE;
          v_base_objetivo          CONSTANT VARCHAR2(11)  := UPPER(TRIM(fug_obt_pardinamico('BA_OBJ_CRC_MENSUAL')));
          v_base_actual            CONSTANT VARCHAR2(11)  := UPPER(TRIM(SYS_CONTEXT('USERENV','DB_NAME')));  
          v_base_prod              CONSTANT VARCHAR2(11)  := UPPER(TRIM(fug_obt_pardinamico('BA_PRO_CRC_CONTROL')));
      BEGIN
          -- Obtener fecha actual desde función
          v_fec_actual := pag_cal.fu_obt_fec_actual(1);

          -- Obtener última fecha del mes hábil
          SELECT ult_dia_mes_habil 
          INTO v_ult_dia_mes_habil
          FROM ge_calendarios 
          WHERE cod_modulo = 1;
          
          --verificar si es finmes 
          IF v_base_actual != v_base_objetivo THEN
            RAISE_APPLICATION_ERROR(-20001, 'Inserción prohibida en base que no sea finmes  |  Base actual: ' || v_base_actual);
          ELSIF v_base_actual = v_base_prod THEN  --Controlar que no se permita insertar en base produccion
           RAISE_APPLICATION_ERROR(-20001, 'Inserción prohibida en base productiva  |  Base actual: ' ||v_base_actual);
          ELSE
            IF v_fec_actual = v_ult_dia_mes_habil THEN
               IT.PRG_EJE_CRC_MENSUAL;   -- Ejecutar proceso   
            ELSE
               RAISE_APPLICATION_ERROR(-20002, 'La fecha actual no es la misma que la del último día hábil del mes: ' || TO_CHAR(v_fec_actual, 'YYYY-MM-DD'));
            END IF;
          END IF;   

      END;
    ]',
    number_of_arguments => 0,
    start_date          => TO_TIMESTAMP_TZ('2025-10-01 10:00:00 -03:00', 'YYYY-MM-DD HH24:MI:SS TZR'),
    repeat_interval     => 'FREQ=DAILY;BYHOUR=10,11;BYMINUTE=0;BYSECOND=0',
    end_date            => NULL,
    enabled             => FALSE,
    auto_drop           => FALSE,
    comments            => 'Ejecución del orquestador de procesos mensuales 2 vez al dia en el intervalo 6-8am.'
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => '"IT"."JOB_PRO_CRC_MENSUAL"', 
    attribute => 'store_output', 
    value     => TRUE
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => '"IT"."JOB_PRO_CRC_MENSUAL"', 
    attribute => 'logging_level', 
    value     => DBMS_SCHEDULER.LOGGING_OFF
  );

  DBMS_SCHEDULER.ENABLE(
    name => '"IT"."JOB_PRO_CRC_MENSUAL"'
  );
END;
/









