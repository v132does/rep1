BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COB_CARGO_ME', 'COBRO DE CARGO MON.EXTRANJERA', 'GE_PAR_DINAMICOS', null, user, sysdate, user, sysdate, 'Se utiliza para verificar si se cobra comisión por depósitos efectivo en moneda extranjera. Se aplica a determinados segmentos de clientes.', null, null, 'N', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('COB_CARGO_ME', 'N', null, null, null, null, user, sysdate, user, sysdate, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('COB_CARGO_TRX_ME', 'TRANSACCION DE CARGO MON.EXTRANJERA', 'GE_PAR_DINAMICOS', null, user, sysdate, user, sysdate, 'Se utiliza para identificar la transación para cobro de comisión por depósitos efectivo en moneda extranjera.', null, null, 'N', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('COB_CARGO_TRX_ME', '5069', null, null, null, null, user, sysdate, user, sysdate, null);

commit;
