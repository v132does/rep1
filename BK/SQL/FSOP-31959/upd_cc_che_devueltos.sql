Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update cc_che_devueltos a
set a.sal_multa = 0
where a.usu_insercion = 'MIGRAV'
and a.sal_multa > 0;
commit;
