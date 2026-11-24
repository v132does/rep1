begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/

DELETE from GE_ARC_CAMPOS
where nom_tabla = 'PR_PRE_CHE_ROGA_TMP'
AND ARCHIVO = 'PR_PLA_CHE_ROGA.XLS'
AND REFERENCIA = 'PR_PRE_CHE_ROGA';

commit;