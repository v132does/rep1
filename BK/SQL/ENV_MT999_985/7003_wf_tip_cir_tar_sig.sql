begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into wf_tip_cir_tar_sig (COD_TIP_CIRCUITO, COD_TIP_TAREA, COD_TIP_TAR_SIGUIENTE, DESCRIPCION, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, TAR_EXCEPCION)
values (995, 0, 1, 'Autorización de MT encaje especial', USER, SYSDATE, USER, SYSDATE, null);

commit;
