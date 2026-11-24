BEGIN pre_ini_aplicacion; END; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO, REFERENCIA)
values ('PRE_CHE_ROG_VAL_DIVISOR', 'DIVISOR A USAR FORMULA IVA CHE ROGA', 'GE_PAR_DINAMICOS', 'Divisor utilizado para el IVA en los prestamos correspondiente a CHE ROGA PORA
valor actual = 1,005', null, null, 'N', null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO, REFERENCIA)
values ('PRE_CHE_ROG_POR_IVA_CAL', 'PORCENTAJE INT. P/ CALCULO IVA CRP', 'GE_PAR_DINAMICOS', 'Porcentaje del interés a utilizar para el calculo del IVA en los prestamos correspondiente a CHE ROGA PORA
valor actual = 10%', null, null, 'N', null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO, REFERENCIA)
values ('PRE_CHE_ROG_POR_EXE_CAL', 'PORCENTAJE INT. P/ CAL. EXENTO CRP', 'GE_PAR_DINAMICOS', 'Porcentaje del interés a utilizar para el calculo del EXENTO en los prestamos correspondiente a CHE ROGA PORA
valor actual = 90%', null, null, 'N', null, null);

commit;
