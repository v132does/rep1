Begin pre_ini_aplicacion; end; 
/
insert into ge_parametros (PARAMETRO, DESCRIPCION, TAB_RELACION, REFERENCIA, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, OBSERVACION, PRO_VERIFICACION, PERMISO, MODIFICABLE, VAL_DEFECTO)
values ('PRE_VER_MAD_LIN_PER', 'IND. DE CONTROL DE LINEA MODALIDAD', 'GE_PAR_DINAMICOS', null, 'IT', to_date('04-04-2025 17:28:25', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('04-04-2025 17:28:25', 'dd-mm-yyyy hh24:mi:ss'), 'Indica si la modalidad controlara que la persona tenga una Linea de Credito disponible.', null, null, 'N', null);

commit;
