begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
update ge_transacciones c
   set cod_tasa = 455
 where cod_transaccion = 703
   and cod_modalidad = 668;

commit;
