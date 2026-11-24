begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_arc_campos (REFERENCIA, NOM_TABLA, ARCHIVO, NRO_SECUENCIA, DESCRIPCION, TIP_DATO, FORMATO, POS_INICIAL, LONGITUD, POS_DECIMAL, CAMPO, FUNCION, USU_MODIFICACION, FEC_MODIFICACION, USU_INSERCION, FEC_INSERCION, SALTAR)
values ('PER_CUMPLIMIENTO', 'GE_PER_CUMPLIMIENTO_TMP', 'PER_CUMPLIMIENTO.CSV', 1, 'CODIGO DE PERSONA', 'VARCHAR2', null, null, 10, null, 'COD_PERSONA', null, 'CURIARTE', to_date('26-06-2024 16:37:41', 'dd-mm-yyyy hh24:mi:ss'), 'CURIARTE', to_date('26-06-2024 13:32:17', 'dd-mm-yyyy hh24:mi:ss'), null);

commit;
