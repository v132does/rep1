BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_CIERRE', 'Usuario de Cierre', to_date('26-07-2024 10:27:56', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('26-07-2024 10:27:56', 'dd-mm-yyyy hh24:mi:ss'), 'JNICORA', 'JNICORA', 'JNICORA', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_CIERRE', 'Usuario de Cierre', to_date('26-07-2024 10:27:57', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('26-07-2024 10:27:57', 'dd-mm-yyyy hh24:mi:ss'), 'GUGODOY', 'GUGODOY', 'GUGODOY', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_CIERRE', 'Usuario de Cierre', to_date('26-07-2024 10:27:57', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('26-07-2024 10:27:57', 'dd-mm-yyyy hh24:mi:ss'), 'DINSFRAN', 'DINSFRAN', 'DINSFRAN', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_CIERRE', 'Usuario de Cierre', to_date('26-07-2024 10:27:57', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('26-07-2024 10:27:57', 'dd-mm-yyyy hh24:mi:ss'), 'EDOLDAN', 'EDOLDAN', 'EDOLDAN', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_CIERRE', 'Usuario de Cierre', to_date('26-07-2024 10:27:57', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('26-07-2024 10:27:57', 'dd-mm-yyyy hh24:mi:ss'), 'APICAJERO', 'APICAJERO', 'APICAJERO', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('USU_CIERRE', 'Usuario de Cierre', to_date('26-07-2024 10:27:57', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('26-07-2024 10:27:57', 'dd-mm-yyyy hh24:mi:ss'), 'DGUERRENO', 'DGUERRENO', 'DGUERRENO', 'S');

commit;
