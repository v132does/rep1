begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_DEFECTO, MODIFICABLE)
values ('CC_ACT_REC_AUT', 'ACTIVAR RECHAZO AUTOMATICO', 'GE_PAR_DINAMICOS', null, 'Activar el Rechazo Automático de Cheques', null, null, 'IT', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), null, null);

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CAJ_COD_CAM_OPCION', 'Cod. de opcion para campo', 'GE_PAR_DINAMICOS', null, 'Se utiliza identificar los campos de transacciones de caja correspondientes a opciones, mediante el valor de la columna observacion en ge_tra_campos', null, null, 'N', null);

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CAJ_COD_OPC', 'Cod. de mensaje para Opcion', 'GE_PAR_DINAMICOS', null, 'Se utiliza para identificar el código de mensaje correspondiente para desplegar una ventana de Opción SI/NO.', null, null, 'N', null);

insert into it.ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CAJ_COD_OPC_CUSTOM', 'Cod. de mensaje para Opcion Custom', 'GE_PAR_DINAMICOS', null, 'Se utiliza para identificar el código de mensaje correspondiente para desplegar una ventana de Opción personalizada con diferentes opciones.', null, null, 'N', null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_DEFECTO, MODIFICABLE)
values ('COD_CAU_BLO_CTA_IF', 'Bloqueo Cta. por Insuf. Fondos', 'GE_PAR_DINAMICOS', null, 'Cod. de causa de bloqueo de Cta. por Insuf. de Fondos', null, null, 'IT', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_DEFECTO, MODIFICABLE)
values ('CAN_DIAS_BLOQUEO', 'Bloqueo Cta. por Insuf. Fondos', 'GE_PAR_DINAMICOS', null, 'Cant. de días para finalizacion de bloqueo de Cta. por Insuf. de Fondos', null, null, 'IT', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_DEFECTO, MODIFICABLE)
values ('COD_CAU_INH_BLO_CTA', 'Bloqueo Cta. por Inhibicion', 'GE_PAR_DINAMICOS', null, 'Cod. de causas de inhibicion a ser verif. para el bloqueo de cta por ch. devueltos', null, null, 'IT', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('27-01-2025 11:45:35', 'dd-mm-yyyy hh24:mi:ss'), null, null);

insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('FEC_INH_AUTOMATICA', 'Fec. implementacion proc. Inh. aut.', 'GE_PAR_DINAMICOS', null, 'Esta fecha se utiliza en el proceso de automatizacion de inhibicion de Ctas. Ctes.', null, null, null, null);

commit;  
