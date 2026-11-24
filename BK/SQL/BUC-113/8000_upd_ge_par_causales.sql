begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
update ge_par_causales c set c.val_parametro = 507 where c.cod_causa=59
and c.parametro='COD_CAU_BLO_TRANSACCION';


update ge_par_causales c set c.val_parametro = 604 where c.cod_causa=59
and c.parametro='COD_CAU_DES_TRANSACCION';

commit;
