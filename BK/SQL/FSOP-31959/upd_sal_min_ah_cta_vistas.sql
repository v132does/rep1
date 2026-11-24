Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ah_cta_vistas a set a.sal_minimo = 0 where a.sal_minimo != 0;
commit;
