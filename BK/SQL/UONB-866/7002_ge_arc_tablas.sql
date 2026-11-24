begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
insert into ge_arc_tablas (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, BORRAR, USU_MODIFICACION, FEC_MODIFICACION, USU_INSERCION, FEC_INSERCION)
values ('PER_WORKFLOW', 'GE_PER_WORKFLOW_TMP', 'PER_WORKFLOW.CSV', 1, 'S', 'CURIARTE', to_date('26-06-2024 16:37:07', 'dd-mm-yyyy hh24:mi:ss'), 'CURIARTE', to_date('26-06-2024 12:01:25', 'dd-mm-yyyy hh24:mi:ss'));

commit;
