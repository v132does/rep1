begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into wf_tip_cir_taR_SIG (COD_TIP_CIRCUITO, COD_TIP_TAREA, COD_TIP_TAR_SIGUIENTE, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, TAR_EXCEPCION)
values (400, 0, 1, 'NOTIF. Y COMUNICACION AL CLIENTE', 'IT', to_date('11-02-2025 11:58:05', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('11-02-2025 11:58:05', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into wf_tip_cir_taR_SIG (COD_TIP_CIRCUITO, COD_TIP_TAREA, COD_TIP_TAR_SIGUIENTE, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, TAR_EXCEPCION)
values (400, 1, 2, 'CANCELACION DE LA CUENTA', 'IT', to_date('11-02-2025 11:58:05', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('11-02-2025 11:58:05', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into wf_tip_cir_taR_SIG (COD_TIP_CIRCUITO, COD_TIP_TAREA, COD_TIP_TAR_SIGUIENTE, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, TAR_EXCEPCION)
values (401, 0, 1, 'NOTIF. AL CLIENTE', 'IT', to_date('11-02-2025 11:58:05', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('11-02-2025 11:58:05', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into wf_tip_cir_taR_SIG (COD_TIP_CIRCUITO, COD_TIP_TAREA, COD_TIP_TAR_SIGUIENTE, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, TAR_EXCEPCION)
values (401, 1, 2, 'CANCELACION DE LA CUENTA', 'IT', to_date('11-02-2025 11:58:06', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('11-02-2025 11:58:06', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into wf_tip_cir_taR_SIG (COD_TIP_CIRCUITO, COD_TIP_TAREA, COD_TIP_TAR_SIGUIENTE, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, TAR_EXCEPCION)
values (402, 0, 1, 'NOTIF. AL CLIENTE', 'IT', to_date('11-02-2025 11:58:06', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('11-02-2025 11:58:06', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into wf_tip_cir_taR_SIG (COD_TIP_CIRCUITO, COD_TIP_TAREA, COD_TIP_TAR_SIGUIENTE, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, TAR_EXCEPCION)
values (402, 1, 2, 'CANCELACION DE LA CUENTA', 'IT', to_date('11-02-2025 11:58:06', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('11-02-2025 11:58:06', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
