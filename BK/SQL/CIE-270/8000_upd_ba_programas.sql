begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
update ba_programas a
set a.ope_mod_cerrado = 'S'
where a.cod_programa in ('AMDEBCRE','GMCONOPE'); 
commit;
