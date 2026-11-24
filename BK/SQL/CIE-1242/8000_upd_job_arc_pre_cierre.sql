BEGIN
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      =>  'IT.JOB_ARC_PRE_CIERRE', 
    attribute => 'job_action',
    value     => 'BEGIN
                    begin pre_ini_aplicacion; 
                    pae_cnf.G_COD_MODULO:=1; end; 
                    IT.PRG_GEN_ASI_CIE_TMP;
                    IT.PRB_GEN_PRE_CIERRE; 
                  END;'
  );
END;
