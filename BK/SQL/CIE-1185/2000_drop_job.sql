BEGIN
   DBMS_SCHEDULER.DROP_JOB (
      job_name => 'IT.JOB_DAILY_PRP_PRO_INI_PRE',
      force    => TRUE
   );
EXCEPTION
   WHEN OTHERS THEN
      -- Opcional: Manejo en caso de que el Job no exista (-27475)
      IF SQLCODE = -27475 THEN
         DBMS_OUTPUT.PUT_LINE('El Job IT.JOB_DAILY_PRP_PRO_INI_PRE no existe.');
      ELSE
         RAISE;
      END IF;
END;
/
