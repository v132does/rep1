Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
delete from PR_PRE_APROBADOS_TMP where fec_ini_oferta is not null;
delete from TA_LIN_PRE_APROBADO_TMP where fec_ini_oferta is not null;

commit;
