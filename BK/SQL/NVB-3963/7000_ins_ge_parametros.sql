begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('CAN_MAX_DOC_FACTURY', 'CANTIDAD MAXIMA DE DOC. FACTURY', 'GE_PAR_DINAMICOS', null, 'FENCISO', to_date('16-01-2024 15:39:47', 'dd-mm-yyyy hh24:mi:ss'), 'FENCISO', to_date('16-01-2024 15:39:47', 'dd-mm-yyyy hh24:mi:ss'), 'Cantidad Maxima de Documentos pendientes generados de Factury', null, null, 'N', null);


commit;