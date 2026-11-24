begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
delete it.ge_tra_campos a
where a.cod_transaccion = 352
and   a.cod_campo = 'NRO_BOLETA';
/
commit;
