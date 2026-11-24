BEGIN
  -- Si existe lo eliminamos
  BEGIN
    DBMS_SCHEDULER.DROP_JOB(
      job_name => 'IT.JOB_EJECUTA_CRC_DIARIO',
      force    => TRUE
    );
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'IT.JOB_EJECUTA_CRC_DIARIO',
    job_type        => 'PLSQL_BLOCK',
    job_action      => q'[
      DECLARE
        v_id_ejecucion   NUMBER;
        v_estado_final   VARCHAR2(30);
        v_retcode        NUMBER;
        v_retdesc        VARCHAR2(4000);

        v_is_skip        BOOLEAN := FALSE;

        -- Para drenar DBMS_OUTPUT
        l_lines  DBMS_OUTPUT.CHARARR;
        l_num    INTEGER := 1000;
      BEGIN
        -- Ejecuta CRC (modo AUTO)
        IT.PAG_CRC.PRC_EJECUTAR_CRC(
          O_ID_EJECUCION => v_id_ejecucion,
          O_ESTADO_FINAL => v_estado_final,
          O_RETCODE      => v_retcode,
          O_RETDESC      => v_retdesc
        );

        -- Detectar SKIP (ya existe OK)
        IF NVL(v_retcode,0) = 1
           AND v_retdesc LIKE 'Ya existe una ejecución OK para la fecha%' THEN
          v_is_skip := TRUE;
        END IF;

        ------------------------------------------------------------------
        -- DRENAR TODO EL DBMS_OUTPUT generado por procesos internos
        ------------------------------------------------------------------
        LOOP
          DBMS_OUTPUT.GET_LINES(l_lines, l_num);
          EXIT WHEN l_num = 0;
          l_num := 1000;
        END LOOP;

        ------------------------------------------------------------------
        -- ERROR REAL → marcar FAILED
        ------------------------------------------------------------------
        IF NVL(v_retcode,0) <> 0 AND NOT v_is_skip THEN
          RAISE_APPLICATION_ERROR(
            -20001,
            'CRC FAILED | ID_EJECUCION='||NVL(TO_CHAR(v_id_ejecucion),'NULL')||
            ' | ESTADO='||NVL(v_estado_final,'NULL')||
            ' | RETDESC='||SUBSTR(NVL(v_retdesc,'(sin detalle)'),1,900)
          );
        END IF;

        ------------------------------------------------------------------
        -- OUTPUT LIMPIO (solo una línea final)
        ------------------------------------------------------------------
        IF v_is_skip THEN
          DBMS_OUTPUT.PUT_LINE('SKIP CRC | '||SUBSTR(v_retdesc,1,900));
        ELSE
          DBMS_OUTPUT.PUT_LINE('OK CRC | ID_EJECUCION='||v_id_ejecucion||' | ESTADO='||v_estado_final);
        END IF;

      END;
    ]',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=WEEKLY;BYDAY=MON,TUE,WED,THU,FR;BYHOUR=0,1,2,3,4,5,6,7,8,9,10,11;BYMINUTE=0,15,30,45;BYSECOND=0',
    enabled         => TRUE,
    auto_drop       => FALSE,
    comments        => 'CRC (lun-vie) cada 15 min entre 00:00 y 11:45 - Output limpio'
  );

  -- Logging detallado
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'IT.JOB_EJECUTA_CRC_DIARIO',
    attribute => 'logging_level',
    value     => DBMS_SCHEDULER.LOGGING_FULL
  );

  -- Captura DBMS_OUTPUT (pero drenamos lo interno para que quede limpio)
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'IT.JOB_EJECUTA_CRC_DIARIO',
    attribute => 'store_output',
    value     => TRUE
  );

END;
/