BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_ret_monedas (COD_RETENCION, COD_MONEDA, CAN_DIAS, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (10, 'GS', 1, 'IT', to_date('21-06-2023 11:40:03', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('21-06-2023 11:40:03', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_ret_monedas (COD_RETENCION, COD_MONEDA, CAN_DIAS, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (11, 'GS', 2, 'IT', to_date('21-06-2023 11:40:03', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('21-06-2023 11:40:03', 'dd-mm-yyyy hh24:mi:ss'));

insert into ge_ret_monedas (COD_RETENCION, COD_MONEDA, CAN_DIAS, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (12, 'GS', 3, 'IT', to_date('21-06-2023 11:40:03', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('21-06-2023 11:40:03', 'dd-mm-yyyy hh24:mi:ss'));

commit;
