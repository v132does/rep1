begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion)
values ('BLO_CHE_ROGA', 'BLOQUEOS POR CHE ROGA', 'GE_BLOQUEOS', null, 'MARCA IDENTIFICATORIA CHE ROGA', null, null, user, sysdate, user,sysdate);

commit;
