BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ge_transacciones t set t.cod_tasa = 358 
where t.cod_transaccion = 784 
  and t.cod_modulo=4 
  and cod_modalidad =41 ;

commit;
