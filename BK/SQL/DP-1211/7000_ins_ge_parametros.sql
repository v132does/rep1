begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('MTO_MIN_MAXIMIZAR', 'MONTO MINIMO A MAXIMIZAR', 'GE_PAR_DINAMICOS', null, USER, SYSDATE, USER, SYSDATE, 'Se utiliza para definir el monto minimo para maximizar o no cargos, se aplica por modalidad', null, null, 'N', null);

commit;
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('MTO_MIN_MAXIMIZAR', '500000', null, 602, null, 'GS', user, sysdate, user, sysdate, null);

commit;

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CUO_MIN_MAXIMIZAR', 'CUOTA MINIMA A MAXIMIZAR', 'GE_PAR_DINAMICOS', null, USER, SYSDATE, USER, SYSDATE, 'Se utiliza para definir la cuota minima para maximizar o no cargos, se aplica por modalidad', null, null, 'N', null);

commit;
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CUO_MIN_MAXIMIZAR', '1', null, 602, null, null, user, sysdate, user, sysdate, null);

commit;
