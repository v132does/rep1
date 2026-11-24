BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('TIP_COM_VENTA', 'RECIBO', to_date('03-05-2021 19:47:21', 'dd-mm-yyyy hh24:mi:ss'), 'F', 'F', to_date('03-05-2021 19:47:21', 'dd-mm-yyyy hh24:mi:ss'), 'B', '3', 'RECIBO', 'S');

commit;
