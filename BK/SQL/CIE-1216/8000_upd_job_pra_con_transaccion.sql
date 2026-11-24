BEGIN
  -- 1. Actualizamos los horarios a las 9:30, 12:30 y 15:30 todos los días
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'IT.JOB_PRA_CON_TRANSACCIONES',
    attribute => 'REPEAT_INTERVAL',
    value     => 'Freq=DAILY;ByHour=9,12,15,18;ByMinute=30;BySecond=0'
  );

  -- 2. Aseguramos la zona horaria de Paraguay (-03:00) usando formato numérico (Universal)
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'IT.JOB_PRA_CON_TRANSACCIONES',
    attribute => 'START_DATE',
    value     => TO_TIMESTAMP_TZ('26-08-2026 09:00:00 -03:00', 'DD-MM-YYYY HH24:MI:SS TZR')
  );

  -- 3. Actualizamos el comentario para que refleje la nueva realidad
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'IT.JOB_PRA_CON_TRANSACCIONES',
    attribute => 'COMMENTS',
    value     => 'Job que procesa el consolidado de transacciones a las 09:30, 12:30, 15:30 y 18:30 hs.'
  );

  -- 4. Finalmente, lo activamos
  DBMS_SCHEDULER.ENABLE('IT.JOB_PRA_CON_TRANSACCIONES');
END;
/
