Begin pre_ini_aplicacion; end; 
/
insert into ge_causales (COD_CAUSA, DESCRIPCION, TIPO, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values (927, 'BLOQUEO DE SALDOS DESEM. COM. DEUDA', 'B', 'IT', to_date('07-10-2024 15:04:20', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('07-10-2024 15:04:20', 'dd-mm-yyyy hh24:mi:ss'));

commit;
