BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
--Parámetros
--Configuracion para operacion de Retención Deposito en efectivo TEDs
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('COD_RET_DEP_EFE_TED', 'CODIGO RET. DEPOSITO EFECTIVO TED', 'GE_CTA_DEF_ADICIONALES', 'RET_DEP_EFE_TED', 'Se configura el Codigo de Retencion para el deposito en efectivo ', null, null, 'IT', to_date('04-05-2023 13:36:37', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('25-05-2023 16:20:20', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_RET_DEP_TED', 'Conf. de Ret. Dep. Efectivo TEDs', 'GE_PAR_DINAMICOS', null, 'Configuracion para operacion de Retención Deposito en efectivo TEDs', null, null, 'IT', to_date('26-04-2022 08:34:13', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('26-04-2022 08:34:13', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('COD_TRA_CTA_TED_DP_EF_TED_RET', 'Cod Tran CTA TED Dep Efe TEDs RET', 'GE_PAR_DINAMICOS', null, 'Conf de Cod Transaccion CTA TED para Deposito en efectivo TEDs RET', null, null, 'IT', to_date('03-05-2023 10:17:36', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-05-2023 10:17:36', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('COD_TRA_HIJO_DEP_EFE_TED_RET', 'Cod Tran HIJO Dep Efe TEDs RET', 'GE_PAR_DINAMICOS', null, 'Conf de Cod Transaccion HIJO para Deposito en efectivo TEDs Retencion', null, null, 'IT', to_date('03-05-2023 10:06:37', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-05-2023 10:06:37', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('COD_TRA_PADRE_DEP_EFE_TED_RET', 'Cod Tran Padre Dep Efe TEDs RET', 'GE_PAR_DINAMICOS', null, 'Conf de Cod Transaccion Padre para Deposito en efectivo TEDs Con Retencion', null, null, 'IT', to_date('03-05-2023 10:03:56', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-05-2023 10:03:56', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_OPE_DEP_RET', 'Conf. de Cod. Ope a retener en TED', 'GE_PAR_DINAMICOS', null, 'Configuracion de Cod. Oper a aplicar retencion', null, null, 'IT', to_date('29-05-2023 17:58:36', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('29-05-2023 17:58:36', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_TIP_PERSONA', 'Conf valores de tipos de personas', 'GE_PAR_DINAMICOS', null, 'Configuracion de tipos de personas utilizados en el TED', null, null, 'IT', to_date('29-05-2023 17:55:47', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('29-05-2023 17:55:47', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_TRA_HIJ_EFE_LIB', 'Cod.transacción HIJ Liberacion TED', 'GE_PAR_DINAMICOS', null, 'Este parametro es cod de trans hijo de liberacion de Deposito Playero TED', null, null, 'IT', to_date('02-08-2023 16:44:08', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('02-08-2023 16:44:08', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_TRA_PAD_EFE_LIB', 'Cod. transacción PAD Liberacion TED', 'GE_PAR_DINAMICOS', null, 'Este parametro es cod de trans padre de liberacion de Deposito Playero TED', null, null, 'IT', to_date('02-08-2023 16:44:08', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('02-08-2023 16:44:08', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_COD_RET_EFE_24', 'Cod. de retencion 24 hs saldos TED', 'GE_PAR_DINAMICOS', null, 'Este parametro es cod de retencion de saldos 24 hs en Deposito efectivo Playero TED', null, null, 'IT', to_date('04-08-2023 14:27:32', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-08-2023 15:52:43', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_COD_RET_EFE_48', 'Cod. de retencion 48 hs saldos TED', 'GE_PAR_DINAMICOS', null, 'Este parametro es cod de retencion de saldos 48 hs en Deposito efectivo Playero TED', null, null, 'IT', to_date('04-08-2023 15:52:43', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-08-2023 15:52:43', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_COD_RET_EFE_72', 'Cod. de retencion 72 hs saldos TED', 'GE_PAR_DINAMICOS', null, 'Este parametro es cod de retencion de saldos 72 hs en Deposito efectivo Playero TED', null, null, 'IT', to_date('04-08-2023 15:52:43', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-08-2023 15:52:43', 'dd-mm-yyyy hh24:mi:ss'));

commit;
