
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
--
insert into GE_PROCESOs (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, PERMISO)
values (981, 'CHE_RECHBC', 1, 'N', 'P',   'ITGF_ADMINISTRADOR');

insert into GE_PROCESOs (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, PERMISO)
values (982, 'CHE_RECHBC_USD', 1, 'N', 'P',   'ITGF_ADMINISTRADOR');

commit;
