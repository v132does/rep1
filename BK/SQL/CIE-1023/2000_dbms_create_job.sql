BEGIN
dbms_scheduler.create_job (
        job_name        => 'IT.JOB_DAILY_PRP_PRO_INI_PRE',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'IT.PRP_PRO_INI_PRE', -- Nombre del procedimiento
        start_date      => TRUNC(SYSDATE) + 20/24, -- Comienza hoy a las 20:00 hs
        -- Frecuencia: Diaria (FREQ=DAILY), a las 20 horas (BYHOUR=20), 0 minutos, 0 segundos.
        repeat_interval => 'FREQ=DAILY; BYHOUR=20; BYMINUTE=0; BYSECOND=0',
        end_date        => NULL,
        enabled         => TRUE, -- Se habilita inmediatamente
        comments        => 'Job diario automático para la desconsolidación y borrado de préstamos cancelados el mismo día.'
    );
END;