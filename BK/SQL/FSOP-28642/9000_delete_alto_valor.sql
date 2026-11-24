begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
--
delete ge_par_dinamicos where parametro = 'MTO_CHE_RET_CERO' and cod_modulo is not null;

commit;
