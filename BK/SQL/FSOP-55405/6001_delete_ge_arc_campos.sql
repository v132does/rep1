Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
delete from ge_arc_campos where referencia in ('PR_PLA_PRE_APROBADOS','TA_PLA_PRE_APROBADOS');

commit;
