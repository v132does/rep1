begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/

insert into ge_parametros (parametro, descripcion, tab_relacion, referencia, observacion, pro_verificacion, permiso, modificable, val_defecto)
values ('MTO_COM_TMIN', 'MONTO COMISION TIGO MINUTOS', 'GE_PAR_DINAMICOS', null, 'Importe Comision de Compra de Minutos Tigo', null, null, 'N', null);

commit;
