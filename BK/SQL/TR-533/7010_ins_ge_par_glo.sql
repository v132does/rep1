Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/ 
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_AUT_RENOVACION', 'Auto renovacion', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), '0 no renueva, 1 si.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_BON_TARJETA', 'Bonificacion de tarjeta', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'Bonificacion de tarjeta', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_CARTERA', 'Cartera', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'Cartera CrediCentro, seg?n parametr?a', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_CARTERA_TC', 'Cartera de Credito GP', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'Cartera de Credito GP', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_CIERRE', 'Cierre', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'Depender? del grupo que desee enviar la entidad. El grupo 6 es para prepagas y en el caso de Credicentro tiene el grupo 50- CICLO 4/Credicentro', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_COD_LIMITE', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:13', 'dd-mm-yyyy hh24:mi:ss'), 'L?mite General, seg?n parametr?a', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_COD_SUCURSAL', 'Codigo de Sucursal Global', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'Codigo de Sucursal Global', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_COM_SEG_DESEMPLEO', 'Compania de seguros', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'Sin seguro de desempleo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_COM_SEG_VIDA', 'Compania seguro vida', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'Sin seguro de vida', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_DGI_POSICION', 'Dgi posicion', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'Sin informar', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_DUR_TARJETA', 'Duracion de tarjeta', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'En meses', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_EST_CLIENTE', 'Estado del cliente', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'Activo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_GRU_AFINIDAD', 'Grupo Afinidad Prepaga', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:14', 'dd-mm-yyyy hh24:mi:ss'), 'Grupo Afinidad Prepaga', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_GRU_AFI_TAR_CREDITO', 'Grupo Afinidad Tarjeta Credito GLP', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('13-05-2024 11:27:15', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:15', 'dd-mm-yyyy hh24:mi:ss'), 'Grupo Afinidad Tarjeta Credito GLP', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_LIMITE', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:15', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:15', 'dd-mm-yyyy hh24:mi:ss'), 'L?mite de compra.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_NACIONALIDAD', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:15', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:15', 'dd-mm-yyyy hh24:mi:ss'), '32 para Argentina /600 Paraguaya', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_20_TIP_EMI_RESUMEN', 'Tipo emision resumen', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:27:15', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:27:15', 'dd-mm-yyyy hh24:mi:ss'), 'Tipo emision resumen', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_AUT_RENOVACION', 'Auto renovacion', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:21', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:21', 'dd-mm-yyyy hh24:mi:ss'), '0 no renueva, 1 si.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_BON_TARJETA', 'Bonificacion de tarjeta', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:21', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:21', 'dd-mm-yyyy hh24:mi:ss'), 'Bonificacion de tarjeta', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_CARTERA', 'Cartera', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:21', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:21', 'dd-mm-yyyy hh24:mi:ss'), 'Cartera CrediCentro, seg?n parametr?a', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_CARTERA_TC', 'Cartera de Credito GP', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:21', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:21', 'dd-mm-yyyy hh24:mi:ss'), 'Cartera de Credito GP', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_CIERRE', 'Cierre', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:21', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:21', 'dd-mm-yyyy hh24:mi:ss'), 'Depender? del grupo que desee enviar la entidad. El grupo 6 es para prepagas y en el caso de Credicentro tiene el grupo 50- CICLO 4/Credicentro', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_COD_LIMITE', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'L?mite General, seg?n parametr?a', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_COD_SUCURSAL', 'Codigo de Sucursal Global', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'Codigo de Sucursal Global', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_COM_SEG_DESEMPLEO', 'Compania de seguros', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'Sin seguro de desempleo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_COM_SEG_VIDA', 'Compania seguro vida', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'Sin seguro de vida', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_DGI_POSICION', 'Dgi posicion', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'Sin informar', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_DUR_TARJETA', 'Duracion de tarjeta', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'En meses', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_EST_CLIENTE', 'Estado del cliente', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:22', 'dd-mm-yyyy hh24:mi:ss'), 'Activo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_GRU_AFINIDAD', 'Grupo Afinidad Prepaga', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('13-05-2024 11:26:23', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:23', 'dd-mm-yyyy hh24:mi:ss'), 'Grupo Afinidad Prepaga', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_GRU_AFI_TAR_CREDITO', 'Grupo Afinidad Tarjeta Credito GLP', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('13-05-2024 11:26:23', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:23', 'dd-mm-yyyy hh24:mi:ss'), 'Grupo Afinidad Tarjeta Credito GLP', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_LIMITE', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:24', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:24', 'dd-mm-yyyy hh24:mi:ss'), 'L?mite de compra.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_NACIONALIDAD', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:25', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:25', 'dd-mm-yyyy hh24:mi:ss'), '32 para Argentina /600 Paraguaya', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_38_TIP_EMI_RESUMEN', 'Tipo emision resumen', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('13-05-2024 11:26:26', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('13-05-2024 11:26:26', 'dd-mm-yyyy hh24:mi:ss'), 'Tipo emision resumen', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_AUT_RENOVACION', 'Auto renovacion', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:54', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:54', 'dd-mm-yyyy hh24:mi:ss'), '0 no renueva, 1 si.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_BON_TARJETA', 'Bonificacion de tarjeta', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:54', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:54', 'dd-mm-yyyy hh24:mi:ss'), 'Bonificacion de tarjeta', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_CARTERA', 'Cartera', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:54', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:54', 'dd-mm-yyyy hh24:mi:ss'), 'Cartera CrediCentro, seg?n parametr?a', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_CARTERA_TC', 'Cartera de Credito GP', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:54', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:54', 'dd-mm-yyyy hh24:mi:ss'), 'Cartera de Credito GP', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_CIERRE', 'Cierre', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:54', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:54', 'dd-mm-yyyy hh24:mi:ss'), 'Depender? del grupo que desee enviar la entidad. El grupo 6 es para prepagas y en el caso de Credicentro tiene el grupo 50- CICLO 4/Credicentro', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_COD_LIMITE', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'L?mite General, seg?n parametr?a', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_COD_SUCURSAL', 'Codigo de Sucursal Global', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'Codigo de Sucursal Global', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_COM_SEG_DESEMPLEO', 'Compania de seguros', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'Sin seguro de desempleo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_COM_SEG_VIDA', 'Compania seguro vida', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'Sin seguro de vida', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_DGI_POSICION', 'Dgi posicion', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'Sin informar', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_DUR_TARJETA', 'Duracion de tarjeta', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:55', 'dd-mm-yyyy hh24:mi:ss'), 'En meses', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_EST_CLIENTE', 'Estado del cliente', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'Activo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_GRU_AFINIDAD', 'Grupo Afinidad Prepaga', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'Grupo Afinidad Prepaga', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_GRU_AFI_TAR_CREDITO', 'Grupo Afinidad Tarjeta Credito GLP', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'Grupo Afinidad Tarjeta Credito GLP', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_LIMITE', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'L?mite de compra.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_NACIONALIDAD', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), '32 para Argentina /600 Paraguaya', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_57_TIP_EMI_RESUMEN', 'Tipo emision resumen', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('16-05-2024 17:26:56', 'dd-mm-yyyy hh24:mi:ss'), 'Tipo emision resumen', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_AUT_RENOVACION', 'Auto renovacion', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:28', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:28', 'dd-mm-yyyy hh24:mi:ss'), '0 no renueva, 1 si.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_BON_TARJETA', 'Bonificacion de tarjeta', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:28', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:28', 'dd-mm-yyyy hh24:mi:ss'), 'Bonificacion de tarjeta', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_CARTERA', 'Cartera', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:28', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:28', 'dd-mm-yyyy hh24:mi:ss'), 'Cartera CrediCentro, seg?n parametr?a', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_CARTERA_TC', 'Cartera de Credito GP', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'Cartera de Credito GP', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_CIERRE', 'Cierre', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'Depender? del grupo que desee enviar la entidad. El grupo 6 es para prepagas y en el caso de Credicentro tiene el grupo 50- CICLO 4/Credicentro', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_COD_LIMITE', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'L?mite General, seg?n parametr?a', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_COD_SUCURSAL', 'Codigo de Sucursal Global', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'Codigo de Sucursal Global', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_COM_SEG_DESEMPLEO', 'Compania de seguros', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'Sin seguro de desempleo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_COM_SEG_VIDA', 'Compania seguro vida', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'Sin seguro de vida', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_DGI_POSICION', 'Dgi posicion', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'Sin informar', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_DUR_TARJETA', 'Duracion de tarjeta', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:29', 'dd-mm-yyyy hh24:mi:ss'), 'En meses', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_EST_CLIENTE', 'Estado del cliente', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'Activo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_GRU_AFINIDAD', 'Grupo Afinidad Prepaga', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'Grupo Afinidad Prepaga', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_GRU_AFI_TAR_CREDITO', 'Grupo Afinidad Tarjeta Credito GLP', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'Grupo Afinidad Tarjeta Credito GLP', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_LIMITE', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'L?mite de compra.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_NACIONALIDAD', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), '32 para Argentina /600 Paraguaya', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_58_TIP_EMI_RESUMEN', 'Tipo emision resumen', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:17:30', 'dd-mm-yyyy hh24:mi:ss'), 'Tipo emision resumen', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_AUT_RENOVACION', 'Auto renovacion', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:22', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:22', 'dd-mm-yyyy hh24:mi:ss'), '0 no renueva, 1 si.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_BON_TARJETA', 'Bonificacion de tarjeta', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'Bonificacion de tarjeta', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_CARTERA', 'Cartera', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'Cartera CrediCentro, seg?n parametr?a', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_CARTERA_TC', 'Cartera de Credito GP', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'Cartera de Credito GP', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_CIERRE', 'Cierre', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'Depender? del grupo que desee enviar la entidad. El grupo 6 es para prepagas y en el caso de Credicentro tiene el grupo 50- CICLO 4/Credicentro', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_COD_LIMITE', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'L?mite General, seg?n parametr?a', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_COD_SUCURSAL', 'Codigo de Sucursal Global', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'Codigo de Sucursal Global', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_COM_SEG_DESEMPLEO', 'Compania de seguros', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'Sin seguro de desempleo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_COM_SEG_VIDA', 'Compania seguro vida', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:23', 'dd-mm-yyyy hh24:mi:ss'), 'Sin seguro de vida', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_DGI_POSICION', 'Dgi posicion', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'Sin informar', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_DUR_TARJETA', 'Duracion de tarjeta', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'En meses', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_EST_CLIENTE', 'Estado del cliente', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'Activo', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_GRU_AFINIDAD', 'Grupo Afinidad Prepaga', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'Grupo Afinidad Prepaga', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_GRU_AFI_TAR_CREDITO', 'Grupo Afinidad Tarjeta Credito GLP', 'GE_PAR_ENTES', null, 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'Grupo Afinidad Tarjeta Credito GLP', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_LIMITE', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'L?mite de compra.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_NACIONALIDAD', 'Limite', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), '32 para Argentina /600 Paraguaya', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('GLO_59_TIP_EMI_RESUMEN', 'Tipo emision resumen', 'GE_PAR_ENTES', 'TA', 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'AAGUILERA', to_date('09-05-2024 11:04:24', 'dd-mm-yyyy hh24:mi:ss'), 'Tipo emision resumen', null, null, 'N', null);

commit;
