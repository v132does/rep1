begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
--REL_EQUIFAX_TC
delete from ba_cod_referencias where dominio= 'REL_EQUIFAX_TC';
/
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('REL_EQUIFAX_TC', 'Relación de tipos de Tarjetas entre el banco y Equifax', to_date('25-04-2025 08:51:08', 'dd-mm-yyyy hh24:mi:ss'), 'LMENDOZA', 'UGENERICO', to_date('28-04-2025 14:03:02', 'dd-mm-yyyy hh24:mi:ss'), '505', 'VI', 'Visa', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('REL_EQUIFAX_TC', 'Relación de tipos de Tarjetas entre el banco y Equifax', to_date('28-04-2025 13:27:04', 'dd-mm-yyyy hh24:mi:ss'), 'LMENDOZA', 'UGENERICO', to_date('28-04-2025 14:03:02', 'dd-mm-yyyy hh24:mi:ss'), '506', 'VI', 'Visa', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('REL_EQUIFAX_TC', 'Relación de tipos de Tarjetas entre el banco y Equifax', to_date('25-04-2025 08:51:08', 'dd-mm-yyyy hh24:mi:ss'), 'LMENDOZA', 'LMENDOZA', to_date('25-04-2025 08:51:08', 'dd-mm-yyyy hh24:mi:ss'), '507', 'MC', 'Mastercard', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('REL_EQUIFAX_TC', 'Relación de tipos de Tarjetas entre el banco y Equifax', to_date('28-04-2025 14:05:08', 'dd-mm-yyyy hh24:mi:ss'), 'UGENERICO', 'UGENERICO', to_date('28-04-2025 14:05:08', 'dd-mm-yyyy hh24:mi:ss'), '51', 'VI', 'Visa', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('REL_EQUIFAX_TC', 'Relación de tipos de Tarjetas entre el banco y Equifax', to_date('07-04-2017 16:28:02', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'UGENERICO', to_date('28-04-2025 14:03:03', 'dd-mm-yyyy hh24:mi:ss'), '52', 'MC', 'Mastercard', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('REL_EQUIFAX_TC', 'Relación de tipos de Tarjetas entre el banco y Equifax', to_date('07-04-2017 16:28:02', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'UGENERICO', to_date('28-04-2025 14:03:03', 'dd-mm-yyyy hh24:mi:ss'), '53', 'MC', 'Mastercard', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('REL_EQUIFAX_TC', 'Relación de tipos de Tarjetas entre el banco y Equifax', to_date('07-04-2017 16:28:02', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'UGENERICO', to_date('28-04-2025 14:03:04', 'dd-mm-yyyy hh24:mi:ss'), '54', 'MC', 'Mastercard', 'S');

insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('REL_EQUIFAX_TC', 'Relación de tipos de Tarjetas entre el banco y Equifax', to_date('07-04-2017 16:28:02', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'UGENERICO', to_date('28-04-2025 14:03:04', 'dd-mm-yyyy hh24:mi:ss'), '55', 'MC', 'Mastercard', 'S');


commit;