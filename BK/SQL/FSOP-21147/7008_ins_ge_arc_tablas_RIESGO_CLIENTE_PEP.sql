BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/

insert into GE_ARC_TABLAS (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR, USU_MODIFICACION, FEC_MODIFICACION, USU_INSERCION, FEC_INSERCION)
values ('RIESGO_CLIENTE_PEP', 'TM_CLIENTE_PEP', 'CLIENTESPEP.CSV', 1, 'S', 'IT', to_date('17-12-2021 01:11:46', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('17-12-2021 01:11:46', 'dd-mm-yyyy hh24:mi:ss'));

commit;
