begin
  pre_ini_aplicacion;
  pae_cnf.G_COD_MODULO :=1;
  end;
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_CIERRE', 'Usuario Mov. Cierre', to_date('21-11-2025 08:25:04', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('21-11-2025 08:25:04', 'dd-mm-yyyy hh24:mi:ss'), 'MOVCIERRE', '0', 'MOVCIERRE', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_CIERRE', 'Usuario Mov. Cierre 1', to_date('21-11-2025 08:25:04', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('21-11-2025 08:25:04', 'dd-mm-yyyy hh24:mi:ss'), 'MOVCIERRE1', '1', 'MOVCIERRE', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_MOV_CIERRE', 'Usuario Mov. Cierre 2', to_date('21-11-2025 08:25:04', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('21-11-2025 08:25:34', 'dd-mm-yyyy hh24:mi:ss'), 'MOVCIERRE2', '2', 'MOVCIERRE', 'S');

commit;