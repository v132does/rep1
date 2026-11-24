BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
insert into wf_tip_cir_tareas (COD_TIP_CIRCUITO, COD_TIP_TAREA, DESCRIPCION, DETALLE, ESTADO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_GRU_RESPONSABLE, COD_TIP_TAR_SIGUIENTE, COD_TIP_TAR_RECHAZO, CAN_FIR_REQUERIDAS, AUT_CONJUNTA, TIP_TIEMPO, TIE_ESTIMADO, TIP_ETI_SIGUIENTE, TIP_ETI_RECHAZO, TIP_ETI_CANCELACION, DET_SQL, ACT_AUTOMATICA, ASI_RESPONSABLE, ENV_MAIL, COD_TIP_LIMITE, VE_USUARIO)
values (14, 0, 'VERIFICAR EL ESTADO DE LA CUENTA', 'Verificar y  si corresponde, actualizar el estado de la cuenta para que pueda recibir créditos. O modificar la vinculación para que no figure como cuenta de crédito en un CDA, por ejemplo.', 'A', 'IT', to_date('29-05-2024 16:05:08', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('29-05-2024 16:05:08', 'dd-mm-yyyy hh24:mi:ss'), '600', null, null, 1, 'N', 'H', null, 'A', 'R', 'C', null, 'N', null, 'N', null, 'N');

insert into wf_tip_cir_tareas (COD_TIP_CIRCUITO, COD_TIP_TAREA, DESCRIPCION, DETALLE, ESTADO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_GRU_RESPONSABLE, COD_TIP_TAR_SIGUIENTE, COD_TIP_TAR_RECHAZO, CAN_FIR_REQUERIDAS, AUT_CONJUNTA, TIP_TIEMPO, TIE_ESTIMADO, TIP_ETI_SIGUIENTE, TIP_ETI_RECHAZO, TIP_ETI_CANCELACION, DET_SQL, ACT_AUTOMATICA, ASI_RESPONSABLE, ENV_MAIL, COD_TIP_LIMITE, VE_USUARIO)
values (14, 1, 'VERIFICAR ESTADO DE LA CUENTA PARA CRÉDITO', null, 'A', 'IT', to_date('05-06-2024 16:19:51', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('05-06-2024 16:19:51', 'dd-mm-yyyy hh24:mi:ss'), '600', null, 0, 1, 'N', 'H', null, 'A', 'R', 'C', null, 'N', null, 'N', null, 'N');

commit;
