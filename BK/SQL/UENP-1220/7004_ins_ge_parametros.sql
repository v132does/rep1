BEGIN pre_ini_aplicacion; END; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO, REFERENCIA)
values ('PRE_CHE_ROG_VAL_DIVISOR', 'DIVISOR A USAR FORMULA IVA CHE ROGA', 'GE_PAR_DINAMICOS', 'Divisor utilizado para el IVA en los prestamos correspondiente a CHE ROGA PORA
valor actual = 1', null, null, 'N', null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO, REFERENCIA)
values ('PRE_CHE_ROG_POR_IVA_CAL', 'PORCENTAJE INT. P/ CALCULO IVA CRP', 'GE_PAR_DINAMICOS', 'Porcentaje del interés a utilizar para el calculo del IVA en los prestamos correspondiente a CHE ROGA PORA
valor actual = 10%', null, null, 'N', null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO, REFERENCIA)
values ('PRE_CHE_ROG_POR_EXE_CAL', 'PORCENTAJE INT. P/ CAL. EXENTO CRP', 'GE_PAR_DINAMICOS', 'Porcentaje del interés a utilizar para el calculo del EXENTO en los prestamos correspondiente a CHE ROGA PORA
valor actual = 90%', null, null, 'N', null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_CHE_ROG_VAL_DIV_GTO_ADM', 'DIVISOR A USAR FORMULA IVA CHE ROGA', 'GE_PAR_DINAMICOS', null, 'IT', to_date('20-08-2024 13:52:28', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('20-08-2024 13:52:28', 'dd-mm-yyyy hh24:mi:ss'), 'Divisor utilizado para el IVA para gastos administrativos en los prestamos correspondiente a CHE ROGA PORA
valor actual = 1,005', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_TRA_EXE_CHE_ROGA', 'TRANSACCION EXENTO PARA CHE ROGA', 'GE_PAR_DINAMICOS', null, 'Parámetro creado para identificar la transacción exento de IVA para che roga pora.', null, null, 'N', null);


commit;
