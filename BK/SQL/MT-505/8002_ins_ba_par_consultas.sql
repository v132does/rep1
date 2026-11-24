BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_CHQ_TED', 'ATM_ID', 'A', null, 'F', 'IT', to_date('12-12-2024 14:19:58', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('18-12-2024 08:09:23', 'dd-mm-yyyy hh24:mi:ss'), 1, 'V', 'S', 'N', null);

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_CHQ_TED', 'ESTADO_CH', 'A', null, 'F', 'IT', to_date('08-01-2025 15:59:04', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('08-01-2025 15:59:04', 'dd-mm-yyyy hh24:mi:ss'), 4, 'V', 'S', 'N', null);

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_CHQ_TED', 'NRO_DOC_ID', 'A', null, 'F', 'IT', to_date('12-12-2024 14:19:58', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('18-12-2024 08:09:24', 'dd-mm-yyyy hh24:mi:ss'), 2, 'V', 'S', 'N', null);

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_CHQ_TED', 'FECHA', 'A', null, 'F', 'IT', to_date('08-01-2025 14:20:41', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('08-01-2025 14:20:41', 'dd-mm-yyyy hh24:mi:ss'), 3, 'V', 'S', 'N', null);

commit;
