begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
 
update ge_ret_monedas  set can_dias = 0 where cod_retencion = 1 and cod_moneda = 'GS';
update ge_ret_monedas  set can_dias = 3 where cod_retencion = 1 and cod_moneda = 'USD';
update ge_ret_monedas  set can_dias = 1 where cod_retencion = 2 and cod_moneda in('GS', 'USD');
 update ge_ret_monedas  set can_dias = 2 where cod_retencion = 3 and cod_moneda in('GS', 'USD');
 

COMMIT;
/

 
