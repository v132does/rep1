begin
  pre_ini_aplicacion;
  pae_cnf.G_COD_MODULO :=1;  
  end;
  /
insert into ge_procesos (COD_PROCESO, DESCRIPCION, NRO_ORDEN, OBLIGATORIO, TIPO, HOR_INICIO, HOR_FIN, COD_USUARIO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, ERROR, PERMISO, UBI_DESTINO)
values (191, 'Informe Diario cidesa', 1, 'N', 'P', null, null, null, 'IT', to_date('30-10-2024 14:59:20', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('30-10-2024 14:59:20', 'dd-mm-yyyy hh24:mi:ss'), null, null, null);

commit;
