BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/

insert into GE_ARC_TABLAS (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR, USU_MODIFICACION, FEC_MODIFICACION, USU_INSERCION, FEC_INSERCION)
values ('ONU_PER_FISICA', 'TM_ONU_FISICAS', 'ONU_PER_FISICA.XLS', 1, 'N', 'IT', to_date('31-05-2021 10:47:40', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('31-05-2021 10:47:40', 'dd-mm-yyyy hh24:mi:ss'));

commit;
