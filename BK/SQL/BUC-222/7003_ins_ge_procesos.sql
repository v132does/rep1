Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into GE_PROCESOS (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, HOR_INICIO, HOR_FIN)
values (60, 'COM_CARTERA', 1, 'N', 'P', null, null);

commit;
