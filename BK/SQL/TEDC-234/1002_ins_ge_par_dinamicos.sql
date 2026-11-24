---Parámetro dinámico
BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ge_par_dinamicos (PARAMETRO, VAL_PARAMETRO, COD_MODULO, COD_MODALIDAD, COD_OFICINA, COD_MONEDA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CJ_OPE_TED_UMB', '68', null, null, null, null, 'IT', to_date('29-04-2021 18:40:50', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('05-05-2022 09:00:12', 'dd-mm-yyyy hh24:mi:ss'));
