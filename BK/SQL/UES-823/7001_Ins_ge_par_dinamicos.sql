begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, cod_sub_modalidad)
values ('MTO_COM_TMIN', '5500', null, null, null, null, null);

commit;
