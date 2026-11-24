BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
insert into wf_tip_cir_tar_sig (COD_TIP_CIRCUITO, COD_TIP_TAREA, COD_TIP_TAR_SIGUIENTE, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, TAR_EXCEPCION)
values (14, 0, 1, 'Verificación de estado', 'IT', to_date('05-06-2024 16:28:17', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('05-06-2024 16:28:17', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
