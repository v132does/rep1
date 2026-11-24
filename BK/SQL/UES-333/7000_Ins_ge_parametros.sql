begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('COD_SWIFT_ORIGEN_MT940', 'CODIGO DEL SWIFT ORIGEN MT940', 'GE_PAR_DINAMICOS', null, 'Codigo del swift origen MT940', null, null, 'N', null);

commit;