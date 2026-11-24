Begin pre_ini_aplicacion; end; 
/
insert into ge_tasas (COD_TASA, DESCRIPCION, TIP_VALOR, TIPO, APLICAR, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, COD_MON_BASE)
values (580, 'SEGURO DESEMPLEO Y HOSPITALIZACIÓN', 'P', 'V', 'MO', 'IT', to_date('20-09-2024 14:19:58', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('20-09-2024 14:19:58', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
