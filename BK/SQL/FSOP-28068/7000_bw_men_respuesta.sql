begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
/
insert into bw_men_respuesta (NOMBRE, DES_MENSAJE, ERROR, FEC_INSERCION, USU_INSERCION, FEC_MODIFICACION, USU_MODIFICACION)
values ('331', 'Error al actualizar datos de transferencia', 'S', to_date('11-02-2024 12:32:03', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('11-02-2024 12:32:03', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON');

insert into bw_men_respuesta (NOMBRE, DES_MENSAJE, ERROR, FEC_INSERCION, USU_INSERCION, FEC_MODIFICACION, USU_MODIFICACION)
values ('329', 'Fecha de ingreso o fecha de valor de la transferencias necesarios', 'S', to_date('10-02-2024 13:31:36', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('11-02-2024 11:09:18', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON');

insert into bw_men_respuesta (NOMBRE, DES_MENSAJE, ERROR, FEC_INSERCION, USU_INSERCION, FEC_MODIFICACION, USU_MODIFICACION)
values ('330', 'Error al procesar debito en cierre. Intente mas tarde.', 'S', to_date('10-02-2024 13:31:36', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON', to_date('10-02-2024 13:31:36', 'dd-mm-yyyy hh24:mi:ss'), 'BROLON');

commit;
