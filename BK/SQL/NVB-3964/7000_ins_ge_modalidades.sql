begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into it.ge_modalidades (COD_MODULO, COD_MODALIDAD, DESCRIPCION, COD_GRU_CRUZAMIENTO, SIGLA, COD_PRO_CONTABLE, TIPO)
values (10, 149, 'REPO BURSATIL - RECIBIDO', null, null, 10, 'P');
/
commit;
/