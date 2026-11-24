begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
insert into wf_tip_cir_tar_sig (COD_TIP_CIRCUITO, COD_TIP_TAREA, COD_TIP_TAR_SIGUIENTE, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, TAR_EXCEPCION)
values (167, 0, 1, 'INICIO DE GESTION DE TOPE DE CUENTA BAJO RIESGO', 'IT', to_date('03-02-2025 15:32:39', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-02-2025 15:32:39', 'dd-mm-yyyy hh24:mi:ss'), null);

insert into wf_tip_cir_tar_sig (COD_TIP_CIRCUITO, COD_TIP_TAREA, COD_TIP_TAR_SIGUIENTE, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, TAR_EXCEPCION)
values (167, 1, 2, 'GESTION DE TOPE DE CUENTA BAJO RIESGO', 'IT', to_date('03-02-2025 15:32:39', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('03-02-2025 15:32:39', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
