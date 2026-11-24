begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into bw_men_respuestas (NOMBRE, DES_MENSAJE, ERROR)
values ('ERR_PRO_PAG_INT', 'Autorizacion De Operaciones: Error De Pago A Proveedores Interbancaria', 'S');

insert into bw_men_respuesta (NOMBRE, DES_MENSAJE, ERROR)
values ('ERR_PRO_PAG_INT', 'Autorizacion De Operaciones: Error De Pago A Proveedores Interbancaria', 'S');

commit;
