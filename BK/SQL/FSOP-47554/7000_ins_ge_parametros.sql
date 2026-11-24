begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('LIM_MTO_DIA_DEP_GRAL_PRO_WP', 'LIMITE MONTO DIARIO DEPOSITO GRAL', 'GE_PAR_DINAMICOS', 'Utilizado para controlar el l?mite diario de depositos en gral wepa', 'N');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('LIM_MTO_DIA_EXT_GRAL_PRO_WP', 'LIMITE MONTO DIARIO EXTRACCION GRAL', 'GE_PAR_DINAMICOS', 'Utilizado para controlar el l?mite diario de extracciones en gral wepa', 'N');

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('PAR_CAN_OPE_DEP_PRO_WP', 'CANTIDAD OPE DEP WEPA', 'GE_PAR_DINAMICOS', 'CANTIDAD DE OPERACIONES PERMITIDAS EN WEPA', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, OBSERVACION, MODIFICABLE)
values ('PAR_CAN_OPE_EXT_PRO_WP', 'CANTIDAD OPE EXT WEPA', 'GE_PAR_DINAMICOS', 'CANTIDAD DE OPERACIONES PERMITIDAS EN WEPA', null);

commit;
