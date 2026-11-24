begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into it.ge_par_dinamicos (parametro, val_parametro, cod_modulo, cod_modalidad, cod_oficina, cod_moneda, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_sub_modalidad)
values ('CRE_CHE_CTA_CAN', 'S', null, null, null, null, user, sysdate, user, sysdate, null);
/
commit;
