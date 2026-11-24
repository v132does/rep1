begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_tasas (cod_tasa, descripcion, tip_valor, tipo, aplicar, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, cod_mon_base)
values (455, 'PORCENTAJE COBERTURA FOGAVI', 'P', 'F', 'MO', 'IT', sysdate, 'IT', sysdate, null);

commit;

insert into ge_tas_fechas (cod_tasa, fec_vigencia, cod_oficina, cod_moneda, cod_modulo, cod_modalidad, nro_cuenta, val_maximo, val_minimo, val_base, val_tasa, aplicar, usu_insercion, fec_insercion, usu_modificacion, fec_modificacion, fec_vencimiento, observaciones, val_extension, tip_iva, cod_persona, cod_sub_modalidad, no_actualizable, cod_ente)
values (455, to_date('13-05-2021', 'dd-mm-yyyy'), null, 'GS', 6, 668, null, 999999999.00,1000000.00, 0.00, 0.0100, 'MO', 'IT', sysdate, 'IT', sysdate, null, null, null, null, null, null, 'N', null);

commit;
