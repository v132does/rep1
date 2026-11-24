begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
update it.ge_tra_campos a
set a.nro_orden = 1
where a.cod_transaccion = 352
and  a.cod_campo = 'NRO_CUENTA';
/
update it.ge_tra_campos a
set a.nro_orden = 2
where a.cod_transaccion = 352
and  a.cod_campo = 'DES_CUENTA';
/
update it.ge_tra_campos a
set a.nro_orden = 3
where a.cod_transaccion = 352
and  a.cod_campo = 'COD_MONEDA';
/
update it.ge_tra_campos a
set a.nro_orden = 4
where a.cod_transaccion = 352
and  a.cod_campo = 'TOT_DEPOSITO';
/
update it.ge_tra_campos a
set a.nro_orden = 5
where a.cod_transaccion = 352
and  a.cod_campo = 'IMP_CHE_24';
/
update it.ge_tra_campos a
set a.nro_orden = 7
where a.cod_transaccion = 352
and  a.cod_campo = 'IMP_CHE_48';
/
update it.ge_tra_campos a
set a.nro_orden = 8
where a.cod_transaccion = 352
and  a.cod_campo = 'MSJ_CHE_48';
/
update it.ge_tra_campos a
set a.nro_orden = 9
where a.cod_transaccion = 352
and  a.cod_campo = 'IMP_CHE_72';
/
update it.ge_tra_campos a
set a.nro_orden = 10
where a.cod_transaccion = 352
and  a.cod_campo = 'MSJ_CHE_72';
/
commit;
