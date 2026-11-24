begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into wf_grupos ( COD_GRUPO, DESCRIPCION, ESTADO)
values ('1003', 'AUTORIZADORES - CAMARA DE COMPESACIONES', 'A');

commit;
