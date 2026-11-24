begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
update ge_transacciones_det s
   set s.obligatorio = 'S'
 where cod_modalidad = 663
   and cod_tra_hijo = 709
   and cod_transaccion = 358;

commit;
