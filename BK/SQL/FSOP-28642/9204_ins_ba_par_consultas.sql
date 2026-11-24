begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/
--
insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('PRODEPLOG', 'NRO_CUENTA', null, null, 'F', 'RBARRIOS', to_date('28-12-2023 09:39:28', 'dd-mm-yyyy hh24:mi:ss'), 'RBARRIOS', to_date('28-12-2023 09:39:28', 'dd-mm-yyyy hh24:mi:ss'), 1, 'V', 'S', 'N', null);

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('PRODEPLOG', 'NRO_REFE', null, null, 'F', 'RBARRIOS', to_date('28-12-2023 09:45:29', 'dd-mm-yyyy hh24:mi:ss'), 'RBARRIOS', to_date('28-12-2023 09:49:22', 'dd-mm-yyyy hh24:mi:ss'), 2, 'V', 'S', 'N', null);

commit;
/