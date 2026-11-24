Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CAN_DIA_SAL_CIE_GP','Espera dias saldos cierre', 'GE_PAR_DINAMICOS', null, null, to_date('04-01-2024 14:59:20', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 14:59:20', 'dd-mm-yyyy hh24:mi:ss'), 'Espera dias para ins saldos cierre GP', null, null, 'N', null);

insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_SUB_MODALIDAD)
values ('CAN_DIA_SAL_CIE_GP', '2', null, null, null, null, null, to_date('04-01-2024 15:04:25', 'dd-mm-yyyy hh24:mi:ss'), null, to_date('04-01-2024 15:04:25', 'dd-mm-yyyy hh24:mi:ss'), null);
commit;
