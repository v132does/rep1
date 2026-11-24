BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
insert into ba_rep_programas (COD_PROGRAMA, COD_PRO_REPORTE, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('BMGENREM', 'BLRECDIN', 'IT', to_date('26-12-2023 16:32:50', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('26-12-2023 16:32:50', 'dd-mm-yyyy hh24:mi:ss'));

commit;
