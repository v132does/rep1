CREATE OR REPLACE PROCEDURE IT.PRG_ACT_EST_INI_MOD
 IS
 v_men_error varchar2(4000);
BEGIN
   BEGIN
      dbms_stats.unlock_table_stats(ownname=>'IT',tabname=>'GE_MOVIMIENTOS_NOC');
      
      dbms_stats.gather_table_stats(
         ownname          => 'IT',
         tabname          => 'GE_MOVIMIENTOS_NOC',
         estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
         method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
         cascade          => true
      );
      
      dbms_stats.lock_table_stats(ownname=>'IT',tabname=>'GE_MOVIMIENTOS_NOC');
  EXCEPTION
      WHEN OTHERS THEN
         v_men_error := 'Error Stats NOC: ' || SQLERRM;       
         pag_cie.PR_INS_LOG(v_men_error, it.pag_cie.c_log_WARN, 'AUTONOMOUS_TRANSACTION');
   END;
   update ba_modulos
      set estado = 1
      where cod_modulo <> 2;
END;
/
