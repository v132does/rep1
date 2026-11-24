BEGIN
    DBMS_SCHEDULER.create_job (
        job_name        => 'IT.JOB_SNP_GEN_MT985_STAT_0800',
        start_date      => SYSTIMESTAMP, 
        repeat_interval => 'FREQ=DAILY; BYDAY=MON,TUE,WED,THU,FRI; BYHOUR=8; BYMINUTE=0; BYSECOND=0',
        auto_drop       => FALSE,
        job_type        => 'PLSQL_BLOCK',
        enabled         => TRUE,
        comments        => 'Envía consulta de saldos MT985/STAT',
        job_action      => 
            q'[BEGIN

    PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1;

    IT.PRS_SNP_GEN_MT985_STAT( p_cod_tip_mensaje  => 'MT985/STAT',
                               p_nro_cta_bancaria =>  FUG_OBT_PARDINAMICO (P_PARAMETRO => 'CTA_FIN_INTERBANCARIA_USD',p_cod_moneda=> 'USD'),
                               p_cod_persona      => '1'
                               );

    IT.PRS_SNP_GEN_MT985_STAT( p_cod_tip_mensaje  => 'MT985/STAT',
                               p_nro_cta_bancaria => FUG_OBT_PARDINAMICO (P_PARAMETRO => 'CTA_FIN_INTERBANCARIA_GS',p_cod_moneda=> 'GS'),
                               p_cod_persona      => '1'
                               );
END;]'
    );
END;
/


BEGIN
    DBMS_SCHEDULER.create_job (
        job_name        => 'IT.JOB_SNP_GEN_MT985_STAT_1805',
        start_date      => SYSTIMESTAMP, 
        repeat_interval => 'FREQ=DAILY; BYDAY=MON,TUE,WED,THU,FRI; BYHOUR=18; BYMINUTE=05; BYSECOND=0',
        auto_drop       => FALSE,
        job_type        => 'PLSQL_BLOCK',
        enabled         => TRUE,
        comments        => 'Envía consulta de saldos MT985/STAT',
        job_action      => 
            q'[BEGIN

    PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1;

    IT.PRS_SNP_GEN_MT985_STAT( p_cod_tip_mensaje  => 'MT985/STAT',
                               p_nro_cta_bancaria =>  FUG_OBT_PARDINAMICO (P_PARAMETRO => 'CTA_FIN_INTERBANCARIA_USD',p_cod_moneda=> 'USD'),
                               p_cod_persona      => '1'
                               );

    IT.PRS_SNP_GEN_MT985_STAT( p_cod_tip_mensaje  => 'MT985/STAT',
                               p_nro_cta_bancaria => FUG_OBT_PARDINAMICO (P_PARAMETRO => 'CTA_FIN_INTERBANCARIA_GS',p_cod_moneda=> 'GS'),
                               p_cod_persona      => '1'
                               );
END;]'
    );
END;
/